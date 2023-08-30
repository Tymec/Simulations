extends Node2D


@export var settings: BoidSettings
@export_group("Spawn", "spawn_")
@export var spawn_radius: float = 300
@export var spawn_show: bool = false
@export_group("", "")

@onready var compute: ComputeShader = $ComputeShader

var boid_data: PackedByteArray = PackedByteArray()
var params: PackedFloat32Array
var dispatch_size: int = 0

var prev_edge_visualize: bool = false
var update_settings_request: bool = false
var update_mouse_request: bool = false
var output_image: Image
var output_texture: ImageTexture
var color_image: Image
var color_texture: ImageTexture
@onready var particles: GPUParticles2D = $GPUParticles2D


func _ready() -> void:
	# Connect signals
	settings.settings_changed.connect(_on_settings_changed)

	# Calculate speed, edge and center
	var speed = (settings.boid_speed_min + settings.boid_speed_max) / 2
	var edge = get_viewport_rect().size
	var center = edge / 2

	# Set params
	params = PackedFloat32Array([
		edge.x, edge.y, # Edge size
		edge.x + 100, edge.y + 100, # Mouse position
		0, # Delta
	])

	# Spawn boids
	boid_data.resize(settings.boid_count * 24 + settings.predator_count * 24)
	for i in range(settings.boid_count):
		var pos = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0, spawn_radius) + center
		var vel = pos.normalized() * speed
		var fam = randi_range(1, settings.family_count + 1)
		set_boid(i, pos, vel, fam, false)

	# Spawn predators
	for i in range(settings.predator_count):
		var pos = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0, spawn_radius) + center
		var vel = pos.normalized() * settings.predator_speed
		set_boid(settings.boid_count + i, pos, vel, 0, true)

	# Create output image
	var image_size = settings.shader_image_size
	output_image = Image.create(image_size, image_size, false, Image.FORMAT_RGBAF)
	output_texture = ImageTexture.create_from_image(output_image)

	# Create color image
	color_image = Image.create(image_size, image_size, false, Image.FORMAT_RGBAF)
	color_texture = ImageTexture.create_from_image(color_image)

	# Setup particles
	particles.amount = settings.boid_count + settings.predator_count
	particles.process_material.set_shader_parameter("boid_size", settings.boid_size)
	particles.emitting = true

	# Setup buffers
	compute.register_storage_buffer("Settings", 0, 0, settings.to_byte_array())
	compute.register_storage_buffer("Params", 1, 0, params.to_byte_array())
	compute.register_storage_buffer("BoidsIn", 2, 0, boid_data)
	compute.register_storage_buffer("BoidsOut", 3, 0, boid_data)
	compute.register_texture("OutputImage", 4, image_size, image_size, output_image.get_data(), RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT)
	compute.register_texture("ColorImage", 5, image_size, image_size, color_image.get_data(), RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT)

	# Calculate dispatch size and start compute shader
	dispatch_size = ceili(float(settings.boid_count) / float(settings.WORKGROUP_SIZE))
	if compute.is_available():
		compute.execute(dispatch_size, 1, 1)

func _process(delta):
	# Check if the compute shader is available
	if not compute.is_available():
		return

	# Wait for the compute shader to finish
	compute.wait()

	# Retrieve the output image
	var output_image_data = compute.fetch_texture("OutputImage")
	output_image = Image.create_from_data(settings.shader_image_size, settings.shader_image_size, false, Image.FORMAT_RGBAF, output_image_data)
	output_texture.update(output_image)
	particles.process_material.set_shader_parameter("boid_data", output_texture)

	# Retrieve the color image
	var color_image_data = compute.fetch_texture("ColorImage")
	color_image = Image.create_from_data(settings.shader_image_size, settings.shader_image_size, false, Image.FORMAT_RGBAF, color_image_data)
	color_texture.update(color_image)
	particles.process_material.set_shader_parameter("color_data", color_texture)

	# Update the buffer
	boid_data = compute.fetch_buffer("BoidsOut")
	compute.update_buffer("BoidsIn", boid_data)
	if update_mouse_request:
		update_mouse_request = false
		params[2] = get_local_mouse_position().x
		params[3] = get_local_mouse_position().y
	params[4] = delta
	compute.update_buffer("Params", params.to_byte_array())
	if update_settings_request:
		update_settings_request = false
		compute.update_buffer("Settings", settings.to_byte_array())

	# Execute the compute shader
	compute.execute(dispatch_size, 1, 1)

	if prev_edge_visualize != settings.edge_visualize:
		prev_edge_visualize = settings.edge_visualize
		queue_redraw()

func _draw():
	if settings.edge_visualize:
		var points = [
			Vector2(settings.edge_margin_left, settings.edge_margin_top),
			Vector2(settings.edge_margin_left, get_viewport_rect().size.y - settings.edge_margin_bottom),
			Vector2(get_viewport_rect().size.x - settings.edge_margin_right, get_viewport_rect().size.y - settings.edge_margin_bottom),
			Vector2(get_viewport_rect().size.x - settings.edge_margin_right, settings.edge_margin_top),
		]
		draw_dashed_line(points[0], points[1], Color(1, 0, 0, 0.5), 2, 10)
		draw_dashed_line(points[1], points[2], Color(1, 0, 0, 0.5), 2, 10)
		draw_dashed_line(points[2], points[3], Color(1, 0, 0, 0.5), 2, 10)
		draw_dashed_line(points[3], points[0], Color(1, 0, 0, 0.5), 2, 10)

func _input(event):
	if event is InputEventMouseMotion:
		update_mouse_request = true

func set_boid(i: int, pos: Vector2, vel: Vector2, fam: int, pred: bool) -> void:
	var byte_offset = i * 24
	boid_data.encode_float(byte_offset, pos.x)
	boid_data.encode_float(byte_offset + 4, pos.y)
	boid_data.encode_float(byte_offset + 8, vel.x)
	boid_data.encode_float(byte_offset + 12, vel.y)
	boid_data.encode_s32(byte_offset + 16, fam)
	boid_data.encode_s32(byte_offset + 20, 1 if pred else 0)

func _on_settings_changed() -> void:
	update_settings_request = true
	particles.process_material.set_shader_parameter("boid_size", settings.boid_size)


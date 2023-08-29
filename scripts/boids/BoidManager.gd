extends Node2D


const WORKGROUP_SIZE = 1024


@export var boid_object: PackedScene
@export var settings: BoidSettings
@export_group("Spawn", "spawn_")
@export var spawn_radius: float = 300
@export var spawn_count: int = 10
@export var spawn_size: float = 1.0
@export var spawn_show: bool = false
@export var spawn_families: int = 3
@export_group("", "")
@onready var compute: ComputeShader = $ComputeShader

var boids: Array[Boid] = []
var boid_data: PackedByteArray = PackedByteArray()
var params: PackedByteArray = PackedByteArray()
var dispatch_size: int = 0

# NEW
var update_settings_request: bool = false
var output_image: Image
var output_texture: ImageTexture
var image_size: int = 256
@onready var particles: GPUParticles2D = $GPUParticles2D


func _ready() -> void:
	# Connect signals
	settings.settings_changed.connect(_on_settings_changed)

	# Calculate speed and center
	var speed = (settings.min_speed + settings.max_speed) / 2
	var center = get_viewport_rect().size / 2

	# Set params
	params.resize(16)
	var edge = get_viewport_rect().size
	params.encode_float(0, edge.x)
	params.encode_float(4, edge.y)
	params.encode_s32(8, image_size)
	params.encode_float(12, 0)

	# Spawn boids
	boid_data.resize(spawn_count * 24)
	for i in range(spawn_count):
		# Set random position and velocity
		var boid_pos = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0, spawn_radius) + center
		var boid_vel = boid_pos.normalized() * speed
		var family = randi_range(0, spawn_families)

		boid_data.encode_float(i * 24, boid_pos.x)
		boid_data.encode_float(i * 24 + 4, boid_pos.y)
		boid_data.encode_float(i * 24 + 8, boid_vel.x)
		boid_data.encode_float(i * 24 + 12, boid_vel.y)
		# TODO: Revisit this later
		boid_data.encode_float(i * 24 + 16, family)
		boid_data.encode_float(i * 24 + 20, family)

	# Create image
	output_image = Image.create(image_size, image_size, false, Image.FORMAT_RGBAF)
	output_texture = ImageTexture.create_from_image(output_image)

	# Setup particles
	particles.amount = spawn_count
	particles.emitting = true

	# Setup buffers
	compute.register_storage_buffer("Settings", 0, 0, settings.to_byte_array())
	compute.register_storage_buffer("Params", 1, 0, params)
	compute.register_storage_buffer("BoidsIn", 2, 0, boid_data)
	compute.register_storage_buffer("BoidsOut", 3, 0, boid_data)
	compute.register_texture("BoidsOutImage", 4, image_size, image_size, output_image.get_data(), RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT)

	dispatch_size = ceili(float(spawn_count) / float(WORKGROUP_SIZE))
	if compute.is_available():
		compute.execute(dispatch_size, 1, 1)

func _process(delta):
	# Check if the compute shader is available
	if not compute.is_available():
		return

	# Wait for the compute shader to finish
	compute.wait()

	# Retrieve the results and update the boids
	var output_image_data = compute.fetch_texture("BoidsOutImage")
	output_image = Image.create_from_data(image_size, image_size, false, Image.FORMAT_RGBAF, output_image_data)
	output_texture.update(output_image)
	particles.process_material.set_shader_parameter("boid_data", output_texture)

	# Update the buffer
	boid_data = compute.fetch_buffer("BoidsOut")
	compute.update_buffer("BoidsIn", boid_data)
	params.encode_float(12, delta)
	compute.update_buffer("Params", params)
	if update_settings_request:
		update_settings_request = false
		compute.update_buffer("Settings", settings.to_byte_array())

	# Execute the compute shader
	compute.execute(dispatch_size, 1, 1)

## Called when the settings change
func _on_settings_changed() -> void:
	update_settings_request = true

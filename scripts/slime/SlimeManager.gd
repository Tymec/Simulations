extends Node2D


@export var settings: SlimeSettings
@export var output: CanvasItem
@export var input: ViewportTexture

@onready var compute: ComputeShader = $ComputeShader

var request_settings_update: bool = false
var dispatch_size: int = 0
var image_size: Vector2i
var params: PackedFloat32Array
var agents: PackedByteArray
var output_image: Image
var output_texture: ImageTexture



func _ready():
	if settings.random_seed != -1:
		seed(settings.random_seed)

	# Make sure the viewport matches the image size
	image_size = settings.output_size
	output.get_viewport().size = image_size

	# Connect signals
	settings.settings_changed.connect(_on_settings_changed)

	# Create params buffer
	params = PackedFloat32Array([
		0.0,	# Delta
	])

	# Create agent buffer
	agents = PackedByteArray()
	var agent_offset = 16
	agents.resize(settings.agent_count * agent_offset)
	for i in range(settings.agent_count):
		# From center circle with spawn_radius
		var pos = image_size / 2.0 + Vector2.RIGHT.rotated(randf() * TAU) * randf() * settings.spawn_radius
		#var rot = Vector2.RIGHT.rotated(randf() * TAU).angle()
		# inward circle
		# var rot = ((centre - startPos).normalized.y, (centre - startPos).normalized.x);
		var rot = pos.angle_to_point(image_size / 2.0)
		agents.encode_float(i * agent_offset + 0, pos.x)
		agents.encode_float(i * agent_offset + 4, pos.y)
		agents.encode_float(i * agent_offset + 8, rot)
		agents.encode_float(i * agent_offset + 12, 0)

	# Create output image
	output_image = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	output_texture = ImageTexture.create_from_image(output_image)

	# Set shader parameters
	output.material.set_shader_parameter("evaporateSpeed", settings.evaporate_speed)
	output.material.set_shader_parameter("diffuseSpeed", settings.diffuse_speed)
	output.material.set_shader_parameter("blurRadius", settings.blur_radius)

	# Setup buffers
	compute.register_storage_buffer("Settings", 0, 0, settings.to_byte_array())
	compute.register_storage_buffer("Params", 1, 0, params.to_byte_array())
	compute.register_storage_buffer("Agents", 2, 0, agents)
	compute.register_texture("OutputImage", 3, image_size.x, image_size.y, output_image.get_data(), RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM)

	# Calculate dispatch size and execute the compute shader
	dispatch_size = ceili(float(settings.agent_count) / float(settings.WORKGROUP_SIZE))
	if compute.is_available():
		compute.execute(dispatch_size, 1, 1)

func _physics_process(delta):
	# Check if the compute shader is available
	if not compute.is_available():
		return

	# Wait for the compute shader to finish
	compute.wait()

	# Retrieve the output image
	var output_image_data = compute.fetch_texture("OutputImage")
	output_image = Image.create_from_data(image_size.x, image_size.y, false, Image.FORMAT_RGBA8, output_image_data)
	output_texture.update(output_image)
	output.material.set_shader_parameter("deltaTime", delta)
	output.material.set_shader_parameter("trailMap", output_texture)

	# Update params
	params[0] = delta
	compute.update_buffer("Params", params.to_byte_array())

	# Update settings
	if request_settings_update:
		compute.update_buffer("Settings", settings.to_byte_array())
		request_settings_update = false

	# Update output image
	compute.update_texture("OutputImage", input.get_image().get_data())

	# Execute the compute shader
	compute.execute(dispatch_size, 1, 1)

func _on_settings_changed():
	# Update settings
	request_settings_update = true

	# Update shader parameters
	output.material.set_shader_parameter("evaporateSpeed", settings.evaporate_speed)
	output.material.set_shader_parameter("diffuseSpeed", settings.diffuse_speed)
	output.material.set_shader_parameter("blurRadius", settings.blur_radius)

class_name ComputeShader
extends Node


@export_file("*.glsl") var shader_file

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var uniform_set: RID
var cache: Dictionary


### TODO: Add support for samplers


func _ready() -> void:
	rd = null
	shader = RID()
	pipeline = RID()
	uniform_set = RID()
	cache = {}

func _notification(what) -> void:
	# Object destructor, triggered before the engine deletes this Node.
	if what == NOTIFICATION_PREDELETE:
		_cleanup_gpu()

func _cleanup_gpu() -> void:
	# Check if rendering device is already initialized
	if rd == null:
		return

	# Destroy compute pipeline
	if pipeline.is_valid():
		rd.free_rid(pipeline)
	pipeline = RID()

	# Destroy uniform set
	if uniform_set.is_valid():
		rd.free_rid(uniform_set)
	uniform_set = RID()

	# Destroy uniforms
	for obj in cache.values():
		if obj["rid"].is_valid():
			rd.free_rid(obj["rid"])
	cache.clear()

	# Destroy shader
	if shader.is_valid():
		rd.free_rid(shader)
	shader = RID()

	# Destroy rendering device
	rd.free()
	rd = null

func _init_gpu() -> bool:
	# Check if rendering device is already initialized
	if rd != null:
		return true

	# Create a rendering device
	rd = RenderingServer.create_local_rendering_device()
	if rd == null:
		print("Failed to create rendering device")
		return false

	# Load shader from file
	var shader_code = load(shader_file)
	var shader_spirv = shader_code.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)

	# Create compute pipeline
	pipeline = rd.compute_pipeline_create(shader)

	return true

func _finish_register(uniform_name: String, rid: RID, binding: int, uniform_type: int) -> void:
	# Create uniform
	var uniform = RDUniform.new()
	uniform.uniform_type = uniform_type
	uniform.binding = binding
	uniform.add_id(rid)

	# Add uniform to cache
	cache[uniform_name] = {
		"rid": rid,
		"uniform": uniform,
		"binding": binding,
	}

	# Invalidate uniform set
	if uniform_set.is_valid():
		rd.free_rid(uniform_set)
		uniform_set = RID()

func _precheck(uniform_name: String, should_contain: bool = false) -> bool:
	if not _init_gpu():
		# Check if rendering device is already initialized
		print("RenderingDevice is not available on the current rendering driver")
		return false
	elif (uniform_name in cache) != should_contain:
		# Check if uniform is already registered
		print("Uniform with name '%s' %sregistered" % [uniform_name, "not " if should_contain else ""])
		return false

	return true

## Registers a storage buffer.
func register_storage_buffer(buffer_name: String, binding: int, size: int = 0, data: PackedByteArray = PackedByteArray()) -> bool:
	if not _precheck(buffer_name, false):
		return false

	# Use data size if size is not specified
	if size == 0:
		size = data.size()

	if size == 0:
		print("Buffer size must be greater than 0")
		return false

	# Create buffer
	var rid = rd.storage_buffer_create(size, data)

	# Create uniform, cache it and invalidate uniform set
	_finish_register(buffer_name, rid, binding, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER)

	return true

## Registers a uniform buffer.
func register_uniform_buffer(buffer_name: String, binding: int, size: int = 0, data: PackedByteArray = PackedByteArray()) -> bool:
	if not _precheck(buffer_name, false):
		return false

	# Use data size if size is not specified
	if size == 0:
		size = data.size()

	if size == 0:
		print("Buffer size must be greater than 0")
		return false

	# Create buffer
	var rid = rd.uniform_buffer_create(size, data)

	# Create uniform, cache it and invalidate uniform set
	_finish_register(buffer_name, rid, binding, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER)

	return true

## Registers a texture uniform.
func register_texture(
	texture_name: String, binding: int,
	width: float = 0, height: float = 0,
	data: PackedByteArray = [],
	format: int = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM,
	usage_bits: int = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT,
) -> bool:
	if not _precheck(texture_name, false):
		return false

	# Create texture format
	var texture_format = RDTextureFormat.new()
	texture_format.format = format
	texture_format.width = width
	texture_format.height = height
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + usage_bits

	# Create texture view
	var texture_view = RDTextureView.new()

	# Create texture
	var rid = rd.texture_create(texture_format, texture_view, [] if data.is_empty() else [data])

	# Create uniform, cache it and invalidate uniform set
	_finish_register(texture_name, rid, binding, RenderingDevice.UNIFORM_TYPE_IMAGE)

	return true

## Removes any registered uniforms and buffers.
func unregister_uniform(uniform_name: String) -> bool:
	if not _precheck(uniform_name, true):
		return false

	# Remove uniform from cache
	var obj = cache[uniform_name]
	cache.erase(uniform_name)

	# Invalidate uniform set
	if uniform_set.is_valid():
		rd.free_rid(uniform_set)
		uniform_set = RID()

	# Destroy uniform
	if obj["rid"].is_valid():
		rd.free_rid(obj["rid"])

	return true

## Updates a buffer with new data.
func update_buffer(buffer_name: String, data: PackedByteArray) -> bool:
	if not _precheck(buffer_name, true):
		return false

	# Update buffer
	var buffer = cache[buffer_name]
	rd.buffer_update(buffer["rid"], 0, data.size(), data)

	return true

## Updates a texture uniform with new data.
func update_texture(texture_name: String, data: PackedByteArray) -> bool:
	if not _precheck(texture_name, true):
		return false

	# Update texture
	var texture = cache[texture_name]
	rd.texture_update(texture["rid"], 0, data)

	return true

## Fetches a storage buffer.
func fetch_buffer(buffer_name: String) -> PackedByteArray:
	if not _precheck(buffer_name, true):
		return PackedByteArray()

	# Fetch buffer
	var buffer = cache[buffer_name]
	return rd.buffer_get_data(buffer["rid"])

## Fetches a texture uniform.
func fetch_texture(texture_name: String) -> PackedByteArray:
	if not _precheck(texture_name, true):
		return PackedByteArray()

	# Fetch texture
	var texture = cache[texture_name]
	return rd.texture_get_data(texture["rid"], 0)

## Creates a compute list and dispatches it.
func execute(x_groups: int = 1, y_groups: int = 1, z_groups: int = 1) -> void:
	if not _init_gpu():
		print("RenderingDevice is not available on the current rendering driver")
		return

	# Create compute list
	var compute_list = rd.compute_list_begin()

	# Bind compute pipeline
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)

	# Create uniform set if it doesn't exist
	if not uniform_set.is_valid():
		var uniforms = cache.values().map(func(obj):
			return obj["uniform"]
		)
		uniform_set = rd.uniform_set_create(uniforms, shader, 0)

	# Bind uniform set
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	# Dispatch compute list
	rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)

	# End compute list
	rd.compute_list_end()

	# Submit compute list
	rd.submit()

## Forces a synchronization between the CPU and GPU.
func wait() -> void:
	if rd == null:
		print("RenderingDevice is not available on the current rendering driver")
		return

	# Wait for compute list to finish
	rd.sync()

## Returns whether the rendering device is available.
func is_available() -> bool:
	return _init_gpu()

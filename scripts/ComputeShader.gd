class_name ComputeShader
extends Node


@export_file("*.glsl") var shader_file

var has_submitted: bool
var rd: RenderingDevice
var shader: RID
var pipeline: RID
var uniform_set: RID
var buffers: Dictionary


func _ready() -> void:
	has_submitted = false
	rd = null
	shader = RID()
	pipeline = RID()
	uniform_set = RID()
	buffers = {}

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

	# Destroy buffers
	for buffer in buffers.values():
		if buffer["rid"].is_valid():
			rd.free_rid(buffer["rid"])
	buffers.clear()

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

## Registers a buffer.
func register_buffer(buffer_name: String, data: PackedByteArray, binding: int) -> bool:
	if not _init_gpu():
		# Check if rendering device is already initialized
		print("RenderingDevice is not available on the current rendering driver")
		return false
	elif buffer_name in buffers:
		# Check if buffer is already registered
		print("Buffer with name '%s' already registered" % buffer_name)
		return false

	# Create buffer
	var rid = rd.storage_buffer_create(data.size(), data)
	var uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(rid)

	# Add buffer and recreate uniform set
	buffers[buffer_name] = {
		"rid": rid,
		"uniform": uniform,
		"binding": binding,
	}

	# Recreate uniform set
	if uniform_set.is_valid():
		rd.free_rid(uniform_set)
		uniform_set = RID()

	return true

## Unregisters a buffer.
func unregister_buffer(buffer_name: String) -> bool:
	if not _init_gpu():
		# Check if rendering device is already initialized
		print("RenderingDevice is not available on the current rendering driver")
		return false
	elif buffer_name not in buffers:
		# Check if buffer is already registered
		print("Buffer with name '%s' not registered" % buffer_name)
		return false

	# Remove buffer from buffers
	var buffer = buffers[buffer_name]
	buffers.erase(buffer_name)

	# Destroy uniform set
	if uniform_set.is_valid():
		rd.free_rid(uniform_set)
		uniform_set = RID()

	# Destroy buffer
	rd.free_rid(buffer["rid"])

	return true

## Reregisters a buffer.
func reregister_buffer(buffer_name: String, data: PackedByteArray) -> bool:
	if buffer_name not in buffers:
		# Check if buffer is already registered
		print("Buffer with name '%s' not registered" % buffer_name)
		return false

	var binding = buffers[buffer_name]["binding"]
	if not unregister_buffer(buffer_name):
		print("Failed to unregister buffer with name '%s'" % buffer_name)
		return false

	return register_buffer(buffer_name, data, binding)

## Updates a buffer with new data.
func update_buffer(buffer_name: String, data: PackedByteArray) -> bool:
	if not _init_gpu():
		# Check if rendering device is already initialized
		print("RenderingDevice is not available on the current rendering driver")
		return false
	elif buffer_name not in buffers:
		# Check if buffer is already registered
		print("Buffer with name '%s' not registered" % buffer_name)
		return false

	# Update buffer
	var buffer = buffers[buffer_name]
	rd.buffer_update(buffer["rid"], 0, data.size(), data)

	return true

## Fetches a buffer.
func fetch_buffer(buffer_name: String) -> PackedByteArray:
	if not _init_gpu():
		# Check if rendering device is already initialized
		print("RenderingDevice is not available on the current rendering driver")
		return PackedByteArray()
	elif buffer_name not in buffers:
		# Check if buffer is already registered
		print("Buffer with name '%s' not registered" % buffer_name)
		return PackedByteArray()

	# Fetch buffer
	var buffer = buffers[buffer_name]
	return rd.buffer_get_data(buffer["rid"])

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
		var uniforms = buffers.values().map(func(buffer):
			return buffer["uniform"]
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
	has_submitted = true

## Forces a synchronization between the CPU and GPU.
func wait() -> void:
	if rd == null:
		print("RenderingDevice is not available on the current rendering driver")
		return
	elif not has_submitted:
		print("Compute list has not been submitted")
		return

	# Wait for compute list to finish
	rd.sync()
	has_submitted = false

## Returns whether the rendering device is available.
func is_available() -> bool:
	return _init_gpu()

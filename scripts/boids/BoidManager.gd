extends Node2D


const WORKGROUP_SIZE = 64


@export var boid_object: PackedScene
@export var settings: BoidSettings
@export_group("Spawn", "spawn_")
@export var spawn_radius: float = 300
@export var spawn_count: int = 10
@export var spawn_size: float = 1.0
@export var spawn_show: bool = false
@export_group("", "")
@export var use_cpu: bool = false:
	set(val):
		if use_cpu:
			for i in range(spawn_count):
				set_boid_data(i)
		use_cpu = val
@onready var compute: ComputeShader = $ComputeShader

var boids: Array[Boid] = []
var boid_data: PackedByteArray = PackedByteArray()
var params: PackedByteArray = PackedByteArray()
var dispatch_size: int = 0


func _ready() -> void:
	# Connect signals
	settings.settings_changed.connect(_on_settings_changed)

	# Create a new parent node for all boids
	var parent = Node2D.new()
	parent.set_name("Boids")

	# Offset parent node to center of screen
	var parent_offset = get_viewport_rect().size / 2
	parent.position = parent_offset

	# Calculate speed and dispatch size
	var speed = (settings.min_speed + settings.max_speed) / 2
	dispatch_size = ceili(float(spawn_count) / float(WORKGROUP_SIZE))

	# Resize arrays
	boids.resize(spawn_count)
	boid_data.resize(spawn_count * 16)
	params.resize(16)

	# Set params
	update_params()

	# Spawn boids
	for i in range(spawn_count):
		# Create boid
		var boid = boid_object.instantiate().create(settings, parent_offset, spawn_size, i == 0)

		# Set random position and rotation
		var dir = Vector2(randf_range(0, spawn_radius), 0).rotated(randf_range(0, TAU))
		boid.position = dir
		boid.rotation = dir.angle()
		boid.velocity = dir.normalized() * speed

		# Add to group and set parent
		boid.add_to_group("boids")
		parent.add_child(boid)

		# Add to arrays
		boids[i] = boid
		set_boid_data(i, boid)

	# Add parent to scene
	add_child(parent)

	# Clear the output buffer
	var output_buffer = PackedByteArray()
	output_buffer.resize(spawn_count * 16)
	for i in range(spawn_count):
		output_buffer.encode_float(i * 16, 0)
		output_buffer.encode_float(i * 16 + 4, 0)
		output_buffer.encode_float(i * 16 + 8, 0)
		output_buffer.encode_float(i * 16 + 12, 0)

	# Setup buffers
	compute.register_storage_buffer("Settings", 0, 0, settings.to_byte_array())
	compute.register_storage_buffer("Params", 1, 0, params)
	compute.register_storage_buffer("BoidsIn", 2, 0, boid_data)
	compute.register_storage_buffer("BoidsOut", 3, 0, output_buffer)

func _draw() -> void:
	# Draw spawn radius
	if spawn_show:
		draw_circle($Boids.position, spawn_radius, Color(1, 1, 1, 0.1))

	# Draw edge margins
	if settings.edge_visualize:
		# Draw polygon around the viewport
		var start = get_viewport_rect().position
		var end = get_viewport_rect().end
		var points = [
			Vector2(start.x + settings.edge_margin_left, start.y + settings.edge_margin_top),
			Vector2(end.x - settings.edge_margin_right, start.y + settings.edge_margin_top),
			Vector2(end.x - settings.edge_margin_right, end.y - settings.edge_margin_bottom),
			Vector2(start.x + settings.edge_margin_left, end.y - settings.edge_margin_bottom),
		]
		draw_dashed_line(points[0], points[1], Color(1, 0, 0, 0.4), 2, 8)
		draw_dashed_line(points[1], points[2], Color(1, 0, 0, 0.4), 2, 8)
		draw_dashed_line(points[2], points[3], Color(1, 0, 0, 0.4), 2, 8)
		draw_dashed_line(points[3], points[0], Color(1, 0, 0, 0.4), 2, 8)

func _physics_process(delta):
	if use_cpu:
		_process_cpu(delta)
	else:
		_process_gpu(delta)

func _process_gpu(delta):
	# Check if the compute shader is available
	if not compute.is_available():
		return

	# Update buffer
	compute.update_buffer("BoidsIn", boid_data)

	# Execute compute shader
	compute.execute(dispatch_size, 1, 1)
	compute.wait()

	# Retrieve the results and update the boids
	var output = compute.fetch_buffer("BoidsOut")
	for i in range(spawn_count):
		# Get the boid
		var boid = boids[i]

		# Get the data and set properties
		var _new_position = Vector2(
			output.decode_float(i * 16),
			output.decode_float(i * 16 + 4)
		)
		var new_velocity = Vector2(
			output.decode_float(i * 16 + 8),
			output.decode_float(i * 16 + 12)
		)

		# Update the boid
		boid.update(delta, new_velocity)

		# Update the buffer
		set_boid_data(i, boid)

func _process_cpu(delta):
	# Loop through all boids
	for boid in boids:
		# Compute the boid
		var new_velocity = compute_boid(boid)

		# Update the boid
		boid.update(delta, new_velocity)

## Updates the params buffer
func update_params() -> void:
	var edge = get_viewport_rect().size / 2
	params.encode_float(0, -edge.x)
	params.encode_float(4, -edge.y)
	params.encode_float(8, edge.x)
	params.encode_float(12, edge.y)

## Sets the boid data in the buffer
func set_boid_data(i: int, boid: Boid = null) -> void:
	if boid == null:
		boid = boids[i]
	boid_data.encode_float(i * 16, boid.position.x)
	boid_data.encode_float(i * 16 + 4, boid.position.y)
	boid_data.encode_float(i * 16 + 8, boid.velocity.x)
	boid_data.encode_float(i * 16 + 12, boid.velocity.y)

## Checks if a boid is in the field of view of the current boid
func is_boid_in_fov(boid: Boid, other: Boid) -> bool:
	var self_rot = fmod(boid.rotation, TAU)
	var angle = boid.position.angle_to_point(other.position)
	var angle_diff = abs(angle - self_rot)
	if angle_diff > PI:
		angle_diff = TAU - angle_diff

	return angle_diff < settings.get_view_angle_half()

## Calculates the avoidance, alignment and cohesion for a boid
func compute_boid(boid: Boid) -> Vector2:
	var acceleration = Vector2.ZERO

	var flockmates_heading = 0
	var avg_flock_heading = Vector2.ZERO
	var flockmates_center = 0
	var avg_flock_center = Vector2.ZERO
	var avoidance_heading = Vector2.ZERO

	# Loop through all boids
	for other in boids:
		if boid == other:
			continue

		# Check if boid is in range and in field of view
		var dist = boid.position.distance_to(other.position)
		if dist >= settings.get_view_radius() or not is_boid_in_fov(boid, other):
			continue

		# Avoid if within separation distance
		if dist < settings.distance_separation:
			avoidance_heading += boid.position - other.position
			continue

		# Align if within alignment distance
		if dist < settings.distance_alignment:
			avg_flock_heading += other.velocity
			flockmates_heading += 1

		# Cohere if within cohesion distance
		if dist < settings.distance_cohesion:
			avg_flock_center += other.position
			flockmates_center += 1

	# Apply forces
	acceleration += avoidance_heading * settings.weight_separation
	if flockmates_heading > 0:
		avg_flock_heading /= flockmates_heading
		acceleration += (avg_flock_heading - boid.velocity) * settings.weight_alignment
	if flockmates_center > 0:
		avg_flock_center /= flockmates_center
		acceleration += (avg_flock_center - boid.position) * settings.weight_cohesion

	# Avoid edges
	if settings.edge_avoid:
		var edge = get_viewport_rect().size / 2
		var weight = settings.edge_avoidance_weight
		if boid.position.x < -edge.x + settings.edge_margin_left:
			acceleration.x += weight
		elif boid.position.x > edge.x - settings.edge_margin_right:
			acceleration.x -= weight
		if boid.position.y < -edge.y + settings.edge_margin_top:
			acceleration.y += weight
		elif boid.position.y > edge.y - settings.edge_margin_bottom:
			acceleration.y -= weight

	# Update velocity and limit speed
	var new_velocity = boid.velocity + acceleration
	var speed = clampf(new_velocity.length(), settings.min_speed, settings.max_speed)
	return new_velocity.normalized() * speed

## Called when the settings change
func _on_settings_changed() -> void:
	# Update buffer
	compute.update_buffer("Settings", settings.to_byte_array())

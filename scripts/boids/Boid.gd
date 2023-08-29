class_name Boid
extends Node2D


@export var settings: BoidSettings

var avoidance_heading: Vector2 = Vector2.ZERO
var avg_flock_heading: Vector2 = Vector2.ZERO
var avg_flock_center: Vector2 = Vector2.ZERO
var flockmates_in_view: Array[Boid] = []

var edge: Vector2
var is_following: bool = false
var new_scale: float = 1.0
var velocity: Vector2 = Vector2.ZERO

@onready var shape: Polygon2D = $Polygon2D


func _ready() -> void:
	# Apply scale and color
	shape.scale = Vector2(new_scale, new_scale)
	shape.color = Color(.7, 0.2, .4, 1) if is_following else Color(0, 0.8, 0.8, 1)

func _draw():
	# Only draw if selected
	if not is_following:
		return

	# Draw separation fov
	if settings.visualize_separation:
		var separation_fov_points = Helper.circle_arc_poly(
			Vector2.ZERO,
			settings.distance_separation,
			-settings.get_view_angle_half(),
			+settings.get_view_angle_half(),
		)
		if separation_fov_points.size() >= 3:
			draw_polygon(separation_fov_points, [Color(1, 0, 0, .2)])

	# Draw alignment fov
	if settings.visualize_alignment:
		var alignment_fov_points = Helper.circle_arc_poly(
			Vector2.ZERO,
			settings.distance_alignment,
			-settings.get_view_angle_half(),
			+settings.get_view_angle_half(),
		)
		if alignment_fov_points.size() >= 3:
			draw_polygon(alignment_fov_points, [Color(0, 0, 1, .2)])

	# Draw cohesion fov
	if settings.visualize_cohesion:
		var cohesion_fov_points = Helper.circle_arc_poly(
			Vector2.ZERO,
			settings.distance_cohesion,
			-settings.get_view_angle_half(),
			+settings.get_view_angle_half(),
		)
		if cohesion_fov_points.size() >= 3:
			draw_polygon(cohesion_fov_points, [Color(0, 1, 0, .2)])

	# Draw lines to flockmates
	for boid in flockmates_in_view:
		var dist = boid.global_position.distance_to(global_position)

		var color: Color = Color(1, 1, 1, 0)
		# Make the separation line the inverse of red (cyan)
		if dist < settings.distance_separation and settings.visualize_separation:
			color = Color(0, 1, 1, .3)
		# Make the alignment line the inverse of blue (yellow)
		elif dist < settings.distance_alignment and settings.visualize_alignment:
			color = Color(1, 1, 0, .3)
		# Make the cohesion line the inverse of green (magenta)
		elif dist < settings.distance_cohesion and settings.visualize_cohesion:
			color = Color(1, 0, 1, .3)
		else:
			continue

		draw_line(Vector2.ZERO, to_local(boid.global_position), color)

## Updates the boid
func update(delta: float) -> void:
	var acceleration = Vector2.ZERO

	# Update flockmates
	acceleration += avoidance_heading * settings.weight_separation
	acceleration += avg_flock_heading * settings.weight_alignment
	acceleration += avg_flock_center * settings.weight_cohesion

	# Avoid edges
	if settings.edge_avoid:
		var weight = settings.edge_avoidance_weight
		if position.x < -edge.x + settings.edge_margin_left:
			acceleration.x += weight
		elif position.x > edge.x - settings.edge_margin_right:
			acceleration.x -= weight
		if position.y < -edge.y + settings.edge_margin_top:
			acceleration.y += weight
		elif position.y > edge.y - settings.edge_margin_bottom:
			acceleration.y -= weight

	# Move boid
	move(acceleration, delta)

	# Wrap around the screen
	if settings.edge_wrap:
		position.x = wrapf(position.x, -edge.x, edge.x)
		position.y = wrapf(position.y, -edge.y, edge.y)

	# DEBUG: Redraw gizmos
	if is_following and settings.visualizations_enabled():
		queue_redraw()

## Updates the boid's position based on the given acceleration
func move(acceleration: Vector2, delta: float) -> void:
	# Apply acceleration to velocity
	velocity += acceleration

	# Clamp velocity to max speed
	var speed = clampf(velocity.length(), settings.min_speed, settings.max_speed)
	var dir = velocity.normalized()
	velocity = dir * speed

	# Move and rotate according to velocity
	position += velocity * delta
	rotation = velocity.angle()

## Returns the direction the boid is facing
func get_direction() -> Vector2:
	return Vector2(cos(rotation), sin(rotation))

## Creates a boid with the given settings
func create(_settings: BoidSettings, _edge: Vector2, _scale: float = 1.0, following: bool = false) -> Boid:
	settings = _settings
	edge = _edge
	is_following = following
	new_scale = _scale

	return self

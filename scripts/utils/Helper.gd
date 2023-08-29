extends Node2D


func _bresenhamLow(origin: Vector2i, destination: Vector2i) -> Array[Vector2i]:
	var dx = destination.x - origin.x
	var dy = destination.y - origin.y

	var yi = 1
	if dy < 0:
		yi = -1
		dy = -dy

	var diff = 2 * dy - dx
	var y = origin.y

	var points: Array[Vector2i] = []
	for x in range(origin.x, destination.x + 1):
		points.append(Vector2i(x, y))
		if diff > 0:
			y += yi
			diff += 2 * (dy - dx)
		else:
			diff += 2 * dy

	return points

func _bresenhamHigh(origin: Vector2i, destination: Vector2i) -> Array[Vector2i]:
	var dx = destination.x - origin.x
	var dy = destination.y - origin.y

	var xi = 1
	if dx < 0:
		xi = -1
		dx = -dx

	var diff = 2 * dx - dy
	var x = origin.x


	var points: Array[Vector2i] = []
	for y in range(origin.y, destination.y + 1):
		points.append(Vector2i(x, y))
		if diff > 0:
			x += xi
			diff += 2 * (dx - dy)
		else:
			diff += 2 * dx

	return points

## Returns an array of points between origin and destination using Bresenham's line algorithm
func bresenham(origin: Vector2i, destination: Vector2i) -> Array[Vector2i]:
	if abs(destination.y - origin.y) < abs(destination.x - origin.x):
		if origin.x > destination.x:
			return _bresenhamLow(destination, origin)
		else:
			return _bresenhamLow(origin, destination)
	else:
		if origin.y > destination.y:
			return _bresenhamHigh(destination, origin)
		else:
			return _bresenhamHigh(origin, destination)

## Creates a raycast from the given position (global) at the given angle (degrees) and length.
func ray_at_angle(
	pos: Vector2,
	length: float,
	angle: float,
	collision_mask: int = -1,
	exclude: Array[RID] = []
) -> PhysicsRayQueryParameters2D:
	var query = PhysicsRayQueryParameters2D.create(
		pos,
		pos + Vector2(length, 0).rotated(deg_to_rad(angle))
	)
	if collision_mask != -1:
		query.collision_mask = collision_mask
	query.exclude = exclude
	return query

## Creates a polygon of points that form a circle arc between the given angles (radians)
## relative to the current node's rotation.
func circle_arc_poly(
	center: Vector2, radius: float,
	angle_from: float, angle_to: float,
	resolution: int = 32
) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var angle_step: float = (angle_to - angle_from) / resolution
	var radius_vector: Vector2 = Vector2(radius, 0)

	if abs(angle_to - angle_from) < TAU:
		points.append(center)

	if abs(angle_to - angle_from) < 0.01:
		return points

	for i in range(resolution):
		var angle: float = angle_from + i * angle_step
		points.append(
			center + radius_vector.rotated(angle)
		)

	return points

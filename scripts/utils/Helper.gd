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

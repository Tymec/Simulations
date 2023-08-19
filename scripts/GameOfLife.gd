@tool
extends Node2D


@export var tick_interval: float = 0.1
@export var wrap_around: bool = false
@export var grid_size: Vector2i = Vector2i(32, 32):
	set(x):
		grid_size = x
		rects = generate()
		cells.resize(rects.size())
		cells.fill(false)
		queue_redraw()
@export_group("Cell", "cell_")
@export_range(1, 0, 1, "or_greater") var cell_size: int = 8:
	set(x):
		cell_size = x
		rects = generate()
		queue_redraw()
@export_range(1, 0, 1, "or_greater") var cell_spacing: int = 1:
	set(x):
		cell_spacing = x
		rects = generate()
		queue_redraw()
@export var cell_active_color: Color = Color(0, 0, 0, 1):
	set(x):
		cell_active_color = x
		queue_redraw()
@export var cell_inactive_color: Color = Color(1, 1, 1, 1):
	set(x):
		cell_inactive_color = x
		queue_redraw()
@export_group("", "")

var is_running = false
var elapsed_time = 0.0
var generation = 0
var cells: Array[bool] = []
var rects: Array[Rect2] = []


func toggle_simulation():
	is_running = not is_running
	elapsed_time = 0.0

func get_cell(x: int, y: int, _cells: Array[bool] = cells) -> bool:
	if wrap_around:
		if x < 0:
			x = grid_size.x - 1
		elif x >= grid_size.x:
			x = 0
		if y < 0:
			y = grid_size.y - 1
		elif y >= grid_size.y:
			y = 0
	elif x < 0 or x >= grid_size.x or y < 0 or y >= grid_size.y:
		return false
	return _cells[x + y * grid_size.x]

func set_cell(x: int, y: int, value: bool, _cells: Array[bool] = cells):
	if wrap_around:
		if x < 0:
			x = grid_size.x - 1
		elif x >= grid_size.x:
			x = 0
		if y < 0:
			y = grid_size.y - 1
		elif y >= grid_size.y:
			y = 0
	elif x < 0 or x >= grid_size.x or y < 0 or y >= grid_size.y:
		return
	_cells[x + y * grid_size.x] = value

func get_neighbours(x: int, y: int, _cells: Array[bool] = cells) -> int:
	var count = 0
	
	# top left
	if get_cell(x - 1, y - 1, _cells):
		count += 1
	# top
	if get_cell(x, y - 1, _cells):
		count += 1
	# top right
	if get_cell(x + 1, y - 1, _cells):
		count += 1
	# left
	if get_cell(x - 1, y, _cells):
		count += 1
	# right
	if get_cell(x + 1, y, _cells):
		count += 1
	# bottom left
	if get_cell(x - 1, y + 1, _cells):
		count += 1
	# bottom
	if get_cell(x, y + 1, _cells):
		count += 1
	# bottom right
	if get_cell(x + 1, y + 1, _cells):
		count += 1

	return count

func update_cell(x: int, y: int, _cells: Array[bool] = cells):
	var neighbours = get_neighbours(x, y)
	var cell = get_cell(x, y)

	if cell:
		set_cell(x, y, neighbours == 2 or neighbours == 3, _cells)
	else:
		set_cell(x, y, neighbours == 3, _cells)

func update_cells():
	var _cells: Array[bool] = cells.duplicate()

	for y in range(grid_size.y):
		for x in range(grid_size.x):
			update_cell(x, y, _cells)

	return _cells

func hash_grid(_cells: Array[bool] = cells) -> String:
	# XX-YYYY-YYYY-...-YYYY (XX = grid size, Y = cell cluster state)
	var _hash_str = ""

	# encode grid size into first 2 bytes
	var _grid_size = grid_size.x | (grid_size.y << 8)
	_hash_str += String.chr(_grid_size & 0xFF)
	_hash_str += String.chr((_grid_size >> 8) & 0xFF)

	_hash_str += "-"

	var _hash = 0
	var _bit = 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if _bit == 4:
				_hash_str += String.chr(_hash & 0xFF)
				_hash = 0
				_bit = 0

			_hash <<= 1
			if get_cell(x, y, _cells):
				_hash |= 1
			_bit += 1

	if _bit > 0:
		_hash <<= 4 - _bit
		_hash_str += String.chr(_hash & 0xFF)

	return _hash_str

func recover_grid(_hash_str: String) -> Array[bool]:
	var _cells: Array[bool] = []

	var _hash = 0
	for i in range(4):
		_hash <<= 8
		_hash += _hash_str[i].unicode_at(0)
	
	var _grid_size_x = _hash & 0xFF
	var _grid_size_y = (_hash >> 8) & 0xFF
	
	_cells.resize(grid_size.x * grid_size.y)
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if _hash & (1 << (x + y * grid_size.x)):
				set_cell(x, y, true, _cells)
	
	return _cells

## Convert global position to grid coordinates
func to_coords(pos: Vector2) -> Vector2i:
	var dims = get_dimensions()
	if pos.x < dims.x or pos.y < dims.y or pos.x >= dims.z or pos.y >= dims.w:
		return Vector2i(-1, -1)
	
	pos += get_grid_center()

	var col = floor(pos.x / (cell_size + cell_spacing))
	var row = floor(pos.y / (cell_size + cell_spacing))
	return Vector2i(col, row)

func reset_cells():
	is_running = false
	generation = 0
	elapsed_time = 0.0
	cells.fill(false)
	queue_redraw()

## Generate a grid of cells
func generate() -> Array[Rect2]:
	var rs: Array[Rect2] = []
	
	for row in range(grid_size.y):
		for col in range(grid_size.x):
			var rect_pos = Vector2(col, row) * (cell_size + cell_spacing)

			# Center the grid
			rect_pos -= get_grid_center()

			var rect = Rect2(
				rect_pos,
				Vector2(cell_size, cell_size)
			)
			rs.append(rect)

	return rs

## Get center of grid
func get_grid_center() -> Vector2:
	return grid_size * (cell_size + cell_spacing) / 2

## Get grid size in pixels
func get_dimensions() -> Vector4i:
	var first_cell = rects[0]
	var last_cell = rects[rects.size() - 1]

	var top_left = first_cell.position - first_cell.size / 2
	var bottom_right = last_cell.position + last_cell.size / 2

	return Vector4i(
		top_left.x,
		top_left.y,
		bottom_right.x,
		bottom_right.y
	)

func _ready():
	# Initialize the grid
	rects = generate()
	cells.resize(rects.size())
	cells.fill(false)

func _draw():
	for i in range(rects.size()):
		draw_rect(
			rects[i], 
			cell_active_color if cells[i] else cell_inactive_color, 
		)

func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_R and event.pressed:
			reset_cells()
			print("Hash: %s" % str(hash_grid()))
		elif event.keycode == KEY_SPACE and event.pressed:
			toggle_simulation()
		print("Hash: %s" % str(hash_grid()))
	elif event is InputEventMouseButton:
		var mouse_pos = get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var cell = to_coords(mouse_pos)
			if cell == Vector2i(-1, -1):
				return
			set_cell(cell.x, cell.y, true)
			print("Hash: %s" % str(hash_grid()))
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var cell = to_coords(mouse_pos)
			if cell == Vector2i(-1, -1):
				return
			set_cell(cell.x, cell.y, false)
			print("Hash: %s" % str(hash_grid()))
			queue_redraw()
	elif event is InputEventMouseMotion:
		if event.button_mask & (MOUSE_BUTTON_LEFT | MOUSE_BUTTON_RIGHT):
			var destination = get_global_mouse_position()
			var origin = destination - event.relative

			var origin_cell = to_coords(origin)
			var destination_cell = to_coords(destination)

			if origin_cell == Vector2i(-1, -1) or destination_cell == Vector2i(-1, -1):
				return

			var add_cell = event.button_mask & MOUSE_BUTTON_LEFT
			for cell in Helper.bresenham(origin_cell, destination_cell):
				set_cell(cell.x, cell.y, add_cell)
			print("Hash: %s" % str(hash_grid()))
			queue_redraw()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if not is_running:
		return
		
	if elapsed_time >= tick_interval:
		var new_cells = update_cells()
		if new_cells == cells:
			is_running = false
			print("Simulation finished.")
			return
		cells = new_cells
		queue_redraw()
		generation += 1
		print("Generation: ", generation)
		elapsed_time = 0
	else:
		elapsed_time += _delta

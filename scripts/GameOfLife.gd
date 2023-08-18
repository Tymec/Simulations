extends Simulation

@export var tick_interval: float = 0.1

@onready var camera = $Camera2D
@onready var grid = $Grid

var cols: int = 0
var rows: int = 0
var is_running = false
var cells: Array[bool] = []


func toggle_simulation():
	is_running = not is_running

func get_cell(x: int, y: int) -> bool:
	if x < 0 or x >= cols or y < 0 or y >= rows:
		return false
	return cells[x + y * cols]

func set_cell(x: int, y: int, value: bool):
	if x < 0 or x >= cols or y < 0 or y >= rows:
		return
	cells[x + y * cols] = value

func get_neighbours(x: int, y: int) -> int:
	var count = 0
	
	# top left
	if get_cell(x - 1, y - 1):
		count += 1
	# top
	if get_cell(x, y - 1):
		count += 1
	# top right
	if get_cell(x + 1, y - 1):
		count += 1
	# left
	if get_cell(x - 1, y):
		count += 1
	# right
	if get_cell(x + 1, y):
		count += 1
	# bottom left
	if get_cell(x - 1, y + 1):
		count += 1
	# bottom
	if get_cell(x, y + 1):
		count += 1
	# bottom right
	if get_cell(x + 1, y + 1):
		count += 1

	return count

func update_cell(x: int, y: int):
	var neighbours = get_neighbours(x, y)
	var cell = get_cell(x, y)
	
	if cell and (neighbours < 2 or neighbours > 3):
		set_cell(x, y, false)
	elif not cell and neighbours == 3:
		set_cell(x, y, true)

func update_cells():
	for y in range(rows):
		for x in range(cols):
			update_cell(x, y)

# Called when the node enters the scene tree for the first time.
func _ready():
	# Initialize the grid
	var grid_size = grid.get_cell_count()
	cols = grid_size.x
	rows = grid_size.y
	cells.resize(cols * rows)
	cells.fill(false)

	# Place the camera in the center of the grid
	camera.set_offset(grid.get_center())

	# Print information about the grid and the viewport
	var grid_max_size = grid.get_size()
	var viewport_size = get_viewport().size as Vector2
	print("Grid size: ", grid_max_size)
	print("Viewport size: ", viewport_size)
	var space_left = (viewport_size - grid_max_size) / viewport_size
	print("Horizontal space left: %.0f" % (space_left.x * 100), "%")
	print("Vertical space left: %.0f" % (space_left.y * 100), "%")

func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_R and event.pressed:
			grid.reset_cells()
		elif event.keycode == KEY_SPACE and event.pressed:
			toggle_simulation()
	elif event is InputEventMouseButton:
		var mouse_pos = grid.get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			grid.set_cell(grid.to_coords(mouse_pos), true)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			grid.set_cell(grid.to_coords(mouse_pos), false)
	elif event is InputEventMouseMotion:
		if event.button_mask & (MOUSE_BUTTON_LEFT | MOUSE_BUTTON_RIGHT):
			var destination = grid.get_global_mouse_position()
			var origin = destination - event.relative

			var origin_coords = grid.to_coords(origin)
			var destination_coords = grid.to_coords(destination)

			if origin_coords == Vector2i(-1, -1) or destination_coords == Vector2i(-1, -1):
				return

			var add_cell = event.button_mask & MOUSE_BUTTON_LEFT
			for point in Helper.bresenham(origin_coords, destination_coords):
				grid.set_cell(point, add_cell)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not is_running:
		return
		
	update_cells()
	# apply the changes to the grid
	print("Tick")

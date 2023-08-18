@tool # DEBUG
extends Node2D
class_name Grid


# @export_range(1, 0, 1, "or_greater") var grid_size: int = 32:
# 	set(new_grid_size):
# 		grid_size = new_grid_size
# 		_render_cells()
@export var grid_size: Vector2i = Vector2i(32, 32):
	set(new_grid_size):
		grid_size = new_grid_size
		_render_cells()
@export_group("Cell", "cell_")
@export_range(1, 0, 1, "or_greater") var cell_size: int = 8:
	set(new_cell_size):
		cell_size = new_cell_size
		_render_cells()
@export_range(1, 0, 1, "or_greater") var cell_spacing: int = 1:
	set(new_cell_spacing):
		cell_spacing = new_cell_spacing
		_render_cells()
@export var active_color: Color = Color(1, 1, 1, 1):
	set(new_active_color):
		active_color = new_active_color
		_render_cells()
@export var cell_style: StyleBox:
	set(new_cell_style):
		cell_style = new_cell_style
		_render_cells()
@export_group("", "")

func _render_cells():
	if not Engine.is_editor_hint():
		return

	cells = generate()
	if cell_style:
		queue_redraw()


class GridCell:
	var pos: Vector2
	var rect: Rect2
	var style: StyleBoxFlat
	var is_empty: bool = true

	var color: Color:
		set(new_color):
			style.bg_color = new_color

var cells: Array[GridCell] = []


## Get center of grid
func get_center() -> Vector2:
	return grid_size * (cell_size + cell_spacing) / 2

## Get maximum size of grid
func get_size() -> Vector2:
	return grid_size * (cell_size + cell_spacing)

## Get cell count
func get_cell_count() -> Vector2i:
	return grid_size

## Get neighboring cells
func get_neighbours(coords: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []

	for row in range(-1, 2):
		for col in range(-1, 2):
			if row == 0 and col == 0:
				continue

			var neighbor_coords = coords + Vector2i(col, row)
			if neighbor_coords.x < 0 or neighbor_coords.x >= grid_size.x:
				continue
			elif neighbor_coords.y < 0 or neighbor_coords.y >= grid_size.y:
				continue

			var neighbor = get_cell(neighbor_coords)
			if neighbor:
				neighbors.append(neighbor_coords)

	return neighbors

## Check if cell is active
func is_cell_active(coords: Vector2i) -> bool:
	var cell = get_cell(coords)
	if not cell:
		return false
	return not cell.is_empty

## Get cell at specified coordinates
func get_cell(coords: Vector2i) -> GridCell:
	var idx = coords.y * grid_size.x + coords.x
	if idx < 0 or idx >= cells.size():
		return null
	return cells[idx]

## Set cell to active or inactive
func set_cell(coords: Vector2i, active: bool, skip_redraw: bool = false):
	var cell = get_cell(coords)
	if not cell:
		return
	elif cell.is_empty == not active:
		return

	if active:
		cell.color = active_color
	else:
		cell.color = cell_style.bg_color
	cell.is_empty = not active
	
	if not skip_redraw:
		queue_redraw()

## Convert global position to grid coordinates
func to_coords(pos: Vector2) -> Vector2i:
	var max_grid_size = get_size()
	if pos.x < 0 or pos.y < 0:
		return Vector2i(-1, -1)
	elif pos.x >= max_grid_size.x or pos.y >= max_grid_size.y:
		return Vector2i(-1, -1)

	var col = floor(pos.x / (cell_size + cell_spacing))
	var row = floor(pos.y / (cell_size + cell_spacing))
	return Vector2i(col, row)

## Reset all specified cells or all if none specified
func reset_cells(cells_to_reset: Array[GridCell] = []):
	if cells_to_reset.size() == 0:
		cells_to_reset = cells

	for cell in cells_to_reset:
		cell.is_empty = true
		cell.color = cell_style.bg_color

	queue_redraw()

## Generate a grid of cells
func generate() -> Array[GridCell]:
	if not cell_style:
		print_debug("Missing StyleBox for grid cell")
		return []

	var grid: Array[GridCell] = []

	for row in range(grid_size.y):
		for col in range(grid_size.x):
			var cell = GridCell.new()
			cell.pos = Vector2(col, row)
			cell.rect = Rect2(
				cell.pos * (cell_size + cell_spacing), 
				Vector2(cell_size, cell_size)
			)
			cell.style = cell_style.duplicate()
			grid.append(cell)

	return grid

func _ready():
	if not Engine.is_editor_hint():
		cells = generate()

func _draw():
	for cell in cells:
		draw_style_box(cell.style, cell.rect)

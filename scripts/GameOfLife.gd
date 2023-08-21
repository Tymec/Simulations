@tool
extends Node2D


enum CellState {ALIVE = 0, DEAD = 1, TRAIL = 2}
enum EdgeBehaviour {ALIVE = 0, DEAD = 1, WRAP = 2, KILL = 3}
enum CellStyle {SQUARE = 0, SQUARE_OUTLINE = 1, CIRCLE = 2, CIRLCE_OUTLINE = 3, DIAMOND = 4, DIAMOND_OUTLINE = 5}


@export var rle_input: TextEdit
@export var cell_style: CellStyle = CellStyle.SQUARE:
	set(val):
		cell_style = val
		queue_redraw()
@export var edge_behaviour: EdgeBehaviour = EdgeBehaviour.WRAP
@export var randomize_on_start: bool = true:
	set(val):
		randomize_on_start = val
@export_group("Grid", "grid_")
@export var grid_size: Vector2i = Vector2i(32, 32):
	set(val):
		grid_size = val
		generate_rects()
		emit_signal("grid_size_changed", grid_size)
@export_range(1, 0, 1, "or_greater") var grid_cell_size: int = 16:
	set(val):
		grid_cell_size = val
		if Engine.is_editor_hint() and rects.size() == 0:
			generate_grid()
			queue_redraw()
			return

		generate_rects()
		queue_redraw()
@export_range(1, 0, 1, "or_greater") var grid_spacing: int = 4:
	set(val):
		grid_spacing = val
		if Engine.is_editor_hint() and rects.size() == 0:
			generate_grid()
			queue_redraw()
			return

		generate_rects()
		queue_redraw()
@export_range(0, 0, 1, "or_greater") var grid_trail_length: int = 0:
	set(val):
		grid_trail_length = val
@export var grid_alive_cell_color: Color = Color(0, 0, 0, 1):
	set(val):
		grid_alive_cell_color = val
		queue_redraw()
@export var grid_dead_cell_color: Color = Color(1, 1, 1, 1):
	set(val):
		grid_dead_cell_color = val
		queue_redraw()
@export var grid_trail_cell_color: Color = Color(.2, .7, .8, 1):
	set(val):
		grid_trail_cell_color = val
		queue_redraw()
@export_group("Rules", "rule_")
@export var rule_births: Array[int] = [3]:
	set(val):
		rule_births = val
@export var rule_survivals: Array[int] = [2, 3]:
	set(val):
		rule_survivals = val
@export_group("", "")


signal simulation_status(status: String)
signal generation_changed(generation: int)
signal births_changed(births: int)
signal deaths_changed(deaths: int)
signal grid_size_changed(size: Vector2i)


@onready var timer: Timer = $Timer
var rects: Array[Rect2] = []
var current_grid: Array[int] = []
var next_grid: Array[int] = []
var original_grid: Array[int] = []

var generation: int = 0
var births: int = 0
var deaths: int = 0

## Get the cell at the given coordinates
func get_cell(x: int, y: int, cells: Array[int]) -> int:
	# Check if the cell is out of bounds and handle it accordingly based on the edge behaviour
	if x < 0 or x >= grid_size.x or y < 0 or y >= grid_size.y:
		if edge_behaviour == EdgeBehaviour.WRAP:
			x = wrapi(x, 0, grid_size.x)
			y = wrapi(y, 0, grid_size.y)
		else:
			return edge_behaviour

	# Return the cell at the given coordinates
	return cells[x + y * grid_size.x]

## Set the cell at the given coordinates to the given value
func set_cell(x: int, y: int, value: int, cells: Array[int], force_nowrap: bool = false):
	# Check if the cell is out of bounds and handle it accordingly based on the edge behaviour
	if x < 0 or x >= grid_size.x or y < 0 or y >= grid_size.y:
		if force_nowrap:
			return
		elif edge_behaviour == EdgeBehaviour.WRAP:
			x = wrapi(x, 0, grid_size.x)
			y = wrapi(y, 0, grid_size.y)
		else:
			return
	elif x == 0 or x == grid_size.x - 1 or y == 0 or y == grid_size.y - 1:
		if edge_behaviour == EdgeBehaviour.KILL and value == CellState.ALIVE and not force_nowrap:
			value = CellState.DEAD
			for i in range(-1, 2):
				for j in range(-1, 2):
					if i == 0 and j == 0:
						continue

					set_cell(x + i, y + j, CellState.DEAD, cells, true)

	# Set the cell at the given coordinates to the given value
	cells[x + y * grid_size.x] = value

## Get number of active cells around the given cell
func get_neighbours(x: int, y: int, cells: Array[int]) -> int:
	var count = 0

	# Check all cells around the given cell
	for i in range(-1, 2):
		for j in range(-1, 2):
			# Skip the cell itself
			if i == 0 and j == 0:
				continue

			# Check if the cell is alive
			if get_cell(x + i, y + j, cells) == CellState.ALIVE:
				count += 1

			# Optimization: if the count is already 4, we can stop checking
			if count > 3:
				return count

	return count

## Updates the cells in the grid
func update_grid() -> bool:
	var has_changed = false

	# Update all cells in the grid
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			# Get the cell and its neighbours
			var cell = get_cell(x, y, current_grid)
			var neighbours = get_neighbours(x, y, current_grid)

			# Check if the cell should live or die based on the number of neighbours
			var new_state = cell
			if cell == CellState.ALIVE:
				new_state = CellState.DEAD + grid_trail_length
				if neighbours in rule_survivals:
					new_state = CellState.ALIVE
					births += 1
					emit_signal("births_changed", births)
				else:
					deaths += 1
					emit_signal("deaths_changed", deaths)
			else:
				if neighbours in rule_births:
					new_state = CellState.ALIVE
				elif new_state != CellState.DEAD:
					new_state -= 1

			# Update the cell
			if cell != new_state:
				has_changed = true
			set_cell(x, y, new_state, next_grid)

	return has_changed

## Generates a cell shape at the given coordinates
func generate_shape(x: int, y: int):
	return Rect2(
		Vector2(x, y) * (grid_cell_size + grid_spacing) - get_grid_center(),
		Vector2(grid_cell_size, grid_cell_size)
	)

## Generate rects for cells in the grid
func generate_rects():
	# Clear the rects
	rects.clear()

	# Resize the rects
	rects.resize(grid_size.x * grid_size.y)

	# Generate rects for all cells in the grid
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			rects[x + y * grid_size.x] = generate_shape(x, y)

## Generate a grid of cells
func generate_grid():
	# Clear the grid
	rects.clear()
	current_grid.clear()
	next_grid.clear()

	# Resize the grid
	rects.resize(grid_size.x * grid_size.y)
	current_grid.resize(grid_size.x * grid_size.y)
	next_grid.resize(grid_size.x * grid_size.y)

	# Generate the grid
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var index = x + y * grid_size.x

			# Create the rect for the cell and add it to the grid
			rects[index] = generate_shape(x, y)

			# Initialize the cell to dead
			var initial_value = CellState.DEAD
			if randomize_on_start:
				initial_value =  CellState.DEAD if randi() % 2 == 0 else CellState.ALIVE
			current_grid[index] = initial_value
			next_grid[index] = initial_value

## Convert global coordinates to grid coordinates
func to_coords(pos: Vector2) -> Vector2i:
	# Check if the position is out of bounds
	var dims = get_dimensions()
	if pos.x < dims.x or pos.y < dims.y or pos.x >= dims.z or pos.y >= dims.w:
		return Vector2i(-1, -1)

	# Offset the position by the center of the grid
	pos += get_grid_center()

	# Convert the position to grid coordinates
	var col = floor(pos.x / (grid_cell_size + grid_spacing))
	var row = floor(pos.y / (grid_cell_size + grid_spacing))
	return Vector2i(col, row)

## Get center of grid (in local coordinates)
func get_grid_center() -> Vector2:
	return grid_size * (grid_cell_size + grid_spacing) / 2

## Get dimensions of grid (in local coordinates)
func get_dimensions() -> Vector4i:
	var top_left = rects[0].position
	var bottom_right = rects[rects.size() - 1].end

	return Vector4i(
		top_left.x,
		top_left.y,
		bottom_right.x,
		bottom_right.y
	)

## Reset counter values
func reset_counters():
	generation = 0
	emit_signal("generation_changed", generation)
	births = 0
	emit_signal("births_changed", births)
	deaths = 0
	emit_signal("deaths_changed", deaths)

## Parse RLE string
func parse_rle(contents: String) -> Dictionary:
	var grid: Array[int] = current_grid.duplicate()
	grid.fill(CellState.DEAD)
	var new_grid_size: Vector2i = grid_size
	var new_rule_births: Array[int] = rule_births.duplicate()
	var new_rule_survivals: Array[int] = rule_survivals.duplicate()

	var x = 0
	var y = 0
	var offset = 0
	var run_count = ""

	# Parse the file
	var lines = contents.split("\n")
	for line in lines:
		line = line.strip_edges()

		# Skip comments
		if line.begins_with("#"):
			continue

		# Parse header
		if line.begins_with("x"):
			# Parse the line
			var tokens = line.split(",")
			var map = {}
			for token in tokens:
				token = token.strip_edges()

				# Check if the token is empty
				if token == "":
					continue

				var parts = token.split("=")
				if parts.size() != 2:
					continue

				var key = parts[0].strip_edges()
				var value = parts[1].strip_edges()

				if key == "" or value == "":
					continue

				map[key] = value

			# Get the grid size
			if "x" in map and "y" in map:
				var pattern_size = Vector2i(map["x"].to_int(), map["y"].to_int())
				if pattern_size.x > grid_size.x or pattern_size.y > grid_size.y:
					# Resize to 2x the pattern size
					var sz = max(pattern_size.x, pattern_size.y)
					new_grid_size = Vector2i(sz, sz) * 2
					grid.resize(new_grid_size.x * new_grid_size.y)
					grid.fill(CellState.DEAD)

				# try to center the pattern
				offset = (new_grid_size - pattern_size) / 2
				x = offset.x
				y = offset.y
			else:
				print_debug("Invalid RLE file: missing grid size")
				return {"success": false}

			# Get the rule string
			if "rule" in map:
				var rule = map["rule"].to_lower()
				if rule.begins_with("b") and rule.contains("/") and rule.contains("s"):
					var parts = rule.split("/")
					var birth = parts[0].strip_edges()
					var survival = parts[1].strip_edges()

					if birth.begins_with("b") and survival.begins_with("s"):
						birth = birth.split("").slice(1)
						survival = survival.split("").slice(1)

						new_rule_births.clear()
						new_rule_survivals.clear()

						for i in birth:
							new_rule_births.append(i.to_int())
						for i in survival:
							new_rule_survivals.append(i.to_int())
					else:
						print_debug("Invalid RLE file: invalid rule string")
						return {"success": false}
				else:
					print_debug("Invalid RLE file: invalid or unsupported rule string")
					return {"success": false}

			continue

		# Parse the line
		var tokens = line.split("")
		for token in tokens:
			token = token.strip_edges()

			# Check if the token is empty
			if token == "":
				continue

			# Check if the token is a number
			if token.is_valid_int():
				run_count += token
				continue

			# Check if the token is a letter or symbol
			var letter = token.to_lower()
			var count = 1
			if run_count != "":
				count = run_count.to_int()
				run_count = ""

			if letter == "b":
				for i in range(count):
					grid[x + y * new_grid_size.x] = CellState.DEAD
					x += 1
			elif letter == "o":
				for i in range(count):
					grid[x + y * new_grid_size.x] = CellState.ALIVE
					x += 1
			elif letter == "$":
				x = offset.x
				y += 1
			elif letter == "!":
				return {
					"success": true,
					"grid": grid,
					"size": new_grid_size,
					"rule": {
						"births": rule_births,
						"survivals": rule_survivals
					}
				}

	print_debug("Invalid RLE file: missing end of file marker")
	return {"success": false}

func _ready():
	generate_grid()

func _draw():
	for i in range(rects.size()):
		var color = grid_dead_cell_color
		if current_grid[i] == CellState.ALIVE:
			color = grid_alive_cell_color
		elif current_grid[i] > CellState.DEAD and grid_trail_length > 0:
			color = grid_dead_cell_color.lerp(grid_trail_cell_color, current_grid[i] / float(grid_trail_length))

		if cell_style == CellStyle.CIRCLE:
			draw_circle(rects[i].position + rects[i].size / 2.0, grid_cell_size / 2.0, color)
		elif cell_style == CellStyle.CIRLCE_OUTLINE:
			draw_arc(rects[i].position + rects[i].size / 2.0, grid_cell_size / 2.0, 0, TAU, 32, color, 1)
		elif cell_style == CellStyle.SQUARE_OUTLINE:
			draw_polyline([
				rects[i].position,
				rects[i].position + Vector2(rects[i].size.x, 0),
				rects[i].position + rects[i].size,
				rects[i].position + Vector2(0, rects[i].size.y),
				rects[i].position,
			], color, 1)
		elif cell_style == CellStyle.DIAMOND:
			draw_colored_polygon([
				rects[i].position + Vector2(rects[i].size.x / 2, 0),
				rects[i].position + Vector2(rects[i].size.x, rects[i].size.y / 2),
				rects[i].position + Vector2(rects[i].size.x / 2, rects[i].size.y),
				rects[i].position + Vector2(0, rects[i].size.y / 2),
				rects[i].position + Vector2(rects[i].size.x / 2, 0),
			], color)
		elif cell_style == CellStyle.DIAMOND_OUTLINE:
			draw_polyline([
				rects[i].position + Vector2(rects[i].size.x / 2, 0),
				rects[i].position + Vector2(rects[i].size.x, rects[i].size.y / 2),
				rects[i].position + Vector2(rects[i].size.x / 2, rects[i].size.y),
				rects[i].position + Vector2(0, rects[i].size.y / 2),
				rects[i].position + Vector2(rects[i].size.x / 2, 0),
			], color, 1, false)
		else:
			draw_rect(rects[i], color)

func _input(event):
	if event is InputEventMouseButton:
		if not timer.is_stopped() and not timer.paused:
			return

		if event.button_mask & (MOUSE_BUTTON_LEFT | MOUSE_BUTTON_RIGHT) and event.pressed:
			# Place/remove a single cell at the mouse position
			var pt = to_coords(get_global_mouse_position())
			if pt != Vector2i(-1, -1):
				var new_state = CellState.ALIVE if event.button_mask & MOUSE_BUTTON_LEFT else CellState.DEAD
				set_cell(pt.x, pt.y, new_state, current_grid, true)
				queue_redraw()
	elif event is InputEventMouseMotion:
		if not timer.is_stopped() and not timer.paused:
			return

		if event.button_mask & (MOUSE_BUTTON_LEFT | MOUSE_BUTTON_RIGHT):
			# Draw/erase cells in a line from the previous mouse position to the current one
			var origin = to_coords(get_global_mouse_position() - event.relative)
			var destination = to_coords(get_global_mouse_position())

			if origin != Vector2i(-1, -1) and destination != Vector2i(-1, -1):
				var new_state = CellState.ALIVE if event.button_mask & MOUSE_BUTTON_LEFT else CellState.DEAD
				for pt in Helper.bresenham(origin, destination):
					set_cell(pt.x, pt.y, new_state, current_grid, true)
				queue_redraw()

func _on_timer_timeout():
	# Perform simulation step and stop if nothing changed
	if not update_grid():
		timer.paused = true
		emit_signal("simulation_status", "finished")
		return

	# Update generation counter
	generation += 1
	emit_signal("generation_changed", generation)

	# Swap grids and redraw
	var tmp = current_grid
	current_grid = next_grid
	next_grid = tmp
	queue_redraw()

func _on_play_button_pressed():
	if timer.is_stopped():
		# Save current grid state
		original_grid = current_grid.duplicate()

		# Reset counters
		reset_counters()

		# Start simulation
		timer.start()
		timer.paused = false
		emit_signal("simulation_status", "running")
	elif timer.paused:
		# Resume simulation
		timer.paused = false
		emit_signal("simulation_status", "running")

func _on_pause_button_pressed():
	if not timer.is_stopped():
		# Pause simulation
		timer.paused = true
		emit_signal("simulation_status", "paused")

func _on_reset_button_pressed():
	if not timer.is_stopped():
		# Stop simulation
		timer.stop()
		timer.paused = false
		emit_signal("simulation_status", "stopped")

		# Reset counters
		reset_counters()

		# Reset grid to original state
		current_grid = original_grid.duplicate()
		original_grid.clear()
		queue_redraw()
	elif timer.is_stopped() and original_grid.is_empty():
		# Randomize grid
		for y in range(grid_size.y):
			for x in range(grid_size.x):
				set_cell(x, y, randi() % 2, current_grid, true)
		queue_redraw()

func _on_clear_button_pressed():
	if not timer.is_stopped():
		# Stop simulation
		timer.stop()
		timer.paused = false
		emit_signal("simulation_status", "stopped")

	# Clear grid if it's not empty
	if original_grid.size() > 0:
		original_grid.clear()

	# Reset counters
	reset_counters()

	# Clear grid
	current_grid.fill(CellState.DEAD)
	next_grid.fill(CellState.DEAD)
	queue_redraw()

func _on_save_button_pressed():
	pass # Replace with function body.

func _on_load_button_pressed():
	pass # Replace with function body.

func _on_grid_size_x_value_changed(value):
	if value != grid_size.x:
		# Stop simulation
		timer.stop()
		timer.paused = false

		# Clear original grid if it's not empty
		original_grid.clear()

		# Reset counters
		reset_counters()

		# Resize grid
		grid_size.x = value

		# Regenerate grid
		generate_grid()
		queue_redraw()

func _on_grid_size_y_value_changed(value):
	if value != grid_size.y:
		# Stop simulation
		timer.stop()
		timer.paused = false

		# Clear original grid if it's not empty
		original_grid.clear()

		# Reset counters
		reset_counters()

		# Resize grid
		grid_size.y = value

		# Regenerate grid
		generate_grid()
		queue_redraw()

func _on_cell_size_value_changed(value):
	if value != grid_cell_size:
		grid_cell_size = value

func _on_spacing_value_changed(value):
	if value != grid_spacing:
		grid_spacing = value

func _on_edge_behaviour_item_selected(index):
	if not timer.is_stopped() and not timer.paused:
		timer.paused = true
	edge_behaviour = index

func _on_dead_color_changed(color):
	grid_dead_cell_color = color

func _on_alive_color_changed(color):
	grid_alive_cell_color = color

func _on_randomize_toggled(button_pressed):
	randomize_on_start = button_pressed

func _on_trail_color_changed(color):
	grid_trail_cell_color = color

func _on_trail_length_value_changed(value):
	if value != grid_trail_length:
		grid_trail_length = value

func _on_speed_value_changed(value):
	if not timer.is_stopped() and not timer.paused:
		timer.paused = true
	timer.wait_time = value
	timer.paused = false

func _on_cell_style_item_selected(index):
	cell_style = index

func _on_rle_input_child_entered_tree(node):
	rle_input = node

func _on_rle_input_text_changed():
	if not rle_input:
		return

	# Stop simulation
	timer.stop()
	timer.paused = false

	# Clear original grid if it's not empty
	original_grid.clear()

	# Reset counters
	reset_counters()

	# Parse RLE input
	var rle = rle_input.text
	var result = parse_rle(rle)

	if result["success"]:
		print("RLE input parsed successfully.")

		current_grid.clear()
		next_grid.clear()

		current_grid = result["grid"]
		next_grid = current_grid.duplicate()

		grid_size = result["size"]
		emit_signal("grid_size_changed", grid_size)
		rule_births = result["rule"]["births"]
		rule_survivals = result["rule"]["survivals"]

		generate_rects()
		queue_redraw()

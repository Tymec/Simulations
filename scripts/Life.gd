extends Node2D


#const INVOCATIONS = 1
enum EdgeBehaviour {WRAP = 0, DEAD = 1, KILL = 2}
enum Counter {GENERATION = 0, SURVIVALS = 1, BIRTHS = 2, DEATHS = 3}


signal simulation_status(status: String)
signal generation_changed(generation: int)
signal births_changed(births: int)
signal deaths_changed(deaths: int)
signal survivals_changed(survivals: int)

@export var randomize_on_start: bool = false:
	set(val):
		randomize_on_start = val
@export_group("Grid", "grid_")
@export var grid_size: Vector2i = Vector2i(32, 32):
	set(val):
		grid_size = val

		rects = generate_rects()
		grid = generate_grid()
		var next_grid = grid.duplicate()
		original_grid.clear()

		# Reset counters
		reset_counters()

		compute.reregister_buffer("grid", grid.to_byte_array())
		compute.reregister_buffer("next_grid", next_grid.to_byte_array())

		queue_redraw()
@export_range(1, 0, 1, "or_greater") var grid_cell_size: int = 16:
	set(val):
		grid_cell_size = val
		rects = generate_rects()
		queue_redraw()
@export_range(1, 0, 1, "or_greater") var grid_spacing: int = 4:
	set(val):
		grid_spacing = val
		rects = generate_rects()
		queue_redraw()
@export_group("Colors", "colors_")
@export var colors_alive: Color = Color(0, 0, 0, 1):
	set(val):
		colors_alive = val
		queue_redraw()
@export var colors_dead: Color = Color(1, 1, 1, 1):
	set(val):
		colors_dead = val
		queue_redraw()
@export_group("Behavior", "behavior_")
@export var behavior_edge: EdgeBehaviour = EdgeBehaviour.WRAP:
	set(val):
		behavior_edge = val
		settings[0] = val
		compute.update_buffer("settings", settings.to_byte_array())
@export_flags("0", "1", "2", "3", "4", "5", "6", "7", "8") var behavior_rule_births = 8:
	set(val):
		behavior_rule_births = val
		settings[1] = val
		compute.update_buffer("settings", settings.to_byte_array())
@export_flags("0", "1", "2", "3", "4", "5", "6", "7", "8") var behavior_rule_survivals = 12:
	set(val):
		behavior_rule_survivals = val
		settings[2] = val
		compute.update_buffer("settings", settings.to_byte_array())
@export_group("", "")

@onready var timer: Timer = $Timer
@onready var compute: ComputeShader = $ComputeShader

var rects: Array[Rect2]
var grid: PackedInt32Array
var original_grid: PackedInt32Array
var settings: PackedInt32Array
var counters: PackedInt32Array


## Set the cell at the given coordinates to the given value
func set_cell(x: int, y: int, value: int) -> void:
	# Check if the cell is out of bounds and handle it accordingly based on the edge behaviour
	if x < 0 or x >= grid_size.x or y < 0 or y >= grid_size.y:
		return

	# Set the cell at the given coordinates to the given value
	grid[x + y * grid_size.x] = value

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

## Generate the rects for the grid
func generate_rects() -> Array[Rect2]:
	var _rects: Array[Rect2] = []

	_rects.resize(grid_size.x * grid_size.y)
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			_rects[y * grid_size.x + x] = Rect2(
				Vector2(x, y) * (grid_cell_size + grid_spacing) - get_grid_center(),
				Vector2(grid_cell_size, grid_cell_size)
			)

	return _rects

## Generate grid cell data
func generate_grid(rng: bool = false) -> PackedInt32Array:
	var _grid = PackedInt32Array()
	_grid.resize(grid_size.x * grid_size.y)
	if rng:
		for i in range(_grid.size()):
			_grid[i] = randi() % 2
	else:
		_grid.fill(0)
	return _grid

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

## Reset the counters
func reset_counters() -> void:
	counters = PackedInt32Array([0, 0, 0, 0])
	compute.update_buffer("counters", counters.to_byte_array())

	emit_signal("generation_changed", 0)
	emit_signal("survivals_changed", 0)
	emit_signal("births_changed", 0)
	emit_signal("deaths_changed", 0)

## Perform a single simulation step
func simulation_step() -> void:
	# Check if the compute shader is available
	if not compute.is_available():
		return

	# Update buffers
	compute.update_buffer("grid", grid.to_byte_array())
	compute.update_buffer("counters", counters.to_byte_array())

	# Run the compute shader
	compute.execute(grid_size.x, grid_size.y, 1)
	compute.wait() # TODO: Run in parallel

	# Retrieve the results and update the grid
	var new_grid = compute.fetch_buffer("next_grid").to_int32_array()
	grid = new_grid

	# Update counters
	var new_counters = compute.fetch_buffer("counters").to_int32_array()

	# If nothing has changed, pause the simulation
	if new_counters[Counter.BIRTHS] == counters[Counter.BIRTHS] and new_counters[Counter.DEATHS] == counters[Counter.DEATHS]:
		timer.paused = true
		emit_signal("simulation_status", "paused")
		return

	# Update the counters
	new_counters[Counter.GENERATION] = counters[Counter.GENERATION] + 1
	counters = new_counters
	emit_signal("generation_changed", new_counters[Counter.GENERATION])
	emit_signal("survivals_changed", new_counters[Counter.SURVIVALS])
	emit_signal("births_changed", new_counters[Counter.BIRTHS])
	emit_signal("deaths_changed", new_counters[Counter.DEATHS])

	# Queue a redraw
	queue_redraw()

func _ready() -> void:
	# Setup the grid
	grid = generate_grid(randomize_on_start)
	var next_grid = grid.duplicate()
	original_grid = []
	rects = generate_rects()
	queue_redraw()

	# Setup arrays
	settings = PackedInt32Array([behavior_edge, behavior_rule_births, behavior_rule_survivals])
	counters = PackedInt32Array([0, 0, 0, 0])

	# Setup the compute shader
	compute.register_buffer("grid", grid.to_byte_array(), 0)
	compute.register_buffer("next_grid", next_grid.to_byte_array(), 1)
	compute.register_buffer("settings", settings.to_byte_array(), 2)
	compute.register_buffer("counters", counters.to_byte_array(), 3)

func _draw() -> void:
	for i in range(rects.size()):
		draw_rect(rects[i], colors_alive if grid[i] == 1 else colors_dead)

func _input(event) -> void:
	if event is InputEventMouseButton:
		if not timer.is_stopped() and not timer.paused:
			return

		if event.button_mask & (MOUSE_BUTTON_LEFT | MOUSE_BUTTON_RIGHT) and event.pressed:
			# Place/remove a single cell at the mouse position
			var pt = to_coords(get_global_mouse_position())
			if pt != Vector2i(-1, -1):
				var new_state = 1 if event.button_mask & MOUSE_BUTTON_LEFT else 0
				set_cell(pt.x, pt.y, new_state)
				queue_redraw()
	elif event is InputEventMouseMotion:
		if not timer.is_stopped() and not timer.paused:
			return

		if event.button_mask & (MOUSE_BUTTON_LEFT | MOUSE_BUTTON_RIGHT):
			# Draw/erase cells in a line from the previous mouse position to the current one
			var origin = to_coords(get_global_mouse_position() - event.relative)
			var destination = to_coords(get_global_mouse_position())

			if origin != Vector2i(-1, -1) and destination != Vector2i(-1, -1):
				var new_state = 1 if event.button_mask & MOUSE_BUTTON_LEFT else 0
				for pt in Helper.bresenham(origin, destination):
					set_cell(pt.x, pt.y, new_state)
				queue_redraw()

func _on_timer_timeout() -> void:
	call_deferred("simulation_step")

func _on_play_button_pressed() -> void:
	if timer.is_stopped():
		# Save the current grid state
		original_grid = grid.duplicate()

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

func _on_pause_button_pressed() -> void:
	if not timer.is_stopped():
		# Pause simulation
		timer.paused = true
		emit_signal("simulation_status", "paused")

func _on_reset_button_pressed() -> void:
	if not timer.is_stopped():
		# Stop simulation
		timer.stop()
		timer.paused = false
		emit_signal("simulation_status", "stopped")

		# Reset counters
		reset_counters()

		# Reset grid to original state
		grid = original_grid.duplicate()
		original_grid.clear()
		queue_redraw()
	elif timer.is_stopped() and original_grid.is_empty():
		# Randomize grid
		grid = generate_grid(true)
		queue_redraw()

func _on_clear_button_pressed() -> void:
	if not timer.is_stopped():
		# Stop simulation
		timer.stop()
		timer.paused = false
		emit_signal("simulation_status", "stopped")

	# Reset counters
	reset_counters()

	# Clear the grid
	grid.fill(0)
	queue_redraw()

func _on_grid_size_x_changed(value: int) -> void:
	if value != grid_size.x:
		# Stop simulation
		timer.stop()
		timer.paused = false
		emit_signal("simulation_status", "stopped")

		# Resize grid
		grid_size.x = value

func _on_grid_size_y_changed(value: int) -> void:
	if value != grid_size.y:
		# Stop simulation
		timer.stop()
		timer.paused = false
		emit_signal("simulation_status", "stopped")

		# Resize grid
		grid_size.y = value

func _on_grid_cell_size_changed(value: int) -> void:
	if value != grid_cell_size:
		grid_cell_size = value

func _on_grid_spacing_changed(value: int) -> void:
	if value != grid_spacing:
		grid_spacing = value

func _on_edge_behaviour_selected(index: int) -> void:
	if index != behavior_edge:
		behavior_edge = index as EdgeBehaviour

func _on_speed_value_changed(value: float) -> void:
	if value != timer.wait_time:
		Engine.time_scale = value

func _on_dead_color_changed(color: Color) -> void:
	colors_dead = color

func _on_alive_color_changed(color: Color) -> void:
	colors_alive = color

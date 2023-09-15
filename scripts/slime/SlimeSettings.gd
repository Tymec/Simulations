class_name SlimeSettings
extends Resource


signal settings_changed


const WORKGROUP_SIZE = 1024

@export_range(100, 1000, 1, "or_greater") var agent_count: int = 1000
@export_range(1, 100, 1, "or_greater") var agent_speed: float = 30.0:
	set(val):
		agent_speed = val
		settings_changed.emit()
@export_range(0, 3, .01) var evaporate_speed: float = 0.2:
	set(val):
		evaporate_speed = val
		settings_changed.emit()
@export_range(0, 10, .01) var diffuse_speed: float = 0.2:
	set(val):
		diffuse_speed = val
		settings_changed.emit()
@export_range(0, 10, 1) var blur_radius: int = 1:
	set(val):
		blur_radius = val
		settings_changed.emit()
@export_range(0, 10, 1) var sensor_size: int = 3:
	set(val):
		sensor_size = val
		settings_changed.emit()
@export_range(0, 360, 1) var sensor_angle: int = 120:
	set(val):
		sensor_angle = val
		settings_changed.emit()
@export_range(0, 100, 0.1) var sensor_distance: float = 1.0:
	set(val):
		sensor_distance = val
		settings_changed.emit()
@export var turn_speed: float = 1.0:
	set(val):
		turn_speed = val
		settings_changed.emit()
@export_range(1, 1000, 1) var spawn_radius: int = 100
@export var random_seed: int = -1
@export var output_size: Vector2i = Vector2i(1152, 648)


func to_byte_array() -> PackedByteArray:
	var result = PackedByteArray()
	result.resize(32)

	result.encode_u32(0, agent_count)
	result.encode_float(4, agent_speed)
	result.encode_u32(8, output_size.x)
	result.encode_u32(12, output_size.y)

	result.encode_s32(16, sensor_size)
	result.encode_float(20, deg_to_rad(sensor_angle / 2.0))
	result.encode_float(24, sensor_distance)
	result.encode_float(28, turn_speed * TAU)

	return result

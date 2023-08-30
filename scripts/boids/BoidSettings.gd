class_name BoidSettings
extends Resource


signal settings_changed

const WORKGROUP_SIZE = 1024

@export_group("Boid", "boid_")
@export_range(100, 100, 1, "or_greater") var boid_count: int = 100:
	set(val):
		boid_count = val
		settings_changed.emit()
@export_range(0.1, 5, 0.1) var boid_size: float = 1.0:
	set(val):
		boid_size = val
		settings_changed.emit()
@export_subgroup("Speed", "boid_speed_")
@export_range(1, 500) var boid_speed_min: float = 200.0:
	set(val):
		boid_speed_min = val
		settings_changed.emit()
@export_range(1, 500) var boid_speed_max: float = 300.0:
	set(val):
		boid_speed_max = val
		settings_changed.emit()
@export_subgroup("Separation", "boid_separation_")
@export_range(0, 500) var boid_separation_distance: int = 10:
	set(val):
		boid_separation_distance = val
		settings_changed.emit()
@export_range(0, 2, 0.0001) var boid_separation_weight: float = 0.05:
	set(val):
		boid_separation_weight = val
		settings_changed.emit()
@export_subgroup("Alignment", "boid_alignment_")
@export_range(0, 500) var boid_alignment_distance: int = 50:
	set(val):
		boid_alignment_distance = val
		settings_changed.emit()
@export_range(0, 2, 0.0001) var boid_alignment_weight: float = 0.05:
	set(val):
		boid_alignment_weight = val
		settings_changed.emit()
@export_subgroup("Cohesion", "boid_cohesion_")
@export_range(0, 500) var boid_cohesion_distance: int = 50:
	set(val):
		boid_cohesion_distance = val
		settings_changed.emit()
@export_range(0, 2, 0.0001) var boid_cohesion_weight: float = 0.0005:
	set(val):
		boid_cohesion_weight = val
		settings_changed.emit()
@export_group("Edge", "edge_")
@export var edge_wrap: bool = true:
	set(val):
		edge_wrap = val
		settings_changed.emit()
@export_range(0, 10, 0.1) var edge_avoid_weight: float = 0.5:
	set(val):
		edge_avoid_weight = val
		settings_changed.emit()
@export var edge_visualize: bool = false
@export_subgroup("Margin", "edge_margin_")
@export_range(0, 100, 1, "or_greater") var edge_margin_left: int = 100:
	set(val):
		edge_margin_left = val
		settings_changed.emit()
@export_range(0, 100, 1, "or_greater") var edge_margin_right: int = 100:
	set(val):
		edge_margin_right = val
		settings_changed.emit()
@export_range(0, 100, 1, "or_greater") var edge_margin_top: int = 100:
	set(val):
		edge_margin_top = val
		settings_changed.emit()
@export_range(0, 100, 1, "or_greater") var edge_margin_bottom: int = 100:
	set(val):
		edge_margin_bottom = val
		settings_changed.emit()
#@export_group("View", "view_")
# Currently not used, as the computation is too expensive
#@export_range(0, 360) var view_angle: int = 270
@export_group("Family", "family_")
@export_range(0, 1, 1, "or_greater") var family_count: int = 0:
	set(val):
		family_count = val
		settings_changed.emit()
@export_range(0, 500) var family_distance: int = 50:
	set(val):
		family_distance = val
		settings_changed.emit()
@export_range(0, 2, 0.0001) var family_weight: float = 0.1:
	set(val):
		family_weight = val
		settings_changed.emit()
@export_group("Predator", "predator_")
@export_range(0, 1, 1, "or_greater") var predator_count: int = 0:
	set(val):
		predator_count = val
		settings_changed.emit()
@export_range(0, 500) var predator_speed: float = 300.0:
	set(val):
		predator_speed = val
		settings_changed.emit()
@export_range(0, 500) var predator_distance: int = 50:
	set(val):
		predator_distance = val
		settings_changed.emit()
@export_range(0, 2, 0.0001) var predator_weight: float = 0.1:
	set(val):
		predator_weight = val
		settings_changed.emit()
@export_group("Mouse", "mouse_")
@export_range(0, 500) var mouse_distance: int = 50:
	set(val):
		mouse_distance = val
		settings_changed.emit()
@export_range(0, 2, 0.0001) var mouse_weight: float = 5:
	set(val):
		mouse_weight = val
		settings_changed.emit()
@export_group("Shader", "shader_")
 # TODO: Dynamically set based on boid_count and WORKGROUP_SIZE
@export var shader_image_size: int = 256
@export_group("", "")


func to_byte_array() -> PackedByteArray:
	var int_buffer = PackedInt32Array([
		boid_count,
		boid_separation_distance * boid_separation_distance,
		boid_alignment_distance * boid_alignment_distance,
		boid_cohesion_distance * boid_cohesion_distance,
		1 if edge_wrap else 0,
		edge_margin_left,
		edge_margin_right,
		edge_margin_top,
		edge_margin_bottom,
		family_count,
		family_distance * family_distance,
		predator_count,
		predator_speed,
		predator_distance * predator_distance,
		mouse_distance * mouse_distance,
		shader_image_size,
	])
	var float_buffer = PackedFloat32Array([
		boid_size,
		boid_speed_min,
		boid_speed_max,
		boid_separation_weight,
		boid_alignment_weight,
		boid_cohesion_weight,
		edge_avoid_weight,
		family_weight,
		predator_weight,
		mouse_weight,
	])

	var buffer = PackedByteArray()
	buffer.append_array(int_buffer.to_byte_array())
	buffer.append_array(float_buffer.to_byte_array())
	return buffer


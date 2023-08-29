class_name BoidSettings
extends Resource


signal settings_changed


@export_range(1, 500) var min_speed: float = 200.0:
	set(val):
		min_speed = val
		settings_changed.emit()
@export_range(1, 500) var max_speed: float = 300.0:
	set(val):
		max_speed = val
		settings_changed.emit()
@export_group("Edge", "edge_")
@export var edge_wrap: bool = true:
	set(val):
		edge_wrap = val
		settings_changed.emit()
@export var edge_avoid: bool = false:
	set(val):
		edge_avoid = val
		settings_changed.emit()
@export var edge_avoidance_weight: float = 0.2:
	set(val):
		edge_avoidance_weight = val
		settings_changed.emit()
@export var edge_visualize: bool = false
@export_subgroup("Margin", "edge_margin_")
@export_range(0, 300, 1, "allow_greater") var edge_margin_left: int = 100:
	set(val):
		edge_margin_left = val
		settings_changed.emit()
@export_range(0, 300, 1, "allow_greater") var edge_margin_right: int = 100:
	set(val):
		edge_margin_right = val
		settings_changed.emit()
@export_range(0, 300, 1, "allow_greater") var edge_margin_top: int = 100:
	set(val):
		edge_margin_top = val
		settings_changed.emit()
@export_range(0, 300, 1, "allow_greater") var edge_margin_bottom: int = 100:
	set(val):
		edge_margin_bottom = val
		settings_changed.emit()
@export_subgroup("", "")
@export_group("View", "view_")
@export_range(0, 360) var view_angle: int = 270:
	set(val):
		view_angle = val
		settings_changed.emit()
@export_group("Distance", "distance_")
@export_range(0, 500) var distance_separation: int = 10:
	set(val):
		distance_separation = val
		settings_changed.emit()
@export_range(0, 500) var distance_alignment: int = 50:
	set(val):
		distance_alignment = val
		settings_changed.emit()
@export_range(0, 500) var distance_cohesion: int = 50:
	set(val):
		distance_cohesion = val
		settings_changed.emit()
@export_range(0, 500) var distance_family_avoidance: int = 50:
	set(val):
		distance_family_avoidance = val
		settings_changed.emit()
@export_group("Weight", "weight_")
@export_range(0, 2) var weight_separation: float = 0.05:
	set(val):
		weight_separation = val
		settings_changed.emit()
@export_range(0, 2) var weight_alignment: float = 0.05:
	set(val):
		weight_alignment = val
		settings_changed.emit()
@export_range(0, 2, 0.0001) var weight_cohesion: float = 0.0005:
	set(val):
		weight_cohesion = val
		settings_changed.emit()
@export_group("Visualize", "visualize_")
@export var visualize_separation: bool = false
@export var visualize_alignment: bool = false
@export var visualize_cohesion: bool = false
@export_group("", "")


func get_view_angle_half() -> float:
	return deg_to_rad(view_angle / 2.0)

func get_view_radius() -> float:
	return max(distance_separation, distance_alignment, distance_cohesion)

func visualizations_enabled() -> bool:
	return visualize_separation || visualize_alignment || visualize_cohesion

func to_byte_array() -> PackedByteArray:
	var buffer = PackedByteArray()
	buffer.resize(60)

	buffer.encode_float(0, deg_to_rad(view_angle / 2.0))

	buffer.encode_s32(4, distance_separation)
	buffer.encode_s32(8, distance_alignment)
	buffer.encode_s32(12, distance_cohesion)

	buffer.encode_float(16, weight_separation)
	buffer.encode_float(20, weight_alignment)
	buffer.encode_float(24, weight_cohesion)

	buffer.encode_float(28, min_speed)
	buffer.encode_float(32, max_speed)

	buffer.encode_float(36, edge_avoidance_weight if edge_avoid else 0.0)
	buffer.encode_float(40, edge_margin_left)
	buffer.encode_float(44, edge_margin_right)
	buffer.encode_float(48, edge_margin_top)
	buffer.encode_float(52, edge_margin_bottom)

	# TODO: Revisit this later
	buffer.encode_float(56, distance_family_avoidance)

	return buffer

class_name BoidSettings
extends Resource


signal settings_changed


@export_range(1, 500) var min_speed: float = 200.0
@export_range(1, 500) var max_speed: float = 300.0
@export_group("Edge", "edge_")
@export var edge_wrap: bool = true
@export var edge_avoid: bool = false
@export var edge_avoidance_weight: float = 10.0
@export var edge_visualize: bool = false
@export_subgroup("Margin", "edge_margin_")
@export_range(0, 300, 1, "allow_greater") var edge_margin_left: int = 100
@export_range(0, 300, 1, "allow_greater") var edge_margin_right: int = 100
@export_range(0, 300, 1, "allow_greater") var edge_margin_top: int = 100
@export_range(0, 300, 1, "allow_greater") var edge_margin_bottom: int = 100
@export_subgroup("", "")
@export_group("View", "view_")
@export_range(0, 360) var view_angle: int = 270:
	set(val):
		view_angle = val
		settings_changed.emit()
@export_group("Distance", "distance_")
@export_range(0, 500) var distance_separation: int = 50:
	set(val):
		distance_separation = val
		settings_changed.emit()
@export_range(0, 500) var distance_alignment: int = 100:
	set(val):
		distance_alignment = val
		settings_changed.emit()
@export_range(0, 500) var distance_cohesion: int = 200:
	set(val):
		distance_cohesion = val
		settings_changed.emit()
@export_group("Weight", "weight_")
@export_range(0, 10) var weight_separation: float = 0.3
@export_range(0, 10) var weight_alignment: float = 0.1
@export_range(0, 10) var weight_cohesion: float = 0.05
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
	buffer.resize(16)

	buffer.encode_s32(0, view_angle)
	buffer.encode_s32(4, distance_separation)
	buffer.encode_s32(8, distance_alignment)
	buffer.encode_s32(12, distance_cohesion)

	return buffer

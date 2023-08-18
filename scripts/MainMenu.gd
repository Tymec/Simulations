extends Control


@export var simulations: Array[PackedScene] = []

@onready var main_buttons = $HBoxContainer/MainButtons
@onready var simulation_select = $HBoxContainer/SimulationSelect


func _ready():
	main_buttons.show()
	simulation_select.hide()

	var parent = simulation_select.get_node("MarginContainer/VBoxContainer")
	for simulation in simulations:
		var instance = simulation.instantiate()

		if not instance is Simulation:
			continue

		var button = Button.new()
		button.text = instance.simulation_name
		button.disabled = not instance.simulation_enabled
		button.connect("pressed", func():
			get_tree().change_scene_to_packed(simulation)
		)
		
		parent.add_child(button)
		
	parent.move_child(parent.get_node("BackButton"), parent.get_child_count() - 1)


func _on_start_button_pressed():
	main_buttons.hide()
	simulation_select.show()

func _on_settings_button_pressed():
	pass # Replace with function body.

func _on_quit_button_pressed():
	get_tree().quit()

func _on_back_button_pressed():
	simulation_select.hide()
	main_buttons.show()

extends HBoxContainer

@export var label = "Label"
@export var default_value = "value"

func _ready():
	$Label.text = label + ":"
	$Value.text = str(default_value)

func _on_value_update(value):
	$Value.text = str(value)

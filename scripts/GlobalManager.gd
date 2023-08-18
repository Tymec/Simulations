extends Node


var last_title_update: float = 0.0
var title_update_interval: float = 5.0


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _physics_process(_delta):
	var time = Time.get_ticks_msec()
	if time - last_title_update > title_update_interval:
		last_title_update = time
		DisplayServer.window_set_title("Simulations - %.0f FPS" % Engine.get_frames_per_second())

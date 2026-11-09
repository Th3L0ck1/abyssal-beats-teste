extends Control

var button_type = null
var timer_preview: float = 0.0
var frame_preview: int = 0

func _ready() -> void:
	$fade_transition.show()
	$fade_transition/AnimationPlayer.play("fade_out")

func _process(delta: float) -> void:
	timer_preview += delta
	if timer_preview >= 0.16:
		timer_preview = 0.0
		frame_preview = (frame_preview + 1) % 4
		if has_node("Decor/SquetchPreview"):
			$Decor/SquetchPreview.frame = 8 + frame_preview
		if has_node("Decor/PeixotoPreview"):
			$Decor/PeixotoPreview.frame = 8 + frame_preview

func _on_play_pressed() -> void:
	button_type = "play"
	GameState.play_tone(523.25, 0.10, "keyboard")
	GameState.reset_world_progress()
	$fade_transition.show()
	$fade_transition/fade_timer.start()
	$fade_transition/AnimationPlayer.play("fade_in")

func _on_settings_pressed() -> void:
	button_type = "settings"
	GameState.play_tone(392.00, 0.10, "guitar")
	$fade_transition.show()
	$fade_transition/fade_timer.start()
	$fade_transition/AnimationPlayer.play("fade_in")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_fade_timer_timeout() -> void:
	if button_type == "play":
		get_tree().change_scene_to_file("res://Scenes/world.tscn")
	elif button_type == "settings":
		get_tree().change_scene_to_file("res://Scenes/settings.tscn")

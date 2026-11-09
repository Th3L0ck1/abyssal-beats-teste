extends Control

func _ready() -> void:
	$fade_transition.show()
	$fade_transition/AnimationPlayer.play("fade_out")

	if has_node("MainBox/VolumeBox/VolumeSlider"):
		$MainBox/VolumeBox/VolumeSlider.value = GameState.master_volume * 100.0
		_atualizar_texto_volume(GameState.master_volume * 100.0)
	if has_node("MainBox/ScreenBox/BtnFullscreen"):
		_atualizar_texto_tela()

func _atualizar_texto_volume(val: float) -> void:
	if has_node("MainBox/VolumeBox/VolumeLabel"):
		$MainBox/VolumeBox/VolumeLabel.text = "Volume Geral: %d%%" % int(val)

func _atualizar_texto_tela() -> void:
	if has_node("MainBox/ScreenBox/BtnFullscreen"):
		if GameState.is_fullscreen:
			$MainBox/ScreenBox/BtnFullscreen.text = "Tela: Cheia (Fullscreen)"
		else:
			$MainBox/ScreenBox/BtnFullscreen.text = "Tela: Janela Maximizada"

func _on_volume_slider_value_changed(value: float) -> void:
	GameState.apply_volume(value / 100.0)
	_atualizar_texto_volume(value)

func _on_btn_fullscreen_pressed() -> void:
	GameState.apply_fullscreen(not GameState.is_fullscreen)
	_atualizar_texto_tela()
	GameState.play_tone(440.0, 0.08, "keyboard")

func _on_btn_test_squetch_pressed() -> void:
	GameState.play_note_sfx(false, "up")

func _on_btn_test_peixoto_pressed() -> void:
	GameState.play_note_sfx(true, "up")

func _on_back_pressed() -> void:
	GameState.play_tone(329.63, 0.09, "guitar")
	$fade_transition.show()
	$fade_transition/fade_timer.start()
	$fade_transition/AnimationPlayer.play("fade_in")

func _on_fade_timer_timeout() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")

extends Control

@onready var volume_slider: HSlider = $MainBox/VolumeBox/VolumeSlider
@onready var volume_label: Label = $MainBox/VolumeBox/VolumeLabel
@onready var btn_fullscreen: Button = $MainBox/ScreenBox/BtnFullscreen

func _ready() -> void:
	GameState.fade_out()
	volume_slider.value = GameState.master_volume * 100.0
	_atualizar_texto_volume(volume_slider.value)
	_atualizar_texto_tela()

func _atualizar_texto_volume(val: float) -> void:
	volume_label.text = "Volume Geral: %d%%" % int(val)

func _atualizar_texto_tela() -> void:
	if GameState.is_fullscreen:
		btn_fullscreen.text = "Tela: Cheia (Fullscreen)"
	else:
		btn_fullscreen.text = "Tela: Janela Maximizada"

func _on_volume_slider_value_changed(value: float) -> void:
	GameState.apply_volume(value / 100.0)
	_atualizar_texto_volume(value)

func _on_btn_fullscreen_pressed() -> void:
	GameState.apply_fullscreen(not GameState.is_fullscreen)
	_atualizar_texto_tela()
	GameState.play_ui_sfx("click")

func _on_btn_test_squetch_pressed() -> void:
	GameState.play_note_sfx(false, "up")

func _on_btn_test_peixoto_pressed() -> void:
	GameState.play_note_sfx(true, "up")

func _on_back_pressed() -> void:
	if GameState.is_transitioning:
		return
	GameState.play_ui_sfx("back")
	GameState.fade_to_scene("res://Scenes/menu.tscn")

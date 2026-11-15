extends Control

@onready var volume_slider: HSlider = $MainBox/VolumeBox/VolumeSlider
@onready var volume_label: Label = $MainBox/VolumeBox/VolumeLabel
@onready var btn_fullscreen: Button = $MainBox/ScreenBox/BtnFullscreen
@onready var btn_squetch: Button = $MainBox/ScreenBox/BtnTestSquetch
@onready var btn_peixoto: Button = $MainBox/ScreenBox/BtnTestPeixoto
@onready var btn_control_mode: Button = $MainBox/ControlBox/BtnControlMode
@onready var btn_back: Button = $Back

func _ready() -> void:
	GameState.fade_out()
	volume_slider.value = GameState.master_volume * 100.0
	_atualizar_texto_volume(volume_slider.value)
	_atualizar_texto_tela()
	_atualizar_texto_controle()
	GameState.controller_mode_changed.connect(func(_m): _atualizar_texto_controle())
	_setup_focus_navigation()
	volume_slider.grab_focus()

func _setup_focus_navigation() -> void:
	volume_slider.focus_neighbor_bottom = btn_fullscreen.get_path()
	volume_slider.focus_neighbor_top = btn_back.get_path()

	btn_fullscreen.focus_neighbor_top = volume_slider.get_path()
	btn_fullscreen.focus_neighbor_bottom = btn_control_mode.get_path()
	btn_fullscreen.focus_neighbor_right = btn_squetch.get_path()

	btn_squetch.focus_neighbor_top = volume_slider.get_path()
	btn_squetch.focus_neighbor_bottom = btn_control_mode.get_path()
	btn_squetch.focus_neighbor_left = btn_fullscreen.get_path()
	btn_squetch.focus_neighbor_right = btn_peixoto.get_path()

	btn_peixoto.focus_neighbor_top = volume_slider.get_path()
	btn_peixoto.focus_neighbor_bottom = btn_control_mode.get_path()
	btn_peixoto.focus_neighbor_left = btn_squetch.get_path()

	btn_control_mode.focus_neighbor_top = btn_fullscreen.get_path()
	btn_control_mode.focus_neighbor_bottom = btn_back.get_path()

	btn_back.focus_neighbor_top = btn_control_mode.get_path()
	btn_back.focus_neighbor_bottom = volume_slider.get_path()

	for btn: Control in [btn_fullscreen, btn_squetch, btn_peixoto, btn_control_mode, btn_back]:
		if btn:
			btn.focus_entered.connect(func(): GameState.play_ui_sfx("hover"))

func _atualizar_texto_volume(val: float) -> void:
	volume_label.text = "Volume Geral: %d%%" % int(val)

func _atualizar_texto_tela() -> void:
	if GameState.is_fullscreen:
		btn_fullscreen.text = "Tela: Cheia (Fullscreen)"
	else:
		btn_fullscreen.text = "Tela: Janela Maximizada"

func _atualizar_texto_controle() -> void:
	if not btn_control_mode:
		return
	var count := Input.get_connected_joypads().size()
	var joy_info := "%d conectado%s" % [count, "s" if count != 1 else ""]
	btn_control_mode.text = "Controle: %s (%s)" % [GameState.get_controller_mode_name(), joy_info]

func _on_volume_slider_value_changed(value: float) -> void:
	GameState.apply_volume(value / 100.0)
	_atualizar_texto_volume(value)

func _on_btn_fullscreen_pressed() -> void:
	GameState.apply_fullscreen(not GameState.is_fullscreen)
	_atualizar_texto_tela()
	GameState.play_ui_sfx("click")

func _on_btn_control_mode_pressed() -> void:
	GameState.cycle_controller_mode()
	_atualizar_texto_controle()
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel", false) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		get_viewport().set_input_as_handled()
		_on_back_pressed()

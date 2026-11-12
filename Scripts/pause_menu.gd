extends CanvasLayer
class_name PauseMenu

## Menu de Pausa In-Game (ESC / Start) usado tanto no Mundo quanto na Batalha.
## Processa mesmo com SceneTree pausada (PROCESS_MODE_ALWAYS).

const FONT_PIXEL: FontFile = preload("res://Themes/Stacked pixel.ttf")

var is_combat: bool = false
var is_open: bool = false
var selected_idx: int = 0
var can_pause_Check: Callable
var on_retreat_callback: Callable
var on_toggle_map_callback: Callable
var is_map_visible_check: Callable
var on_quit_menu_callback: Callable

var root_ctrl: Control
var card_panel: Control
var option_buttons: Array[Button] = []
var hint_footer: Label

func setup(
	p_is_combat: bool,
	p_can_pause: Callable,
	p_on_quit_menu: Callable,
	p_on_retreat: Callable = Callable(),
	p_on_toggle_map: Callable = Callable(),
	p_is_map_visible: Callable = Callable()
) -> void:
	is_combat = p_is_combat
	can_pause_Check = p_can_pause
	on_quit_menu_callback = p_on_quit_menu
	on_retreat_callback = p_on_retreat
	on_toggle_map_callback = p_on_toggle_map
	is_map_visible_check = p_is_map_visible
	_build_ui()

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _build_ui() -> void:
	if root_ctrl and is_instance_valid(root_ctrl):
		root_ctrl.queue_free()
	option_buttons.clear()

	root_ctrl = Control.new()
	root_ctrl.position = Vector2.ZERO
	root_ctrl.size = Vector2(480, 270)
	add_child(root_ctrl)

	var backdrop := ColorRect.new()
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(480, 270)
	backdrop.color = Color(0.02, 0.04, 0.09, 0.80)
	root_ctrl.add_child(backdrop)

	card_panel = Control.new()
	card_panel.position = Vector2(130, 52)
	card_panel.size = Vector2(220, 166)
	root_ctrl.add_child(card_panel)

	var border_outer := ColorRect.new()
	border_outer.position = Vector2(-2, -2)
	border_outer.size = Vector2(224, 170)
	border_outer.color = Color(0.31, 0.89, 0.89, 0.92)
	card_panel.add_child(border_outer)

	var bg_inner := ColorRect.new()
	bg_inner.position = Vector2.ZERO
	bg_inner.size = Vector2(220, 166)
	bg_inner.color = Color(0.04, 0.08, 0.16, 0.97)
	card_panel.add_child(bg_inner)

	var top_accent := ColorRect.new()
	top_accent.position = Vector2(0, 0)
	top_accent.size = Vector2(220, 26)
	top_accent.color = Color(0.08, 0.15, 0.28, 1.0)
	card_panel.add_child(top_accent)

	var title := Label.new()
	title.position = Vector2(0, 5)
	title.size = Vector2(220, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_PIXEL)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.98, 0.95, 0.21, 1.0))
	title.text = "JOGO PAUSADO"
	card_panel.add_child(title)

	var labels: Array[String] = [
		"CONTINUAR",
		_texto_volume(),
		"RECUAR AO MAPA" if is_combat else _texto_mapa(),
		"MENU PRINCIPAL"
	]

	for i in range(labels.size()):
		var btn := Button.new()
		btn.position = Vector2(18, 34 + i * 27)
		btn.size = Vector2(184, 22)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_override("font", FONT_PIXEL)
		btn.add_theme_font_size_override("font_size", 10)
		btn.text = labels[i]
		var idx := i
		btn.mouse_entered.connect(func():
			if is_open and selected_idx != idx:
				selected_idx = idx
				GameState.play_ui_sfx("hover")
				_refresh_visuals()
		)
		btn.pressed.connect(func():
			if is_open:
				selected_idx = idx
				_activate_option(idx)
		)
		card_panel.add_child(btn)
		option_buttons.append(btn)

	hint_footer = Label.new()
	hint_footer.position = Vector2(0, 146)
	hint_footer.size = Vector2(220, 16)
	hint_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_footer.add_theme_font_override("font", FONT_PIXEL)
	hint_footer.add_theme_font_size_override("font_size", 8)
	hint_footer.add_theme_color_override("font_color", Color(0.58, 0.76, 0.88, 0.9))
	hint_footer.text = "W/S: Navegar  |  Enter: OK  |  ESC: Fechar"
	card_panel.add_child(hint_footer)

	_refresh_visuals()

func _texto_volume() -> String:
	return "< VOLUME: %d%% >" % int(roundf(GameState.master_volume * 100.0))

func _texto_mapa() -> String:
	var vis := true
	if is_map_visible_check.is_valid():
		vis = bool(is_map_visible_check.call())
	return "MINIMAPA: %s" % ("ATIVO" if vis else "OCULTO")

func _refresh_visuals() -> void:
	if option_buttons.size() < 4:
		return
	option_buttons[1].text = _texto_volume()
	if not is_combat:
		option_buttons[2].text = _texto_mapa()

	for i in range(option_buttons.size()):
		var btn := option_buttons[i]
		var sel := (i == selected_idx)
		var prefix := "> " if sel else ""
		var suffix := " <" if sel and i != 1 else ""
		var base_text := btn.text.trim_prefix("> ").trim_suffix(" <")
		btn.text = prefix + base_text + suffix
		var col := Color(0.98, 0.95, 0.21, 1.0) if sel else Color(0.82, 0.92, 1.0, 0.9)
		if i == 3 and not sel:
			col = Color(0.92, 0.45, 0.48, 0.95)
		btn.add_theme_color_override("font_color", col)
		btn.add_theme_color_override("font_hover_color", Color(0.98, 0.95, 0.21, 1.0))

func toggle_pause() -> void:
	if is_open:
		close_pause()
	else:
		open_pause()

func open_pause() -> void:
	if is_open:
		return
	if can_pause_Check.is_valid() and not bool(can_pause_Check.call()):
		return
	is_open = true
	selected_idx = 0
	visible = true
	get_tree().paused = true
	_refresh_visuals()
	if card_panel:
		card_panel.scale = Vector2(0.92, 0.92)
		card_panel.pivot_offset = card_panel.size * 0.5
		var tw := create_tween()
		tw.tween_property(card_panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	GameState.play_ui_sfx("click")

func close_pause() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	GameState.play_ui_sfx("back")

func _adjust_volume(step_pct: float) -> void:
	var atual_pct: float = roundf(GameState.master_volume * 100.0)
	var novo_pct: float = clampf(roundf((atual_pct + step_pct) / 10.0) * 10.0, 0.0, 100.0)
	GameState.apply_volume(novo_pct / 100.0)
	GameState.play_ui_sfx("hover")
	_refresh_visuals()

func _activate_option(idx: int) -> void:
	match idx:
		0:
			close_pause()
		1:
			var prox_pct: float = roundf(GameState.master_volume * 100.0) + 10.0
			if prox_pct > 100.0:
				prox_pct = 0.0
			GameState.apply_volume(prox_pct / 100.0)
			GameState.play_ui_sfx("click")
			_refresh_visuals()
		2:
			if is_combat:
				is_open = false
				visible = false
				get_tree().paused = false
				GameState.play_ui_sfx("back")
				if on_retreat_callback.is_valid():
					on_retreat_callback.call()
			else:
				if on_toggle_map_callback.is_valid():
					on_toggle_map_callback.call()
				GameState.play_ui_sfx("click")
				_refresh_visuals()
		3:
			is_open = false
			visible = false
			get_tree().paused = false
			GameState.play_ui_sfx("back")
			if on_quit_menu_callback.is_valid():
				on_quit_menu_callback.call()

func _unhandled_input(event: InputEvent) -> void:
	var pressed_pause := false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		pressed_pause = true
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		pressed_pause = true

	if pressed_pause:
		get_viewport().set_input_as_handled()
		toggle_pause()
		return

	if not is_open:
		return

	if event.is_action_pressed("ui_up", false) or event.is_action_pressed("p1_up", false) or event.is_action_pressed("p2_up", false):
		get_viewport().set_input_as_handled()
		selected_idx = (selected_idx - 1 + option_buttons.size()) % option_buttons.size()
		GameState.play_ui_sfx("hover")
		_refresh_visuals()
	elif event.is_action_pressed("ui_down", false) or event.is_action_pressed("p1_down", false) or event.is_action_pressed("p2_down", false):
		get_viewport().set_input_as_handled()
		selected_idx = (selected_idx + 1) % option_buttons.size()
		GameState.play_ui_sfx("hover")
		_refresh_visuals()
	elif selected_idx == 1 and (event.is_action_pressed("ui_left", false) or event.is_action_pressed("p1_left", false) or event.is_action_pressed("p2_left", false)):
		get_viewport().set_input_as_handled()
		_adjust_volume(-10.0)
	elif selected_idx == 1 and (event.is_action_pressed("ui_right", false) or event.is_action_pressed("p1_right", false) or event.is_action_pressed("p2_right", false)):
		get_viewport().set_input_as_handled()
		_adjust_volume(10.0)
	elif event.is_action_pressed("ui_accept", false):
		get_viewport().set_input_as_handled()
		_activate_option(selected_idx)

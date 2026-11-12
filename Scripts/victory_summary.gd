extends CanvasLayer
class_name VictorySummary

## Sequencia de 2 paineis exibida apos a Vitoria:
## Painel 1: Comparativo entre Squetch (P1) e Peixoto (P2) (Quadrados Pulados, Hits Tomados, Notas Acertadas).
## Painel 2: Mapa de Calor do Grid 3x3 (onde os players mais foram) e em qual casa foram mais acertados.

const FONT_PIXEL: FontFile = preload("res://Themes/Stacked pixel.ttf")
const NOMES_CASAS: Dictionary = {
	Vector2i(0, 0): "Topo-Esq (0,0)",
	Vector2i(1, 0): "Topo-Meio (1,0)",
	Vector2i(2, 0): "Topo-Dir (2,0)",
	Vector2i(0, 1): "Meio-Esq (0,1)",
	Vector2i(1, 1): "Centro (1,1)",
	Vector2i(2, 1): "Meio-Dir (2,1)",
	Vector2i(0, 2): "Base-Esq (0,2)",
	Vector2i(1, 2): "Base-Meio (1,2)",
	Vector2i(2, 2): "Base-Dir (2,2)",
}

var step_atual: int = 1
var titulo_custom: String = "VITORIA!"
var on_finished_callback: Callable

var root_ctrl: Control
var card_ctrl: Control
var page1_ctrl: Control
var page2_ctrl: Control
var action_btn: Button
var heatmap_drawer: _HeatmapDrawer

func _ready() -> void:
	layer = 30

func show_summary(p_titulo: String, p_on_finished: Callable) -> void:
	titulo_custom = p_titulo
	on_finished_callback = p_on_finished
	step_atual = 1
	_construir_interface()
	if card_ctrl:
		card_ctrl.scale = Vector2(0.90, 0.90)
		card_ctrl.pivot_offset = card_ctrl.size * 0.5
		var tw := create_tween()
		tw.tween_property(card_ctrl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _construir_interface() -> void:
	if root_ctrl and is_instance_valid(root_ctrl):
		root_ctrl.queue_free()

	root_ctrl = Control.new()
	root_ctrl.position = Vector2.ZERO
	root_ctrl.size = Vector2(480, 270)
	add_child(root_ctrl)

	var backdrop := ColorRect.new()
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(480, 270)
	backdrop.color = Color(0.02, 0.04, 0.10, 0.84)
	root_ctrl.add_child(backdrop)

	card_ctrl = Control.new()
	card_ctrl.position = Vector2(64, 34)
	card_ctrl.size = Vector2(352, 202)
	root_ctrl.add_child(card_ctrl)

	var border_rect := ColorRect.new()
	border_rect.position = Vector2(-2, -2)
	border_rect.size = Vector2(356, 206)
	border_rect.color = Color(0.31, 0.89, 0.89, 0.95)
	card_ctrl.add_child(border_rect)

	var inner_bg := ColorRect.new()
	inner_bg.position = Vector2.ZERO
	inner_bg.size = Vector2(352, 202)
	inner_bg.color = Color(0.04, 0.08, 0.16, 0.98)
	card_ctrl.add_child(inner_bg)

	var header_bg := ColorRect.new()
	header_bg.position = Vector2.ZERO
	header_bg.size = Vector2(352, 26)
	header_bg.color = Color(0.08, 0.15, 0.28, 1.0)
	card_ctrl.add_child(header_bg)

	page1_ctrl = Control.new()
	page1_ctrl.position = Vector2.ZERO
	page1_ctrl.size = Vector2(352, 168)
	card_ctrl.add_child(page1_ctrl)
	_montar_pagina_1()

	page2_ctrl = Control.new()
	page2_ctrl.position = Vector2.ZERO
	page2_ctrl.size = Vector2(352, 168)
	page2_ctrl.visible = false
	card_ctrl.add_child(page2_ctrl)
	_montar_pagina_2()

	action_btn = Button.new()
	action_btn.position = Vector2(56, 172)
	action_btn.size = Vector2(240, 24)
	action_btn.flat = true
	action_btn.focus_mode = Control.FOCUS_NONE
	action_btn.add_theme_font_override("font", FONT_PIXEL)
	action_btn.add_theme_font_size_override("font_size", 11)
	action_btn.add_theme_color_override("font_color", Color(0.98, 0.95, 0.21, 1.0))
	action_btn.add_theme_color_override("font_hover_color", Color(0.35, 1.0, 1.0, 1.0))
	action_btn.text = "> PROXIMO: MAPA DE CALOR (3x3) <"
	action_btn.pressed.connect(_avancar_passo)
	card_ctrl.add_child(action_btn)

func _criar_label(parent: Node, pos: Vector2, sz: Vector2, texto: String, cor: Color, tam: int = 10, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.add_theme_font_override("font", FONT_PIXEL)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.text = texto
	parent.add_child(l)
	return l

func _montar_pagina_1() -> void:
	_criar_label(page1_ctrl, Vector2(0, 5), Vector2(352, 20), "%s - COMPARATIVO DOS PLAYERS" % titulo_custom, Color(0.98, 0.95, 0.21, 1.0), 11)

	# Cabecalhos P1 vs P2
	_criar_label(page1_ctrl, Vector2(16, 34), Vector2(110, 16), "SQUETCH (P1)", Color(0.35, 0.95, 1.0, 1.0), 10, HORIZONTAL_ALIGNMENT_LEFT)
	_criar_label(page1_ctrl, Vector2(226, 34), Vector2(110, 16), "PEIXOTO (P2)", Color(1.0, 0.68, 0.26, 1.0), 10, HORIZONTAL_ALIGNMENT_RIGHT)

	var linhas: Array[Dictionary] = [
		{"titulo": "QUADRADOS PULADOS", "p1": GameState.p1_jumps, "p2": GameState.p2_jumps},
		{"titulo": "HITS TOMADOS", "p1": GameState.p1_hits_taken, "p2": GameState.p2_hits_taken},
		{"titulo": "NOTAS DE SINFONIA", "p1": GameState.p1_notes_hit, "p2": GameState.p2_notes_hit}
	]

	for i in range(linhas.size()):
		var item: Dictionary = linhas[i]
		var y_base := 56.0 + i * 36.0
		var v1 := int(item["p1"])
		var v2 := int(item["p2"])
		var soma := maxi(1, v1 + v2)
		var r1 := float(v1) / float(soma)
		if v1 == 0 and v2 == 0:
			r1 = 0.5

		_criar_label(page1_ctrl, Vector2(0, y_base), Vector2(352, 14), String(item["titulo"]), Color(0.80, 0.90, 1.0, 0.95), 9)
		_criar_label(page1_ctrl, Vector2(18, y_base + 13), Vector2(54, 16), str(v1), Color(0.35, 0.95, 1.0, 1.0), 11, HORIZONTAL_ALIGNMENT_LEFT)
		_criar_label(page1_ctrl, Vector2(280, y_base + 13), Vector2(54, 16), str(v2), Color(1.0, 0.68, 0.26, 1.0), 11, HORIZONTAL_ALIGNMENT_RIGHT)

		var bar_bg := ColorRect.new()
		bar_bg.position = Vector2(68, y_base + 16)
		bar_bg.size = Vector2(216, 8)
		bar_bg.color = Color(0.10, 0.16, 0.26, 1.0)
		page1_ctrl.add_child(bar_bg)

		var w1 := roundf(216.0 * r1)
		var bar_p1 := ColorRect.new()
		bar_p1.position = Vector2(68, y_base + 16)
		bar_p1.size = Vector2(w1, 8)
		bar_p1.color = Color(0.28, 0.88, 0.96, 0.95)
		page1_ctrl.add_child(bar_p1)

		var bar_p2 := ColorRect.new()
		bar_p2.position = Vector2(68 + w1, y_base + 16)
		bar_p2.size = Vector2(216.0 - w1, 8)
		bar_p2.color = Color(0.96, 0.62, 0.24, 0.95)
		page1_ctrl.add_child(bar_p2)

func _montar_pagina_2() -> void:
	_criar_label(page2_ctrl, Vector2(0, 5), Vector2(352, 20), "MAPA DE CALOR (3x3) & CASAS MAIS ATINGIDAS", Color(0.98, 0.95, 0.21, 1.0), 10)

	var melhor_visita_cell := Vector2i(1, 1)
	var max_visitas := -1
	var pior_hit_cell := Vector2i(-1, -1)
	var max_hits := 0

	for y in range(3):
		for x in range(3):
			var c := Vector2i(x, y)
			var vis := int(GameState.grid_visits.get(c, 0))
			if vis > max_visitas:
				max_visitas = vis
				melhor_visita_cell = c
			var h := int(GameState.grid_hits_taken.get(c, 0))
			if h > max_hits:
				max_hits = h
				pior_hit_cell = c

	heatmap_drawer = _HeatmapDrawer.new()
	heatmap_drawer.position = Vector2(20, 34)
	heatmap_drawer.setup(pior_hit_cell, max_hits)
	page2_ctrl.add_child(heatmap_drawer)

	_criar_label(page2_ctrl, Vector2(158, 36), Vector2(182, 14), "CASA ONDE MAIS FORAM:", Color(0.35, 0.95, 1.0, 1.0), 9, HORIZONTAL_ALIGNMENT_LEFT)
	var txt_vis := "%s\n(%d pulos na casa)" % [NOMES_CASAS.get(melhor_visita_cell, "Centro (1,1)"), maxi(0, max_visitas)]
	_criar_label(page2_ctrl, Vector2(158, 51), Vector2(182, 30), txt_vis, Color(0.98, 0.92, 0.32, 1.0), 10, HORIZONTAL_ALIGNMENT_LEFT)

	_criar_label(page2_ctrl, Vector2(158, 88), Vector2(182, 14), "CASA MAIS ACERTADA:", Color(1.0, 0.42, 0.46, 1.0), 9, HORIZONTAL_ALIGNMENT_LEFT)
	var txt_hit := "Nenhum hit sofrido!\n(Esquiva Perfeita!)"
	if max_hits > 0 and pior_hit_cell != Vector2i(-1, -1):
		txt_hit = "%s\n(%d hits sofridos)" % [NOMES_CASAS.get(pior_hit_cell, "(1,1)"), max_hits]
	_criar_label(page2_ctrl, Vector2(158, 103), Vector2(182, 30), txt_hit, Color(1.0, 0.65, 0.30, 1.0) if max_hits > 0 else Color(0.45, 1.0, 0.65, 1.0), 10, HORIZONTAL_ALIGNMENT_LEFT)

	_criar_label(page2_ctrl, Vector2(158, 140), Vector2(184, 24), "Azul = Pouco uso | Ouro = Muito uso\nBorda Vermelha = Mais tomaram hit", Color(0.62, 0.78, 0.90, 0.9), 8, HORIZONTAL_ALIGNMENT_LEFT)

func _avancar_passo() -> void:
	if step_atual == 1:
		step_atual = 2
		page1_ctrl.visible = false
		page2_ctrl.visible = true
		action_btn.text = "> CONTINUAR <"
		GameState.play_ui_sfx("click")
	else:
		GameState.play_ui_sfx("click")
		if on_finished_callback.is_valid():
			on_finished_callback.call()
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept", false):
		get_viewport().set_input_as_handled()
		_avancar_passo()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		get_viewport().set_input_as_handled()
		_avancar_passo()
	elif event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_START):
		get_viewport().set_input_as_handled()
		_avancar_passo()


class _HeatmapDrawer extends Node2D:
	var cell_mais_atingida: Vector2i = Vector2i(-1, -1)
	var max_hits_val: int = 0
	var pulse_t: float = 0.0

	func setup(p_hit_cell: Vector2i, p_max_hits: int) -> void:
		cell_mais_atingida = p_hit_cell
		max_hits_val = p_max_hits

	func _process(delta: float) -> void:
		pulse_t += delta * 5.0
		queue_redraw()

	func _draw() -> void:
		var cell_w := 38.0
		var cell_h := 36.0
		var gap := 4.0

		var max_peso := 0.01
		var pesos: Dictionary = {}
		for y in range(3):
			for x in range(3):
				var c := Vector2i(x, y)
				var p := float(GameState.grid_visits.get(c, 0)) + float(GameState.ml_brain.heatmap.get(c, 1.0)) * 0.35
				pesos[c] = p
				if p > max_peso:
					max_peso = p

		for y in range(3):
			for x in range(3):
				var c := Vector2i(x, y)
				var ratio := clampf(float(pesos[c]) / max_peso, 0.0, 1.0)
				var rx := x * (cell_w + gap)
				var ry := y * (cell_h + gap)
				var rect := Rect2(Vector2(rx, ry), Vector2(cell_w, cell_h))

				# Gradiente termico: Azul Abissal -> Ciano -> Amarelo/Laranja Quente
				var col_frio := Color(0.10, 0.22, 0.40, 0.95)
				var col_medio := Color(0.20, 0.72, 0.78, 0.95)
				var col_quente := Color(0.98, 0.68, 0.18, 0.95)
				var fill_col := col_frio.lerp(col_medio, ratio * 2.0) if ratio < 0.5 else col_medio.lerp(col_quente, (ratio - 0.5) * 2.0)

				draw_rect(rect, fill_col, true)

				if c == cell_mais_atingida and max_hits_val > 0:
					var pulse := 0.65 + 0.35 * sin(pulse_t)
					draw_rect(rect.grow(1.0), Color(1.0, 0.22, 0.28, pulse), false, 2.0)
				else:
					draw_rect(rect, Color(0.35, 0.85, 0.95, 0.45), false, 1.0)

				var visitas := int(GameState.grid_visits.get(c, 0))
				var hits := int(GameState.grid_hits_taken.get(c, 0))
				draw_string(FONT_PIXEL, Vector2(rx + 6, ry + 16), "%dx" % visitas, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
				if hits > 0:
					draw_string(FONT_PIXEL, Vector2(rx + 5, ry + 30), "%d hit" % hits, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.35, 0.38, 1.0))

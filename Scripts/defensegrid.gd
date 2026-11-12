extends GridBase
class_name DefenseGrid

const CELL_ORIGIN: Vector2 = Vector2(200, 160)
const CELL_STEP: float = 40.0

const FX_GEYSER: Texture2D = preload("res://Sprites/VFX/VFX_Geyser.png")
const FX_BOLT: Texture2D = preload("res://Sprites/VFX/VFX_Bolt.png")
const FX_SLASH: Texture2D = preload("res://Sprites/VFX/VFX_Slash.png")
const FX_BLAST: Texture2D = preload("res://Sprites/VFX/VFX_Blast.png")
const FX_RING: Texture2D = preload("res://Sprites/VFX/VFX_Ring.png")
const FX_HIT: Texture2D = preload("res://Sprites/VFX/VFX_Hit.png")
const NOTES_TEX: Texture2D = preload("res://Sprites/VFX/Notes_sheet.png")
const WARN_TEX: Texture2D = preload("res://Sprites/VFX/WarnIcons_sheet.png")
const ICONS_TEX: Texture2D = preload("res://Sprites/World/WorldIcons_sheet.png")
const FONT_PIXEL: FontFile = preload("res://Themes/Stacked pixel.ttf")

var enemy_id: String = "jellyfish"
var enemy: Dictionary = {}
var patterns: Array = []

var timer_ataque: float = 0.0
var timer_ataque_interval: float = 2.9
var timer_symphony: float = 0.0
var symphony_gap: float = 2.5
var symphony_lifetime: float = 8.0
var symphony_time_left: float = 0.0
var intro_time: float = 1.7

var beat_timer: float = 0.0
var beat_step: int = 0
var beat_counter: int = 0
var base_guardian_scale: Vector2 = Vector2.ONE
var arena_atmosphere: ArenaAtmosphere
var pause_menu: PauseMenu

var todas_as_casas: Array[Vector2i] = [
	Vector2i(0,0), Vector2i(1,0), Vector2i(2,0),
	Vector2i(0,1), Vector2i(1,1), Vector2i(2,1),
	Vector2i(0,2), Vector2i(1,2), Vector2i(2,2)
]

var symphony_ativa: bool = false
var celula_symphony: Vector2i = Vector2i(-1, -1)
var sequencia_atual: Array[String] = []
var progresso_ritmo: int = 0
var nome_ritmo_atual: String = ""
var symphony_id: int = 0

var vida_players: int = 5
var vida_inimigo: int = 3
var vida_inimigo_max: int = 3
var combate_encerrado: bool = false
var golpe_final_em_curso: bool = false
var fase2: bool = false

var guardian_anim_state: String = "idle"
var guardian_timer: float = 0.0
var guardian_frame: int = 0
var guardian_state_ttl: float = 0.0

var direcoes_possiveis: Array[String] = ["up", "down", "left", "right"]
var nomes_ritmos: Array[String] = [
	"Groove Coral (4 Notas)",
	"Acorde Abissal (5 Notas)",
	"Riff das Profundezas (5 Notas)",
	"Sinfonia Bioluminescente (6 Notas)"
]

var arrow_texture: Texture2D = preload("res://Sprites/UI/Arrows_sheet.png")
var icones_setas: Array[Sprite2D] = []
var hearts: Array[Sprite2D] = []

@onready var guardian: Node2D = $Guardian
@onready var guardian_sprite: Sprite2D = $Guardian/Sprite2D
@onready var camera: Camera2D = $Camera2D
@onready var p1: PlayerBase = $Players/Player1
@onready var p2: PlayerBase = $Players/Player2
@onready var coral_left: Sprite2D = $ArenaDecor/CoralLeft
@onready var coral_right: Sprite2D = $ArenaDecor/CoralRight
@onready var pillar_left: Sprite2D = $ArenaDecor/PillarLeft
@onready var pillar_right: Sprite2D = $ArenaDecor/PillarRight
@onready var rhythm_display: Node2D = $RhythmDisplay
@onready var timer_bar_fill: ColorRect = $RhythmDisplay/TimerBarFill
@onready var telegraphs_node: Node2D = $Telegraphs
@onready var effects_node: Node2D = $Effects
@onready var hp_enemy_label: Label = $HUD/HPEnemy
@onready var enemy_bar_fill: ColorRect = $HUD/EnemyBarFill
@onready var banner_label: Label = $HUD/Banner
@onready var symphony_prompt: Label = $HUD/SymphonyPrompt

func _ready() -> void:
	GameState.fade_out()

	arena_atmosphere = ArenaAtmosphere.new()
	$ArenaDecor.add_child(arena_atmosphere)
	$ArenaDecor.move_child(arena_atmosphere, 0)

	GameState.spawn_ambient_bubbles($ArenaDecor, Vector2(480, 270), Vector2(240, 275), 18)

	enemy_id = GameState.current_enemy_id
	enemy = EnemyData.get_enemy(enemy_id)
	_configurar_inimigo()

	for casa in todas_as_casas:
		var nome_no := "(%d,%d)" % [casa.x, casa.y]
		var no_plataforma = $Grid.get_node_or_null(nome_no)
		if no_plataforma:
			plataformas[casa] = no_plataforma
			if no_plataforma.has_method("set_estado"):
				no_plataforma.set_estado("normal")

	GameState.grid_visits[p1.current_cell] = int(GameState.grid_visits.get(p1.current_cell, 0)) + 1
	GameState.grid_visits[p2.current_cell] = int(GameState.grid_visits.get(p2.current_cell, 0)) + 1

	_criar_coracoes()
	_atualizar_hud_combate()
	_configurar_pausa()
	timer_ataque = timer_ataque_interval - intro_time
	timer_symphony = symphony_gap - 1.2
	_animar_entrada_arena()
	_mostrar_banner("%s apareceu!" % enemy["name"], 1.5)

func _animar_entrada_arena() -> void:
	# Plataformas emergem e acendem em onda diagonal
	for casa in todas_as_casas:
		var plat: Node2D = plataformas.get(casa)
		if not plat:
			continue
		var atraso := float(casa.x + casa.y) * 0.065
		plat.modulate = Color(0.35, 0.85, 1.0, 0.0)
		plat.scale = Vector2(0.72, 0.72)
		var ptw := plat.create_tween()
		ptw.tween_interval(atraso)
		ptw.set_parallel(true)
		ptw.tween_property(plat, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.tween_property(plat, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Inimigo emerge das profundezas (sombra abissal -> forma completa + onda de sonar)
	var pos_final := guardian.position
	guardian.position = pos_final + Vector2(0, -18)
	guardian_sprite.scale = base_guardian_scale * 0.55
	guardian_sprite.modulate = Color(0.08, 0.16, 0.32, 0.0)
	var gtw := create_tween().set_parallel(true)
	gtw.tween_property(guardian, "position", pos_final, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gtw.tween_property(guardian_sprite, "scale", base_guardian_scale, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gtw.tween_property(guardian_sprite, "modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.22).timeout.connect(func():
		if is_inside_tree():
			VFX.play(effects_node, FX_RING, 6, 14.0, pos_final, Vector2(2.1, 2.1), false, 1)
			if arena_atmosphere:
				arena_atmosphere.pulse_beat(1.35)
	)

func _configurar_pausa() -> void:
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(
		true,
		func() -> bool: return not combate_encerrado and not golpe_final_em_curso,
		func() -> void: _encerrar_e_sair("res://Scenes/menu.tscn"),
		func() -> void: _encerrar_e_sair("res://Scenes/world.tscn")
	)

func _configurar_inimigo() -> void:
	guardian_sprite.texture = enemy["sheet"]
	guardian_sprite.hframes = 8
	base_guardian_scale = Vector2.ONE * float(enemy["scale"])
	guardian_sprite.scale = base_guardian_scale
	vida_inimigo = int(enemy["hp"])
	vida_inimigo_max = vida_inimigo
	timer_ataque_interval = float(enemy["interval"])
	patterns = (enemy["patterns"] as Array).duplicate()

	$Background.modulate = enemy.get("bg_modulate", Color.WHITE)
	var coral_col: Color = enemy.get("coral_modulate", Color.WHITE)
	coral_left.modulate = coral_col
	coral_right.modulate = coral_col
	var pillar_col: Color = enemy.get("pillar_modulate", Color.WHITE)
	pillar_left.modulate = pillar_col
	pillar_right.modulate = pillar_col

	var bar_col: Color = enemy.get("bar_color", Color(0.88, 0.28, 0.36, 1.0))
	enemy_bar_fill.color = bar_col
	hp_enemy_label.add_theme_color_override("font_color", bar_col.lightened(0.28))

	if arena_atmosphere:
		arena_atmosphere.setup(
			enemy.get("aura_color", Color(0.22, 0.92, 1.0, 1.0)),
			enemy.get("accent_color", Color(0.68, 0.48, 1.0, 1.0)),
			guardian.position
		)

func _criar_coracoes() -> void:
	for i in range(5):
		var h := Sprite2D.new()
		h.texture = ICONS_TEX
		h.hframes = 10
		h.frame = 9
		h.position = Vector2(52 + i * 13, 11)
		$HUD/Hearts.add_child(h)
		hearts.append(h)

func _process(delta: float) -> void:
	_animar_guardiao(delta)
	_processar_batida_arena(delta)
	if combate_encerrado or golpe_final_em_curso:
		return

	GameState.ml_brain.atualizar_presenca(p1.current_cell, p2.current_cell, delta)

	timer_ataque += delta
	if timer_ataque >= timer_ataque_interval:
		timer_ataque = 0.0
		iniciar_ataque()

	if not symphony_ativa:
		timer_symphony += delta
		if timer_symphony >= symphony_gap:
			timer_symphony = 0.0
			symphony()
	else:
		symphony_time_left = maxf(0.0, symphony_time_left - delta)
		_atualizar_barra_tempo_symphony()

	_atualizar_status_symphony()

func _processar_batida_arena(delta: float) -> void:
	beat_timer += delta
	var intervalo_batida := 0.38 if fase2 else 0.50
	if beat_timer >= intervalo_batida:
		beat_timer = 0.0
		beat_step = (beat_step + 1) % 2
		beat_counter += 1
		coral_left.frame = beat_step
		coral_right.frame = 1 - beat_step
		pillar_left.frame = 2 + beat_step
		pillar_right.frame = 2 + (1 - beat_step)
		if arena_atmosphere:
			arena_atmosphere.pulse_beat(1.2 if fase2 else 0.95)
		if not combate_encerrado:
			var notas_batida: Array = enemy.get("beat_notes", [65.41, 49.0])
			var freq_base: float = float(notas_batida[beat_step % notas_batida.size()])
			if fase2:
				freq_base *= 1.1892
			var wave_tipo: String = String(enemy.get("beat_wave", "beat"))
			GameState.play_tone(freq_base, 0.075, wave_tipo)
			if beat_counter % 4 == 0:
				var harm: float = float(enemy.get("beat_harmonic", 261.63))
				if fase2:
					harm *= 1.1892
				GameState.play_tone(harm, 0.055, "bell" if wave_tipo == "bell" else "synth")
			guardian_sprite.scale = base_guardian_scale * 1.06
			var tw := create_tween()
			tw.tween_property(guardian_sprite, "scale", base_guardian_scale, 0.14)

func _animar_guardiao(delta: float) -> void:
	if guardian_state_ttl > 0.0:
		guardian_state_ttl -= delta
		if guardian_state_ttl <= 0.0:
			guardian_anim_state = "idle"

	guardian_timer += delta
	if guardian_timer >= 0.16:
		guardian_timer = 0.0
		guardian_frame = (guardian_frame + 1) % 4
		match guardian_anim_state:
			"idle":
				guardian_sprite.frame = guardian_frame % 4
			"attack":
				guardian_sprite.frame = 4 + (guardian_frame % 2)
			"hurt":
				guardian_sprite.frame = 6 + (guardian_frame % 2)

func _cell_pos(c: Vector2i) -> Vector2:
	return CELL_ORIGIN + Vector2(c.x, c.y) * CELL_STEP

func get_cell_world_pos(c: Vector2i) -> Vector2:
	return _cell_pos(c) + Vector2(0, -8)

#Machine learning
func iniciar_ataque() -> void:
	var estado_s := GameState.ml_brain.obter_estado_tatico(p1.current_cell, p2.current_cell, symphony_ativa, celula_symphony)
	var nome: String = GameState.ml_brain.escolher_padrao(estado_s, patterns)
	ejecutar_ataque(construir_patron(nome), estado_s, nome)
	if fase2 and randf() < 0.4:
		await get_tree().create_timer(0.9).timeout
		if is_inside_tree() and not combate_encerrado and not golpe_final_em_curso:
			var estado_extra := GameState.ml_brain.obter_estado_tatico(p1.current_cell, p2.current_cell, symphony_ativa, celula_symphony)
			ejecutar_ataque(construir_patron("celula"), estado_extra, "celula")

func _strike(cells: Array, hit_at: float, tint: String, fx: String, stagger: float = 0.0, flip: bool = false) -> Dictionary:
	return {
		"cells": cells,
		"hit_at": hit_at,
		"tint": tint,
		"fx": fx,
		"stagger": stagger,
		"flip": flip,
		"tels": {},
		"icons": [],
		"hits": 0,
		"ameacou": false,
		"estado": "",
		"padrao": ""
	}

func construir_patron(nombre: String) -> Array:
	var strikes: Array = []
	match nombre:
		"celula":
			# 1 plataforma escolhida pelo modelo preditivo (Markov + Heatmap)
			var alvo_celula := GameState.ml_brain.escolher_alvo_celula(todas_as_casas, p1.current_cell, p2.current_cell, celula_symphony)
			strikes.append(_strike([alvo_celula], 1.5, "red", "geyser"))
		"linha":
			var row := GameState.ml_brain.escolher_alvo_linha(p1.current_cell, p2.current_cell, celula_symphony)
			strikes.append(_linha(row, randf() < 0.5, 1.7))
		"linha_dupla":
			var row_principal := GameState.ml_brain.escolher_alvo_linha(p1.current_cell, p2.current_cell, celula_symphony)
			var seguro := (row_principal + (1 if randf() < 0.5 else 2)) % 3
			var rev := randf() < 0.5
			for r in range(3):
				if r != seguro:
					strikes.append(_linha(r, rev, 1.9))
		"coluna":
			var col := GameState.ml_brain.escolher_alvo_coluna(p1.current_cell, p2.current_cell, celula_symphony)
			strikes.append(_coluna(col, 1.5))
		"coluna_dupla":
			var col_principal := GameState.ml_brain.escolher_alvo_coluna(p1.current_cell, p2.current_cell, celula_symphony)
			var seguro_c := (col_principal + (1 if randf() < 0.5 else 2)) % 3
			for cc in range(3):
				if cc != seguro_c:
					strikes.append(_coluna(cc, 1.7))
		"cruz":
			var centro: Vector2i = GameState.ml_brain.escolher_alvo_celula(todas_as_casas, p1.current_cell, p2.current_cell, celula_symphony)
			var cells: Array = [centro]
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				if todas_as_casas.has(centro + d):
					cells.append(centro + d)
			strikes.append(_strike(cells, 1.7, "orange", "blast", 0.0))
		"ondas":
			var origem: Vector2i = GameState.ml_brain.escolher_alvo_celula(todas_as_casas, p1.current_cell, p2.current_cell, celula_symphony)
			for k in range(3):
				var ring: Array = []
				for c in todas_as_casas:
					if absi(c.x - origem.x) + absi(c.y - origem.y) == k:
						ring.append(c)
				if ring.size() > 0:
					strikes.append(_strike(ring, 1.6 + 0.5 * k, "orange", "ring"))
		"diagonal":
			var cells_d: Array = []
			for c in todas_as_casas:
				if c.x == c.y or c.x + c.y == 2:
					cells_d.append(c)
			strikes.append(_strike(cells_d, 1.8, "orange", "blast"))
		"xadrez":
			var celula_prevista := GameState.ml_brain.prever_celula_jogador(p1.current_cell)
			var paridade := (celula_prevista.x + celula_prevista.y) % 2
			var cells_x: Array = []
			for c in todas_as_casas:
				if (c.x + c.y) % 2 == paridade:
					cells_x.append(c)
			strikes.append(_strike(cells_x, 1.9, "red", "geyser"))
	return strikes

func _linha(row: int, rev: bool, hit_at: float) -> Dictionary:
	var cells: Array = [Vector2i(0, row), Vector2i(1, row), Vector2i(2, row)]
	if rev:
		cells.reverse()
	var s := _strike(cells, hit_at, "red", "slash", 0.13, rev)
	# seta de aviso na borda de onde o golpe comeca
	s["icons"] = [{"pos": _cell_pos(Vector2i(3 if rev else -1, row)), "frame": 3 if rev else 2}]
	return s

func _coluna(col: int, hit_at: float) -> Dictionary:
	var cells: Array = [Vector2i(col, 0), Vector2i(col, 1), Vector2i(col, 2)]
	var s := _strike(cells, hit_at, "yellow", "bolt")
	s["icons"] = [{"pos": _cell_pos(Vector2i(col, -1)) + Vector2(0, 6), "frame": 1}]
	return s

func ejecutar_ataque(strikes: Array, estado_s: String = "", padrao_nome: String = "") -> void:
	if combate_encerrado or golpe_final_em_curso:
		return
	guardian_anim_state = "attack"
	guardian_state_ttl = 0.6
	GameState.play_tone(180.0, 0.1, "bell")
	for s in strikes:
		s["estado"] = estado_s
		s["padrao"] = padrao_nome
		s["ameacou"] = s["cells"].has(p1.current_cell) or s["cells"].has(p2.current_cell) or (symphony_ativa and s["cells"].has(celula_symphony))
		for c in s["cells"]:
			var tel := Telegraph.new()
			tel.setup(s["tint"], s["hit_at"])
			tel.position = _cell_pos(c) + Vector2(0, -2)
			telegraphs_node.add_child(tel)
			s["tels"][c] = tel
			if not (symphony_ativa and c == celula_symphony):
				var plat: Node2D = plataformas.get(c)
				if plat and plat.has_method("set_estado"):
					plat.set_estado("warning")
		for ic in s["icons"]:
			var w := Sprite2D.new()
			w.texture = WARN_TEX
			w.hframes = 5
			w.frame = ic["frame"]
			w.position = ic["pos"]
			w.z_index = 4
			telegraphs_node.add_child(w)
			var tw := w.create_tween().set_loops()
			tw.tween_property(w, "modulate:a", 0.25, 0.12)
			tw.tween_property(w, "modulate:a", 1.0, 0.12)
			s["tels"][ic["pos"]] = w
		_resolver_strike(s)

func _resolver_strike(s: Dictionary) -> void:
	await get_tree().create_timer(s["hit_at"]).timeout
	if not is_inside_tree():
		return
	var idx := 0
	for c in s["cells"]:
		if combate_encerrado or golpe_final_em_curso or not is_inside_tree():
			break
		_impactar_celda(c, s, idx)
		idx += 1
		if s["stagger"] > 0.0:
			await get_tree().create_timer(s["stagger"]).timeout
			if not is_inside_tree():
				return
	for key in s["tels"]:
		var node = s["tels"][key]
		if is_instance_valid(node):
			node.queue_free()
	await get_tree().create_timer(0.08).timeout
	if not is_inside_tree():
		return
	if String(s.get("estado", "")) != "" and String(s.get("padrao", "")) != "":
		var hits := int(s.get("hits", 0))
		var recompensa := -0.25
		if hits > 0:
			recompensa = 1.0 * float(hits)
		elif bool(s.get("ameacou", false)):
			recompensa = 0.3
		var novo_estado := GameState.ml_brain.obter_estado_tatico(p1.current_cell, p2.current_cell, symphony_ativa, celula_symphony)
		GameState.ml_brain.atualizar_q_value(String(s["estado"]), String(s["padrao"]), recompensa, novo_estado, patterns)
		_atualizar_hud_combate()

func _restaurar_plataforma(c: Vector2i) -> void:
	var plat: Node2D = plataformas.get(c)
	if not plat or not plat.has_method("set_estado"):
		return
	if symphony_ativa and c == celula_symphony:
		plat.set_estado("symphony")
	else:
		plat.set_estado("normal")

func _impactar_celda(c: Vector2i, s: Dictionary, idx: int) -> void:
	var tel = s["tels"].get(c)
	if tel and is_instance_valid(tel):
		tel.queue_free()
	var plat: Node2D = plataformas.get(c)
	if plat and plat.has_method("set_estado"):
		plat.set_estado("attack")
		get_tree().create_timer(0.26).timeout.connect(func():
			if is_inside_tree():
				_restaurar_plataforma(c)
		)
	var pos := _cell_pos(c)
	match s["fx"]:
		"geyser":
			VFX.play(effects_node, FX_GEYSER, 7, 16.0, pos + Vector2(0, -15), Vector2.ONE, false, 2)
			GameState.play_tone(110.0, 0.14, "noise")
		"bolt":
			VFX.play(effects_node, FX_BOLT, 6, 18.0, pos, Vector2.ONE, false, 2)
			if c.y == 0:
				VFX.play(effects_node, FX_BOLT, 6, 18.0, pos - Vector2(0, 40), Vector2.ONE, false, 2)
			if idx == 0:
				GameState.play_tone(300.0, 0.16, "zap")
				_shake(2.5, 0.22)
		"slash":
			VFX.play(effects_node, FX_SLASH, 6, 16.0, pos, Vector2.ONE, s["flip"], 2)
			GameState.play_tone(420.0 - idx * 40.0, 0.07, "noise")
		"blast":
			VFX.play(effects_node, FX_BLAST, 7, 16.0, pos, Vector2.ONE, false, 2)
			if idx == 0:
				GameState.play_tone(90.0, 0.22, "boom")
				_shake(3.5, 0.28)
		"ring":
			VFX.play(effects_node, FX_RING, 6, 14.0, pos, Vector2(1.5, 1.5), false, 2)
			if idx == 0:
				GameState.play_tone(380.0, 0.2, "bell")
				_shake(1.5, 0.15)
	_aplicar_dano(c, s)

func _aplicar_dano(c: Vector2i, s: Dictionary) -> void:
	await get_tree().create_timer(0.07).timeout
	if not is_inside_tree() or combate_encerrado or golpe_final_em_curso:
		return
	var p = occupied_cells.get(c)
	if p and p.invulnerable_time <= 0.0:
		s["hits"] = int(s.get("hits", 0)) + 1
		_herir_jogador(p)

func _herir_jogador(p: Node) -> void:
	p.play_hurt_anim()
	GameState.record_hit_taken(bool(p.get("is_peixoto")), p.get("current_cell"))
	vida_players = maxi(0, vida_players - 1)
	VFX.play(effects_node, FX_HIT, 5, 18.0, p.global_position + Vector2(0, -4), Vector2(1.5, 1.5), false, 5)
	_mostrar_popup_dano(p.global_position + Vector2(0, -18), "-1 HP", Color(1.0, 0.32, 0.38, 1.0))
	_shake(3.0, 0.2)
	_atualizar_hud_combate()
	if vida_players <= 0:
		_derrota_combate()

func _mostrar_popup_dano(pos: Vector2, texto: String, cor: Color) -> void:
	var lbl := Label.new()
	lbl.text = texto
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(64, 18)
	lbl.pivot_offset = Vector2(32, 9)
	lbl.position = pos - Vector2(32, 9)
	lbl.scale = Vector2(1.3, 1.3)
	lbl.z_index = 14
	lbl.add_theme_font_override("font", FONT_PIXEL)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", cor)
	lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.11, 1.0))
	lbl.add_theme_constant_override("outline_size", 4)
	effects_node.add_child(lbl)

	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - 22.0, 0.68).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.68).set_delay(0.18)
	tw.chain().tween_callback(lbl.queue_free)

func _shake(amount: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount * v, 1.0, 0.0, dur)


func gerar_sequencia_ritmo() -> void:
	sequencia_atual.clear()
	progresso_ritmo = 0

	var tipo_ritmo := randi() % nomes_ritmos.size()
	nome_ritmo_atual = nomes_ritmos[tipo_ritmo]
	var tamanho := 4
	if tipo_ritmo == 1 or tipo_ritmo == 2:
		tamanho = 5
	elif tipo_ritmo == 3:
		tamanho = 6

	for i in range(tamanho):
		sequencia_atual.append(direcoes_possiveis.pick_random())

	_desenhar_setas_ritmo()

func _desenhar_setas_ritmo() -> void:
	for ic in icones_setas:
		if is_instance_valid(ic):
			ic.queue_free()
	icones_setas.clear()

	var total := sequencia_atual.size()
	var espaco := 22.0
	var inicio_x := -((total - 1) * espaco) * 0.5

	for i in range(total):
		var spr := Sprite2D.new()
		spr.texture = arrow_texture
		spr.hframes = 8
		var dir_idx := _indice_direcao(sequencia_atual[i])
		spr.frame = dir_idx + (4 if i < progresso_ritmo else 0)
		spr.position = Vector2(inicio_x + i * espaco, -1)
		rhythm_display.add_child(spr)
		icones_setas.append(spr)

func _indice_direcao(dir_name: String) -> int:
	match dir_name:
		"up":
			return 0
		"down":
			return 1
		"left":
			return 2
		"right":
			return 3
	return 0

func _atualizar_barra_tempo_symphony() -> void:
	var ratio := clampf(symphony_time_left / symphony_lifetime, 0.0, 1.0)
	timer_bar_fill.size.x = 140.0 * ratio
	if ratio > 0.5:
		timer_bar_fill.color = Color(0.31, 0.89, 0.89, 1.0)
	elif ratio > 0.25:
		timer_bar_fill.color = Color(0.98, 0.85, 0.25, 1.0)
	else:
		var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.025)
		timer_bar_fill.color = Color(0.95, 0.28, 0.32, pulse)

func symphony() -> void:
	if combate_encerrado or golpe_final_em_curso:
		return

	symphony_id += 1
	var meu_id := symphony_id

	var celula_alvo: Vector2i = todas_as_casas.pick_random()
	var plataforma_alvo: Node2D = plataformas.get(celula_alvo)

	symphony_ativa = true
	symphony_time_left = symphony_lifetime
	celula_symphony = celula_alvo
	gerar_sequencia_ritmo()
	_atualizar_barra_tempo_symphony()

	if plataforma_alvo and plataforma_alvo.has_method("set_estado"):
		plataforma_alvo.set_estado("symphony")

	rhythm_display.position.x = 240.0
	rhythm_display.visible = true

	GameState.play_tone(660.0, 0.14, "bell")
	await get_tree().create_timer(symphony_lifetime).timeout

	if not is_inside_tree() or symphony_id != meu_id or not symphony_ativa:
		return

	_encerrar_symphony_visual(celula_alvo)

func _encerrar_symphony_visual(celula: Vector2i) -> void:
	symphony_ativa = false
	celula_symphony = Vector2i(-1, -1)
	timer_symphony = 0.0
	var plat: Node2D = plataformas.get(celula)
	if plat and plat.has_method("set_estado"):
		plat.set_estado("normal")
	rhythm_display.visible = false
	if not combate_encerrado:
		symphony_prompt.text = "Desvie dos alertas! A proxima Plataforma de Sinfonia ja vem..."

func _atualizar_status_symphony() -> void:
	if not symphony_ativa:
		return

	var p1_na_casa := (p1.current_cell == celula_symphony and not p1.is_jumping)
	var p2_na_casa := (p2.current_cell == celula_symphony and not p2.is_jumping)

	if p1_na_casa:
		symphony_prompt.text = "%s - SQUETCH tocando! [Setas] (%d/%d)" % [nome_ritmo_atual, progresso_ritmo, sequencia_atual.size()]
		rhythm_display.modulate = Color(1, 1, 1, 1)
	elif p2_na_casa:
		symphony_prompt.text = "%s - PEIXOTO tocando! [Num 8/5/4/6 ou Controle] (%d/%d)" % [nome_ritmo_atual, progresso_ritmo, sequencia_atual.size()]
		rhythm_display.modulate = Color(1, 1, 1, 1)
	else:
		symphony_prompt.text = "%s - Pise na plataforma da SINFONIA (notas saindo do chao)!" % nome_ritmo_atual
		rhythm_display.modulate = Color(0.65, 0.85, 0.95, 0.75)

func process_symphony_input(player: Node, nota_dir: String) -> void:
	if combate_encerrado or golpe_final_em_curso or not symphony_ativa:
		return

	if player.current_cell != celula_symphony or player.is_jumping:
		return

	if progresso_ritmo < sequencia_atual.size():
		var esperado := sequencia_atual[progresso_ritmo]
		if nota_dir == esperado:
			var ic := icones_setas[progresso_ritmo]
			if is_instance_valid(ic):
				ic.frame = _indice_direcao(nota_dir) + 4
				var tw := create_tween()
				tw.tween_property(ic, "scale", Vector2(1.35, 1.35), 0.06)
				tw.tween_property(ic, "scale", Vector2(1.0, 1.0), 0.06)
			_nota_acertada(player)
			progresso_ritmo += 1

			if progresso_ritmo >= sequencia_atual.size():
				song_atack(player)
		else:
			progresso_ritmo = 0
			GameState.play_tone(150.0, 0.08, "synth")
			var total := icones_setas.size()
			for i in range(total):
				if is_instance_valid(icones_setas[i]):
					icones_setas[i].frame = _indice_direcao(sequencia_atual[i])
			_animar_erro_ritmo()

func _animar_erro_ritmo() -> void:
	rhythm_display.modulate = Color(1.0, 0.38, 0.38, 1.0)
	var tw := create_tween()
	tw.tween_property(rhythm_display, "position:x", 234.0, 0.04)
	tw.tween_property(rhythm_display, "position:x", 246.0, 0.04)
	tw.tween_property(rhythm_display, "position:x", 237.0, 0.04)
	tw.tween_property(rhythm_display, "position:x", 240.0, 0.04)
	tw.tween_callback(func(): rhythm_display.modulate = Color.WHITE)

func _nota_acertada(player: Node) -> void:
	GameState.record_note_hit(bool(player.get("is_peixoto")))
	var n := Sprite2D.new()
	n.texture = NOTES_TEX
	n.hframes = 6
	n.frame = randi() % 6
	n.position = player.global_position + Vector2(randf_range(-6, 6), -12)
	n.z_index = 5
	effects_node.add_child(n)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "position:y", n.position.y - 22.0, 0.5)
	tw.tween_property(n, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(n.queue_free)

func song_atack(autor: Node = null) -> void:
	var celula_usada := celula_symphony
	if vida_inimigo <= 1:
		golpe_final_em_curso = true
		_limpar_alertas()
	_encerrar_symphony_visual(celula_usada)

	if autor and autor.has_method("play_symphony_anim"):
		autor.play_symphony_anim()

	var origem: Vector2 = autor.global_position if autor else Vector2(240, 200)
	VFX.play(effects_node, FX_RING, 6, 14.0, _cell_pos(celula_usada), Vector2(1.4, 1.4), false, 2)
	GameState.play_tone(880.0, 0.18, "bell")

	var alvo: Vector2 = guardian.global_position
	for i in range(6):
		var n := Sprite2D.new()
		n.texture = NOTES_TEX
		n.hframes = 6
		n.frame = i % 6
		n.position = origem
		n.z_index = 6
		n.scale = Vector2(1.5, 1.5)
		effects_node.add_child(n)
		var tw := n.create_tween()
		tw.tween_interval(i * 0.05)
		tw.tween_property(n, "position", alvo + Vector2(randf_range(-14, 14), randf_range(-10, 10)), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(n.queue_free)

	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree() or combate_encerrado:
		return
	_golpear_inimigo(alvo)

func _golpear_inimigo(alvo: Vector2) -> void:
	guardian_anim_state = "hurt"
	guardian_state_ttl = 0.7
	guardian_sprite.self_modulate = Color(2.8, 2.8, 2.8, 1.0)
	var flash_tw := create_tween()
	flash_tw.tween_property(guardian_sprite, "self_modulate", Color.WHITE, 0.16)
	VFX.play(effects_node, FX_HIT, 5, 16.0, alvo, Vector2(3, 3), false, 5)
	_mostrar_popup_dano(alvo + Vector2(randf_range(-8.0, 8.0), -18.0), "-1 HP", Color(1.0, 0.92, 0.26, 1.0))
	GameState.play_tone(200.0, 0.2, "boom")
	_shake(3.0, 0.25)
	vida_inimigo = maxi(0, vida_inimigo - 1)
	_atualizar_hud_combate()
	if vida_inimigo <= 0:
		_vencer_combate()
	elif enemy_id == "boss" and not fase2 and vida_inimigo <= vida_inimigo_max / 2:
		fase2 = true
		patterns = (enemy["patterns_fase2"] as Array).duplicate()
		timer_ataque_interval *= 0.8
		_ativar_visual_fase2()
		_mostrar_banner("O Guardiao esta furioso!", 1.6)
		_shake(4.0, 0.4)

func _ativar_visual_fase2() -> void:
	if arena_atmosphere:
		arena_atmosphere.set_enraged(Color(1.0, 0.18, 0.28, 1.0), Color(1.0, 0.65, 0.20, 1.0))
	var tw := create_tween().set_parallel(true)
	tw.tween_property($Background, "modulate", Color(1.22, 0.58, 0.66, 1.0), 0.65)
	tw.tween_property(coral_left, "modulate", Color(1.38, 0.35, 0.42, 1.0), 0.65)
	tw.tween_property(coral_right, "modulate", Color(1.38, 0.35, 0.42, 1.0), 0.65)
	tw.tween_property(pillar_left, "modulate", Color(1.18, 0.62, 0.68, 1.0), 0.65)
	tw.tween_property(pillar_right, "modulate", Color(1.18, 0.62, 0.68, 1.0), 0.65)
	tw.tween_property(enemy_bar_fill, "color", Color(0.98, 0.22, 0.30, 1.0), 0.65)
	hp_enemy_label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.56, 1.0))

# =====================================================================
#  HUD / FIM DE COMBATE
# =====================================================================
func _atualizar_hud_combate() -> void:
	for i in range(hearts.size()):
		hearts[i].modulate = Color(1, 1, 1, 1) if i < vida_players else Color(0.22, 0.22, 0.3, 1)
	hp_enemy_label.text = "%s  %d/%d" % [enemy["name"], vida_inimigo, vida_inimigo_max]
	var largura_alvo := 150.0 * float(vida_inimigo) / float(maxi(1, vida_inimigo_max))
	var tw := create_tween()
	tw.tween_property(enemy_bar_fill, "size:x", largura_alvo, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _mostrar_banner(texto: String, dur: float) -> void:
	banner_label.text = texto
	banner_label.modulate.a = 1.0
	banner_label.show()
	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_property(banner_label, "modulate:a", 0.0, 0.4)

func _limpar_alertas() -> void:
	for ch in telegraphs_node.get_children():
		ch.queue_free()
	for casa in todas_as_casas:
		var plat: Node2D = plataformas.get(casa)
		if plat and plat.has_method("set_estado"):
			plat.set_estado("normal")
	rhythm_display.visible = false

func _vencer_combate() -> void:
	combate_encerrado = true
	GameState.battle_result = "win"
	GameState.ml_brain.save_model()
	symphony_ativa = false
	_limpar_alertas()
	symphony_prompt.text = "VITORIA! %s foi derrotado pela Sinfonia!" % enemy["name"]
	_mostrar_banner("VITORIA!", 2.0)
	p1.play_symphony_anim()
	p2.play_symphony_anim()
	p1.timer_estado_especial = 3.0
	p2.timer_estado_especial = 3.0
	guardian_anim_state = "hurt"
	guardian_state_ttl = 5.0

	var alvo: Vector2 = guardian.global_position
	for i in range(7):
		get_tree().create_timer(i * 0.17).timeout.connect(func():
			if not is_inside_tree():
				return
			VFX.play(effects_node, FX_BLAST, 7, 16.0, alvo + Vector2(randf_range(-26, 26), randf_range(-22, 22)), Vector2(1.4, 1.4), false, 6)
			GameState.play_tone(80.0 + randf() * 40.0, 0.16, "boom")
			_shake(3.0, 0.2)
		)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(guardian, "modulate:a", 0.0, 0.9)

	await get_tree().create_timer(1.8).timeout
	if not is_inside_tree():
		return
	var resumo := VictorySummary.new()
	add_child(resumo)
	resumo.show_summary("VITORIA!", func():
		if is_inside_tree():
			GameState.fade_to_scene("res://Scenes/world.tscn")
	)

func _derrota_combate() -> void:
	if combate_encerrado:
		return
	combate_encerrado = true
	GameState.battle_result = "lose"
	GameState.ml_brain.save_model()
	_limpar_alertas()
	symphony_prompt.text = "RECUANDO AO MUNDO SUBAQUATICO..."
	_mostrar_banner("DERROTA...", 2.0)
	await get_tree().create_timer(1.4).timeout
	if is_inside_tree():
		GameState.fade_to_scene("res://Scenes/world.tscn")

func _encerrar_e_sair(cena_destino: String) -> void:
	if combate_encerrado:
		return
	combate_encerrado = true
	GameState.battle_result = "lose"
	GameState.ml_brain.save_model()
	_limpar_alertas()
	GameState.fade_to_scene(cena_destino)

func on_player_landed(_player: Node, _cell: Vector2i) -> void:
	_atualizar_status_symphony()

func request_move(player: Node, from_cell: Vector2i, to_cell: Vector2i) -> int:
	if combate_encerrado:
		return 0

	if to_cell.x < 0 or to_cell.x > 2 or to_cell.y < 0 or to_cell.y > 2:
		return 0

	var resultado := _resolver_ocupacao_celula(player, from_cell, to_cell)
	if resultado == 1:
		GameState.ml_brain.registrar_movimento(from_cell, to_cell)
	return resultado

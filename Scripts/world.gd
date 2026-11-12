extends GridBase
class_name WorldGrid

## Mundo de exploracao estilo Hoptale: os jogadores pulam livremente de plataforma em plataforma,
## abrem portoes (toque / chave / placas duplas), pegam chaves e entram em batalhas pisando nos icones de inimigo.

const TILE_STEP: int = 26
const MAP_ORIGIN: Vector2 = Vector2(40, 54)
const MAX_DX: int = 13   # distancia maxima permitida entre os jogadores (a camera segue os dois)
const MAX_DY: int = 6
const ENEMY_IDS: Dictionary = {"j": "jellyfish", "c": "crab", "b": "puffer", "p": "bell", "G": "boss"}
const PLATE_GATE: Dictionary = {"u": "V", "v": "V"}
const ZONAS: Array = [[0, "RECIFE INICIAL"], [14, "RUINAS SONORAS"], [30, "FOSSA DOS SINOS"], [43, "COVIL DO GUARDIAO"]]
const DEFAULT_HINT: String = "P1: WASD  |  P2: IJKL / Controle  |  [M] Mapa  |  [ESC] Pausa"
const DECOR_TEX: Texture2D = preload("res://Sprites/Maps/UnderwaterDecor_sheet.png")

var kinds: Dictionary = {}         # Vector2i -> caractere do mapa
var plates_by_gate: Dictionary = {}
var gates_by_letter: Dictionary = {}

var spawn_p1: Vector2i = Vector2i(2, 9)
var spawn_p2: Vector2i = Vector2i(2, 10)
var map_size: Vector2i = Vector2i.ZERO
var total_inimigos: int = 0

var em_transicao: bool = false
var fim_demo: bool = false
var cam_pos: Vector2 = Vector2.ZERO
var hint_timer: float = 0.0
var decor_nodes: Array = []
var decor_timer: float = 0.0
var decor_step: int = 0
var mensagem_inicial: String = ""
var minimap_radar: MinimapRadar
var pause_menu: PauseMenu

@onready var camera: Camera2D = $Camera2D
@onready var p1: PlayerBase = $Players/Player1
@onready var p2: PlayerBase = $Players/Player2
@onready var zone_label: Label = $HUD/ZoneLabel
@onready var keys_label: Label = $HUD/KeysLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var banner_label: Label = $HUD/Banner

func _ready() -> void:
	GameState.fade_out()

	_processar_resultado_batalha()
	_construir_mundo()
	_posicionar_jogadores()
	_espalhar_decoracao()
	_configurar_camera()
	GameState.spawn_ambient_bubbles(camera, Vector2(480, 270), Vector2(0, 140), 18)
	_configurar_minimapa_e_pausa()
	_atualizar_hud()
	hint_label.text = DEFAULT_HINT
	if mensagem_inicial != "":
		mostrar_dica(mensagem_inicial, 4.0)

func _configurar_minimapa_e_pausa() -> void:
	minimap_radar = MinimapRadar.new()
	$HUD.add_child(minimap_radar)
	minimap_radar.setup(self)

	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(
		false,
		func() -> bool: return not em_transicao and not fim_demo,
		func() -> void: _ir_para_menu(),
		Callable(),
		func() -> void: _alternar_minimapa(),
		func() -> bool: return minimap_radar != null and minimap_radar.visible
	)

func _alternar_minimapa() -> void:
	if minimap_radar:
		minimap_radar.visible = not minimap_radar.visible

func _processar_resultado_batalha() -> void:
	if GameState.battle_result == "win":
		GameState.world_cleared[GameState.battle_cell] = true
		mensagem_inicial = "Vitoria! O caminho esta livre."
	elif GameState.battle_result == "lose":
		if GameState.battle_trigger_player == 1:
			GameState.world_p1_cell = GameState.battle_return_cell
		else:
			GameState.world_p2_cell = GameState.battle_return_cell
		mensagem_inicial = "Derrotados! Tentem de novo quando estiverem prontos."
	GameState.battle_result = ""

func _construir_mundo() -> void:
	var rows = WorldMap.ROWS
	map_size = Vector2i(rows[0].length(), rows.size())
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var ch: String = rows[y][x]
			if ch == ".":
				continue
			var cell := Vector2i(x, y)
			var kind := ch
			if ch == "1":
				spawn_p1 = cell
				kind = "o"
			elif ch == "2":
				spawn_p2 = cell
				kind = "o"
			elif ENEMY_IDS.has(ch):
				total_inimigos += 1
				if GameState.world_cleared.has(cell):
					kind = "o"

			var tile := WorldTile.new()
			tile.name = "(%d,%d)" % [x, y]
			tile.position = get_cell_world_pos(cell)
			$Grid.add_child(tile)
			tile.setup(kind, GameState.world_opened.has(cell), GameState.world_taken.has(cell))
			plataformas[cell] = tile
			kinds[cell] = kind

			if PLATE_GATE.has(kind):
				var g: String = PLATE_GATE[kind]
				if not plates_by_gate.has(g):
					plates_by_gate[g] = []
				plates_by_gate[g].append(cell)
			if kind == "D" or kind == "K" or kind == "V":
				if not gates_by_letter.has(kind):
					gates_by_letter[kind] = []
				gates_by_letter[kind].append(cell)

	# placas de grupos ja abertos continuam acionadas
	for g in plates_by_gate:
		if _grupo_aberto(g):
			for pc in plates_by_gate[g]:
				plataformas[pc].set_pressed(true, true)

func _grupo_aberto(letter: String) -> bool:
	if not gates_by_letter.has(letter):
		return false
	for gc in gates_by_letter[letter]:
		if not plataformas[gc].open:
			return false
	return true

func _celula_segura(cell: Vector2i) -> bool:
	return plataformas.has(cell) and not plataformas[cell].is_closed_gate() and not ENEMY_IDS.has(kinds.get(cell, "o"))

func _posicionar_jogadores() -> void:
	occupied_cells.clear()
	var c1: Vector2i
	var c2: Vector2i
	if not GameState.world_initialized:
		c1 = spawn_p1
		c2 = spawn_p2
		GameState.world_initialized = true
	else:
		c1 = GameState.world_p1_cell
		c2 = GameState.world_p2_cell
	if not _celula_segura(c1):
		c1 = spawn_p1
	if not _celula_segura(c2) or c2 == c1:
		c2 = _celula_livre_perto(c1)
	p1.place_at(c1)
	p2.place_at(c2)
	register_player(p1, c1)
	register_player(p2, c2)
	GameState.world_p1_cell = c1
	GameState.world_p2_cell = c2

func _celula_livre_perto(cell: Vector2i) -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]
	var fila: Array[Vector2i] = [cell]
	var visitados: Dictionary = {cell: true}
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_front()
		for d in dirs:
			var n: Vector2i = atual + d
			if visitados.has(n) or not plataformas.has(n):
				continue
			visitados[n] = true
			if _celula_segura(n):
				return n
			if not plataformas[n].is_closed_gate():
				fila.append(n)
	return spawn_p2

func _espalhar_decoracao() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 11
	for y in range(-3, map_size.y + 3):
		for x in range(-3, map_size.x + 3):
			var perto := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if plataformas.has(Vector2i(x + dx, y + dy)):
						perto = true
			if perto or rnd.randf() > 0.075:
				continue
			var spr := Sprite2D.new()
			spr.texture = DECOR_TEX
			spr.hframes = 8
			var base: int = [0, 2, 4, 6][rnd.randi() % 4]
			spr.frame = base
			spr.position = get_cell_world_pos(Vector2i(x, y)) + Vector2(rnd.randi_range(-6, 6), rnd.randi_range(-6, 6))
			spr.modulate = Color(0.75, 0.85, 0.95, 1.0)
			$Scenery.add_child(spr)
			decor_nodes.append([spr, base])

func _configurar_camera() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP_ORIGIN.x + map_size.x * TILE_STEP + 40)
	camera.limit_bottom = int(MAP_ORIGIN.y + map_size.y * TILE_STEP + 20)
	cam_pos = _alvo_camera()
	camera.global_position = cam_pos.round()

func _alvo_camera() -> Vector2:
	return (p1.global_position + p2.global_position) * 0.5

func get_cell_world_pos(cell: Vector2i) -> Vector2:
	return MAP_ORIGIN + Vector2(cell.x * TILE_STEP, cell.y * TILE_STEP)

# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	cam_pos = cam_pos.lerp(_alvo_camera(), 1.0 - exp(-7.0 * delta))
	camera.global_position = cam_pos.round()

	_atualizar_placas()

	decor_timer += delta
	if decor_timer >= 0.5:
		decor_timer = 0.0
		decor_step = (decor_step + 1) % 2
		for d in decor_nodes:
			d[0].frame = d[1] + decor_step

	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0:
			hint_label.text = DEFAULT_HINT

	var zona: String = ZONAS[0][1]
	var media_x := int((p1.current_cell.x + p2.current_cell.x) * 0.5)
	for z in ZONAS:
		if media_x >= z[0]:
			zona = z[1]
	zone_label.text = zona

func _ocupada_por_jogador(cell: Vector2i) -> bool:
	return (p1.current_cell == cell and not p1.is_jumping) or (p2.current_cell == cell and not p2.is_jumping)

func _atualizar_placas() -> void:
	for g in plates_by_gate:
		if _grupo_aberto(g):
			continue
		var todas := true
		for pc in plates_by_gate[g]:
			var pr := _ocupada_por_jogador(pc)
			plataformas[pc].set_pressed(pr)
			if not pr:
				todas = false
		if todas and not em_transicao:
			for gc in gates_by_letter.get(g, []):
				_abrir_porta(gc)
			mostrar_dica("As placas abriram o portao!")

func _abrir_porta(cell: Vector2i) -> void:
	GameState.world_opened[cell] = true
	plataformas[cell].open_gate()

func _celula_de(player: Node) -> Vector2i:
	return player.target_cell if player.is_jumping else player.current_cell

func _outro(player: Node) -> Node:
	return p2 if player == p1 else p1

# ------------------------------------------------------------------ regras de movimento
func request_move(player: Node, from_cell: Vector2i, to_cell: Vector2i) -> int:
	if em_transicao or fim_demo:
		return 0
	if not plataformas.has(to_cell):
		return 0

	var ref: Vector2i = _celula_de(_outro(player))
	if abs(to_cell.x - ref.x) > MAX_DX or abs(to_cell.y - ref.y) > MAX_DY:
		mostrar_dica("Fiquem perto do seu parceiro!")
		return 0

	var tile: WorldTile = plataformas[to_cell]
	if tile.is_closed_gate():
		match tile.kind:
			"D":
				_abrir_porta(to_cell)
				mostrar_dica("Portao aberto!")
			"K":
				if GameState.world_keys > 0:
					GameState.world_keys -= 1
					_abrir_porta(to_cell)
					_atualizar_hud()
					mostrar_dica("Portao destrancado com a chave!")
				else:
					mostrar_dica("Portao trancado! Procure um bau dourado com uma chave.")
			"V":
				mostrar_dica("Este portao so abre com as DUAS placas pisadas ao mesmo tempo!")
		return 0

	return _resolver_ocupacao_celula(player, from_cell, to_cell)

func on_player_landed(player: Node, cell: Vector2i) -> void:
	if em_transicao or fim_demo:
		return
	GameState.world_p1_cell = _celula_de(p1)
	GameState.world_p2_cell = _celula_de(p2)

	var kind: String = kinds.get(cell, "o")
	if ENEMY_IDS.has(kind):
		_iniciar_batalha(player, cell, kind)
	elif kind == "k":
		_pegar_bau(cell)
	elif kind == "F":
		_fim_da_demo()

func _pegar_bau(cell: Vector2i) -> void:
	if GameState.world_taken.has(cell):
		return
	GameState.world_taken[cell] = true
	GameState.world_keys += 1
	plataformas[cell].take_chest()
	_atualizar_hud()
	mostrar_dica("Voce pegou uma chave!")

func _iniciar_batalha(player: Node, cell: Vector2i, kind: String) -> void:
	em_transicao = true
	var id: String = ENEMY_IDS[kind]
	var celula_outro: Vector2i = _outro(player).current_cell

	GameState.current_enemy_id = id
	GameState.battle_cell = cell
	GameState.battle_trigger_player = 1 if player == p1 else 2
	GameState.battle_return_cell = player.previous_cell
	GameState.battle_result = ""
	GameState.world_p1_cell = cell if player == p1 else celula_outro
	GameState.world_p2_cell = cell if player == p2 else celula_outro
	mostrar_dica("Encontro: %s!" % EnemyData.get_enemy(id)["name"], 3.0)
	GameState.play_tone(220.0, 0.16, "zap")

	# Pulso de Sonar Abissal + leve zoom dramatico no ponto do encontro
	var sonar := _EncounterSonar.new()
	sonar.position = get_cell_world_pos(cell)
	add_child(sonar)
	var ctw := create_tween()
	ctw.tween_property(camera, "zoom", Vector2(1.15, 1.15), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	GameState.fade_to_scene("res://Scenes/defense.tscn")

func _fim_da_demo() -> void:
	fim_demo = true
	banner_label.text = "FIM DA DEMO!\nVoces dominaram a Sinfonia Abissal"
	banner_label.show()
	p1.play_symphony_anim()
	p2.play_symphony_anim()
	p1.timer_estado_especial = 5.0
	p2.timer_estado_especial = 5.0
	GameState.play_note_sfx(false, "up")
	GameState.play_note_sfx(true, "right")
	await get_tree().create_timer(1.8).timeout
	if not is_inside_tree():
		return
	banner_label.hide()
	var resumo := VictorySummary.new()
	add_child(resumo)
	resumo.show_summary("FIM DA DEMO!", func():
		if is_inside_tree():
			_ir_para_menu()
	)

func _ir_para_menu() -> void:
	if em_transicao:
		return
	em_transicao = true
	GameState.fade_to_scene("res://Scenes/menu.tscn")

# ------------------------------------------------------------------ HUD
func mostrar_dica(texto: String, duracao: float = 2.6) -> void:
	hint_label.text = texto
	hint_timer = duracao

func _atualizar_hud() -> void:
	keys_label.text = "x%d" % GameState.world_keys
	status_label.text = "Inimigos: %d/%d" % [GameState.world_cleared.size(), total_inimigos]

func _on_btn_menu_pressed() -> void:
	if pause_menu:
		pause_menu.open_pause()
	else:
		_ir_para_menu()

func _unhandled_input(event: InputEvent) -> void:
	if em_transicao or fim_demo:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M or event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			_alternar_minimapa()
			GameState.play_ui_sfx("hover")


class _EncounterSonar extends Node2D:
	var progress: float = 0.0

	func _ready() -> void:
		z_index = 10
		var tw := create_tween()
		tw.tween_property(self, "progress", 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r1 := lerpf(6.0, 48.0, progress)
		var a1 := (1.0 - progress) * 0.85
		draw_arc(Vector2.ZERO, r1, 0.0, TAU, 32, Color(0.35, 0.95, 1.0, a1), 2.0)
		var p2_prog := clampf((progress - 0.18) / 0.82, 0.0, 1.0)
		if p2_prog > 0.0:
			var r2 := lerpf(4.0, 36.0, p2_prog)
			var a2 := (1.0 - p2_prog) * 0.75
			draw_arc(Vector2.ZERO, r2, 0.0, TAU, 28, Color(1.0, 0.38, 0.45, a2), 1.5)

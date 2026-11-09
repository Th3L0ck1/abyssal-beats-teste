extends Node2D
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

var enemy_id: String = "jellyfish"
var enemy: Dictionary = {}
var patterns: Array = []

var timer_ataque: float = 0.0
var timer_ataque_interval: float = 2.9
var timer_symphony: float = 0.0
var symphony_gap: float = 2.5
var symphony_lifetime: float = 8.0
var intro_time: float = 1.7

var occupied_cells: Dictionary = {}
var plataformas: Dictionary = {}
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
	"Solo Bioluminescente (6 Notas)"
]

var arrow_texture: Texture2D = preload("res://Sprites/UI/Arrows_sheet.png")
var icones_setas: Array[Sprite2D] = []
var hearts: Array[Sprite2D] = []

func _ready() -> void:
	$fade_transition.show()
	$fade_transition/AnimationPlayer.play("fade_out")

	enemy_id = GameState.current_enemy_id
	enemy = EnemyData.get_enemy(enemy_id)
	_configurar_inimigo()

	for casa in todas_as_casas:
		var nome_no = "(%d,%d)" % [casa.x, casa.y]
		var no_plataforma = $Grid.get_node_or_null(nome_no)
		if no_plataforma:
			plataformas[casa] = no_plataforma
			if no_plataforma.has_method("set_estado"):
				no_plataforma.set_estado("normal")

	_criar_coracoes()
	_atualizar_hud_combate()
	timer_ataque = timer_ataque_interval - intro_time
	timer_symphony = symphony_gap - 1.2
	_mostrar_banner("%s apareceu!" % enemy["name"], 1.5)

func _configurar_inimigo() -> void:
	var spr: Sprite2D = $Guardian/Sprite2D
	spr.texture = load(enemy["sheet"])
	spr.hframes = 8
	spr.scale = Vector2.ONE * float(enemy["scale"])
	vida_inimigo = int(enemy["hp"])
	vida_inimigo_max = vida_inimigo
	timer_ataque_interval = float(enemy["interval"])
	patterns = (enemy["patterns"] as Array).duplicate()

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
	if combate_encerrado:
		return

	timer_ataque += delta
	if timer_ataque >= timer_ataque_interval:
		timer_ataque = 0.0
		iniciar_ataque()

	if not symphony_ativa:
		timer_symphony += delta
		if timer_symphony >= symphony_gap:
			timer_symphony = 0.0
			symphony()

	_atualizar_status_symphony()

func _animar_guardiao(delta: float) -> void:
	if guardian_state_ttl > 0.0:
		guardian_state_ttl -= delta
		if guardian_state_ttl <= 0.0:
			guardian_anim_state = "idle"

	guardian_timer += delta
	if guardian_timer >= 0.16:
		guardian_timer = 0.0
		guardian_frame = (guardian_frame + 1) % 4
		var spr: Sprite2D = $Guardian/Sprite2D
		match guardian_anim_state:
			"idle":
				spr.frame = guardian_frame % 4
			"attack":
				spr.frame = 4 + (guardian_frame % 2)
			"hurt":
				spr.frame = 6 + (guardian_frame % 2)

func _cell_pos(c: Vector2i) -> Vector2:
	return CELL_ORIGIN + Vector2(c.x, c.y) * CELL_STEP

func get_cell_world_pos(c: Vector2i) -> Vector2:
	return _cell_pos(c) + Vector2(0, -8)

# =====================================================================
#  ATAQUES DO INIMIGO  (padroes + alerta + VFX)
# =====================================================================
func iniciar_ataque() -> void:
	if enemy_id == "boss" and not fase2 and vida_inimigo <= vida_inimigo_max / 2:
		fase2 = true
		patterns = (enemy["patterns_fase2"] as Array).duplicate()
		timer_ataque_interval *= 0.8
		_mostrar_banner("O Guardiao esta furioso!", 1.6)
		_shake(4.0, 0.4)

	var nome: String = patterns.pick_random()
	ejecutar_ataque(construir_patron(nome))
	if fase2 and randf() < 0.4:
		await get_tree().create_timer(0.9).timeout
		if is_inside_tree() and not combate_encerrado:
			ejecutar_ataque(construir_patron("celula"))

func _strike(cells: Array, hit_at: float, tint: String, fx: String, stagger: float = 0.0, flip: bool = false) -> Dictionary:
	return {"cells": cells, "hit_at": hit_at, "tint": tint, "fx": fx, "stagger": stagger, "flip": flip, "tels": {}, "icons": []}

func construir_patron(nombre: String) -> Array:
	var strikes: Array = []
	match nombre:
		"celula":
			# 1 plataforma so: gêiser
			strikes.append(_strike([todas_as_casas.pick_random()], 1.5, "red", "geyser"))
		"linha":
			var row := randi() % 3
			strikes.append(_linha(row, randf() < 0.5, 1.7))
		"linha_dupla":
			var seguro := randi() % 3
			var rev := randf() < 0.5
			for r in range(3):
				if r != seguro:
					strikes.append(_linha(r, rev, 1.9))
		"coluna":
			strikes.append(_coluna(randi() % 3, 1.5))
		"coluna_dupla":
			var seguro_c := randi() % 3
			for cc in range(3):
				if cc != seguro_c:
					strikes.append(_coluna(cc, 1.7))
		"cruz":
			var centro: Vector2i = todas_as_casas.pick_random()
			var cells: Array = [centro]
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				if todas_as_casas.has(centro + d):
					cells.append(centro + d)
			strikes.append(_strike(cells, 1.7, "orange", "blast", 0.0))
		"ondas":
			var origem: Vector2i = todas_as_casas.pick_random()
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
			var paridade := randi() % 2
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

func ejecutar_ataque(strikes: Array) -> void:
	if combate_encerrado:
		return
	guardian_anim_state = "attack"
	guardian_state_ttl = 0.6
	GameState.play_tone(180.0, 0.1, "bell")
	for s in strikes:
		for c in s["cells"]:
			var tel := Telegraph.new()
			tel.setup(s["tint"], s["hit_at"])
			tel.position = _cell_pos(c) + Vector2(0, -2)
			$Telegraphs.add_child(tel)
			s["tels"][c] = tel
		for ic in s["icons"]:
			var w := Sprite2D.new()
			w.texture = WARN_TEX
			w.hframes = 5
			w.frame = ic["frame"]
			w.position = ic["pos"]
			w.z_index = 4
			$Telegraphs.add_child(w)
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
		if combate_encerrado or not is_inside_tree():
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

func _impactar_celda(c: Vector2i, s: Dictionary, idx: int) -> void:
	var tel = s["tels"].get(c)
	if tel and is_instance_valid(tel):
		tel.queue_free()
	var pos := _cell_pos(c)
	match s["fx"]:
		"geyser":
			VFX.play($Effects, FX_GEYSER, 7, 16.0, pos + Vector2(0, -15), Vector2.ONE, false, 2)
			GameState.play_tone(110.0, 0.14, "noise")
		"bolt":
			VFX.play($Effects, FX_BOLT, 6, 18.0, pos, Vector2.ONE, false, 2)
			if c.y == 0:
				VFX.play($Effects, FX_BOLT, 6, 18.0, pos - Vector2(0, 40), Vector2.ONE, false, 2)
			if idx == 0:
				GameState.play_tone(300.0, 0.16, "zap")
				_shake(2.5, 0.22)
		"slash":
			VFX.play($Effects, FX_SLASH, 6, 16.0, pos, Vector2.ONE, s["flip"], 2)
			GameState.play_tone(420.0 - idx * 40.0, 0.07, "noise")
		"blast":
			VFX.play($Effects, FX_BLAST, 7, 16.0, pos, Vector2.ONE, false, 2)
			if idx == 0:
				GameState.play_tone(90.0, 0.22, "boom")
				_shake(3.5, 0.28)
		"ring":
			VFX.play($Effects, FX_RING, 6, 14.0, pos, Vector2(1.5, 1.5), false, 2)
			if idx == 0:
				GameState.play_tone(380.0, 0.2, "bell")
				_shake(1.5, 0.15)
	_aplicar_dano(c)

func _aplicar_dano(c: Vector2i) -> void:
	await get_tree().create_timer(0.07).timeout
	if not is_inside_tree() or combate_encerrado:
		return
	var p = occupied_cells.get(c)
	if p and p.invulnerable_time <= 0.0:
		_herir_jogador(p)

func _herir_jogador(p: Node) -> void:
	print("Player tomou dano em: ", p.current_cell)
	p.play_hurt_anim()
	vida_players = max(0, vida_players - 1)
	VFX.play($Effects, FX_HIT, 5, 18.0, p.global_position + Vector2(0, -4), Vector2(1.5, 1.5), false, 5)
	_shake(3.0, 0.2)
	_atualizar_hud_combate()
	if vida_players <= 0:
		_derrota_combate()

func _shake(amount: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): $Camera2D.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount * v, 1.0, 0.0, dur)

# =====================================================================
#  SINFONIA
# =====================================================================
func gerar_sequencia_ritmo() -> void:
	sequencia_atual.clear()
	progresso_ritmo = 0

	var tipo_ritmo = randi() % nomes_ritmos.size()
	nome_ritmo_atual = nomes_ritmos[tipo_ritmo]
	var tamanho = 4
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

	if not has_node("RhythmDisplay"):
		return

	var total = sequencia_atual.size()
	var espaco = 22.0
	var inicio_x = -((total - 1) * espaco) * 0.5

	for i in range(total):
		var spr = Sprite2D.new()
		spr.texture = arrow_texture
		spr.hframes = 8
		var dir_idx = _indice_direcao(sequencia_atual[i])
		spr.frame = dir_idx + (4 if i < progresso_ritmo else 0)
		spr.position = Vector2(inicio_x + i * espaco, 0)
		$RhythmDisplay.add_child(spr)
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

func symphony() -> void:
	if combate_encerrado:
		return

	symphony_id += 1
	var meu_id = symphony_id

	var celula_alvo: Vector2i = todas_as_casas.pick_random()
	var plataforma_alvo: Node2D = plataformas.get(celula_alvo)

	symphony_ativa = true
	celula_symphony = celula_alvo
	gerar_sequencia_ritmo()

	if plataforma_alvo and plataforma_alvo.has_method("set_estado"):
		plataforma_alvo.set_estado("symphony")

	if has_node("RhythmDisplay"):
		$RhythmDisplay.visible = true

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
	if has_node("RhythmDisplay"):
		$RhythmDisplay.visible = false
	if has_node("HUD/SymphonyPrompt") and not combate_encerrado:
		$HUD/SymphonyPrompt.text = "Desvie dos alertas! A proxima Plataforma de Sinfonia ja vem..."

func _atualizar_status_symphony() -> void:
	if not has_node("HUD/SymphonyPrompt") or not symphony_ativa:
		return

	var p1_na_casa = ($Players/Player1.current_cell == celula_symphony and not $Players/Player1.is_jumping)
	var p2_na_casa = ($Players/Player2.current_cell == celula_symphony and not $Players/Player2.is_jumping)

	if p1_na_casa:
		$HUD/SymphonyPrompt.text = "%s - SQUETCH na plataforma! Use as SETAS (%d/%d)" % [nome_ritmo_atual, progresso_ritmo, sequencia_atual.size()]
		$RhythmDisplay.modulate = Color(1, 1, 1, 1)
	elif p2_na_casa:
		$HUD/SymphonyPrompt.text = "%s - PEIXOTO na plataforma! Use Y/A/X/B ou 8/5/4/6 (%d/%d)" % [nome_ritmo_atual, progresso_ritmo, sequencia_atual.size()]
		$RhythmDisplay.modulate = Color(1, 1, 1, 1)
	else:
		$HUD/SymphonyPrompt.text = "%s - Pise na plataforma da SINFONIA (notas saindo do chao)!" % nome_ritmo_atual
		$RhythmDisplay.modulate = Color(0.65, 0.85, 0.95, 0.75)

func process_symphony_input(player: Node, nota_dir: String) -> void:
	if combate_encerrado or not symphony_ativa:
		return

	# O jogador precisa estar em cima da plataforma de sinfonia (pode sair/voltar para desviar!)
	if player.current_cell != celula_symphony or player.is_jumping:
		return

	if progresso_ritmo < sequencia_atual.size():
		var esperado = sequencia_atual[progresso_ritmo]
		if nota_dir == esperado:
			var ic = icones_setas[progresso_ritmo]
			if is_instance_valid(ic):
				ic.frame = _indice_direcao(nota_dir) + 4
				var tw = create_tween()
				tw.tween_property(ic, "scale", Vector2(1.35, 1.35), 0.06)
				tw.tween_property(ic, "scale", Vector2(1.0, 1.0), 0.06)
			_nota_acertada(player)
			progresso_ritmo += 1

			if progresso_ritmo >= sequencia_atual.size():
				song_atack(player)
		else:
			# Errou a seta: reseta o progresso da sequencia atual para tentar de novo
			progresso_ritmo = 0
			GameState.play_tone(150.0, 0.08, "synth")
			for i in range(icones_setas.size()):
				if is_instance_valid(icones_setas[i]):
					icones_setas[i].frame = _indice_direcao(sequencia_atual[i])

func _nota_acertada(player: Node) -> void:
	var n := Sprite2D.new()
	n.texture = NOTES_TEX
	n.hframes = 6
	n.frame = randi() % 6
	n.position = player.global_position + Vector2(randf_range(-6, 6), -12)
	n.z_index = 5
	$Effects.add_child(n)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "position:y", n.position.y - 22.0, 0.5)
	tw.tween_property(n, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(n.queue_free)

func song_atack(autor: Node = null) -> void:
	print("Symphony ativada por um dos jogadores!")
	var celula_usada = celula_symphony
	_encerrar_symphony_visual(celula_usada)

	if autor and autor.has_method("play_symphony_anim"):
		autor.play_symphony_anim()

	var origem: Vector2 = autor.global_position if autor else Vector2(240, 200)
	VFX.play($Effects, FX_RING, 6, 14.0, _cell_pos(celula_usada), Vector2(1.4, 1.4), false, 2)
	GameState.play_tone(880.0, 0.18, "bell")

	# Rajada de notas musicais ate o inimigo
	var alvo: Vector2 = $Guardian.global_position
	for i in range(6):
		var n := Sprite2D.new()
		n.texture = NOTES_TEX
		n.hframes = 6
		n.frame = i % 6
		n.position = origem
		n.z_index = 6
		n.scale = Vector2(1.5, 1.5)
		$Effects.add_child(n)
		var tw := n.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(n, "position", alvo + Vector2(randf_range(-14, 14), randf_range(-10, 10)), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(n.queue_free)

	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree() or combate_encerrado:
		return
	_golpear_inimigo(alvo)

func _golpear_inimigo(alvo: Vector2) -> void:
	guardian_anim_state = "hurt"
	guardian_state_ttl = 0.7
	VFX.play($Effects, FX_HIT, 5, 16.0, alvo, Vector2(3, 3), false, 5)
	GameState.play_tone(200.0, 0.2, "boom")
	_shake(3.0, 0.25)
	vida_inimigo = max(0, vida_inimigo - 1)
	_atualizar_hud_combate()
	if vida_inimigo <= 0:
		_vencer_combate()

# =====================================================================
#  HUD / FIM DE COMBATE
# =====================================================================
func _atualizar_hud_combate() -> void:
	for i in range(hearts.size()):
		hearts[i].modulate = Color(1, 1, 1, 1) if i < vida_players else Color(0.22, 0.22, 0.3, 1)
	if has_node("HUD/HPEnemy"):
		$HUD/HPEnemy.text = "%s  %d/%d" % [enemy["name"], vida_inimigo, vida_inimigo_max]
	if has_node("HUD/EnemyBarFill"):
		$HUD/EnemyBarFill.size.x = 150.0 * float(vida_inimigo) / float(max(1, vida_inimigo_max))

func _mostrar_banner(texto: String, dur: float) -> void:
	if not has_node("HUD/Banner"):
		return
	var b: Label = $HUD/Banner
	b.text = texto
	b.modulate.a = 1.0
	b.show()
	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_property(b, "modulate:a", 0.0, 0.4)

func _limpar_alertas() -> void:
	for ch in $Telegraphs.get_children():
		ch.queue_free()
	if has_node("RhythmDisplay"):
		$RhythmDisplay.visible = false

func _vencer_combate() -> void:
	combate_encerrado = true
	GameState.battle_result = "win"
	symphony_ativa = false
	_limpar_alertas()
	if has_node("HUD/SymphonyPrompt"):
		$HUD/SymphonyPrompt.text = "VITORIA! %s foi derrotado pela Sinfonia!" % enemy["name"]
	_mostrar_banner("VITORIA!", 2.0)
	$Players/Player1.play_symphony_anim()
	$Players/Player2.play_symphony_anim()
	guardian_anim_state = "hurt"
	guardian_state_ttl = 5.0

	var alvo: Vector2 = $Guardian.global_position
	for i in range(7):
		get_tree().create_timer(i * 0.17).timeout.connect(func():
			VFX.play($Effects, FX_BLAST, 7, 16.0, alvo + Vector2(randf_range(-26, 26), randf_range(-22, 22)), Vector2(1.4, 1.4), false, 6)
			GameState.play_tone(80.0 + randf() * 40.0, 0.16, "boom")
			_shake(3.0, 0.2)
		)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property($Guardian, "modulate:a", 0.0, 0.9)

	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		_fade_para_mundo()

func _derrota_combate() -> void:
	if combate_encerrado:
		return
	combate_encerrado = true
	GameState.battle_result = "lose"
	_limpar_alertas()
	if has_node("HUD/SymphonyPrompt"):
		$HUD/SymphonyPrompt.text = "RECUANDO AO MUNDO SUBAQUATICO..."
	_mostrar_banner("DERROTA...", 2.0)
	await get_tree().create_timer(1.4).timeout
	if is_inside_tree():
		_fade_para_mundo()

func _fade_para_mundo() -> void:
	$fade_transition.show()
	$fade_transition/fade_timer.start()
	$fade_transition/AnimationPlayer.play("fade_in")

func _on_fade_timer_timeout() -> void:
	get_tree().change_scene_to_file("res://Scenes/world.tscn")

func register_player(player: Node, cell: Vector2i) -> void:
	occupied_cells[cell] = player

func on_player_landed(_player: Node, _cell: Vector2i) -> void:
	_atualizar_status_symphony()

func request_move(player: Node, from_cell: Vector2i, to_cell: Vector2i) -> int:
	if combate_encerrado:
		return 0

	if to_cell.x < 0 or to_cell.x > 2 or to_cell.y < 0 or to_cell.y > 2:
		return 0

	var ocupante = occupied_cells.get(to_cell)

	if ocupante != null and ocupante != player:
		if ocupante.is_jumping and ocupante.target_cell == to_cell:
			occupied_cells.erase(to_cell)
			occupied_cells[ocupante.current_cell] = ocupante
			ocupante.cancel_jump()
			return -1
		else:
			return 0

	occupied_cells.erase(from_cell)
	occupied_cells[to_cell] = player
	return 1

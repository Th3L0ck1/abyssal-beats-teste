extends Node2D
class_name ArenaAtmosphere

## Camada visual de atmosfera abissal para a arena de combate:
## desenha feixes de luz subaquaticos, halo ritmico atras do inimigo, moldura luminosa sob o grid 3x3
## e particulas bioluminescentes sincronizadas com a batida de cada criatura.

var aura_color: Color = Color(0.22, 0.92, 1.0, 1.0)
var accent_color: Color = Color(0.68, 0.48, 1.0, 1.0)
var guardian_pos: Vector2 = Vector2(240, 56)

var time_accum: float = 0.0
var beat_energy: float = 0.0
var enraged: bool = false
var motes: Array[Dictionary] = []

func setup(p_aura: Color, p_accent: Color, p_guardian_pos: Vector2 = Vector2(240, 56)) -> void:
	aura_color = p_aura
	accent_color = p_accent
	guardian_pos = p_guardian_pos
	motes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(28):
		motes.append({
			"pos": Vector2(rng.randf_range(16.0, 464.0), rng.randf_range(24.0, 248.0)),
			"vel": Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-18.0, -7.0)),
			"phase": rng.randf_range(0.0, TAU),
			"size": 2.0 if i % 3 != 0 else 3.0,
			"use_accent": (i % 2 == 1)
		})

func pulse_beat(strength: float = 1.0) -> void:
	beat_energy = clampf(strength, 0.0, 1.5)

func set_enraged(p_aura: Color, p_accent: Color) -> void:
	enraged = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "aura_color", p_aura, 0.65)
	tw.tween_property(self, "accent_color", p_accent, 0.65)

func _process(delta: float) -> void:
	var speed_mult := 1.45 if enraged else 1.0
	time_accum += delta * speed_mult
	beat_energy = move_toward(beat_energy, 0.0, delta * 2.8)

	for m in motes:
		var p: Vector2 = m["pos"]
		var v: Vector2 = m["vel"]
		p.x += (v.x + sin(time_accum * 1.8 + float(m["phase"])) * 5.0) * delta * speed_mult
		p.y += v.y * (1.0 + beat_energy * 0.55) * delta * speed_mult
		if p.y < 20.0:
			p.y = 250.0
			p.x = fposmod(p.x + 37.0, 448.0) + 16.0
		if p.x < 10.0:
			p.x = 470.0
		elif p.x > 470.0:
			p.x = 10.0
		m["pos"] = p

	queue_redraw()

func _draw() -> void:
	_draw_light_shafts()
	_draw_guardian_halo()
	_draw_grid_sanctuary_glow()
	_draw_bioluminescent_motes()

func _draw_light_shafts() -> void:
	var bases: Array[float] = [68.0, 148.0, 240.0, 332.0, 412.0]
	for i in range(bases.size()):
		var sway := sin(time_accum * 0.75 + i * 1.15) * 14.0
		var top_x := bases[i] + sway * 0.4
		var bot_x := bases[i] + (i - 2) * 18.0 + sway
		var half_top := 12.0 + (i % 2) * 4.0
		var half_bot := 28.0 + (i % 2) * 8.0
		var col := accent_color if i % 2 == 1 else aura_color
		var alpha := (0.045 + 0.025 * sin(time_accum * 1.3 + i)) + beat_energy * 0.035
		var pts := PackedVector2Array([
			Vector2(top_x - half_top, 22.0),
			Vector2(top_x + half_top, 22.0),
			Vector2(bot_x + half_bot, 248.0),
			Vector2(bot_x - half_bot, 248.0)
		])
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, alpha))

func _draw_guardian_halo() -> void:
	var breath := sin(time_accum * 2.4) * 3.0
	var base_r := 32.0 + breath + beat_energy * 9.0

	# Camadas suaves de brilho radial atras do inimigo
	draw_circle(guardian_pos, base_r * 1.45, Color(aura_color.r, aura_color.g, aura_color.b, 0.06 + beat_energy * 0.04))
	draw_circle(guardian_pos, base_r * 1.05, Color(aura_color.r, aura_color.g, aura_color.b, 0.11 + beat_energy * 0.06))
	draw_circle(guardian_pos, base_r * 0.68, Color(accent_color.r, accent_color.g, accent_color.b, 0.14 + beat_energy * 0.08))

	# Aneis harmonicos pulsantes
	var ring_r1 := 28.0 + fposmod(time_accum * 18.0, 26.0)
	var ring_a1 := clampf(1.0 - (ring_r1 - 28.0) / 26.0, 0.0, 1.0) * (0.28 + beat_energy * 0.18)
	draw_arc(guardian_pos, ring_r1, 0.0, TAU, 36, Color(aura_color.r, aura_color.g, aura_color.b, ring_a1), 1.5)

	var ring_r2 := 24.0 + beat_energy * 7.0
	draw_arc(guardian_pos, ring_r2, 0.0, TAU, 32, Color(accent_color.r, accent_color.g, accent_color.b, 0.24 + beat_energy * 0.16), 1.0)

	# Orbitais bioluminescentes ao redor do guardiao
	var qtd_orb := 6 if enraged else 4
	for i in range(qtd_orb):
		var ang := time_accum * (1.6 if enraged else 1.0) + float(i) * TAU / float(qtd_orb)
		var orb_pos := guardian_pos + Vector2(cos(ang) * (base_r * 1.12), sin(ang) * (base_r * 0.58))
		var orb_col := accent_color if i % 2 == 0 else aura_color
		draw_rect(Rect2(orb_pos - Vector2(2, 2), Vector2(4, 4)), Color(orb_col.r, orb_col.g, orb_col.b, 0.28 + beat_energy * 0.2), true)
		draw_rect(Rect2(orb_pos - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 1.0, 1.0, 0.78), true)

func _draw_grid_sanctuary_glow() -> void:
	var grid_rect := Rect2(Vector2(174.0, 134.0), Vector2(132.0, 114.0))
	var glow_a := 0.04 + beat_energy * 0.045
	draw_rect(grid_rect, Color(aura_color.r, aura_color.g, aura_color.b, glow_a), true)
	draw_rect(grid_rect, Color(aura_color.r, aura_color.g, aura_color.b, 0.18 + beat_energy * 0.16), false, 1.0)

func _draw_bioluminescent_motes() -> void:
	for m in motes:
		var p: Vector2 = m["pos"]
		var sz: float = m["size"]
		var col: Color = accent_color if bool(m["use_accent"]) else aura_color
		var twinkle := 0.45 + 0.40 * sin(time_accum * 3.2 + float(m["phase"])) + beat_energy * 0.15
		draw_rect(Rect2(p - Vector2(sz, sz), Vector2(sz * 2.0, sz * 2.0)), Color(col.r, col.g, col.b, twinkle * 0.26), true)
		draw_rect(Rect2(p - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)), Color(col.r, col.g, col.b, clampf(twinkle, 0.2, 0.95)), true)

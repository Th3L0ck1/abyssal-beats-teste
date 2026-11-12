extends Node

var master_volume: float = 0.85
var is_fullscreen: bool = false

# --- Progresso do mundo (persiste entre world.tscn <-> defense.tscn) ---
var world_initialized: bool = false
var world_p1_cell: Vector2i = Vector2i(2, 9)
var world_p2_cell: Vector2i = Vector2i(2, 10)
var world_keys: int = 0
var world_cleared: Dictionary = {}   # Vector2i -> true (inimigos derrotados)
var world_opened: Dictionary = {}    # Vector2i -> true (portoes abertos)
var world_taken: Dictionary = {}     # Vector2i -> true (baus coletados)

# --- Estado da batalha atual ---
var current_enemy_id: String = "jellyfish"
var battle_cell: Vector2i = Vector2i(-1, -1)
var battle_trigger_player: int = 1
var battle_return_cell: Vector2i = Vector2i.ZERO
var battle_result: String = ""       # "", "win" ou "lose"
var ml_brain: MLBrain = MLBrain.new()

# --- Estatisticas comparativas dos jogadores e do Grid 3x3 ---
var p1_jumps: int = 0
var p2_jumps: int = 0
var p1_hits_taken: int = 0
var p2_hits_taken: int = 0
var p1_notes_hit: int = 0
var p2_notes_hit: int = 0
var grid_visits: Dictionary = {}      # Vector2i(x, y) -> int (pisadas no grid 3x3)
var grid_hits_taken: Dictionary = {}  # Vector2i(x, y) -> int (hits sofridos em cada casa 3x3)

const SETTINGS_PATH: String = "user://settings.cfg"
const BUBBLE_TEX: Texture2D = preload("res://Sprites/VFX/Bubble.png")
const SYNTH_CHANNELS: int = 4
const MIX_RATE: float = 22050.0

var _players: Array[AudioStreamPlayer] = []
var _next_channel: int = 0
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _fade_tween: Tween
var is_transitioning: bool = false

func _ready() -> void:
	_setup_fade_layer()
	_setup_synth()
	load_settings()
	# Atalho de depuracao: godot --path . res://Scenes/defense.tscn -- --enemy=boss
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enemy="):
			current_enemy_id = arg.trim_prefix("--enemy=")

func _exit_tree() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	_players.clear()

func _setup_fade_layer() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

func fade_out(duration: float = 0.65) -> void:
	is_transitioning = false
	if not _fade_rect:
		return
	if _fade_tween:
		_fade_tween.kill()
	_fade_rect.color.a = 1.0
	_fade_rect.visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", 0.0, duration)
	_fade_tween.tween_callback(func(): _fade_rect.visible = false)

func fade_to_scene(scene_path: String, duration: float = 0.65) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	if _fade_tween:
		_fade_tween.kill()
	_fade_rect.color.a = 0.0
	_fade_rect.visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", 1.0, duration)
	_fade_tween.tween_callback(func():
		is_transitioning = false
		get_tree().change_scene_to_file(scene_path)
	)

func spawn_ambient_bubbles(parent: Node, area_size: Vector2 = Vector2(480, 270), center_pos: Vector2 = Vector2(240, 275), amount: int = 16) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "AmbientBubbles"
	p.texture = BUBBLE_TEX
	p.amount = amount
	p.lifetime = 5.5
	p.preprocess = 3.0
	p.position = center_pos
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(area_size.x * 0.5, 10.0)
	p.direction = Vector2(0, -1)
	p.spread = 14.0
	p.gravity = Vector2(0, -12)
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 36.0
	p.scale_amount_min = 0.45
	p.scale_amount_max = 0.95
	p.color = Color(0.75, 0.95, 1.0, 0.38)
	parent.add_child(p)
	return p

func _setup_synth() -> void:
	for i in range(SYNTH_CHANNELS):
		var player := AudioStreamPlayer.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = MIX_RATE
		gen.buffer_length = 0.25
		player.stream = gen
		add_child(player)
		_players.append(player)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		master_volume = float(cfg.get_value("audio", "master_volume", 0.85))
		is_fullscreen = bool(cfg.get_value("video", "is_fullscreen", false))
	apply_volume(master_volume, false)
	if DisplayServer.get_name() != "headless":
		apply_fullscreen(is_fullscreen, false)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "is_fullscreen", is_fullscreen)
	cfg.save(SETTINGS_PATH)

func apply_volume(value: float, persist: bool = true) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index("Master")
	if master_volume <= 0.01:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))
	if persist:
		save_settings()

func apply_fullscreen(enabled: bool, persist: bool = true) -> void:
	is_fullscreen = enabled
	if DisplayServer.get_name() != "headless":
		if is_fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	if persist:
		save_settings()

func reset_world_progress() -> void:
	world_initialized = false
	world_keys = 0
	world_cleared.clear()
	world_opened.clear()
	world_taken.clear()
	battle_cell = Vector2i(-1, -1)
	battle_result = ""
	current_enemy_id = "jellyfish"
	p1_jumps = 0
	p2_jumps = 0
	p1_hits_taken = 0
	p2_hits_taken = 0
	p1_notes_hit = 0
	p2_notes_hit = 0
	grid_visits.clear()
	grid_hits_taken.clear()

func record_jump(is_peixoto: bool, in_combat: bool, cell: Vector2i) -> void:
	if is_peixoto:
		p2_jumps += 1
	else:
		p1_jumps += 1
	if in_combat and cell.x >= 0 and cell.x <= 2 and cell.y >= 0 and cell.y <= 2:
		grid_visits[cell] = int(grid_visits.get(cell, 0)) + 1

func record_hit_taken(is_peixoto: bool, cell: Vector2i) -> void:
	if is_peixoto:
		p2_hits_taken += 1
	else:
		p1_hits_taken += 1
	if cell.x >= 0 and cell.x <= 2 and cell.y >= 0 and cell.y <= 2:
		grid_hits_taken[cell] = int(grid_hits_taken.get(cell, 0)) + 1

func record_note_hit(is_peixoto: bool) -> void:
	if is_peixoto:
		p2_notes_hit += 1
	else:
		p1_notes_hit += 1

func play_tone(freq: float, duration: float = 0.09, style: String = "synth") -> void:
	if _players.is_empty() or DisplayServer.get_name() == "headless":
		return
	var player: AudioStreamPlayer = _players[_next_channel]
	_next_channel = (_next_channel + 1) % _players.size()
	if not player.playing:
		player.play()
	var pb := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if not pb:
		return
	var frames := mini(int(MIX_RATE * duration), pb.get_frames_available())
	for i in range(frames):
		var t := float(i) / MIX_RATE
		var env := 1.0 - (float(i) / float(maxi(1, frames)))
		var sample := 0.0
		match style:
			"guitar":
				# Timbre de violao de coral (harmonicos quentes + decaimento)
				sample = (sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 2.0 * t) * 0.3 + sin(TAU * freq * 3.0 * t) * 0.1) * env * env
			"keyboard":
				# Timbre de teclado sintetizador do Squetch
				var s := sin(TAU * freq * t)
				sample = (0.7 * signf(s) + 0.3 * s) * env * 0.5
			"noise":
				# Impacto/agua: ruido filtrado grosseiramente
				sample = (randf() * 2.0 - 1.0) * env * env * 0.9
			"zap":
				# Choque eletrico: serra descendente
				var f := freq * (1.0 + env * 1.5)
				sample = (fmod(t * f, 1.0) * 2.0 - 1.0) * env * 0.6
			"boom":
				# Explosao: seno grave caindo + ruido
				var fb := freq * (0.5 + env * 0.8)
				sample = (sin(TAU * fb * t) * 0.7 + (randf() * 2.0 - 1.0) * 0.4) * env
			"bell":
				# Sino metalico (parciais inarmonicos)
				sample = (sin(TAU * freq * t) * 0.5 + sin(TAU * freq * 2.76 * t) * 0.3 + sin(TAU * freq * 5.4 * t) * 0.2) * env * env
			"beat":
				# Pulso ritmico subaquatico suave
				var f_beat := freq * (0.75 + env * 0.35)
				sample = sin(TAU * f_beat * t) * env * env * 0.32
			_:
				sample = sin(TAU * freq * t) * env * 0.5
		sample *= 0.25
		pb.push_frame(Vector2(sample, sample))

const FREQS_KEYBOARD: Dictionary = {
	"up": 523.25,    # C5
	"right": 659.25, # E5
	"down": 783.99,  # G5
	"left": 880.00   # A5
}
const FREQS_GUITAR: Dictionary = {
	"up": 261.63,    # C4
	"right": 329.63, # E4
	"down": 392.00,  # G4
	"left": 440.00   # A4
}

func play_note_sfx(is_peixoto: bool, dir_name: String) -> void:
	if is_peixoto:
		play_tone(FREQS_GUITAR.get(dir_name, 329.63), 0.12, "guitar")
	else:
		play_tone(FREQS_KEYBOARD.get(dir_name, 523.25), 0.10, "keyboard")

func play_ui_sfx(kind: String = "click") -> void:
	match kind:
		"hover":
			play_tone(440.0, 0.04, "synth")
		"back":
			play_tone(329.63, 0.08, "guitar")
		_:
			play_tone(523.25, 0.07, "keyboard")

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

var _audio_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	apply_volume(master_volume)
	_setup_synth()
	# Atalho de depuracao: godot --path . res://Scenes/defense.tscn -- --enemy=boss
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enemy="):
			current_enemy_id = arg.trim_prefix("--enemy=")

func _setup_synth() -> void:
	_audio_player = AudioStreamPlayer.new()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	_audio_player.stream = gen
	add_child(_audio_player)
	_audio_player.play()
	_playback = _audio_player.get_stream_playback()

func apply_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index("Master")
	if master_volume <= 0.01:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))

func apply_fullscreen(enabled: bool) -> void:
	is_fullscreen = enabled
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func reset_world_progress() -> void:
	world_initialized = false
	world_keys = 0
	world_cleared.clear()
	world_opened.clear()
	world_taken.clear()
	battle_cell = Vector2i(-1, -1)
	battle_result = ""
	current_enemy_id = "jellyfish"

func play_tone(freq: float, duration: float = 0.09, style: String = "synth") -> void:
	if not _playback:
		return
	var frames = int(22050.0 * duration)
	var avail = _playback.get_frames_available()
	frames = min(frames, avail)
	for i in range(frames):
		var t = float(i) / 22050.0
		var env = 1.0 - (float(i) / float(max(1, frames)))
		var sample = 0.0
		match style:
			"guitar":
				# Timbre de violao de coral (harmonicos quentes + decaimento)
				sample = (sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 2.0 * t) * 0.3 + sin(TAU * freq * 3.0 * t) * 0.1) * env * env
			"keyboard":
				# Timbre de teclado sintetizador do Squetch
				var s = sin(TAU * freq * t)
				sample = (0.7 * sign(s) + 0.3 * s) * env * 0.5
			"noise":
				# Impacto/agua: ruido filtrado grosseiramente
				sample = (randf() * 2.0 - 1.0) * env * env * 0.9
			"zap":
				# Choque eletrico: serra descendente
				var f = freq * (1.0 + env * 1.5)
				sample = (fmod(t * f, 1.0) * 2.0 - 1.0) * env * 0.6
			"boom":
				# Explosao: seno grave caindo + ruido
				var fb = freq * (0.5 + env * 0.8)
				sample = (sin(TAU * fb * t) * 0.7 + (randf() * 2.0 - 1.0) * 0.4) * env
			"bell":
				# Sino metalico (parciais inarmonicos)
				sample = (sin(TAU * freq * t) * 0.5 + sin(TAU * freq * 2.76 * t) * 0.3 + sin(TAU * freq * 5.4 * t) * 0.2) * env * env
			_:
				sample = sin(TAU * freq * t) * env * 0.5
		sample *= 0.25
		_playback.push_frame(Vector2(sample, sample))

func play_note_sfx(is_peixoto: bool, dir_name: String) -> void:
	var freqs_keyboard = {
		"up": 523.25,    # C5
		"right": 659.25, # E5
		"down": 783.99,  # G5
		"left": 880.00   # A5
	}
	var freqs_guitar = {
		"up": 261.63,    # C4
		"right": 329.63, # E4
		"down": 392.00,  # G4
		"left": 440.00   # A4
	}
	if is_peixoto:
		play_tone(freqs_guitar.get(dir_name, 329.63), 0.12, "guitar")
	else:
		play_tone(freqs_keyboard.get(dir_name, 523.25), 0.10, "keyboard")

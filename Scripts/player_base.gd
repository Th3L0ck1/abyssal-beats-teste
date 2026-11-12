extends Node2D
class_name PlayerBase

## Base compartilhada pelos dois jogadores (Squetch = p1, Peixoto = p2).
## Movimentacao por pulos parabolicos de bloco em bloco tanto no mundo quanto na batalha.

const SHADOW_TEX: Texture2D = preload("res://Sprites/Players/Shadow.png")

@export var grid: Node2D
@export var player_prefix: String = "p1"
@export var is_peixoto: bool = false
@export var current_cell: Vector2i = Vector2i(0, 1)
@export var hold_repeat: bool = false
@export var hop_time: float = 0.22
@export var hop_height: float = 13.0
@export var sprite_rest_y: float = 0.0

var target_cell: Vector2i = Vector2i.ZERO
var previous_cell: Vector2i = Vector2i.ZERO
var is_jumping: bool = false
var hop_cooldown: float = 0.0
var tween: Tween
var shadow: Sprite2D

var anim_state: String = "idle"
var timer_anim: float = 0.0
var anim_step: int = 0
var timer_estado_especial: float = 0.0

var invulnerable_time: float = 0.0
var prev_dir: Vector2i = Vector2i.ZERO
var buffered_dir: Vector2i = Vector2i.ZERO
var buffer_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	target_cell = current_cell
	previous_cell = current_cell
	global_position = get_world_position(current_cell)
	_criar_sombra()
	if sprite:
		sprite.position.y = sprite_rest_y
	if grid and grid.has_method("register_player"):
		grid.register_player(self, current_cell)

func _criar_sombra() -> void:
	shadow = Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = SHADOW_TEX
	shadow.position = Vector2(0, 6)
	add_child(shadow)
	move_child(shadow, 0)

func place_at(cell: Vector2i) -> void:
	if tween:
		tween.kill()
	is_jumping = false
	hop_cooldown = 0.0
	current_cell = cell
	target_cell = cell
	previous_cell = cell
	global_position = get_world_position(cell)
	if sprite:
		sprite.position.y = sprite_rest_y
		sprite.scale = Vector2.ONE
	if shadow:
		shadow.scale = Vector2.ONE
		shadow.modulate.a = 0.95

func _process(delta: float) -> void:
	if invulnerable_time > 0.0:
		invulnerable_time -= delta
		if sprite:
			sprite.modulate.a = 0.4 if int(invulnerable_time * 14.0) % 2 == 0 else 1.0
	elif sprite and sprite.modulate.a != 1.0:
		sprite.modulate.a = 1.0

	if timer_estado_especial > 0.0:
		timer_estado_especial -= delta
		if timer_estado_especial <= 0.0 and not is_jumping:
			anim_state = "idle"

	if not is_jumping:
		timer_anim += delta
		var intervalo := 0.18 if anim_state == "idle" else 0.10
		if timer_anim >= intervalo:
			timer_anim = 0.0
			anim_step = (anim_step + 1) % 4
			_atualizar_sprite()

	hop_cooldown = maxf(0.0, hop_cooldown - delta)
	buffer_timer -= delta
	_poll_movement()

func _atualizar_sprite() -> void:
	if not sprite or sprite.hframes < 14:
		return
	match anim_state:
		"idle":
			sprite.frame = anim_step % 4
		"jump":
			sprite.frame = 4 + (anim_step % 4)
		"symphony":
			sprite.frame = 8 + (anim_step % 4)
		"hurt":
			sprite.frame = 12 + (anim_step % 2)

# ---------------------------------------------------------------- Movimento em Pulos de Bloco em Bloco
func _poll_direction() -> Vector2i:
	var v := Input.get_vector(player_prefix + "_left", player_prefix + "_right", player_prefix + "_up", player_prefix + "_down")
	if v.length() < 0.5:
		return Vector2i.ZERO
	if absf(v.x) > absf(v.y):
		return Vector2i(1 if v.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if v.y > 0.0 else -1)

func _poll_movement() -> void:
	var dir := _poll_direction()
	var new_press := dir != Vector2i.ZERO and dir != prev_dir
	prev_dir = dir

	if is_jumping:
		if new_press:
			buffered_dir = dir
			buffer_timer = 0.16
		return

	if buffer_timer > 0.0 and buffered_dir != Vector2i.ZERO:
		var bd := buffered_dir
		buffered_dir = Vector2i.ZERO
		buffer_timer = 0.0
		hop_cooldown = 0.0
		try_move(bd, true)
		return

	if dir != Vector2i.ZERO:
		if new_press:
			hop_cooldown = 0.0
			try_move(dir, true)
		elif hold_repeat and hop_cooldown <= 0.0:
			try_move(dir, false)

func try_move(dir_i: Vector2i, is_new_press: bool = true) -> void:
	if not grid or is_jumping:
		return

	if sprite:
		if dir_i.x < 0:
			sprite.flip_h = true
		elif dir_i.x > 0:
			sprite.flip_h = false

	target_cell = current_cell + dir_i
	var status: int = grid.request_move(self, current_cell, target_cell)

	if status == 1:
		previous_cell = current_cell
		is_jumping = true
		if anim_state != "hurt":
			anim_state = "jump"
		GameState.play_tone(290.0 if is_peixoto else 340.0, 0.05, "guitar" if is_peixoto else "synth")
		_executar_pulo_bloco(get_world_position(current_cell), get_world_position(target_cell), hop_height, hop_time)
	elif is_new_press or status == -1:
		trigger_bounce(false)
	else:
		target_cell = current_cell

func _aplicar_passo_pulo(u: float, pos_origem: Vector2, pos_destino: Vector2, altura: float) -> void:
	# Trajetoria horizontal suave de bloco em bloco + arco parabolico vertical 4*u*(1-u)
	var u_suave := smoothstep(0.0, 1.0, u)
	global_position = pos_origem.lerp(pos_destino, u_suave)
	var parabola := 4.0 * u * (1.0 - u)
	if sprite:
		sprite.position.y = sprite_rest_y - altura * parabola
		sprite.scale = Vector2.ONE.lerp(Vector2(0.84, 1.20), parabola)
		if anim_state == "jump" and sprite.hframes >= 14:
			sprite.frame = 4 + clampi(int(u * 4.0), 0, 3)
	if shadow:
		shadow.scale = Vector2.ONE.lerp(Vector2(0.50, 0.50), parabola)
		shadow.modulate.a = lerpf(0.95, 0.42, parabola)

func _executar_pulo_bloco(pos_origem: Vector2, pos_destino: Vector2, altura: float, duracao: float) -> void:
	tween_reset()
	tween.tween_method(func(u: float): _aplicar_passo_pulo(u, pos_origem, pos_destino, altura), 0.0, 1.0, duracao)
	tween.tween_callback(_on_hop_finished)

func _on_hop_finished() -> void:
	current_cell = target_cell
	is_jumping = false
	# Pausa ritmica mais calma entre pulos continuos para nao gerar poluicao visual
	hop_cooldown = 0.095 if hold_repeat else 0.0
	GameState.record_jump(is_peixoto, not hold_repeat, current_cell)
	if shadow:
		shadow.scale = Vector2.ONE
		shadow.modulate.a = 0.95
	if sprite:
		sprite.position.y = sprite_rest_y
		sprite.scale = Vector2(1.22, 0.78)
		var squash_tw := create_tween()
		squash_tw.tween_property(sprite, "scale", Vector2.ONE, 0.065).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if timer_estado_especial <= 0.0 or anim_state != "hurt":
		anim_state = "idle"
		anim_step = 0
		_atualizar_sprite()
	if grid:
		if grid.has_method("step_platform"):
			grid.step_platform(current_cell)
		if grid.has_method("on_player_landed"):
			grid.on_player_landed(self, current_cell)

func trigger_bounce(from_mid_air: bool = false) -> void:
	var cell_alvo := target_cell
	target_cell = current_cell
	is_jumping = true
	if anim_state != "hurt":
		anim_state = "jump"
	GameState.play_tone(160.0 if is_peixoto else 180.0, 0.07, "guitar" if is_peixoto else "synth")
	tween_reset()

	var pos_origem := get_world_position(current_cell)
	var pos_atual := global_position
	var pos_impacto := pos_origem if from_mid_air else pos_origem.lerp(get_world_position(cell_alvo), 0.55)
	var dur := 0.12 if from_mid_air else 0.17
	var alt := 6.0 if from_mid_air else 9.0

	tween.tween_method(func(u: float):
		var pos_x := pos_atual.lerp(pos_origem, u) if from_mid_air else (pos_origem.lerp(pos_impacto, u * 2.0) if u < 0.5 else pos_impacto.lerp(pos_origem, (u - 0.5) * 2.0))
		global_position = pos_x
		var parabola := 4.0 * u * (1.0 - u)
		if sprite:
			sprite.position.y = sprite_rest_y - alt * parabola
			sprite.scale = Vector2.ONE.lerp(Vector2(0.86, 1.15), parabola)
			if anim_state == "jump" and sprite.hframes >= 14:
				sprite.frame = 4 + clampi(int(u * 4.0), 0, 3)
		if shadow:
			shadow.scale = Vector2.ONE.lerp(Vector2(0.58, 0.58), parabola)
	, 0.0, 1.0, dur)

	tween.tween_callback(func():
		is_jumping = false
		hop_cooldown = 0.065 if hold_repeat else 0.0
		if sprite:
			sprite.position.y = sprite_rest_y
			sprite.scale = Vector2.ONE
		if shadow:
			shadow.scale = Vector2.ONE
			shadow.modulate.a = 0.95
		if timer_estado_especial <= 0.0 or anim_state != "hurt":
			anim_state = "idle"
			_atualizar_sprite()
		if grid and grid.has_method("step_platform"):
			grid.step_platform(current_cell)
	)

func cancel_jump() -> void:
	trigger_bounce(true)

# ---------------------------------------------------------------- Sinfonia
func _unhandled_input(event: InputEvent) -> void:
	if not grid or not grid.has_method("process_symphony_input"):
		return
	if grid.get("combate_encerrado"):
		return
	check_symphony_input(event)

func check_symphony_input(event: InputEvent) -> void:
	var nota_dir := ""
	if event.is_action_pressed(player_prefix + "_note_up", false):
		nota_dir = "up"
	elif event.is_action_pressed(player_prefix + "_note_down", false):
		nota_dir = "down"
	elif event.is_action_pressed(player_prefix + "_note_left", false):
		nota_dir = "left"
	elif event.is_action_pressed(player_prefix + "_note_right", false):
		nota_dir = "right"

	if nota_dir != "":
		if anim_state != "hurt":
			play_symphony_anim()
		GameState.play_note_sfx(is_peixoto, nota_dir)
		grid.process_symphony_input(self, nota_dir)

func play_symphony_anim() -> void:
	anim_state = "symphony"
	timer_estado_especial = 0.45
	anim_step = (anim_step + 1) % 4
	_atualizar_sprite()

func play_hurt_anim() -> void:
	anim_state = "hurt"
	timer_estado_especial = 0.50
	invulnerable_time = 1.1
	anim_step = 0
	_atualizar_sprite()
	if sprite:
		sprite.self_modulate = Color(2.6, 1.4, 1.4, 1.0)
		var tw := create_tween()
		tw.tween_property(sprite, "self_modulate", Color.WHITE, 0.16)
	GameState.play_tone(110.0 if is_peixoto else 120.0, 0.18, "noise")

func get_world_position(cell: Vector2i) -> Vector2:
	if grid and grid.has_method("get_cell_world_pos"):
		return grid.get_cell_world_pos(cell)
	return Vector2(cell) * 40.0

func tween_reset() -> void:
	if tween:
		tween.kill()
	tween = create_tween()

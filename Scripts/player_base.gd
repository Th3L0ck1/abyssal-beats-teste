extends CharacterBody2D
class_name PlayerBase

## Base compartilhada pelos dois jogadores (player_1.gd e player_2.gd so definem o prefixo dos inputs).
## Usada tanto no mundo (hold_repeat = true, anda livremente) quanto na batalha (um pulo por toque).

@export var grid: Node2D
@export var current_cell: Vector2i = Vector2i(0, 1)
@export var grid_offset: Vector2 = Vector2(200, 150)
@export var cell_pixel_size: int = 40
@export var hold_repeat: bool = false
@export var hop_time: float = 0.16
@export var hop_height: float = 10.0
@export var sprite_rest_y: float = 0.0

var player_prefix: String = "p1"
var is_peixoto: bool = false

var target_cell: Vector2i = Vector2i.ZERO
var previous_cell: Vector2i = Vector2i.ZERO
var is_jumping: bool = false
var tween: Tween
var arc_tween: Tween

var anim_state: String = "idle"
var timer_anim: float = 0.0
var anim_step: int = 0
var timer_estado_especial: float = 0.0

var invulnerable_time: float = 0.0
var prev_dir: Vector2i = Vector2i.ZERO
var buffered_dir: Vector2i = Vector2i.ZERO
var buffer_timer: float = 0.0

func _ready() -> void:
	target_cell = current_cell
	previous_cell = current_cell
	global_position = get_world_position(current_cell)
	_criar_sombra()
	if has_node("Sprite2D"):
		$Sprite2D.position.y = sprite_rest_y
	if grid and grid.has_method("register_player"):
		grid.register_player(self, current_cell)

func _criar_sombra() -> void:
	var sh := Sprite2D.new()
	sh.name = "Shadow"
	sh.texture = load("res://Sprites/Players/Shadow.png")
	sh.position = Vector2(0, 6)
	add_child(sh)
	move_child(sh, 0)

func place_at(cell: Vector2i) -> void:
	if tween:
		tween.kill()
	if arc_tween:
		arc_tween.kill()
	is_jumping = false
	current_cell = cell
	target_cell = cell
	previous_cell = cell
	global_position = get_world_position(cell)
	if has_node("Sprite2D"):
		$Sprite2D.position.y = sprite_rest_y

func _process(delta: float) -> void:
	if invulnerable_time > 0.0:
		invulnerable_time -= delta
		if has_node("Sprite2D"):
			$Sprite2D.modulate.a = 0.4 if int(invulnerable_time * 14.0) % 2 == 0 else 1.0
	elif has_node("Sprite2D") and $Sprite2D.modulate.a != 1.0:
		$Sprite2D.modulate.a = 1.0

	if timer_estado_especial > 0.0:
		timer_estado_especial -= delta
		if timer_estado_especial <= 0.0 and not is_jumping:
			anim_state = "idle"

	timer_anim += delta
	var intervalo = 0.18 if anim_state == "idle" else 0.10
	if timer_anim >= intervalo:
		timer_anim = 0.0
		anim_step = (anim_step + 1) % 4
		_atualizar_sprite()

	buffer_timer -= delta
	_poll_movement()

func _atualizar_sprite() -> void:
	if not has_node("Sprite2D"):
		return
	var spr: Sprite2D = $Sprite2D
	if spr.hframes < 14:
		return
	match anim_state:
		"idle":
			spr.frame = anim_step % 4
		"jump":
			spr.frame = 4 + (anim_step % 4)
		"symphony":
			spr.frame = 8 + (anim_step % 4)
		"hurt":
			spr.frame = 12 + (anim_step % 2)

# ---------------------------------------------------------------- Movimento
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
			buffer_timer = 0.15
		return

	if buffer_timer > 0.0 and buffered_dir != Vector2i.ZERO:
		var bd := buffered_dir
		buffered_dir = Vector2i.ZERO
		buffer_timer = 0.0
		try_move(bd, true)
		return

	if dir != Vector2i.ZERO and (new_press or hold_repeat):
		try_move(dir, new_press)

func try_move(dir_i: Vector2i, is_new_press: bool = true) -> void:
	if not grid or is_jumping:
		return

	if has_node("Sprite2D"):
		if dir_i.x < 0:
			$Sprite2D.flip_h = true
		elif dir_i.x > 0:
			$Sprite2D.flip_h = false

	target_cell = current_cell + dir_i
	var status: int = grid.request_move(self, current_cell, target_cell)

	if status == 1:
		previous_cell = current_cell
		is_jumping = true
		anim_state = "jump"
		anim_step = 0
		_atualizar_sprite()
		GameState.play_tone(290.0 if is_peixoto else 340.0, 0.05, "guitar" if is_peixoto else "synth")

		tween_reset()
		tween.tween_property(self, "global_position", get_world_position(target_cell), hop_time)
		_animar_arco_25d(hop_height, hop_time)
		tween.tween_callback(_on_hop_finished)
	elif is_new_press:
		trigger_bounce()
	else:
		target_cell = current_cell

func _on_hop_finished() -> void:
	current_cell = target_cell
	is_jumping = false
	anim_state = "idle"
	if grid and grid.has_method("on_player_landed"):
		grid.on_player_landed(self, current_cell)

func _animar_arco_25d(altura: float, duracao: float) -> void:
	if not has_node("Sprite2D"):
		return
	if arc_tween:
		arc_tween.kill()
	var spr: Sprite2D = $Sprite2D
	arc_tween = create_tween()
	arc_tween.tween_property(spr, "position:y", sprite_rest_y - altura, duracao * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc_tween.tween_property(spr, "position:y", sprite_rest_y, duracao * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func trigger_bounce() -> void:
	is_jumping = true
	anim_state = "jump"
	GameState.play_tone(160.0 if is_peixoto else 180.0, 0.07, "guitar" if is_peixoto else "synth")
	tween_reset()

	var pos_origem = get_world_position(current_cell)
	var pos_alvo = get_world_position(target_cell)
	var pos_impacto = pos_origem.lerp(pos_alvo, 0.65)

	tween.tween_property(self, "global_position", pos_impacto, 0.09)
	tween.tween_property(self, "global_position", pos_origem, 0.09)
	_animar_arco_25d(6.0, 0.18)

	tween.tween_callback(func():
		target_cell = current_cell
		is_jumping = false
		anim_state = "idle"
	)

func cancel_jump() -> void:
	trigger_bounce()

# ---------------------------------------------------------------- Sinfonia
func _unhandled_input(event: InputEvent) -> void:
	check_symphony_input(event)

func check_symphony_input(event: InputEvent) -> void:
	var nota_dir = ""
	if event.is_action_pressed(player_prefix + "_note_up", false):
		nota_dir = "up"
	elif event.is_action_pressed(player_prefix + "_note_down", false):
		nota_dir = "down"
	elif event.is_action_pressed(player_prefix + "_note_left", false):
		nota_dir = "left"
	elif event.is_action_pressed(player_prefix + "_note_right", false):
		nota_dir = "right"

	if nota_dir != "":
		play_symphony_anim()
		GameState.play_note_sfx(is_peixoto, nota_dir)
		if grid and grid.has_method("process_symphony_input"):
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
	GameState.play_tone(110.0 if is_peixoto else 120.0, 0.18, "noise")

func get_world_position(cell: Vector2i) -> Vector2:
	if grid and grid.has_method("get_cell_world_pos"):
		return grid.get_cell_world_pos(cell)
	var px = cell.x * cell_pixel_size
	var py = cell.y * cell_pixel_size
	return Vector2(px, py) + grid_offset

func tween_reset() -> void:
	if tween:
		tween.kill()
	tween = create_tween()

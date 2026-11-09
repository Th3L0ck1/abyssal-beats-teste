extends Node2D
class_name WorldTile

## Plataforma do mundo (estilo Hoptale): quadrado simples com bolhas + icones por cima
## (inimigo, bau, portao, placa...).

const TILE_TEX: Texture2D = preload("res://Sprites/World/WorldTiles_sheet.png")
const ICON_TEX: Texture2D = preload("res://Sprites/World/WorldIcons_sheet.png")
const BUBBLES_TEX: Texture2D = preload("res://Sprites/VFX/VFX_Bubbles.png")

const ENEMY_KINDS := {"j": 0, "c": 1, "b": 2, "p": 3, "G": 4}   # kind -> frame do icone
const FR_OPEN := 15

var kind: String = "o"
var sprite: Sprite2D
var icon: Sprite2D
var alert: Sprite2D

var open: bool = false
var pressed: bool = false
var chest_taken: bool = false
var timer: float = 0.0
var step: int = 0
var phase: float = 0.0
var base_frame: int = 0
var anim_count: int = 1

func _ready() -> void:
	phase = float((int(position.x) * 7 + int(position.y) * 13) % 100) / 100.0 * TAU

func setup(kind_: String, opened: bool = false, taken: bool = false) -> void:
	kind = kind_
	open = opened
	chest_taken = taken

	sprite = Sprite2D.new()
	sprite.texture = TILE_TEX
	sprite.hframes = 18
	add_child(sprite)

	icon = Sprite2D.new()
	icon.texture = ICON_TEX
	icon.hframes = 10
	icon.position = Vector2(0, -4)
	icon.z_index = 1
	icon.visible = false
	add_child(icon)

	alert = Sprite2D.new()
	alert.texture = ICON_TEX
	alert.hframes = 10
	alert.frame = 5
	alert.position = Vector2(0, -16)
	alert.z_index = 2
	alert.visible = false
	add_child(alert)

	_resolver_visual()

func _resolver_visual() -> void:
	icon.visible = false
	alert.visible = false
	anim_count = 1
	if ENEMY_KINDS.has(kind):
		base_frame = 6 if kind == "G" else 4
		anim_count = 2
		icon.frame = ENEMY_KINDS[kind]
		icon.visible = true
		alert.visible = true
	elif kind == "k":
		base_frame = 0
		anim_count = 4
		icon.frame = 8 if chest_taken else 7
		icon.visible = true
	elif kind == "u":
		base_frame = 8
	elif kind == "v":
		base_frame = 10
	elif kind == "D":
		base_frame = FR_OPEN if open else 12
	elif kind == "K":
		base_frame = FR_OPEN if open else 13
	elif kind == "V":
		base_frame = FR_OPEN if open else 14
	elif kind == "F":
		base_frame = 16
		anim_count = 2
	else:
		base_frame = 0
		anim_count = 4
	_atualizar_frame()

func is_gate() -> bool:
	return kind == "D" or kind == "K" or kind == "V"

func is_closed_gate() -> bool:
	return is_gate() and not open

func _process(delta: float) -> void:
	if not sprite:
		return
	timer += delta
	if timer >= 0.24:
		timer = 0.0
		step = (step + 1) % 4
		_atualizar_frame()
	var t := Time.get_ticks_msec() * 0.001
	if alert.visible:
		alert.position.y = -16.0 + roundf(sin(t * 5.0 + phase) * 2.0)
		icon.position.y = -4.0 + roundf(sin(t * 3.0 + phase))
	elif kind == "k" and not chest_taken:
		icon.position.y = -4.0 + roundf(sin(t * 3.0 + phase) * 0.8)

func _atualizar_frame() -> void:
	if kind == "u" or kind == "v":
		sprite.frame = base_frame + (1 if pressed else 0)
	else:
		sprite.frame = base_frame + (step % anim_count if anim_count > 1 else 0)

func set_pressed(value: bool, silent: bool = false) -> void:
	if pressed == value:
		return
	pressed = value
	_atualizar_frame()
	if pressed and not silent:
		GameState.play_tone(520.0 if kind == "u" else 620.0, 0.08, "bell")

func open_gate() -> void:
	if open:
		return
	open = true
	base_frame = FR_OPEN
	anim_count = 1
	_atualizar_frame()
	VFX.play(self, BUBBLES_TEX, 5, 11.0, Vector2(0, -4), Vector2(1.8, 1.8), false, 3)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.07)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.12)
	GameState.play_tone(330.0, 0.08, "bell")

func clear_enemy() -> void:
	kind = "o"
	_resolver_visual()
	VFX.play(self, BUBBLES_TEX, 5, 11.0, Vector2(0, -6), Vector2(1.8, 1.8), false, 3)

func take_chest() -> void:
	if chest_taken:
		return
	chest_taken = true
	icon.frame = 8
	icon.position.y = -4
	VFX.play(self, BUBBLES_TEX, 5, 11.0, Vector2(0, -8), Vector2(1.5, 1.5), false, 3)
	GameState.play_tone(784.0, 0.12, "bell")

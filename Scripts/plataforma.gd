extends Node2D
class_name PlataformaNode

const NOTES_TEX: Texture2D = preload("res://Sprites/VFX/Notes_sheet.png")

@export var estado_atual: String = "normal"

var timer_anim: float = 0.0
var frame_step: int = 0
var fase_flutuacao: float = 0.0
var note_timer: float = 0.0
var afundamento_pulo: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	fase_flutuacao = float(get_index()) * 0.65
	_atualizar_frame()

func _process(delta: float) -> void:
	timer_anim += delta
	var intervalo := 0.35
	match estado_atual:
		"warning":
			intervalo = 0.15
		"attack":
			intervalo = 0.08
		"symphony":
			intervalo = 0.18

	if timer_anim >= intervalo:
		timer_anim = 0.0
		frame_step = (frame_step + 1) % 4
		_atualizar_frame()

	afundamento_pulo = move_toward(afundamento_pulo, 0.0, delta * 24.0)
	sprite.position.y = sin(Time.get_ticks_msec() * 0.003 + fase_flutuacao) + afundamento_pulo

	# Plataforma de Sinfonia: notas musicais saem do chao
	if estado_atual == "symphony":
		note_timer += delta
		if note_timer >= 0.17:
			note_timer = 0.0
			_spawn_nota()

func _spawn_nota() -> void:
	var n := Sprite2D.new()
	n.texture = NOTES_TEX
	n.hframes = 6
	n.frame = randi() % 6
	n.z_index = 3
	n.position = Vector2(randf_range(-11.0, 11.0), randf_range(-4.0, 5.0))
	n.scale = Vector2(0.4, 0.4)
	n.modulate.a = 0.0
	add_child(n)
	var dur := randf_range(1.1, 1.5)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "position:y", n.position.y - randf_range(28.0, 42.0), dur)
	tw.tween_property(n, "position:x", n.position.x + randf_range(-9.0, 9.0), dur).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "scale", Vector2.ONE, 0.25)
	tw.tween_property(n, "modulate:a", 1.0, 0.12)
	tw.tween_property(n, "modulate:a", 0.0, 0.45).set_delay(dur - 0.45)
	tw.chain().tween_callback(n.queue_free)

func set_estado(novo_estado: String) -> void:
	estado_atual = novo_estado
	timer_anim = 0.0
	frame_step = 0
	note_timer = 0.0
	_atualizar_frame()

func _atualizar_frame() -> void:
	if not sprite:
		return
	match estado_atual:
		"warning":
			sprite.frame = 2 + (frame_step % 4)
		"attack":
			sprite.frame = 6 + (frame_step % 4)
		"symphony":
			sprite.frame = 10 + (frame_step % 4)
		_:
			sprite.frame = frame_step % 2

func on_stepped() -> void:
	afundamento_pulo = 3.2
	if sprite:
		sprite.scale = Vector2(1.10, 0.88)
		var tw := create_tween()
		tw.tween_property(sprite, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

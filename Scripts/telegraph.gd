extends Sprite2D
class_name Telegraph

## Aviso visual (alerta) mostrado sobre a plataforma que sera atacada.
const TEX: Texture2D = preload("res://Sprites/VFX/Telegraph_sheet.png")
const TINTS: Dictionary = {"red": 0, "yellow": 1, "orange": 2}

var tint_index: int = 0
var ttl: float = 1.5
var t: float = 0.0
var step_t: float = 0.0
var step: int = 0

func setup(tint: String, time_to_hit: float) -> void:
	texture = TEX
	hframes = 12
	tint_index = TINTS.get(tint, 0)
	ttl = time_to_hit
	frame = tint_index * 4
	modulate.a = 0.0

func _process(delta: float) -> void:
	t += delta
	step_t += delta
	var interval := 0.14 if t < ttl - 0.6 else 0.06   # pisca mais rapido perto do impacto
	if step_t >= interval:
		step_t = 0.0
		step = (step + 1) % 4
		frame = tint_index * 4 + step
	modulate.a = clampf(t / 0.12, 0.0, 1.0)
	var pop := clampf(t / 0.12, 0.0, 1.0)
	scale = Vector2.ONE * (0.75 + 0.25 * pop)

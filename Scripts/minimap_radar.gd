extends Node2D
class_name MinimapRadar

## Mini-Mapa Abissal compacto no canto superior direito do mundo (50x20 casas em escala 2x2 px).
## Pode ser alternado a qualquer momento com a tecla M / Tab ou pelo Menu de Pausa.

const FONT_PIXEL: FontFile = preload("res://Themes/Stacked pixel.ttf")
const CELL_PX: int = 2
const PAD: int = 3

var world: Node2D
var pulse_t: float = 0.0
var label_hint: Label

func setup(p_world: Node2D) -> void:
	world = p_world
	position = Vector2(368, 28)

	label_hint = Label.new()
	label_hint.position = Vector2(0, 47)
	label_hint.size = Vector2(106, 12)
	label_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_hint.add_theme_font_override("font", FONT_PIXEL)
	label_hint.add_theme_font_size_override("font_size", 8)
	label_hint.add_theme_color_override("font_color", Color(0.55, 0.78, 0.90, 0.78))
	label_hint.text = "[M] Mapa"
	add_child(label_hint)

func _process(delta: float) -> void:
	if not visible:
		return
	pulse_t += delta * 4.5
	queue_redraw()

func _draw() -> void:
	if not world:
		return
	var map_sz: Vector2i = world.get("map_size")
	if map_sz == Vector2i.ZERO:
		return

	var w := float(map_sz.x * CELL_PX + PAD * 2)
	var h := float(map_sz.y * CELL_PX + PAD * 2)

	# Moldura abissal semitransparente
	draw_rect(Rect2(Vector2(-1, -1), Vector2(w + 2, h + 2)), Color(0.31, 0.89, 0.89, 0.68), false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.03, 0.06, 0.13, 0.84), true)

	var kinds: Dictionary = world.get("kinds")
	var plataformas: Dictionary = world.get("plataformas")
	var pulse := 0.72 + 0.28 * sin(pulse_t)

	for cell: Vector2i in kinds:
		var k: String = kinds[cell]
		var tile = plataformas.get(cell)
		var px := Vector2(PAD + cell.x * CELL_PX, PAD + cell.y * CELL_PX)
		var col := Color(0.18, 0.40, 0.56, 0.72)

		if tile and tile.has_method("is_closed_gate") and tile.is_closed_gate():
			col = Color(0.92, 0.54, 0.20, 0.95)
		elif k == "u" or k == "v":
			col = Color(0.28, 0.88, 0.72, 0.90)
		elif k == "k" and not GameState.world_taken.has(cell):
			col = Color(1.0, 0.92, 0.22, pulse)
		elif k == "G":
			col = Color(0.92, 0.32, 1.0, pulse)
		elif k == "F":
			col = Color(0.35, 1.0, 0.65, pulse)
		elif k == "j" or k == "c" or k == "b" or k == "p":
			col = Color(0.98, 0.30, 0.36, pulse)

		draw_rect(Rect2(px, Vector2(CELL_PX, CELL_PX)), col, true)

	# Jogadores (Squetch = Ciano, Peixoto = Coral/Dourado)
	var p1: Node = world.get("p1")
	var p2: Node = world.get("p2")
	if p2:
		var c2: Vector2i = p2.get("current_cell")
		var pos2 := Vector2(PAD + c2.x * CELL_PX - 0.5, PAD + c2.y * CELL_PX - 0.5)
		draw_rect(Rect2(pos2, Vector2(CELL_PX + 1, CELL_PX + 1)), Color(1.0, 0.68, 0.24, 1.0), true)
	if p1:
		var c1: Vector2i = p1.get("current_cell")
		var pos1 := Vector2(PAD + c1.x * CELL_PX - 0.5, PAD + c1.y * CELL_PX - 0.5)
		draw_rect(Rect2(pos1, Vector2(CELL_PX + 1, CELL_PX + 1)), Color(0.35, 1.0, 1.0, 1.0), true)

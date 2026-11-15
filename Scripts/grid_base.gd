extends Node2D
class_name GridBase

## Base compartilhada entre WorldGrid (exploracao) e DefenseGrid (batalha).
## Centraliza o registro de celulas ocupadas, colisao de pulo e o impacto visual ao pisar num bloco.

var occupied_cells: Dictionary = {}
var plataformas: Dictionary = {}

func register_player(player: Node, cell: Vector2i) -> void:
	occupied_cells[cell] = player

func step_platform(cell: Vector2i) -> void:
	var plat: Node2D = plataformas.get(cell)
	if not plat:
		return
	if plat.has_method("on_stepped"):
		plat.on_stepped()
	var ripple := _WaterRipple.new()
	plat.add_child(ripple)

func _resolver_ocupacao_celula(player: Node, from_cell: Vector2i, to_cell: Vector2i) -> int:
	var ocupante = occupied_cells.get(to_cell)
	if ocupante != null and ocupante != player:
		if ocupante.is_jumping and ocupante.target_cell == to_cell:
			occupied_cells.erase(to_cell)
			occupied_cells[ocupante.current_cell] = ocupante
			ocupante.cancel_jump()
			return -1
		return 0

	occupied_cells.erase(from_cell)
	occupied_cells[to_cell] = player
	return 1


class _WaterRipple extends Node2D:
	var progress: float = 0.0

	func _ready() -> void:
		z_index = 1
		var tw := create_tween()
		tw.tween_property(self, "progress", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var rx := lerpf(5.0, 14.0, progress)
		var alpha := (1.0 - progress) * 0.42
		draw_arc(Vector2(0, -1), rx, 0.0, TAU, 20, Color(0.55, 0.95, 1.0, alpha), 1.0)

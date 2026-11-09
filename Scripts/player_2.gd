extends PlayerBase

# Player 2 - Peixoto (peixe-robo com violao de coral): analogico/IJKL para andar, Y A X B (ou Numpad 8 5 4 6) para tocar.
func _init() -> void:
	player_prefix = "p2"
	is_peixoto = true
	current_cell = Vector2i(2, 1)

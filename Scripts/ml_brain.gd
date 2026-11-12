extends RefCounted
class_name MLBrain

## Modulo de Machine Learning do Inimigo:
## 1. Q-Learning Tabular (Aprendizado por Reforco) com politica Epsilon-Greedy para selecao de padroes de ataque.
## 2. Cadeia de Markov de 1a Ordem P(c_{t+1} | c_t) para prever para qual celula o jogador vai fugir.
## 3. Mapa de Calor Espacial (Heatmap 3x3 com decaimento exponencial) das celulas preferidas dos jogadores.

const SAVE_PATH: String = "user://ml_brain.cfg"

# Hiperparametros do Q-Learning
var alpha: float = 0.35          # Taxa de aprendizado (learning rate)
var gamma: float = 0.75          # Fator de desconto de recompensas futuras
var epsilon: float = 0.35        # Taxa de exploracao inicial (decai ate epsilon_min)
var epsilon_min: float = 0.10
var epsilon_decay: float = 0.96

# Estruturas do modelo
var q_table: Dictionary = {}             # estado (String) -> { padrao (String): valor_q (float) }
var markov_counts: Dictionary = {}       # "x,y" origem -> { "x,y" destino: contagem (float) }
var heatmap: Dictionary = {}             # Vector2i -> peso de permanencia (float)
var total_episodios: int = 0

func _init() -> void:
	reset_heatmap()
	load_model()

func reset_heatmap() -> void:
	for y in range(3):
		for x in range(3):
			heatmap[Vector2i(x, y)] = 1.0

# =====================================================================
#  1. CADEIA DE MARKOV & HEATMAP ESPACIAL (Predicao de Movimento)
# =====================================================================
func _cell_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]

func _key_to_cell(k: String) -> Vector2i:
	var parts := k.split(",")
	if parts.size() == 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i(1, 1)

## Registra uma transicao de movimento real do jogador (from_cell -> to_cell).
func registrar_movimento(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var k_from := _cell_key(from_cell)
	var k_to := _cell_key(to_cell)
	if not markov_counts.has(k_from):
		markov_counts[k_from] = {}
	var dest_dict: Dictionary = markov_counts[k_from]
	# Aplica leve fator de esquecimento (0.94) para se adaptar a mudancas de habito do jogador
	for k in dest_dict.keys():
		dest_dict[k] = float(dest_dict[k]) * 0.94
	dest_dict[k_to] = float(dest_dict.get(k_to, 0.0)) + 1.0

## Atualiza o Mapa de Calor 3x3 com a posicao atual dos jogadores.
func atualizar_presenca(c1: Vector2i, c2: Vector2i, delta: float) -> void:
	var decay := exp(-0.45 * delta)
	for c in heatmap.keys():
		heatmap[c] = maxf(0.2, float(heatmap[c]) * decay)
	if heatmap.has(c1):
		heatmap[c1] = float(heatmap[c1]) + delta * 2.2
	if heatmap.has(c2):
		heatmap[c2] = float(heatmap[c2]) + delta * 2.2

## Usa a Cadeia de Markov P(c_{t+1} | c_t) + Heatmap para prever onde o jogador estara.
func prever_celula_jogador(cell_atual: Vector2i) -> Vector2i:
	var k_from := _cell_key(cell_atual)
	if not markov_counts.has(k_from):
		return cell_atual
	var dest_dict: Dictionary = markov_counts[k_from]
	var melhor_k := k_from
	var maior_peso := -1.0
	for k_to in dest_dict.keys():
		var c_to := _key_to_cell(k_to)
		# Combina probabilidade de transicao de Markov com o calor da celula destino
		var peso := float(dest_dict[k_to]) + float(heatmap.get(c_to, 1.0)) * 0.25
		if peso > maior_peso:
			maior_peso = peso
			melhor_k = k_to
	return _key_to_cell(melhor_k)

## Pontua o valor tatico de atacar uma celula especifica.
func pontuar_celula(c: Vector2i, p1_cell: Vector2i, p2_cell: Vector2i, pred_p1: Vector2i, pred_p2: Vector2i, symphony_cell: Vector2i) -> float:
	var score := float(heatmap.get(c, 1.0)) * 0.4
	if c == pred_p1:
		score += 2.4
	if c == pred_p2:
		score += 2.4
	if c == p1_cell:
		score += 1.5
	if c == p2_cell:
		score += 1.5
	if c == symphony_cell:
		score += 1.8
	return score + randf_range(0.0, 0.45)

func escolher_alvo_celula(todas: Array[Vector2i], p1_cell: Vector2i, p2_cell: Vector2i, symphony_cell: Vector2i) -> Vector2i:
	if randf() < epsilon:
		return todas.pick_random()
	var pred1 := prever_celula_jogador(p1_cell)
	var pred2 := prever_celula_jogador(p2_cell)
	var melhor_c: Vector2i = todas[0]
	var melhor_s := -999.0
	for c in todas:
		var s := pontuar_celula(c, p1_cell, p2_cell, pred1, pred2, symphony_cell)
		if s > melhor_s:
			melhor_s = s
			melhor_c = c
	return melhor_c

func escolher_alvo_linha(p1_cell: Vector2i, p2_cell: Vector2i, symphony_cell: Vector2i) -> int:
	return _escolher_alvo_eixo(false, p1_cell, p2_cell, symphony_cell)

func escolher_alvo_coluna(p1_cell: Vector2i, p2_cell: Vector2i, symphony_cell: Vector2i) -> int:
	return _escolher_alvo_eixo(true, p1_cell, p2_cell, symphony_cell)

func _escolher_alvo_eixo(eh_coluna: bool, p1_cell: Vector2i, p2_cell: Vector2i, symphony_cell: Vector2i) -> int:
	if randf() < epsilon:
		return randi() % 3
	var pred1 := prever_celula_jogador(p1_cell)
	var pred2 := prever_celula_jogador(p2_cell)
	var melhor_idx := 0
	var melhor_s := -999.0
	for idx in range(3):
		var s := 0.0
		for k in range(3):
			var c := Vector2i(idx, k) if eh_coluna else Vector2i(k, idx)
			s += pontuar_celula(c, p1_cell, p2_cell, pred1, pred2, symphony_cell)
		if s > melhor_s:
			melhor_s = s
			melhor_idx = idx
	return melhor_idx

#Machine learning

func obter_estado_tatico(p1_cell: Vector2i, p2_cell: Vector2i, symphony_ativa: bool, symphony_cell: Vector2i) -> String:
	if symphony_ativa and (p1_cell == symphony_cell or p2_cell == symphony_cell):
		return "em_sinfonia"
	if p1_cell.y == p2_cell.y:
		return "alinhados_linha"
	if p1_cell.x == p2_cell.x:
		return "alinhados_coluna"
	var dist := absi(p1_cell.x - p2_cell.x) + absi(p1_cell.y - p2_cell.y)
	if dist <= 1:
		return "agrupados"
	return "separados"

func _garantir_estado(estado: String, opcoes: Array) -> void:
	if not q_table.has(estado):
		q_table[estado] = {}
	var d: Dictionary = q_table[estado]
	for op in opcoes:
		if not d.has(op):
			d[op] = 0.0

func escolher_padrao(estado: String, opcoes: Array) -> String:
	if opcoes.is_empty():
		return "celula"
	_garantir_estado(estado, opcoes)
	if randf() < epsilon:
		return opcoes.pick_random()

	var d: Dictionary = q_table[estado]
	var melhor_acao: String = opcoes[0]
	var maior_q := -9999.0
	var opcoes_shuffled := opcoes.duplicate()
	opcoes_shuffled.shuffle()
	for op in opcoes_shuffled:
		var q_val := float(d.get(op, 0.0))
		if q_val > maior_q:
			maior_q = q_val
			melhor_acao = op
	return melhor_acao

func atualizar_q_value(estado_antigo: String, acao: String, recompensa: float, estado_novo: String, opcoes: Array) -> void:
	_garantir_estado(estado_antigo, opcoes)
	_garantir_estado(estado_novo, opcoes)

	var d_old: Dictionary = q_table[estado_antigo]
	var d_new: Dictionary = q_table[estado_novo]

	var q_atual := float(d_old.get(acao, 0.0))
	var max_q_futuro := 0.0
	var primeiro := true
	for op in opcoes:
		var v := float(d_new.get(op, 0.0))
		if primeiro or v > max_q_futuro:
			max_q_futuro = v
			primeiro = false

	var novo_q := q_atual + alpha * (recompensa + gamma * max_q_futuro - q_atual)
	d_old[acao] = snappedf(novo_q, 0.001)

	total_episodios += 1
	epsilon = maxf(epsilon_min, epsilon * epsilon_decay)

#machine learning
func save_model() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ml", "epsilon", epsilon)
	cfg.set_value("ml", "total_episodios", total_episodios)
	cfg.set_value("ml", "q_table", q_table)
	cfg.set_value("ml", "markov_counts", markov_counts)
	cfg.save(SAVE_PATH)

func load_model() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		epsilon = float(cfg.get_value("ml", "epsilon", 0.35))
		total_episodios = int(cfg.get_value("ml", "total_episodios", 0))
		q_table = cfg.get_value("ml", "q_table", {})
		markov_counts = cfg.get_value("ml", "markov_counts", {})

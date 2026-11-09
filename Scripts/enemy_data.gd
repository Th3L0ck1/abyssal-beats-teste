extends RefCounted
class_name EnemyData

## Cada inimigo usa uma spritesheet de 8 frames: 0-3 idle | 4-5 ataque | 6-7 dano.
## Padroes disponiveis: celula, linha, linha_dupla, coluna, coluna_dupla, cruz, ondas, diagonal, xadrez
const ENEMIES: Dictionary = {
	"jellyfish": {
		"name": "Agua-viva Eletrica",
		"sheet": "res://Sprites/Enemies/Jellyfish_sheet.png",
		"scale": 2.0,
		"hp": 2,
		"interval": 2.9,
		"patterns": ["coluna", "coluna", "celula", "coluna_dupla"],
		"icon": 0,
	},
	"crab": {
		"name": "Caranguejo-Robo",
		"sheet": "res://Sprites/Enemies/Crab_sheet.png",
		"scale": 1.7,
		"hp": 3,
		"interval": 3.0,
		"patterns": ["linha", "linha", "celula", "linha_dupla"],
		"icon": 1,
	},
	"puffer": {
		"name": "Baiacu-Mina",
		"sheet": "res://Sprites/Enemies/Puffer_sheet.png",
		"scale": 1.7,
		"hp": 3,
		"interval": 2.9,
		"patterns": ["celula", "cruz", "cruz", "celula"],
		"icon": 2,
	},
	"bell": {
		"name": "Polvo-Sino",
		"sheet": "res://Sprites/Enemies/Bell_sheet.png",
		"scale": 1.7,
		"hp": 3,
		"interval": 3.2,
		"patterns": ["ondas", "ondas", "celula", "xadrez"],
		"icon": 3,
	},
	"boss": {
		"name": "Guardiao Abissal",
		"sheet": "res://Sprites/Enemies/Boss_sheet.png",
		"scale": 1.3,
		"hp": 6,
		"interval": 3.0,
		"patterns": ["celula", "coluna", "linha", "cruz"],
		"patterns_fase2": ["celula", "coluna_dupla", "linha_dupla", "cruz", "ondas", "diagonal", "xadrez"],
		"icon": 4,
	},
}

static func get_enemy(id: String) -> Dictionary:
	return ENEMIES.get(id, ENEMIES["jellyfish"])

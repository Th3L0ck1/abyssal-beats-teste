extends RefCounted
class_name WorldMap

## Legenda: . vazio | o plataforma | 1/2 inicio P1/P2 | j c b p G inimigos (agua-viva, caranguejo, baiacu, polvo-sino, guardiao)
## D portao de toque | K portao com chave | k bau de chave | u v placas duplas -> portao V | F fim da demo
const ROWS: Array[String] = [
	"..................................................",
	"..................................ookoo...........",
	"......ookoo..ooooooooo............ooooo...........",
	"......ooooo..ouooooovo............ooooo...........",
	"......ooooo..ooooooooo..............j.............",
	"........o.......o...................o.............",
	"........j.......c................ooooooo..........",
	"........o.....ooooo.....ooooo....ooooooo..........",
	".ooooo..o.....ooooo.....ooooo....ooboooo..........",
	".o1ooooooooooDoocooooooVoojoooDoKooopooopooKooGoF.",
	".o2ooo..o.....ooooo.....ooooo....ooooboo..........",
	".ooooo..o.....ooooo.....ooooo....ooooooo..........",
	"........j.......o................ooooooo..........",
	"........o.......o...................o.............",
	"......ooooo.....c...................o.............",
	"......ooooo..ooooooo................b.............",
	"......oooko..ooooooo..............ooooo...........",
	"......ooooo..koooooo..............oopoo...........",
	"..................................ooooo..........."
]

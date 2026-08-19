extends TileMapLayer
## Pinta el terreno del monasterio usando el TileSet de placeholders.
##
## Se limita a COLOCAR tiles ya existentes (no dibuja gráficos): puedes
## borrar este script y pintar el mapa a mano en el editor con tus propios
## tiles si lo prefieres. IDs de fuente definidos en monastery_tileset.tres:
##   0 = hierba, 1 = camino, 2 = suelo de piedra, 3 = agua, 4 = campo de labor.

const ANCHO := 20   # celdas
const ALTO := 12
const ORIGEN := Vector2i(0, 0)  # atlas (0,0) para todos los placeholders

func _ready() -> void:
	_pintar()

func _pintar() -> void:
	# Base de hierba.
	for x in range(ANCHO):
		for y in range(ALTO):
			set_cell(Vector2i(x, y), 0, ORIGEN)

	# Plaza/claustro central de piedra.
	for x in range(7, 13):
		for y in range(4, 8):
			set_cell(Vector2i(x, y), 2, ORIGEN)

	# Caminos en cruz.
	for x in range(ANCHO):
		set_cell(Vector2i(x, 6), 1, ORIGEN)
	for y in range(ALTO):
		set_cell(Vector2i(10, y), 1, ORIGEN)

	# Río en el borde inferior.
	for x in range(ANCHO):
		set_cell(Vector2i(x, ALTO - 1), 3, ORIGEN)

	# Campos de labor a los lados.
	for x in range(1, 5):
		for y in range(9, 11):
			set_cell(Vector2i(x, y), 4, ORIGEN)
	for x in range(15, 19):
		for y in range(9, 11):
			set_cell(Vector2i(x, y), 4, ORIGEN)

extends TileMapLayer
## Pinta el patio del monasterio: la vista propia del cenobio (estilo pantalla
## de castillo), separada del mapa del territorio. Solo coloca tiles.
##   0 hierba · 1 camino · 2 piedra · 5 bosque

const ANCHO := 20
const ALTO := 14

func _ready() -> void:
	for x in range(ANCHO):
		for y in range(ALTO):
			var t := 0
			if x == 0 or y == 0 or x == ANCHO - 1 or y == ALTO - 1:
				t = 5  # cinturón de arboleda
			elif x >= 3 and x < ANCHO - 3 and y >= 2 and y < ALTO - 2:
				t = 2  # explanada/claustro de piedra
			set_cell(Vector2i(x, y), t, Vector2i(0, 0))
	# Sendero de acceso.
	for y in range(ALTO - 1, ALTO / 2, -1):
		set_cell(Vector2i(ANCHO / 2, y), 1, Vector2i(0, 0))

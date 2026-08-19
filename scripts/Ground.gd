extends TileMapLayer
## Pinta el terreno del mapa generado proceduralmente al fundar el monasterio.
## Se limita a colocar tiles ya existentes (no dibuja gráficos). Los ids de
## fuente los define monastery_tileset.tres:
##   0 hierba · 1 camino · 2 piedra · 3 agua · 4 campo · 5 bosque · 6 monte.

func _ready() -> void:
	_pintar()

func _pintar() -> void:
	if GameState.terreno.is_empty():
		return
	for x in range(GameState.terreno.size()):
		var col: Array = GameState.terreno[x]
		for y in range(col.size()):
			set_cell(Vector2i(x, y), int(col[y]), Vector2i(0, 0))

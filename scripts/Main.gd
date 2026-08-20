extends Node2D
## Escena principal con dos vistas (estilo Heroes III):
##  - «Territorio»: el mapa grande con parroquias, aldeas, el marcador del
##    monasterio propio y el del monasterio rival. Se entra al monasterio
##    pulsando su marcador. En modo construcción, un clic sobre una casilla
##    válida levanta una explotación (muíño/canteira/pasto).
##  - «Mosteiro»: el patio propio del monasterio con sus edificios y monjes.
## Solo una vista está visible y activa a la vez.

const MonkScene := preload("res://scenes/Monk.tscn")
const BuildingScene := preload("res://scenes/Building.tscn")
const AldeaScene := preload("res://scenes/Aldea.tscn")
const ParroquiaScene := preload("res://scenes/Parroquia.tscn")
const MonMarkerScene := preload("res://scenes/MonMarker.tscn")
const RivalMarkerScene := preload("res://scenes/RivalMarker.tscn")
const ExplotacionMarkerScene := preload("res://scenes/ExplotacionMarker.tscn")
const LeiraMarkerScene := preload("res://scenes/LeiraMarker.tscn")

var _leiras_procesadas: int = 0  # nº de leiras ya consideradas para marcador

# Centro del patio y disposición de los edificios (en celdas del patio).
const PATIO_CENTRO := Vector2i(10, 7)
const LAYOUT := {
	"iglesia": Vector2i(0, 0),
	"scriptorium": Vector2i(-3, 0),
	"bodega": Vector2i(3, 0),
	"hospederia": Vector2i(0, 3),
	"enfermeria": Vector2i(0, -3),
	"granero": Vector2i(-3, 3),
	"molino": Vector2i(3, 3),
}

func _enter_tree() -> void:
	if not GameState.fundado:
		GameState.fundar("camba", "labradores")

func _ready() -> void:
	_poblar_territorio()
	_poblar_mosteiro()
	GameState.solicitar_vista.connect(set_vista)
	GameState.estado_cambiado.connect(_sincronizar_monjes)
	GameState.estado_cambiado.connect(_sincronizar_explotacions)
	GameState.estado_cambiado.connect(_sincronizar_leiras)
	set_vista("mosteiro")

func _tile_a_mundo(t: Vector2i) -> Vector2:
	return Vector2(t.x * 64 + 32, t.y * 64 + 32)

# --- Cambio de vista --------------------------------------------------------

func set_vista(vista: String) -> void:
	var en_mosteiro := vista == "mosteiro"
	$Territorio.visible = not en_mosteiro
	$Mosteiro.visible = en_mosteiro
	if en_mosteiro:
		$Mosteiro/CamMosteiro.make_current()
	else:
		$Territorio/CamTerritorio.make_current()
	GameState.vista_cambiada.emit(vista)

# --- Poblado del territorio -------------------------------------------------

func _poblar_territorio() -> void:
	for i in range(GameState.parroquias.size()):
		var p: Dictionary = GameState.parroquias[i]
		var nodo := ParroquiaScene.instantiate()
		nodo.position = _tile_a_mundo(Vector2i(int(p["x"]), int(p["y"])))
		$Territorio/Parroquias.add_child(nodo)
		nodo.configurar(i)
	for i in range(GameState.aldeas.size()):
		var a: Dictionary = GameState.aldeas[i]
		var nodo := AldeaScene.instantiate()
		nodo.position = _tile_a_mundo(Vector2i(int(a["x"]), int(a["y"])))
		$Territorio/Aldeas.add_child(nodo)
		nodo.configurar(i)
	var marcador := MonMarkerScene.instantiate()
	marcador.position = _tile_a_mundo(GameState.sitio_mosteiro)
	$Territorio/Marcadores.add_child(marcador)
	if GameState.sitio_rival.x >= 0:
		var rival := RivalMarkerScene.instantiate()
		rival.position = _tile_a_mundo(GameState.sitio_rival)
		$Territorio/Marcadores.add_child(rival)
	$Territorio/CamTerritorio.position = _tile_a_mundo(GameState.sitio_mosteiro)
	_sincronizar_explotacions()
	_sincronizar_leiras()

## Coloca un marcador por cada explotación construida (muíño/canteira/pasto).
func _sincronizar_explotacions() -> void:
	var cont: Node2D = $Territorio/Explotacions
	for c in cont.get_children():
		c.queue_free()
	for ex in GameState.explotacions:
		var nodo := ExplotacionMarkerScene.instantiate()
		nodo.tipo = ex["tipo"]
		nodo.position = _tile_a_mundo(Vector2i(int(ex["x"]), int(ex["y"])))
		cont.add_child(nodo)

## Añade un marcador por cada leira nueva que ya tenga celda asignada. Las
## leiras nunca se eliminan (solo cambian de estado), así que basta con
## procesar las que se hayan añadido desde la última sincronización; cada
## marcador se actualiza solo (tiñe según cultivo/estado) al oír estado_cambiado.
func _sincronizar_leiras() -> void:
	var cont: Node2D = $Territorio/Leiras
	for i in range(_leiras_procesadas, GameState.leiras.size()):
		var l: Dictionary = GameState.leiras[i]
		if int(l.get("x", -1)) >= 0:
			var nodo := LeiraMarkerScene.instantiate()
			nodo.position = _tile_a_mundo(Vector2i(int(l["x"]), int(l["y"])))
			cont.add_child(nodo)
			nodo.configurar(i)
	_leiras_procesadas = GameState.leiras.size()

## Si estamos en modo construcción, un clic en el territorio intenta levantar
## la explotación elegida sobre la casilla pulsada.
func _unhandled_input(event: InputEvent) -> void:
	if GameState.modo_construccion == "" or not $Territorio.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mundo := get_global_mouse_position()
		var tile := Vector2i(int(floor(mundo.x / 64.0)), int(floor(mundo.y / 64.0)))
		GameState.construir_explotacion(GameState.modo_construccion, tile.x, tile.y)

# --- Poblado del monasterio -------------------------------------------------

func _poblar_mosteiro() -> void:
	for id in LAYOUT:
		var b := BuildingScene.instantiate()
		b.edificio_id = id
		b.position = _tile_a_mundo(PATIO_CENTRO + LAYOUT[id])
		$Mosteiro/Buildings.add_child(b)
	$Mosteiro/CamMosteiro.position = _tile_a_mundo(PATIO_CENTRO)
	_sincronizar_monjes()

## Ajusta los monjes visibles del patio a la población actual.
func _sincronizar_monjes() -> void:
	var monks: Node2D = $Mosteiro/Monks
	var centro := _tile_a_mundo(PATIO_CENTRO)
	var actuales := monks.get_child_count()
	while actuales < GameState.poblacion:
		var m := MonkScene.instantiate()
		m.position = centro + Vector2(randf_range(-160.0, 160.0), randf_range(-110.0, 110.0))
		m.radio = 90.0
		monks.add_child(m)
		actuales += 1
	while actuales > GameState.poblacion:
		monks.get_child(actuales - 1).queue_free()
		actuales -= 1

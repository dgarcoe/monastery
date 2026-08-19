extends Node2D
## Escena principal de juego. Coloca el monasterio y las aldeas sobre el mapa
## generado en la fundación, y mantiene a los monjes en sincronía con la
## población. El terreno lo pinta Ground.gd.

const MonkScene := preload("res://scenes/Monk.tscn")
const BuildingScene := preload("res://scenes/Building.tscn")
const AldeaScene := preload("res://scenes/Aldea.tscn")

# Disposición de los edificios alrededor del emplazamiento (en celdas).
const LAYOUT := {
	"iglesia": Vector2i(0, 0),
	"scriptorium": Vector2i(-3, 0),
	"bodega": Vector2i(3, 0),
	"hospederia": Vector2i(0, 3),
	"enfermeria": Vector2i(0, -3),
	"granero": Vector2i(-3, 3),
	"molino": Vector2i(3, 3),
}

@onready var monks: Node2D = $Monks
@onready var buildings: Node2D = $Buildings
@onready var aldeas_node: Node2D = $Aldeas
@onready var camera: Camera2D = $Camera

func _enter_tree() -> void:
	# Si se ejecuta Main directamente sin fundar (p. ej. desde el editor),
	# funda una partida por defecto ANTES de que Ground pinte el terreno.
	if not GameState.fundado:
		GameState.fundar("camba", "labradores")

func _ready() -> void:
	_colocar_edificios()
	_colocar_aldeas()
	camera.position = _tile_a_mundo(GameState.sitio_mosteiro)
	_sincronizar_monjes()
	GameState.estado_cambiado.connect(_sincronizar_monjes)

func _tile_a_mundo(t: Vector2i) -> Vector2:
	return Vector2(t.x * 64 + 32, t.y * 64 + 32)

func _colocar_edificios() -> void:
	for id in LAYOUT:
		var b := BuildingScene.instantiate()
		b.edificio_id = id
		b.position = _tile_a_mundo(GameState.sitio_mosteiro + LAYOUT[id])
		buildings.add_child(b)

func _colocar_aldeas() -> void:
	for i in range(GameState.aldeas.size()):
		var a: Dictionary = GameState.aldeas[i]
		var nodo := AldeaScene.instantiate()
		nodo.position = _tile_a_mundo(Vector2i(int(a["x"]), int(a["y"])))
		aldeas_node.add_child(nodo)
		nodo.configurar(i)

## Añade o quita monjes para que coincidan con GameState.poblacion.
func _sincronizar_monjes() -> void:
	var centro := _tile_a_mundo(GameState.sitio_mosteiro)
	var actuales := monks.get_child_count()
	while actuales < GameState.poblacion:
		var m := MonkScene.instantiate()
		m.position = centro + Vector2(randf_range(-95.0, 95.0), randf_range(-75.0, 95.0))
		m.radio = 95.0
		monks.add_child(m)
		actuales += 1
	while actuales > GameState.poblacion:
		monks.get_child(actuales - 1).queue_free()
		actuales -= 1

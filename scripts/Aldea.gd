extends Node2D
## Aldea del contorno: poblado con aldeanos que deambulan (o, si tienen una
## leira propia, van y vuelven a ella para trabajarla). Es la fuente de
## donaciones de tierras y de las familias foreras. Al hacer clic muestra su
## ficha (señal GameState.aldea_pulsada).

const VillagerScene := preload("res://scenes/Villager.tscn")

var indice_aldea: int = -1

@onready var etiqueta: Label = $Nome

func _ready() -> void:
	$Click.input_event.connect(_on_click)

## Vincula esta aldea con su registro en GameState y crea sus aldeanos.
func configurar(idx: int) -> void:
	indice_aldea = idx
	var a: Dictionary = GameState.aldeas[idx]
	etiqueta.text = "%s (%d)" % [a["nome"], int(a["poboacion"])]

	# Leiras propias de esta aldea con celda asignada: los aldeanos que
	# trabajan el campo caminarán hasta ellas en vez de deambular al azar.
	var leiras_propias: Array = []
	for l in GameState.leiras:
		if l["aldea"] == a["nome"] and int(l.get("x", -1)) >= 0:
			leiras_propias.append(Vector2i(int(l["x"]), int(l["y"])))

	var n: int = min(4, int(a["poboacion"]))
	for i in range(n):
		var v := VillagerScene.instantiate()
		v.position = Vector2(randf_range(-42.0, 42.0), randf_range(-30.0, 54.0))
		v.radio = 38.0
		v.velocidad = 18.0
		add_child(v)
		if not leiras_propias.is_empty():
			var tile: Vector2i = leiras_propias[i % leiras_propias.size()]
			var traballo_mundo := Vector2(tile.x * 64 + 32, tile.y * 64 + 32)
			v.asignar_traballo(traballo_mundo - position)

func _on_click(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.aldea_pulsada.emit(indice_aldea)

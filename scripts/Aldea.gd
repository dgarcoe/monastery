extends Node2D
## Aldea del contorno: poblado con aldeanos que deambulan. Es la fuente de
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
	var n: int = min(4, int(a["poboacion"]))
	for i in range(n):
		var v := VillagerScene.instantiate()
		v.position = Vector2(randf_range(-42.0, 42.0), randf_range(-30.0, 54.0))
		v.radio = 38.0
		v.velocidad = 18.0
		add_child(v)

func _on_click(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.aldea_pulsada.emit(indice_aldea)

extends Node2D
## Marcador de una parroquia en el mapa del territorio. Al hacer clic muestra
## su ficha (aldeas que agrupa).

var indice: int = -1

@onready var etiqueta: Label = $Nome

func _ready() -> void:
	$Click.input_event.connect(_on_click)

func configurar(idx: int) -> void:
	indice = idx
	var p: Dictionary = GameState.parroquias[idx]
	etiqueta.text = "%s\n(%d aldeas)" % [p["nome"], p["aldeas"].size()]

func _on_click(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.parroquia_pulsada.emit(indice)

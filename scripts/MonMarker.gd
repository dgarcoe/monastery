extends Node2D
## Marcador del monasterio en el mapa del territorio. Al hacer clic se entra
## en la vista propia del monasterio (su patio y edificios).

func _ready() -> void:
	$Click.input_event.connect(_on_click)

func _on_click(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.solicitar_vista.emit("mosteiro")

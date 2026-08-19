extends Node2D
## Representa un edificio del monasterio en el mapa (un "solar" fijo).
##
## Muestra el placeholder de solar mientras no está construido y cambia a la
## imagen del edificio (con su nivel) una vez erigido. Al hacer clic, avisa a
## la interfaz mediante la señal GameState.edificio_pulsado.

@export var edificio_id: String = ""

@onready var sprite: Sprite2D = $Sprite
@onready var etiqueta: Label = $Nivel

func _ready() -> void:
	_actualizar()
	GameState.estado_cambiado.connect(_actualizar)
	$Click.input_event.connect(_on_input_event)

func _actualizar() -> void:
	var nivel := GameState.get_nivel(edificio_id)
	if nivel > 0:
		sprite.texture = load("res://assets/buildings/%s.png" % edificio_id)
		sprite.modulate = Color(1, 1, 1, 1)
		etiqueta.text = "%s · Niv.%d" % [_nombre(), nivel]
	else:
		sprite.texture = load("res://assets/buildings/plot.png")
		sprite.modulate = Color(1, 1, 1, 0.8)
		etiqueta.text = _nombre()

func _nombre() -> String:
	for e in Data.EDIFICIOS:
		if e["id"] == edificio_id:
			return e["nombre"]
	return edificio_id

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.edificio_pulsado.emit(edificio_id)

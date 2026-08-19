extends Node2D
## Personaje que deambula alrededor de su punto de aparición (monjes y
## aldeanos). Solo comportamiento visual; no afecta a la simulación.

@export var velocidad: float = 24.0
@export var radio: float = 110.0

var _orixe: Vector2
var _destino: Vector2

func _ready() -> void:
	_orixe = position
	_nuevo_destino()

func _nuevo_destino() -> void:
	_destino = _orixe + Vector2(
		randf_range(-radio, radio), randf_range(-radio, radio))

func _process(delta: float) -> void:
	position = position.move_toward(_destino, velocidad * delta)
	if position.distance_to(_destino) < 3.0:
		_nuevo_destino()

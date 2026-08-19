extends Node2D
## Monje que deambula por el recinto del monasterio.
##
## Movimiento sencillo entre puntos aleatorios: es solo comportamiento visual,
## no afecta a la simulación (que vive en GameState). Sustituye el sprite en
## assets/characters/monk.png por el tuyo (o añade un AnimationPlayer) sin
## tocar este script.

@export var velocidad: float = 28.0
var _destino: Vector2
var _limites := Rect2(140, 140, 1000, 480)

func _ready() -> void:
	_destino = position
	_nuevo_destino()

func _nuevo_destino() -> void:
	_destino = Vector2(
		randf_range(_limites.position.x, _limites.end.x),
		randf_range(_limites.position.y, _limites.end.y))

func _process(delta: float) -> void:
	position = position.move_toward(_destino, velocidad * delta)
	if position.distance_to(_destino) < 3.0:
		_nuevo_destino()

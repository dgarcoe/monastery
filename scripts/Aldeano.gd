extends Node2D
## Aldeano que trabaja: si se le asigna una leira, camina periódicamente
## desde su casa hasta ella, se detiene un rato «trabajando» y vuelve a casa;
## sin leira asignada, deambula cerca de la aldea como antes. Puramente
## visual: no afecta a la simulación (que vive en GameState).

@export var velocidad: float = 20.0
@export var radio: float = 38.0       # deambular cuando no hay leira

var _orixe: Vector2
var _traballo: Vector2 = Vector2.ZERO
var _ten_traballo: bool = false
var _en_casa: bool = true
var _destino: Vector2
var _agardando: float = 0.0

func _ready() -> void:
	_orixe = position
	_novo_ciclo()

## Fija la leira (en coordenadas locales a este nodo) hasta la que caminará.
func asignar_traballo(pos_local: Vector2) -> void:
	_traballo = pos_local
	_ten_traballo = true

func _novo_ciclo() -> void:
	if _ten_traballo:
		_destino = _traballo if _en_casa else _orixe + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
	else:
		_destino = _orixe + Vector2(randf_range(-radio, radio), randf_range(-radio, radio))

func _process(delta: float) -> void:
	if _agardando > 0.0:
		_agardando -= delta
		return
	position = position.move_toward(_destino, velocidad * delta)
	if position.distance_to(_destino) < 3.0:
		if _ten_traballo:
			_en_casa = not _en_casa
			_agardando = randf_range(2.0, 5.0)  # se detiene un rato en cada extremo
		_novo_ciclo()

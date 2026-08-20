extends Node2D
## Marcador de una parroquia en el mapa del territorio. Al hacer clic muestra
## su ficha (aldeas que agrupa, influencia de cada facción). El color del
## marcador refleja qué facción domina la parroquia (rivalidad territorial).

var indice: int = -1

@onready var etiqueta: Label = $Nome
@onready var sprite: Sprite2D = $Sprite

const COR_PROPIA := Color(1, 1, 1, 1)

func _ready() -> void:
	$Click.input_event.connect(_on_click)
	GameState.estado_cambiado.connect(_actualizar)

func configurar(idx: int) -> void:
	indice = idx
	_actualizar()

func _actualizar() -> void:
	if indice < 0 or indice >= GameState.parroquias.size():
		return
	var p: Dictionary = GameState.parroquias[indice]
	var dom := GameState.faccion_dominante(p)
	etiqueta.text = "%s\n(%d aldeas · %s)" % [p["nome"], p["aldeas"].size(), GameState.nome_faccion(dom)]
	if dom == "monasterio" or dom == "":
		sprite.modulate = COR_PROPIA
	else:
		var cor: Color = Data.FACCIONES.get(dom, {}).get("color", COR_PROPIA)
		sprite.modulate = cor.lightened(0.15)

func _on_click(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.parroquia_pulsada.emit(indice)

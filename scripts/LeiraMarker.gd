extends Node2D
## Marcador de una leira sobre su celda real del territorio. El color indica
## el producto del cultivo (grano, vino o castañas); una leira yerma se
## muestra atenuada. Al hacer clic abre el panel del Señorío para gestionarla.

const COR_GRAO := Color(0.82, 0.68, 0.25, 1.0)
const COR_VINO := Color(0.55, 0.18, 0.35, 1.0)
const COR_CASTANAS := Color(0.5, 0.32, 0.16, 1.0)

var indice: int = -1

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	$Click.input_event.connect(_on_click)
	GameState.estado_cambiado.connect(_actualizar)

func configurar(idx: int) -> void:
	indice = idx
	_actualizar()

func _actualizar() -> void:
	if indice < 0 or indice >= GameState.leiras.size():
		return
	var l: Dictionary = GameState.leiras[indice]
	var cul := GameState.cultivo_de(l)
	match cul["producto"]:
		"vino": sprite.modulate = COR_VINO
		"castañas": sprite.modulate = COR_CASTANAS
		_: sprite.modulate = COR_GRAO
	if l["estado"] == "yerma":
		sprite.modulate.a = 0.35
	elif l.get("pleito", false):
		sprite.modulate = sprite.modulate.lightened(0.4)
	var escala := 0.55 + 0.2 * int(l["calidade"])  # más grande cuanto mejor la tierra
	sprite.scale = Vector2(escala, escala)

func _on_click(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.leira_pulsada.emit(indice)

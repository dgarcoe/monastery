extends Node2D
## Marcador visual de una explotación construida (muíño, canteira o pasto)
## sobre el territorio. Solo informativo: no genera gráficos, carga el sprite
## correspondiente al tipo desde assets/buildings/.

@export var tipo: String = ""

@onready var sprite: Sprite2D = $Sprite
@onready var etiqueta: Label = $Nome

func _ready() -> void:
	if tipo == "":
		return
	sprite.texture = load("res://assets/buildings/%s.png" % tipo)
	etiqueta.text = Data.EXPLOTACIONS.get(tipo, {}).get("nombre", tipo)

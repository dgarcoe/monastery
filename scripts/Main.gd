extends Node2D
## Escena principal: coloca a los monjes y los mantiene en sincronía con la
## población de GameState. El terreno lo pinta Ground.gd y los edificios están
## colocados como solares fijos en la propia escena Main.tscn.

const MonkScene := preload("res://scenes/Monk.tscn")

@onready var monks: Node2D = $Monks

func _ready() -> void:
	_sincronizar_monjes()
	GameState.estado_cambiado.connect(_sincronizar_monjes)

## Añade o quita monjes visibles para que coincidan con GameState.poblacion.
func _sincronizar_monjes() -> void:
	var actuales := monks.get_child_count()
	while actuales < GameState.poblacion:
		var m := MonkScene.instantiate()
		m.position = Vector2(randf_range(560, 760), randf_range(280, 460))
		monks.add_child(m)
		actuales += 1
	while actuales > GameState.poblacion:
		monks.get_child(actuales - 1).queue_free()
		actuales -= 1

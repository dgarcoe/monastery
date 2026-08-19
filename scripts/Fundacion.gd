extends Control
## Pantalla de fundación: se elige la comarca y la familia fundadora antes de
## generar el mapa y comenzar la partida (siglo VIII).

@onready var comarca_opt: OptionButton = %ComarcaOpt
@onready var comarca_desc: Label = %ComarcaDesc
@onready var familia_opt: OptionButton = %FamiliaOpt
@onready var familia_desc: Label = %FamiliaDesc

func _ready() -> void:
	for c in Data.COMARCAS:
		comarca_opt.add_item(c["nombre"])
	for f in Data.FAMILIAS:
		familia_opt.add_item(f["nombre"])
	comarca_opt.select(0)
	familia_opt.select(0)
	comarca_opt.item_selected.connect(func(_i: int) -> void: _actualizar())
	familia_opt.item_selected.connect(func(_i: int) -> void: _actualizar())
	%BtnFundar.pressed.connect(_fundar)
	_actualizar()

func _actualizar() -> void:
	comarca_desc.text = Data.COMARCAS[comarca_opt.selected]["desc"]
	familia_desc.text = Data.FAMILIAS[familia_opt.selected]["desc"]

func _fundar() -> void:
	var comarca_id: String = Data.COMARCAS[comarca_opt.selected]["id"]
	var familia_id: String = Data.FAMILIAS[familia_opt.selected]["id"]
	GameState.fundar(comarca_id, familia_id)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

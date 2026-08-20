extends Panel
## Panel de Mercado regional: precios dinámicos de los bienes, comprar/vender
## y estado del privilegio de feira.

@onready var resumo: Label = $M/V/Resumo
@onready var lista: VBoxContainer = $M/V/Scroll/Lista

func _ready() -> void:
	hide()
	$M/V/BtnCerrar.pressed.connect(func() -> void: hide())
	GameState.estado_cambiado.connect(_on_estado)

func abrir() -> void:
	show()
	refrescar()

func _on_estado() -> void:
	if visible:
		refrescar()

func refrescar() -> void:
	resumo.text = "Feira y portazgo: %s" % ("concedidos ✓" if GameState.feira else "no concedidos")
	for c in lista.get_children():
		c.queue_free()
	for ben in Data.BENS_MERCADO:
		var d: Dictionary = Data.BENS_MERCADO[ben]
		var nome: String = Data.RECURSOS.get(ben, {}).get("nombre", ben.capitalize())
		var disponible: float = GameState.recursos.get(ben, 0.0)
		var pv := GameState.precio_venta(ben)
		var pc := GameState.precio_compra(ben)

		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(230, 0)
		lbl.text = "%s — venta %d 🪙 · compra %d 🪙  (tenéis %d)" % [nome, int(pv), int(pc), int(disponible)]
		fila.add_child(lbl)

		if not bool(d.get("importado", false)):
			var btn_v := Button.new()
			btn_v.text = "Vender todo"
			btn_v.disabled = disponible < 1.0
			btn_v.pressed.connect(func() -> void: GameState.vender(ben, GameState.recursos.get(ben, 0.0)))
			fila.add_child(btn_v)

		var btn_c := Button.new()
		btn_c.text = "Comprar 5"
		btn_c.disabled = GameState.recursos["plata"] < pc * 5.0
		btn_c.pressed.connect(func() -> void: GameState.comprar(ben, 5.0))
		fila.add_child(btn_c)

		lista.add_child(fila)

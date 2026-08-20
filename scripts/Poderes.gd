extends Panel
## Panel de Poderes: rivalidad por el territorio. Muestra las facciones (con
## su relación con el monasterio) y qué parroquia domina cada una, además de
## las acciones de favor y del modo de construir explotaciones sobre el mapa.

@onready var resumo: Label = $M/V/Resumo
@onready var lista_facciones: VBoxContainer = $M/V/ScrollFacciones/ListaFacciones
@onready var lista_parroquias: VBoxContainer = $M/V/ScrollParroquias/ListaParroquias

func _ready() -> void:
	hide()
	$M/V/BtnCerrar.pressed.connect(func() -> void: hide())
	for tipo in Data.EXPLOTACIONS:
		var btn := Button.new()
		var d: Dictionary = Data.EXPLOTACIONS[tipo]
		btn.text = "%s (%d🪙 %d🪨, sobre %s)" % [
			d["nombre"], int(d["coste_plata"]), int(d["coste_piedra"]), _nome_tile(int(d["requiere_tile"]))]
		btn.pressed.connect(func() -> void:
			GameState.iniciar_construccion(tipo)
			hide())
		$M/V/Construccion/Lista.add_child(btn)
	GameState.estado_cambiado.connect(_on_estado)

func _nome_tile(id: int) -> String:
	match id:
		6: return "monte"
		7: return "regato"
		8: return "pasto"
		_: return "terreno"

func abrir() -> void:
	show()
	refrescar()

func _on_estado() -> void:
	if visible:
		refrescar()

func refrescar() -> void:
	resumo.text = "Vuestro monasterio domina %d de %d parroquias. Explotaciones levantadas: %d." % [
		GameState.parroquias_dominadas(), GameState.parroquias.size(), GameState.explotacions.size()]

	for c in lista_facciones.get_children():
		c.queue_free()
	for id in GameState.facciones:
		var fac: Dictionary = GameState.facciones[id]
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(320, 0)
		lbl.text = "%s — relación %+d · poder %.1f" % [fac["nome"], int(fac["relacion"]), float(fac["poder"])]
		fila.add_child(lbl)
		var btn := Button.new()
		btn.text = "Enviar favor (15🪙)"
		btn.disabled = GameState.recursos["plata"] < GameState.COSTE_FAVOR
		btn.pressed.connect(func() -> void: GameState.favor_faccion(id))
		fila.add_child(btn)
		lista_facciones.add_child(fila)

	for c in lista_parroquias.get_children():
		c.queue_free()
	for p in GameState.parroquias:
		var dom := GameState.faccion_dominante(p)
		var fila := Label.new()
		fila.text = "%s — dominada por %s (%d%%)" % [
			p["nome"], GameState.nome_faccion(dom), int(p["influencia"].get(dom, 0.0))]
		lista_parroquias.add_child(fila)

extends Panel
## Panel del Señorío: patrimonio de tierras, foros, cotos y malestar.
## Presenta cada leira como una fila (LeiraRow.tscn) y ofrece las acciones.

const LeiraRowScene := preload("res://scenes/LeiraRow.tscn")

@onready var resumo: Label = $M/V/Resumo
@onready var lista: VBoxContainer = $M/V/Scroll/Lista
@onready var dialogo: Panel = $Dialogo
@onready var dlg_titulo: Label = $Dialogo/DM/DV/DlgTitulo
@onready var opc: OptionButton = $Dialogo/DM/DV/OpcFraccion
@onready var btn_limosna: Button = $M/V/Barra/BtnLimosna

var _pendiente_indice: int = -1
var _pendiente_modo: String = ""

func _ready() -> void:
	hide()
	dialogo.hide()
	for f in Data.FRACCIONES:
		opc.add_item("%s  (%d%% de la cosecha)" % [f["nombre"], int(round(float(f["valor"]) * 100.0))])
	btn_limosna.pressed.connect(func() -> void: GameState.dar_limosna())
	$M/V/Barra/BtnCerrar.pressed.connect(func() -> void: hide())
	$Dialogo/DM/DV/DBtns/DlgConfirmar.pressed.connect(_on_confirmar)
	$Dialogo/DM/DV/DBtns/DlgCancelar.pressed.connect(func() -> void: dialogo.hide())
	GameState.estado_cambiado.connect(_on_estado)

func abrir() -> void:
	show()
	refrescar()

func _on_estado() -> void:
	if visible:
		refrescar()

func refrescar() -> void:
	resumo.text = _resumen()
	for c in lista.get_children():
		c.queue_free()
	for i in range(GameState.leiras.size()):
		var row := LeiraRowScene.instantiate()
		lista.add_child(row)
		row.set_leira(i)
		row.accion.connect(_on_accion)
	btn_limosna.disabled = GameState.recursos["comida"] < 10.0 or GameState.recursos["plata"] < 5.0

func _resumen() -> String:
	return ("Leiras: %d  (directa %d · aforadas %d · yermas %d)     Cotos: %d · Vasallos: %d · Aniversarios: %d\n" +
			"Malestar campesino: %d%%     Renta foral estimada: %d/año     Diezmo: sobre %d parroquias     Pleitos en curso: %d") % [
		GameState.leiras.size(), GameState.contar_leiras("directa"),
		GameState.contar_leiras("aforada"), GameState.contar_leiras("yerma"),
		GameState.cotos, GameState.vasallos, GameState.aniversarios,
		int(GameState.malestar), int(GameState.renta_foral_estimada()), GameState.cotos,
		GameState.pleitos_en_curso()]

func _on_accion(indice: int, tipo: String) -> void:
	match tipo:
		"aforar":
			_abrir_dialogo(indice, "aforar")
		"renovar":
			_abrir_dialogo(indice, "renovar")
		"directa":
			GameState.poner_en_directa(indice)
		"perdonar":
			GameState.perdonar_deuda(indice)
		"pleitear":
			GameState.pleitear(indice)

func _abrir_dialogo(indice: int, modo: String) -> void:
	_pendiente_indice = indice
	_pendiente_modo = modo
	var plantilla := "Aforar «%s»" if modo == "aforar" else "Renovar el foro de «%s»"
	dlg_titulo.text = plantilla % GameState.leiras[indice]["nome"]
	opc.selected = 1  # quinto por defecto
	dialogo.show()

func _on_confirmar() -> void:
	if _pendiente_indice < 0:
		return
	var valor: float = float(Data.FRACCIONES[opc.selected]["valor"])
	if _pendiente_modo == "aforar":
		GameState.aforar(_pendiente_indice, valor)
	else:
		GameState.renovar_foro(_pendiente_indice, valor)
	dialogo.hide()

extends PanelContainer
## Fila de una leira (parcela) en el panel del Señorío. Muestra su estado y
## ofrece las acciones aplicables (aforar, renovar, explotación directa,
## perdonar deuda). No contiene lógica de juego: delega en GameState mediante
## la señal 'accion'.

signal accion(indice: int, tipo: String)

var indice: int = -1

@onready var lbl_nome: Label = $M/V/Nome
@onready var lbl_estado: Label = $M/V/Estado
@onready var btn_aforar: Button = $M/V/Acciones/BtnAforar
@onready var btn_renovar: Button = $M/V/Acciones/BtnRenovar
@onready var btn_directa: Button = $M/V/Acciones/BtnDirecta
@onready var btn_perdonar: Button = $M/V/Acciones/BtnPerdonar
@onready var btn_pleitear: Button = $M/V/Acciones/BtnPleitear

func _ready() -> void:
	btn_aforar.pressed.connect(func() -> void: accion.emit(indice, "aforar"))
	btn_renovar.pressed.connect(func() -> void: accion.emit(indice, "renovar"))
	btn_directa.pressed.connect(func() -> void: accion.emit(indice, "directa"))
	btn_perdonar.pressed.connect(func() -> void: accion.emit(indice, "perdonar"))
	btn_pleitear.pressed.connect(func() -> void: accion.emit(indice, "pleitear"))

func set_leira(idx: int) -> void:
	indice = idx
	var l: Dictionary = GameState.leiras[idx]
	var cul: Dictionary = GameState.cultivo_de(l)
	var unidade: String = cul["unidad"]
	var estrelas := "★".repeat(int(l["calidade"]))
	lbl_nome.text = "%s — %s %s" % [l["nome"], cul["nombre"], estrelas]

	# En pleito: se muestra el estado del litigio y se ocultan las acciones.
	if l.get("pleito", false):
		lbl_estado.text = "⚖ En pleito ante la Audiencia %s · %d año(s) · forero: %s" % [
			GameState.causa_pleito_txt(l["pleito_causa"]), int(l["pleito_anos"]), l["forero"]]
		btn_aforar.visible = false
		btn_renovar.visible = false
		btn_directa.visible = false
		btn_perdonar.visible = false
		btn_pleitear.visible = false
		return

	var caducado: bool = l["estado"] == "aforada" and int(l["voces"]) <= 0
	match l["estado"]:
		"aforada":
			var txt := "Aforada a %s · renta %s: ≈%d %s/año · voces: %d" % [
				l["forero"], GameState._nome_fraccion(l["fraccion"]),
				int(GameState.renta_leira(l)), unidade, int(l["voces"])]
			if float(l["morosidade"]) > 0.0:
				txt += " · deuda: %d %s" % [int(l["morosidade"]), unidade]
			if caducado:
				txt += "   ⚠ CADUCADO"
			lbl_estado.text = txt
		"directa":
			lbl_estado.text = "Explotación directa del monasterio · rinde %d %s/año" % [
				int(GameState.rendemento_leira(l)), unidade]
		_:
			lbl_estado.text = "Yerma, sin cultivar · rendiría %d %s/año a pleno" % [
				int(GameState.rendemento_leira(l)), unidade]

	btn_aforar.visible = l["estado"] == "yerma" or l["estado"] == "directa"
	btn_renovar.visible = caducado
	btn_directa.visible = l["estado"] == "yerma" or caducado
	var moroso: bool = l["estado"] == "aforada" and float(l["morosidade"]) > 0.0
	btn_perdonar.visible = moroso
	btn_pleitear.visible = moroso  # demandar al forero por impago

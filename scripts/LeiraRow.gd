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

func _ready() -> void:
	btn_aforar.pressed.connect(func() -> void: accion.emit(indice, "aforar"))
	btn_renovar.pressed.connect(func() -> void: accion.emit(indice, "renovar"))
	btn_directa.pressed.connect(func() -> void: accion.emit(indice, "directa"))
	btn_perdonar.pressed.connect(func() -> void: accion.emit(indice, "perdonar"))

func set_leira(idx: int) -> void:
	indice = idx
	var l: Dictionary = GameState.leiras[idx]
	var tipo_nome: String = Data.TIPOS_LEIRA[l["tipo"]]["nombre"]
	var estrelas := "★".repeat(int(l["calidade"]))
	lbl_nome.text = "%s — %s %s" % [l["nome"], tipo_nome, estrelas]

	var caducado: bool = l["estado"] == "aforada" and int(l["voces"]) <= 0
	match l["estado"]:
		"aforada":
			var txt := "Aforada a %s · renta: %s · voces: %d" % [
				l["forero"], GameState._nome_fraccion(l["fraccion"]), int(l["voces"])]
			if float(l["morosidade"]) > 0.0:
				txt += " · deuda: %d" % int(l["morosidade"])
			if caducado:
				txt += "   ⚠ CADUCADO"
			lbl_estado.text = txt
		"directa":
			lbl_estado.text = "Explotación directa del monasterio · rinde %d/año" % int(GameState.rendemento_leira(l))
		_:
			lbl_estado.text = "Yerma, sin cultivar · rendiría %d/año a pleno" % int(GameState.rendemento_leira(l))

	btn_aforar.visible = l["estado"] == "yerma" or l["estado"] == "directa"
	btn_renovar.visible = caducado
	btn_directa.visible = l["estado"] == "yerma" or caducado
	btn_perdonar.visible = l["estado"] == "aforada" and float(l["morosidade"]) > 0.0

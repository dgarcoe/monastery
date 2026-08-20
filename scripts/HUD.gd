extends CanvasLayer
## Interfaz de usuario: barra de recursos, asignación de oficios, construcción,
## mercado, crónica de eventos y fin de partida.
##
## No genera gráficos: solo actualiza el texto de nodos ya colocados en
## HUD.tscn y usa los iconos de assets/ui/. Los botones invocan a GameState.

var _sel_edificio: String = ""
var _sel_parroquia: int = -1
var _vals: Dictionary = {}
var _cnt: Dictionary = {}
var _vista: String = "mosteiro"

func _ready() -> void:
	# Referencias a las etiquetas de valor de cada recurso.
	_vals = {
		"comida": %val_comida, "plata": %val_plata, "piedra": %val_piedra,
		"fe": %val_fe, "manuscritos": %val_manuscritos, "vino": %val_vino,
		"gando": %val_gando,
	}
	# Referencias a los contadores de cada oficio y conexión de botones.
	for o in Data.OFICIOS:
		var id: String = o["id"]
		_cnt[id] = get_node("%cnt_" + id)
		(get_node("%mas_" + id) as Button).pressed.connect(func() -> void: GameState.asignar(id, 1))
		(get_node("%menos_" + id) as Button).pressed.connect(func() -> void: GameState.asignar(id, -1))

	# Botones generales.
	%BtnMes.pressed.connect(func() -> void: GameState.avanzar_mes())
	%ChkAuto.toggled.connect(_on_auto)
	%BtnVenderManu.pressed.connect(func() -> void: GameState.vender("manuscritos", GameState.recursos["manuscritos"]))
	%BtnVenderVino.pressed.connect(func() -> void: GameState.vender("vino", GameState.recursos["vino"]))
	%BtnConstruir.pressed.connect(_on_construir)
	%BtnSenorio.pressed.connect(func() -> void: %Senorio.abrir())
	%BtnPoderes.pressed.connect(func() -> void: %Poderes.abrir())
	%BtnMercado.pressed.connect(func() -> void: %Mercado.abrir())
	%BtnCancelarConstruccion.pressed.connect(func() -> void: GameState.cancelar_construccion())
	%BtnCerrar.pressed.connect(func() -> void: %Popup.hide())
	%BtnEvtOk.pressed.connect(func() -> void: %Evento.hide())
	%BtnReiniciar.pressed.connect(_on_reiniciar)
	%AutoTimer.timeout.connect(func() -> void: GameState.avanzar_mes())
	%BtnDotarIglesia.pressed.connect(func() -> void:
		if _sel_parroquia >= 0: GameState.dotar_iglesia(_sel_parroquia))
	%BtnDisputar.pressed.connect(func() -> void:
		if _sel_parroquia >= 0: GameState.disputar_parroquia(_sel_parroquia))

	# Señales del modelo.
	GameState.estado_cambiado.connect(_refrescar)
	GameState.mensaje.connect(_on_mensaje)
	GameState.evento.connect(_on_evento)
	GameState.fin_de_partida.connect(_on_fin)
	GameState.edificio_pulsado.connect(_on_edificio)
	GameState.aldea_pulsada.connect(_on_aldea)
	GameState.parroquia_pulsada.connect(_on_parroquia)
	GameState.vista_cambiada.connect(_on_vista)
	%BtnVista.pressed.connect(_on_btn_vista)
	%BtnAldeaCerrar.pressed.connect(func() -> void:
		_sel_parroquia = -1
		%AldeaPopup.hide())

	%Popup.hide()
	%Evento.hide()
	%FinJuego.hide()
	%AldeaPopup.hide()
	_refrescar()

func _on_auto(activado: bool) -> void:
	if activado:
		%AutoTimer.start()
	else:
		%AutoTimer.stop()

func _num(valor: float) -> String:
	return str(int(round(valor)))

func _refrescar() -> void:
	for id in _vals.keys():
		_vals[id].text = _num(GameState.recursos[id])
	%val_poblacion.text = "%d/%d" % [GameState.poblacion, GameState.capacidad_poblacion()]
	%val_prestigio.text = str(GameState.prestigio)
	%LblFecha.text = "%s de %d" % [GameState.MESES[GameState.mes - 1], GameState.anio]
	%LblEstacion.text = GameState.estacion()
	%LblLibres.text = "Monjes libres: %d" % GameState.monjes_libres()
	%LblMalestar.text = "Malestar: %d%%" % int(GameState.malestar)

	# Oficios.
	for o in Data.OFICIOS:
		var id: String = o["id"]
		if GameState.oficio_desbloqueado(o):
			_cnt[id].text = str(int(GameState.asignacion[id]))
		else:
			_cnt[id].text = "🔒"
		var libre := GameState.monjes_libres() > 0 and GameState.oficio_desbloqueado(o)
		(get_node("%mas_" + id) as Button).disabled = not libre
		(get_node("%menos_" + id) as Button).disabled = int(GameState.asignacion[id]) <= 0

	%BtnVenderManu.disabled = GameState.recursos["manuscritos"] < 1.0
	%BtnVenderVino.disabled = GameState.recursos["vino"] < 1.0
	%BtnMes.disabled = GameState.terminado

	var construyendo := GameState.modo_construccion != ""
	%LblConstruccion.visible = construyendo
	%BtnCancelarConstruccion.visible = construyendo
	if construyendo:
		var d: Dictionary = Data.EXPLOTACIONS[GameState.modo_construccion]
		%LblConstruccion.text = "Elige en el territorio una casilla de %s para el %s…" % [
			_nome_tile_modo(int(d["requiere_tile"])), d["nombre"]]

	if %Popup.visible and _sel_edificio != "":
		_pintar_popup(_sel_edificio)
	if %AldeaPopup.visible and _sel_parroquia >= 0:
		_on_parroquia(_sel_parroquia)

func _nome_tile_modo(id: int) -> String:
	match id:
		6: return "monte"
		7: return "regato"
		8: return "pasto"
		_: return "terreno"

func _on_aldea(indice: int) -> void:
	if indice < 0 or indice >= GameState.aldeas.size():
		return
	_sel_parroquia = -1
	%AccionesParroquia.visible = false
	var a: Dictionary = GameState.aldeas[indice]
	var zona_nome: String = {
		"cereal": "cereal (centeno y trigo)", "vinha": "viñedo",
		"souto": "souto de castaños", "mixta": "cultivos variados",
	}.get(a["zona"], a["zona"])
	var parr: String = a.get("parroquia", "—")
	%AldeaTitulo.text = "Aldea de %s" % a["nome"]
	%AldeaInfo.text = "Parroquia de %s\nPoblación: %d familias\nContorno de %s\nCasas: %s\n\nDe estas casas salen los foreros de sus heredades, y de sus vecinos las donaciones al monasterio." % [
		parr, int(a["poboacion"]), zona_nome, ", ".join(a["casas"])]
	%AldeaPopup.show()

func _on_parroquia(indice: int) -> void:
	if indice < 0 or indice >= GameState.parroquias.size():
		return
	_sel_parroquia = indice
	var p: Dictionary = GameState.parroquias[indice]
	var nomes: Array = []
	for idx in p["aldeas"]:
		nomes.append(GameState.aldeas[int(idx)]["nome"])
	var dominante := GameState.faccion_dominante(p)
	var barras := ""
	var inf: Dictionary = p["influencia"]
	for id in ["monasterio", "obispo", "nobreza", "rival"]:
		barras += "  %s: %d%%\n" % [GameState.nome_faccion(id), int(inf.get(id, 0.0))]
	%AldeaTitulo.text = "Parroquia de %s" % p["nome"]
	%AldeaInfo.text = "Agrupa %d aldeas: %s.\n\nInfluencia (domina %s):\n%s\nLas parroquias rinden diezmo en proporción a vuestra influencia." % [
		p["aldeas"].size(), ", ".join(nomes), GameState.nome_faccion(dominante), barras]
	%AccionesParroquia.visible = true
	%BtnDotarIglesia.disabled = (GameState.recursos["plata"] < GameState.COSTE_DOTAR_PLATA
		or GameState.recursos["piedra"] < GameState.COSTE_DOTAR_PIEDRA)
	%BtnDisputar.disabled = (dominante == "monasterio" or GameState.recursos["plata"] < GameState.COSTE_DISPUTA)
	%AldeaPopup.show()

func _on_btn_vista() -> void:
	GameState.solicitar_vista.emit("territorio" if _vista == "mosteiro" else "mosteiro")

func _on_vista(vista: String) -> void:
	_vista = vista
	var en_mosteiro := vista == "mosteiro"
	# Los paneles de oficios y crónica pertenecen a la vista del monasterio;
	# en el territorio se ocultan para dejar el mapa libre.
	%OficiosPanel.visible = en_mosteiro
	%CronicaPanel.visible = en_mosteiro
	%BtnVista.text = "Ir al territorio" if en_mosteiro else "Volver al monasterio"

func _on_edificio(edificio_id: String) -> void:
	_sel_edificio = edificio_id
	_pintar_popup(edificio_id)
	%Popup.show()

func _pintar_popup(edificio_id: String) -> void:
	var d: Dictionary = {}
	for e in Data.EDIFICIOS:
		if e["id"] == edificio_id:
			d = e
	if d.is_empty():
		return
	var nivel := GameState.get_nivel(edificio_id)
	%PopupTitulo.text = "%s  (nivel %d/%d)" % [d["nombre"], nivel, d["max_nivel"]]
	%PopupDesc.text = d["desc"]
	if GameState.nivel_maximo_alcanzado(edificio_id):
		%PopupCoste.text = "Nivel máximo alcanzado."
		%BtnConstruir.disabled = true
		%BtnConstruir.text = "Completado"
	else:
		var c := GameState.coste_edificio(edificio_id)
		%PopupCoste.text = "Coste: %d 🪙 plata  ·  %d 🪨 piedra" % [c["plata"], c["piedra"]]
		%BtnConstruir.disabled = not GameState.puede_construir(edificio_id)
		%BtnConstruir.text = "Ampliar" if nivel > 0 else "Construir"

func _on_construir() -> void:
	if _sel_edificio != "":
		GameState.construir(_sel_edificio)

func _on_mensaje(texto: String) -> void:
	%Cronica.append_text("• %s\n" % texto)

func _on_evento(titulo: String, texto: String) -> void:
	%EvtTitulo.text = titulo
	%EvtTexto.text = texto
	%Evento.show()
	%Cronica.append_text("[b]%s:[/b] %s\n" % [titulo, texto])

func _on_fin(texto: String) -> void:
	%ChkAuto.button_pressed = false
	%AutoTimer.stop()
	%FinTexto.text = texto
	%FinJuego.show()

func _on_reiniciar() -> void:
	%FinJuego.hide()
	%Cronica.clear()
	GameState.reset()

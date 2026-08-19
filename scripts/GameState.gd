extends Node
## Modelo y lógica de simulación del monasterio (autoload, sin parte gráfica).
##
## Toda la interfaz (Main, HUD, edificios, monjes) lee este estado y reacciona
## a sus señales. Aquí no se dibuja nada: solo se calcula el paso del tiempo,
## la producción, el consumo y los eventos.

signal estado_cambiado                       ## Algo cambió; refrescad la vista.
signal mensaje(texto: String)                ## Línea para el registro/crónica.
signal evento(titulo: String, texto: String) ## Evento aleatorio para mostrar.
signal fin_de_partida(texto: String)         ## La partida ha terminado.
signal edificio_pulsado(edificio_id: String) ## Se hizo clic en un edificio del mapa.
signal aldea_pulsada(indice: int)             ## Se hizo clic en una aldea del mapa.

# --- Estado -----------------------------------------------------------------
var recursos: Dictionary = {}
var edificios: Dictionary = {}     # id -> nivel (0 = no construido)
var asignacion: Dictionary = {}    # oficio_id -> nº de monjes asignados
var poblacion: int = 5
var mes: int = 1                   # 1..12
var anio: int = 1085               # año de fundación aproximado
var prestigio: int = 0
var terminado: bool = false

var _manuscritos_totales: float = 0.0
var _hito_prestigio: bool = false

# --- Señorío y sistema foral ------------------------------------------------
var leiras: Array = []      # patrimonio de tierras (parcelas)
var vasallos: int = 0       # familias vasallas bajo jurisdicción (cotos)
var cotos: int = 0          # cotos jurisdiccionales concedidos
var aniversarios: int = 0   # misas perpetuas comprometidas (donaciones)
var malestar: float = 10.0  # descontento campesino (0..100)
var _revuelta_ocurrida: bool = false

# --- Fundación, comarca y mapa ----------------------------------------------
const MAPA_ANCHO := 40
const MAPA_ALTO := 26
var fundado: bool = false
var comarca: String = ""
var familia: String = ""
var terreno: Array = []          # terreno[x][y] -> id de tile (0..6)
var aldeas: Array = []           # aldeas del contorno
var sitio_mosteiro: Vector2i = Vector2i(20, 13)

const MESES := [
	"Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
	"Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
]

func _ready() -> void:
	# Estado neutro inicial, salvo que ya se haya fundado (p. ej. al arrancar
	# Main directamente, cuyo _enter_tree funda antes que este _ready).
	if not fundado:
		reset()

## Estado neutro previo a la fundación (aún no hay partida).
func reset() -> void:
	recursos = {
		"comida": 0.0, "plata": 0.0, "fe": 0.0,
		"manuscritos": 0.0, "vino": 0.0, "piedra": 0.0,
	}
	edificios = {}
	for e in Data.EDIFICIOS:
		edificios[e["id"]] = 0
	asignacion = {}
	for o in Data.OFICIOS:
		asignacion[o["id"]] = 0
	poblacion = 0
	mes = 1
	anio = 750
	prestigio = 0
	terminado = false
	_manuscritos_totales = 0.0
	_prestigio_manuscritos_cobrado = 0
	_hito_prestigio = false
	leiras = []
	vasallos = 0
	cotos = 0
	aniversarios = 0
	malestar = 10.0
	_revuelta_ocurrida = false
	fundado = false
	comarca = ""
	familia = ""
	terreno = []
	aldeas = []

## Funda el monasterio en la comarca elegida por la familia elegida.
## Genera el mapa y las aldeas, y fija la dote inicial.
func fundar(comarca_id: String, familia_id: String) -> void:
	reset()
	var c := _def_comarca(comarca_id)
	var f := _def_familia(familia_id)
	comarca = comarca_id
	familia = familia_id
	anio = 750
	mes = 1
	_xerar_mapa(c)
	_xerar_aldeas(c)

	# Dote inicial de la familia más la bonificación de la comarca.
	recursos = {
		"comida": 30.0, "plata": 15.0, "fe": 6.0,
		"manuscritos": 0.0, "vino": 0.0, "piedra": 10.0,
	}
	for k in f["dote"]:
		recursos[k] += float(f["dote"][k])
	for k in c["bonus"]:
		recursos[k] += float(c["bonus"][k])
	recursos["fe"] += float(f["fe"])

	poblacion = int(f["monjes"])
	vasallos = int(f["vasallos"])
	prestigio = int(f["prestigio"])
	asignacion["huerto"] = min(3, poblacion)
	asignacion["oracion"] = max(0, min(2, poblacion - 3))

	# Patrimonio inicial de la familia, repartido entre las aldeas.
	for i in range(int(f["leiras_directas"])):
		var ld := _nova_leira_en_aldea()
		ld["estado"] = "directa"
		leiras.append(ld)
	for i in range(int(f["leiras_aforadas"])):
		var la := _nova_leira_en_aldea()
		la["estado"] = "aforada"
		la["forero"] = _nome_familia_de_aldea(la["aldea"])
		la["fraccion"] = 0.20
		la["voces"] = 3
		leiras.append(la)

	fundado = true
	estado_cambiado.emit()

# --- Generación del mapa ----------------------------------------------------

func _def_comarca(id: String) -> Dictionary:
	for c in Data.COMARCAS:
		if c["id"] == id:
			return c
	return Data.COMARCAS[0]

func _def_familia(id: String) -> Dictionary:
	for f in Data.FAMILIAS:
		if f["id"] == id:
			return f
	return Data.FAMILIAS[0]

func _xerar_mapa(c: Dictionary) -> void:
	terreno = []
	for x in range(MAPA_ANCHO):
		var col: Array = []
		for y in range(MAPA_ALTO):
			col.append(0)  # hierba
		terreno.append(col)

	# Río serpenteante de este a oeste.
	var ry := MAPA_ALTO / 2 + (randi() % 5 - 2)
	for x in range(MAPA_ANCHO):
		ry += randi() % 3 - 1
		ry = clampi(ry, 3, MAPA_ALTO - 4)
		terreno[x][ry] = 3
		if randf() < 0.5:
			terreno[x][clampi(ry + 1, 0, MAPA_ALTO - 1)] = 3

	# Bosques y montes según la comarca (montes hacia los bordes).
	for x in range(MAPA_ANCHO):
		for y in range(MAPA_ALTO):
			if terreno[x][y] != 0:
				continue
			var borde := float(min(y, MAPA_ALTO - 1 - y)) / (MAPA_ALTO / 2.0)
			var r := randf()
			if borde < 0.35 and r < float(c["monte"]):
				terreno[x][y] = 6  # monte
			elif r < float(c["bosque"]):
				terreno[x][y] = 5  # bosque

	# Emplazamiento del monasterio: junto al río, cerca del centro.
	var cx := MAPA_ANCHO / 2
	for dy in range(0, MAPA_ALTO):
		var yy := clampi(MAPA_ALTO / 2 - dy, 1, MAPA_ALTO - 2)
		if terreno[cx][yy] == 0:
			sitio_mosteiro = Vector2i(cx, yy)
			break
	# Explanada de piedra bajo el monasterio.
	for x in range(sitio_mosteiro.x - 2, sitio_mosteiro.x + 3):
		for y in range(sitio_mosteiro.y - 2, sitio_mosteiro.y + 3):
			if x >= 0 and x < MAPA_ANCHO and y >= 0 and y < MAPA_ALTO and terreno[x][y] == 0:
				terreno[x][y] = 2

func _xerar_aldeas(c: Dictionary) -> void:
	aldeas = []
	var obxectivo := int(c["aldeas"])
	var intentos := 0
	while aldeas.size() < obxectivo and intentos < 400:
		intentos += 1
		var x := 2 + randi() % (MAPA_ANCHO - 4)
		var y := 2 + randi() % (MAPA_ALTO - 4)
		if terreno[x][y] != 0:
			continue
		var pos := Vector2i(x, y)
		if pos.distance_to(sitio_mosteiro) < 5.0:
			continue
		var demasiado_cerca := false
		for a in aldeas:
			if pos.distance_to(Vector2i(a["x"], a["y"])) < 5.0:
				demasiado_cerca = true
				break
		if demasiado_cerca:
			continue
		aldeas.append(_nova_aldea(x, y, c))
		# Marca un par de campos de labor junto a la aldea.
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var fx: int = x + d.x
			var fy: int = y + d.y
			if fx >= 0 and fx < MAPA_ANCHO and fy >= 0 and fy < MAPA_ALTO and terreno[fx][fy] == 0:
				terreno[fx][fy] = 4

func _nova_aldea(x: int, y: int, c: Dictionary) -> Dictionary:
	var casas: Array = []
	var n := 3 + randi() % 3
	for i in range(n):
		casas.append(Data.CASAS_FORERAS[randi() % Data.CASAS_FORERAS.size()])
	return {
		"nome": Data.NOMES_ALDEA[randi() % Data.NOMES_ALDEA.size()],
		"x": x, "y": y,
		"poboacion": 3 + randi() % 6,
		"zona": c["zona"],
		"casas": casas,
		"afinidade": 55,
	}

func _tipo_por_zona(zona: String) -> String:
	match zona:
		"cereal": return "cereal"
		"vinha": return "vinha"
		"souto": return "souto"
		_:
			var t := ["cereal", "vinha", "souto"]
			return t[randi() % t.size()]

## Crea una leira nueva vinculada a una aldea al azar (según su zona).
func _nova_leira_en_aldea() -> Dictionary:
	var l := _nova_leira("cereal", 1 + randi() % 3)
	if aldeas.size() > 0:
		var a: Dictionary = aldeas[randi() % aldeas.size()]
		l["aldea"] = a["nome"]
		l["tipo"] = _tipo_por_zona(a["zona"])
		l["nome"] = "%s de %s" % [
			Data.TOPONIMOS_LEIRA[randi() % Data.TOPONIMOS_LEIRA.size()], a["nome"]]
	return l

func _nome_familia_de_aldea(nome_aldea: String) -> String:
	for a in aldeas:
		if a["nome"] == nome_aldea and a["casas"].size() > 0:
			return "os de " + a["casas"][randi() % a["casas"].size()]
	return _nome_familia()

# --- Consultas --------------------------------------------------------------

func get_nivel(edificio_id: String) -> int:
	return int(edificios.get(edificio_id, 0))

func monjes_asignados() -> int:
	var total := 0
	for v in asignacion.values():
		total += int(v)
	return total

func monjes_libres() -> int:
	return poblacion - monjes_asignados()

func oficio_desbloqueado(oficio: Dictionary) -> bool:
	var req: String = oficio.get("requiere", "")
	return req == "" or get_nivel(req) > 0

func capacidad_poblacion() -> int:
	return 6 + get_nivel("iglesia") * 2 + get_nivel("hospederia") * 2

func almacen_max(recurso: String) -> float:
	if recurso == "comida":
		return 80.0 + get_nivel("granero") * 120.0
	return 9999.0

func estacion() -> String:
	if mes in [12, 1, 2]:
		return "Invierno"
	elif mes in [3, 4, 5]:
		return "Primavera"
	elif mes in [6, 7, 8]:
		return "Verano"
	return "Otoño"

func _factor_estacion() -> float:
	match estacion():
		"Invierno": return 0.4
		"Primavera": return 1.0
		"Verano": return 1.3
		_: return 1.1  # Otoño

# --- Asignación de monjes ---------------------------------------------------

func asignar(oficio_id: String, delta: int) -> void:
	if terminado:
		return
	var actual := int(asignacion.get(oficio_id, 0))
	var nuevo := actual + delta
	if nuevo < 0:
		nuevo = 0
	if delta > 0 and monjes_libres() <= 0:
		return  # no hay monjes libres
	asignacion[oficio_id] = nuevo
	estado_cambiado.emit()

# --- Construcción -----------------------------------------------------------

func _def_edificio(edificio_id: String) -> Dictionary:
	for e in Data.EDIFICIOS:
		if e["id"] == edificio_id:
			return e
	return {}

func coste_edificio(edificio_id: String) -> Dictionary:
	# El coste escala con el siguiente nivel a construir.
	var d := _def_edificio(edificio_id)
	if d.is_empty():
		return {"plata": 0, "piedra": 0}
	var siguiente := get_nivel(edificio_id) + 1
	return {
		"plata": int(d["coste_plata"] * siguiente),
		"piedra": int(d["coste_piedra"] * siguiente),
	}

func nivel_maximo_alcanzado(edificio_id: String) -> bool:
	var d := _def_edificio(edificio_id)
	return not d.is_empty() and get_nivel(edificio_id) >= int(d["max_nivel"])

func puede_construir(edificio_id: String) -> bool:
	if terminado or nivel_maximo_alcanzado(edificio_id):
		return false
	var c := coste_edificio(edificio_id)
	return recursos["plata"] >= c["plata"] and recursos["piedra"] >= c["piedra"]

func construir(edificio_id: String) -> bool:
	if not puede_construir(edificio_id):
		return false
	var c := coste_edificio(edificio_id)
	recursos["plata"] -= c["plata"]
	recursos["piedra"] -= c["piedra"]
	edificios[edificio_id] = get_nivel(edificio_id) + 1
	var d := _def_edificio(edificio_id)
	if edificio_id == "iglesia":
		prestigio += 12
	mensaje.emit("Se ha construido: %s (nivel %d)." % [d["nombre"], get_nivel(edificio_id)])
	estado_cambiado.emit()
	return true

# --- Mercado ----------------------------------------------------------------

func vender(recurso: String, cantidad: float) -> void:
	if terminado or not Data.PRECIO_VENTA.has(recurso):
		return
	cantidad = min(cantidad, recursos.get(recurso, 0.0))
	if cantidad <= 0:
		return
	recursos[recurso] -= cantidad
	var ingreso: float = cantidad * float(Data.PRECIO_VENTA[recurso])
	recursos["plata"] += ingreso
	mensaje.emit("Vendido %d de %s por %d de plata." % [int(cantidad), recurso, int(ingreso)])
	estado_cambiado.emit()

# --- Avance del tiempo ------------------------------------------------------

func avanzar_mes() -> void:
	if terminado:
		return
	_producir()
	_consumir()
	_evento_aleatorio()
	_avanzar_calendario()
	_comprobar_fin()
	estado_cambiado.emit()

func _producir() -> void:
	for o in Data.OFICIOS:
		var n := int(asignacion.get(o["id"], 0))
		if n <= 0 or not oficio_desbloqueado(o):
			continue
		var prod: float = n * float(o["base"])
		match o["id"]:
			"huerto":
				prod *= _factor_estacion() * (1.0 + 0.4 * get_nivel("molino"))
			"oracion":
				prod *= 1.0 + 0.25 * get_nivel("iglesia")
			"scriptorium":
				prod *= 1.0 + (get_nivel("scriptorium") - 1) * 1.0  # nivel 2 duplica
		recursos[o["recurso"]] += prod
		if o["id"] == "scriptorium":
			_manuscritos_totales += prod

	# El prestigio crece con la obra escrita: +1 por cada 5 códices copiados.
	var ganado := int(_manuscritos_totales / 5.0) - _prestigio_manuscritos_cobrado
	if ganado > 0:
		prestigio += ganado
		_prestigio_manuscritos_cobrado += ganado

	# Tope de almacén de comida.
	recursos["comida"] = min(recursos["comida"], almacen_max("comida"))

var _prestigio_manuscritos_cobrado: int = 0

func _consumir() -> void:
	recursos["comida"] -= float(poblacion)  # cada monje come 1/mes
	if recursos["comida"] < 0.0:
		recursos["comida"] = 0.0
		recursos["fe"] = max(0.0, recursos["fe"] - 8.0)
		if poblacion > 0:
			poblacion -= 1
			_reajustar_asignacion()
			mensaje.emit("¡Hambruna! No hay comida suficiente y un hermano ha fallecido.")
	# La devoción decae lentamente si no se cultiva.
	recursos["fe"] = max(0.0, recursos["fe"] * 0.96)

func _reajustar_asignacion() -> void:
	# Si hay más monjes asignados que población, libera de los últimos oficios.
	while monjes_asignados() > poblacion:
		for i in range(Data.OFICIOS.size() - 1, -1, -1):
			var id: String = Data.OFICIOS[i]["id"]
			if int(asignacion.get(id, 0)) > 0:
				asignacion[id] -= 1
				break

func _avanzar_calendario() -> void:
	mes += 1
	if mes > 12:
		mes = 1
		anio += 1
		_fin_de_anio()

func _fin_de_anio() -> void:
	_reckoning_foral()
	# Posible ingreso de un novicio si la comunidad prospera.
	if (recursos["fe"] >= poblacion * 6.0
			and recursos["comida"] >= poblacion * 2.0
			and poblacion < capacidad_poblacion()):
		poblacion += 1
		mensaje.emit("Un novicio ha profesado. La comunidad crece a %d monjes." % poblacion)

# --- Señorío: patrimonio, foros, rentas -------------------------------------

func _nome_familia() -> String:
	return "os de " + Data.CASAS_FORERAS[randi() % Data.CASAS_FORERAS.size()]

func _nome_leira() -> String:
	var top: String = Data.TOPONIMOS_LEIRA[randi() % Data.TOPONIMOS_LEIRA.size()]
	var lugar: String = Data.LUGARES[randi() % Data.LUGARES.size()]
	return "%s de %s" % [top, lugar]

## Crea una nueva leira (parcela) yerma del tipo y calidad dados.
func _nova_leira(tipo: String, calidade: int) -> Dictionary:
	return {
		"nome": _nome_leira(),
		"tipo": tipo,
		"calidade": calidade,        # 1..3
		"estado": "yerma",           # yerma | directa | aforada
		"forero": "",
		"fraccion": 0.0,
		"voces": 0,                  # voces restantes del contrato
		"morosidade": 0.0,           # renta atrasada acumulada
		"aldea": "",                 # aldea a la que pertenece la heredad
		"pleito": false,             # ¿litigio en curso ante la Audiencia?
		"pleito_causa": "",          # impago | recuperacion
		"pleito_anos": 0,            # años que lleva el pleito
	}

func rendemento_leira(leira: Dictionary) -> float:
	# Producción anual bruta de una leira a calidad plena (sin clima).
	var base: float = Data.TIPOS_LEIRA[leira["tipo"]]["base"]
	var mults := [0.0, 1.0, 1.4, 1.8]
	var mult: float = mults[int(leira["calidade"])]
	return base * mult

func contar_leiras(estado: String) -> int:
	var n := 0
	for l in leiras:
		if l["estado"] == estado:
			n += 1
	return n

## Renta foral anual estimada (en unidades de recurso) sumando los foros.
func renta_foral_estimada() -> float:
	var total := 0.0
	for l in leiras:
		if l["estado"] == "aforada":
			total += rendemento_leira(l) * float(l["fraccion"])
	return total

# --- Acciones del señorío (invocadas desde la interfaz) ---------------------

## Otorga un foro sobre una leira yerma a una familia campesina.
func aforar(indice: int, fraccion: float) -> bool:
	if terminado or indice < 0 or indice >= leiras.size():
		return false
	var l: Dictionary = leiras[indice]
	if l["estado"] == "aforada":
		return false
	l["estado"] = "aforada"
	l["forero"] = _nome_familia()
	l["fraccion"] = fraccion
	l["voces"] = 3
	l["morosidade"] = 0.0
	mensaje.emit("Se aforó «%s» a %s por tres voces (%s)." % [
		l["nome"], l["forero"], _nome_fraccion(fraccion)])
	estado_cambiado.emit()
	return true

## Renueva un foro caducado (voces agotadas), normalmente subiendo la renta.
func renovar_foro(indice: int, fraccion: float) -> bool:
	if terminado or indice < 0 or indice >= leiras.size():
		return false
	var l: Dictionary = leiras[indice]
	if l["estado"] != "aforada" or int(l["voces"]) > 0:
		return false
	l["fraccion"] = fraccion
	l["voces"] = 3
	l["forero"] = _nome_familia()
	# Subir la renta al renovar agita al campesinado.
	malestar = clampf(malestar + _presion_fraccion(fraccion) * 0.5, 0.0, 100.0)
	mensaje.emit("Se renovó el foro de «%s» con %s a %s." % [
		l["nome"], l["forero"], _nome_fraccion(fraccion)])
	estado_cambiado.emit()
	return true

## Pone una leira en explotación directa (la trabaja el propio monasterio).
func poner_en_directa(indice: int) -> bool:
	if terminado or indice < 0 or indice >= leiras.size():
		return false
	var l: Dictionary = leiras[indice]
	if l.get("pleito", false):
		return false
	if l["estado"] == "aforada" and int(l["voces"]) > 0:
		return false  # no se puede recuperar un foro vigente
	# Recuperar una tierra aforada puede topar con la resistencia de la familia,
	# que acude a la justicia alegando su dominio útil.
	if l["estado"] == "aforada" and l["forero"] != "":
		if randf() < 0.35 + malestar * 0.004:
			_abrir_pleito(l, "recuperacion")
			mensaje.emit("Los foreros de «%s» se niegan a devolver la tierra y pleitean ante la Audiencia." % l["nome"])
			estado_cambiado.emit()
			return true
	l["estado"] = "directa"
	l["forero"] = ""
	l["fraccion"] = 0.0
	l["voces"] = 0
	mensaje.emit("«%s» pasa a explotación directa del monasterio." % l["nome"])
	estado_cambiado.emit()
	return true

## Perdona la renta atrasada de un foro, apaciguando el malestar.
func perdonar_deuda(indice: int) -> bool:
	if terminado or indice < 0 or indice >= leiras.size():
		return false
	var l: Dictionary = leiras[indice]
	if l["morosidade"] <= 0.0 or l.get("pleito", false):
		return false
	l["morosidade"] = 0.0
	malestar = clampf(malestar - 8.0, 0.0, 100.0)
	mensaje.emit("El abad perdona la deuda de %s. El campesinado lo agradece." % l["forero"])
	estado_cambiado.emit()
	return true

## Demanda a un forero moroso ante la Audiencia para cobrar la renta atrasada.
func pleitear(indice: int) -> bool:
	if terminado or indice < 0 or indice >= leiras.size():
		return false
	var l: Dictionary = leiras[indice]
	if l.get("pleito", false) or l["estado"] != "aforada" or float(l["morosidade"]) <= 0.0:
		return false
	if recursos["plata"] < 5.0:
		return false  # hacen falta procuradores y escribanos
	recursos["plata"] -= 5.0
	_abrir_pleito(l, "impago")
	malestar = clampf(malestar + 4.0, 0.0, 100.0)
	mensaje.emit("El monasterio demanda a %s por la renta impagada de «%s»." % [l["forero"], l["nome"]])
	estado_cambiado.emit()
	return true

func _abrir_pleito(l: Dictionary, causa: String) -> void:
	l["pleito"] = true
	l["pleito_causa"] = causa
	l["pleito_anos"] = 0

func pleitos_en_curso() -> int:
	var n := 0
	for l in leiras:
		if l.get("pleito", false):
			n += 1
	return n

func causa_pleito_txt(causa: String) -> String:
	match causa:
		"impago": return "por impago de la renta"
		"recuperacion": return "sobre el dominio de la tierra"
		_: return ""

## Reparte limosna entre los pobres: gasta recursos para calmar el malestar.
func dar_limosna() -> bool:
	if terminado:
		return false
	if recursos["comida"] < 10.0 or recursos["plata"] < 5.0:
		return false
	recursos["comida"] -= 10.0
	recursos["plata"] -= 5.0
	malestar = clampf(malestar - 12.0, 0.0, 100.0)
	recursos["fe"] += 3.0
	mensaje.emit("Se reparte limosna a la puerta del monasterio.")
	estado_cambiado.emit()
	return true

func _nome_fraccion(valor: float) -> String:
	for f in Data.FRACCIONES:
		if is_equal_approx(float(f["valor"]), valor):
			return f["nombre"]
	return "%.2f" % valor

func _presion_fraccion(valor: float) -> float:
	for f in Data.FRACCIONES:
		if is_equal_approx(float(f["valor"]), valor):
			return float(f["presion"])
	return 5.0

# --- Balance anual del señorío (rentas forales, diezmo, malestar) -----------

func _reckoning_foral() -> void:
	var clima := randf_range(0.7, 1.2)  # cosecha del año
	var estacion_txt := "San Martiño del año %d" % anio
	var renta_comida := 0.0
	var renta_vino := 0.0
	var renta_plata := 0.0
	var suma_presion := 0.0
	var n_aforadas := 0

	for l in leiras:
		var recurso: String = Data.TIPOS_LEIRA[l["tipo"]]["recurso"]
		if l.get("pleito", false):
			continue  # las tierras en litigio no rinden renta hasta la sentencia
		match l["estado"]:
			"aforada":
				n_aforadas += 1
				suma_presion += _presion_fraccion(l["fraccion"])
				var cosecha := rendemento_leira(l) * clima
				var renta := cosecha * float(l["fraccion"])
				# Impago si el malestar es alto.
				if malestar > 50.0 and randf() < (malestar - 50.0) / 90.0:
					l["morosidade"] += renta
					mensaje.emit("%s no pudo pagar la renta de «%s»." % [l["forero"], l["nome"]])
				else:
					renta_plata += 1.0  # dereitos, capones y foros en dinero
					if recurso == "vino":
						renta_vino += renta
					else:
						renta_comida += renta
				# Paso de una voz (muerte de una generación) y luctuosa.
				if randf() < 0.14 and int(l["voces"]) > 0:
					l["voces"] = int(l["voces"]) - 1
					renta_plata += 3.0  # luctuosa
					if int(l["voces"]) <= 0:
						mensaje.emit("Caducó el foro de «%s»: puede renovarse o recuperarse." % l["nome"])
			"directa":
				# El monasterio percibe todo el fruto, pero paga a los serventes.
				var fruto := rendemento_leira(l) * clima
				var custo := fruto * 0.4
				if recursos["plata"] >= custo:
					recursos["plata"] -= custo
					if recurso == "vino":
						renta_vino += fruto
					else:
						renta_comida += fruto
				else:
					# Sin plata para jornaleros, solo se recoge la mitad.
					if recurso == "vino":
						renta_vino += fruto * 0.5
					else:
						renta_comida += fruto * 0.5

	recursos["comida"] = min(recursos["comida"] + renta_comida, almacen_max("comida"))
	recursos["vino"] += renta_vino
	recursos["plata"] += renta_plata

	# Diezmo y rentas del señorío jurisdiccional (cotos y vasallos).
	var diezmo_comida := cotos * 4.0 + vasallos * 0.6
	var diezmo_plata := cotos * 3.0 + vasallos * 0.8 + prestigio * 0.05
	recursos["comida"] = min(recursos["comida"] + diezmo_comida, almacen_max("comida"))
	recursos["plata"] += diezmo_plata

	# Aniversarios: cumplir las misas perpetuas cuesta devoción.
	if aniversarios > 0:
		recursos["fe"] = max(0.0, recursos["fe"] - aniversarios * 0.4)

	# Evolución del malestar campesino.
	var presion_media := (suma_presion / n_aforadas) if n_aforadas > 0 else 0.0
	malestar += presion_media
	malestar += cotos * 1.5
	if clima < 0.85:
		malestar += 6.0          # las malas cosechas encienden los ánimos
	else:
		malestar -= 4.0
	malestar = clampf(malestar - 3.0, 0.0, 100.0)  # decaimiento base

	if renta_comida + renta_vino > 0.0:
		mensaje.emit("Rentas forales de %s: %d de comida, %d de vino, %d de plata." % [
			estacion_txt, int(renta_comida), int(renta_vino), int(renta_plata + diezmo_plata)])

	_procesar_pleitos()
	_comprobar_revuelta()

# --- Pleitos forales ante la Audiencia de Galicia ---------------------------

func _procesar_pleitos() -> void:
	for l in leiras:
		# Pleito espontáneo: una deuda enconada acaba ante la justicia.
		if (not l.get("pleito", false) and l["estado"] == "aforada"
				and float(l["morosidade"]) >= rendemento_leira(l) * 0.5
				and malestar > 55.0 and randf() < 0.25):
			_abrir_pleito(l, "impago")
			evento.emit("Pleito foral",
				"El foro de «%s» acaba en pleito ante la Audiencia de Galicia %s." % [
					l["nome"], causa_pleito_txt("impago")])
		if not l.get("pleito", false):
			continue
		l["pleito_anos"] = int(l["pleito_anos"]) + 1
		recursos["plata"] = max(0.0, recursos["plata"] - 4.0)  # costas: procuradores y escribanos
		# La probabilidad de sentencia crece con los años de litigio.
		if randf() < 0.35 + int(l["pleito_anos"]) * 0.15:
			_resolver_pleito(l)

func _resolver_pleito(l: Dictionary) -> void:
	var favorable := clampf(0.45 + prestigio * 0.0015 - malestar * 0.002, 0.15, 0.85)
	var gana := randf() < favorable
	var causa: String = l["pleito_causa"]
	var nome: String = l["nome"]
	# Cerrar el pleito.
	l["pleito"] = false
	l["pleito_causa"] = ""
	l["pleito_anos"] = 0
	match causa:
		"impago":
			if gana:
				var cobro: float = float(l["morosidade"]) * 0.6
				recursos["plata"] += cobro
				l["morosidade"] = 0.0
				malestar = clampf(malestar + 5.0, 0.0, 100.0)
				evento.emit("Sentencia favorable",
					"La Audiencia falla a favor del monasterio: %s paga lo debido de «%s» (%d de plata)." % [
						l["forero"], nome, int(cobro)])
			else:
				l["morosidade"] = 0.0
				prestigio = max(0, prestigio - 3)
				malestar = clampf(malestar - 3.0, 0.0, 100.0)
				evento.emit("Sentencia adversa",
					"El tribunal exime a %s de la deuda de «%s». El monasterio carga con las costas." % [
						l["forero"], nome])
		"recuperacion":
			if gana:
				l["estado"] = "yerma"
				l["forero"] = ""
				l["fraccion"] = 0.0
				l["voces"] = 0
				l["morosidade"] = 0.0
				malestar = clampf(malestar + 6.0, 0.0, 100.0)
				evento.emit("Sentencia favorable",
					"La Audiencia reconoce el dominio directo del monasterio: se recupera «%s»." % nome)
			else:
				# Los foreros conservan la tierra con renta reducida.
				l["estado"] = "aforada"
				l["fraccion"] = 0.125  # oitavo
				l["voces"] = 3
				l["morosidade"] = 0.0
				prestigio = max(0, prestigio - 3)
				malestar = clampf(malestar - 4.0, 0.0, 100.0)
				evento.emit("Sentencia adversa",
					"Los foreros ganan el pleito y conservan «%s» con renta rebajada a oitavo." % nome)

## La gran revuelta de los irmandiños si la presión señorial es insoportable.
func _comprobar_revuelta() -> void:
	if malestar < 80.0:
		return
	if randf() > (malestar - 78.0) / 30.0:
		return
	_revuelta_ocurrida = true
	var perdidas := 0
	for l in leiras:
		if l["estado"] == "aforada" and randf() < 0.5:
			l["estado"] = "yerma"
			l["forero"] = ""
			l["voces"] = 0
			l["morosidade"] = 0.0
			l["pleito"] = false
			l["pleito_causa"] = ""
			l["pleito_anos"] = 0
			perdidas += 1
	recursos["plata"] = max(0.0, recursos["plata"] - 30.0)
	recursos["comida"] = max(0.0, recursos["comida"] - 20.0)
	vasallos = int(vasallos * 0.5)
	prestigio = max(0, prestigio - 10)
	malestar = 40.0
	evento.emit("¡Revuelta de los irmandiños!",
		"El campesinado se levanta contra el señorío. Se abandonan %d foros y arden las rentas. La comunidad tardará años en recomponer su patrimonio." % perdidas)

func _comprobar_fin() -> void:
	if poblacion <= 0:
		terminado = true
		fin_de_partida.emit("El último monje ha partido. El monasterio queda en ruinas.")
		return
	if not _hito_prestigio and prestigio >= 150:
		_hito_prestigio = true
		mensaje.emit("El renombre de vuestro monasterio se extiende por toda Galicia.")

# --- Eventos ----------------------------------------------------------------

func _evento_aleatorio() -> void:
	if randf() > 0.30:  # ~30% de probabilidad por mes
		return
	var total_peso := 0
	for e in Data.EVENTOS:
		total_peso += int(e["peso"])
	var r := randi() % total_peso
	var acum := 0
	for e in Data.EVENTOS:
		acum += int(e["peso"])
		if r < acum:
			aplicar_evento(e["id"])
			evento.emit(e["titulo"], e["texto"])
			return

func aplicar_evento(id: String) -> void:
	match id:
		"buena_cosecha":
			recursos["comida"] = min(recursos["comida"] + 25.0, almacen_max("comida"))
		"donacion_noble":
			recursos["plata"] += 25.0
			recursos["piedra"] += 8.0
		"peregrinos":
			recursos["plata"] += 12.0
			recursos["fe"] += 8.0
			prestigio += 2
		"milagro":
			recursos["fe"] += 15.0
			prestigio += 6
		"incursion_normanda":
			recursos["plata"] = max(0.0, recursos["plata"] - 20.0)
			recursos["comida"] = max(0.0, recursos["comida"] - 20.0)
		"peste":
			var protegido := get_nivel("enfermeria") > 0
			recursos["fe"] = max(0.0, recursos["fe"] - 6.0)
			if not protegido and poblacion > 1 and randf() < 0.6:
				poblacion -= 1
				_reajustar_asignacion()
		"incendio":
			recursos["manuscritos"] = max(0.0, recursos["manuscritos"] - 5.0)
			recursos["comida"] = max(0.0, recursos["comida"] - 10.0)
		"sequia":
			recursos["comida"] = max(0.0, recursos["comida"] - 15.0)
		"visita_obispo":
			if get_nivel("iglesia") > 0 and recursos["fe"] >= 10.0:
				prestigio += 8
			else:
				recursos["fe"] = max(0.0, recursos["fe"] - 5.0)
		"novicio_ilustre":
			if poblacion < capacidad_poblacion():
				poblacion += 1
		"donacion_leira":
			# Nueva heredad al patrimonio, a cambio de un aniversario perpetuo.
			leiras.append(_nova_leira_en_aldea())
			aniversarios += 1
			prestigio += 3
		"manda_testamentaria":
			recursos["plata"] += 20.0
			aniversarios += 1
			prestigio += 2
		"concesion_coto":
			cotos += 1
			vasallos += 4 + randi() % 4
			prestigio += 8

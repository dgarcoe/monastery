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

const MESES := [
	"Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
	"Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
]

func _ready() -> void:
	reset()

## Reinicia la partida a su estado inicial.
func reset() -> void:
	recursos = {
		"comida": 60.0, "plata": 30.0, "fe": 12.0,
		"manuscritos": 0.0, "vino": 0.0, "piedra": 20.0,
	}
	edificios = {}
	for e in Data.EDIFICIOS:
		edificios[e["id"]] = 0
	asignacion = {}
	for o in Data.OFICIOS:
		asignacion[o["id"]] = 0
	poblacion = 5
	mes = 1
	anio = 1085
	prestigio = 0
	terminado = false
	_manuscritos_totales = 0.0
	_prestigio_manuscritos_cobrado = 0
	_hito_prestigio = false
	# Asignación inicial razonable: labranza y oración.
	asignacion["huerto"] = 3
	asignacion["oracion"] = 2
	# Patrimonio inicial del monasterio.
	leiras = []
	vasallos = 0
	cotos = 0
	aniversarios = 0
	malestar = 10.0
	_revuelta_ocurrida = false
	var reserva := _nova_leira("cereal", 2)   # reserva propia, en explotación directa
	reserva["estado"] = "directa"
	leiras.append(reserva)
	leiras.append(_nova_leira("vinha", 1))    # yerma, lista para aforar
	var aforada := _nova_leira("souto", 1)    # ya aforada a una familia
	aforada["estado"] = "aforada"
	aforada["forero"] = _nome_familia()
	aforada["fraccion"] = 0.20
	aforada["voces"] = 3
	leiras.append(aforada)
	estado_cambiado.emit()

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
	if l["estado"] == "aforada" and int(l["voces"]) > 0:
		return false  # no se puede recuperar un foro vigente
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
	if l["morosidade"] <= 0.0:
		return false
	l["morosidade"] = 0.0
	malestar = clampf(malestar - 8.0, 0.0, 100.0)
	mensaje.emit("El abad perdona la deuda de %s. El campesinado lo agradece." % l["forero"])
	estado_cambiado.emit()
	return true

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

	_comprobar_revuelta()

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
			var tipos := ["cereal", "vinha", "souto"]
			var nova := _nova_leira(tipos[randi() % tipos.size()], 1 + randi() % 3)
			leiras.append(nova)
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

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
	# Posible ingreso de un novicio si la comunidad prospera.
	if (recursos["fe"] >= poblacion * 6.0
			and recursos["comida"] >= poblacion * 2.0
			and poblacion < capacidad_poblacion()):
		poblacion += 1
		mensaje.emit("Un novicio ha profesado. La comunidad crece a %d monjes." % poblacion)

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

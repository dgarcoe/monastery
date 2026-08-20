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
signal parroquia_pulsada(indice: int)         ## Se hizo clic en una parroquia.
signal leira_pulsada(indice: int)             ## Se hizo clic en una leira del mapa.
signal vista_cambiada(vista: String)          ## Vista aplicada: "mosteiro" | "territorio".
signal solicitar_vista(vista: String)         ## Petición de cambio de vista.

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
const MAPA_ANCHO := 64
const MAPA_ALTO := 40
var fundado: bool = false
var comarca: String = ""
var familia: String = ""
var terreno: Array = []          # terreno[x][y] -> id de tile (0..8)
var aldeas: Array = []           # aldeas del contorno (todas)
var _nomes_aldea_usados: Dictionary = {}  # evita repetir nombre de aldea
var parroquias: Array = []       # parroquias, cada una con sus aldeas e influencia
var sitio_mosteiro: Vector2i = Vector2i(32, 20)
var sitio_rival: Vector2i = Vector2i(-1, -1)  # emplazamiento del monasterio rival
var explotacions: Array = []     # muíños, canteiras y pastos construidos
var modo_construccion: String = ""  # tipo de EXPLOTACIONS a colocar, o ""

# --- Rivalidad: facciones que disputan el territorio ------------------------
# id -> {nome, poder, relacion(-100..100)}. "poder" mueve cuánta influencia
# empuja la facción cada año; "relacion" atenúa su agresividad hacia el jugador.
var facciones: Dictionary = {}

# --- Mercado regional ---------------------------------------------------------
var precios: Dictionary = {}     # bien -> precio actual (plata/unidad)
var feira: bool = false          # privilegio real de feira y portazgo

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
	_nomes_aldea_usados = {}
	parroquias = []
	explotacions = []
	facciones = {}
	precios = {}
	feira = false

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
	_xerar_parroquias(c)
	_xerar_influencia()
	_xerar_facciones(c)
	_xerar_sitio_rival()
	explotacions = []
	modo_construccion = ""

	# Dote inicial de la familia más la bonificación de la comarca.
	recursos = {
		"comida": 30.0, "plata": 15.0, "fe": 6.0,
		"manuscritos": 0.0, "vino": 0.0, "piedra": 10.0, "gando": 0.0,
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

	# Regatos: pequeños afluentes que bajan del monte hacia el río.
	var n_regatos := 4 + randi() % 4
	for i in range(n_regatos):
		var rx := randi() % MAPA_ANCHO
		var y0 := 1 if randf() < 0.5 else MAPA_ALTO - 2
		var pasos := MAPA_ALTO / 2
		var x := rx
		var y := y0
		var dy := 1 if y0 < MAPA_ALTO / 2 else -1
		for p in range(pasos):
			if x < 0 or x >= MAPA_ANCHO or y < 0 or y >= MAPA_ALTO:
				break
			if terreno[x][y] == 0 or terreno[x][y] == 5 or terreno[x][y] == 6:
				terreno[x][y] = 7  # regato
			if terreno[x][y] == 3:
				break  # llegó al río
			y += dy
			x += randi() % 3 - 1
			x = clampi(x, 0, MAPA_ANCHO - 1)

	# Brañas de pasto en pequeñas manchas, sobre hierba libre.
	var n_brañas := 3 + randi() % 3
	for i in range(n_brañas):
		var bx := 2 + randi() % (MAPA_ANCHO - 4)
		var by := 2 + randi() % (MAPA_ALTO - 4)
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				var xx := bx + ox
				var yy2 := by + oy
				if xx >= 0 and xx < MAPA_ANCHO and yy2 >= 0 and yy2 < MAPA_ALTO and terreno[xx][yy2] == 0:
					if randf() < 0.7:
						terreno[xx][yy2] = 8  # pasto

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

## Genera las parroquias del contorno, cada una con 3–6 aldeas agrupadas.
func _xerar_parroquias(c: Dictionary) -> void:
	aldeas = []
	parroquias = []
	var n_parr := int(c.get("parroquias", 3))
	var intentos := 0
	while parroquias.size() < n_parr and intentos < 800:
		intentos += 1
		var px := 5 + randi() % (MAPA_ANCHO - 10)
		var py := 5 + randi() % (MAPA_ALTO - 10)
		if terreno[px][py] != 0:
			continue
		var pc := Vector2i(px, py)
		if pc.distance_to(sitio_mosteiro) < 9.0:
			continue
		var cerca := false
		for p in parroquias:
			if pc.distance_to(Vector2i(p["x"], p["y"])) < 12.0:
				cerca = true
				break
		if cerca:
			continue
		var idx_parr := parroquias.size()
		var parr := {
			"nome": "%s de %s" % [
				Data.ADVOCACIONS[randi() % Data.ADVOCACIONS.size()],
				Data.LUGARES[randi() % Data.LUGARES.size()]],
			"x": px, "y": py, "aldeas": [],
			# Influencia inicial: el monasterio parte fuerte cerca de casa, el
			# obispo controla la mayor parte del resto (es lo habitual: el
			# diezmo diocesano), y hidalgos/rival se reparten un remanente.
			"influencia": {"monasterio": 0.0, "obispo": 0.0, "nobreza": 0.0, "rival": 0.0},
		}
		parroquias.append(parr)
		terreno[px][py] = 2  # atrio de piedra de la iglesia parroquial
		# 3–6 aldeas alrededor de la parroquia.
		var n_ald := 3 + randi() % 4
		var colocadas := 0
		var t2 := 0
		while colocadas < n_ald and t2 < 300:
			t2 += 1
			var ax := clampi(px + randi() % 13 - 6, 1, MAPA_ANCHO - 2)
			var ay := clampi(py + randi() % 13 - 6, 1, MAPA_ALTO - 2)
			if terreno[ax][ay] != 0:
				continue
			var apos := Vector2i(ax, ay)
			if apos.distance_to(pc) < 2.0 or apos.distance_to(sitio_mosteiro) < 6.0:
				continue
			var solapa := false
			for a in aldeas:
				if apos.distance_to(Vector2i(a["x"], a["y"])) < 3.0:
					solapa = true
					break
			if solapa:
				continue
			var ald := _nova_aldea(ax, ay, c)
			ald["parroquia"] = parr["nome"]
			ald["parroquia_idx"] = idx_parr
			parr["aldeas"].append(aldeas.size())
			# Marca campos de labor junto a la aldea: hasta 6 celdas propias
			# donde luego se plantarán las leiras reales de esta aldea.
			var campos: Array = []
			var offsets := [
				Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
			]
			for d: Vector2i in offsets:
				if campos.size() >= 6:
					break
				var fx: int = ax + d.x
				var fy: int = ay + d.y
				if fx >= 0 and fx < MAPA_ANCHO and fy >= 0 and fy < MAPA_ALTO and terreno[fx][fy] == 0:
					terreno[fx][fy] = 4
					campos.append(Vector2i(fx, fy))
			ald["campos"] = campos
			ald["campos_libres"] = campos.duplicate()
			aldeas.append(ald)
			colocadas += 1

## Reparte la influencia inicial de cada parroquia entre las cuatro partes:
## el monasterio parte fuerte en las parroquias más cercanas a casa, el
## obispo controla por defecto buena parte del resto (el diezmo diocesano es
## la situación de partida), y hidalgos/rival se reparten un remanente menor.
func _xerar_influencia() -> void:
	if parroquias.is_empty():
		return
	var dist_max := 0.0
	for p in parroquias:
		dist_max = maxf(dist_max, Vector2i(p["x"], p["y"]).distance_to(sitio_mosteiro))
	for p in parroquias:
		var d := Vector2i(p["x"], p["y"]).distance_to(sitio_mosteiro)
		var cercania := 1.0 - (d / dist_max if dist_max > 0.0 else 0.0)  # 1 = pegada, 0 = lejana
		var mon := 15.0 + 25.0 * cercania
		var obispo := 45.0 - 10.0 * cercania
		var resto := 100.0 - mon - obispo
		p["influencia"] = {
			"monasterio": mon, "obispo": obispo,
			"nobreza": resto * 0.6, "rival": resto * 0.4,
		}

func _xerar_facciones(c: Dictionary) -> void:
	facciones = {}
	for id in Data.FACCIONES:
		var d: Dictionary = Data.FACCIONES[id]
		facciones[id] = {
			"nome": d["nombre"], "poder": float(d["agresividade"]) * float(c.get("riesgo", 1.0)),
			"relacion": 0.0,
		}

## Facción con más influencia en una parroquia (o "" si no la hay).
func faccion_dominante(parroquia: Dictionary) -> String:
	var inf: Dictionary = parroquia.get("influencia", {})
	var mellor := ""
	var val := -1.0
	for id in inf:
		if float(inf[id]) > val:
			val = float(inf[id])
			mellor = id
	return mellor

func nome_faccion(id: String) -> String:
	if id == "monasterio":
		return "Vuestro monasterio"
	return facciones.get(id, {}).get("nome", Data.FACCIONES.get(id, {}).get("nombre", id))

## Sitúa al monasterio rival en un punto alejado del propio, para marcarlo en
## el territorio (solo un marcador visual: no gestiona edificios ni monjes).
func _xerar_sitio_rival() -> void:
	sitio_rival = Vector2i(-1, -1)
	var mellor_d := 0.0
	var intentos := 0
	while intentos < 200:
		intentos += 1
		var x := 3 + randi() % (MAPA_ANCHO - 6)
		var y := 3 + randi() % (MAPA_ALTO - 6)
		if int(terreno[x][y]) != 0:
			continue
		var d := Vector2i(x, y).distance_to(sitio_mosteiro)
		if d > mellor_d:
			mellor_d = d
			sitio_rival = Vector2i(x, y)
		if d > float(MAPA_ANCHO) * 0.6:
			break

## Nº de parroquias donde el monasterio es la facción dominante.
func parroquias_dominadas() -> int:
	var n := 0
	for p in parroquias:
		if faccion_dominante(p) == "monasterio":
			n += 1
	return n

## Nombre de aldea sin repetir dentro de la partida. Si se agotase la lista
## de topónimos (no ocurre con el máximo actual de aldeas), combina dos para
## seguir garantizando nombres distintos.
func _novo_nome_aldea() -> String:
	var candidatos: Array = []
	for n in Data.NOMES_ALDEA:
		if not _nomes_aldea_usados.has(n):
			candidatos.append(n)
	var nome: String
	if not candidatos.is_empty():
		nome = candidatos[randi() % candidatos.size()]
	else:
		var base: String = Data.NOMES_ALDEA[randi() % Data.NOMES_ALDEA.size()]
		var otro: String = Data.NOMES_ALDEA[randi() % Data.NOMES_ALDEA.size()]
		nome = "%s de %s" % [base, otro]
		var intentos := 0
		while _nomes_aldea_usados.has(nome) and intentos < 20:
			otro = Data.NOMES_ALDEA[randi() % Data.NOMES_ALDEA.size()]
			nome = "%s de %s" % [base, otro]
			intentos += 1
	_nomes_aldea_usados[nome] = true
	return nome

func _nova_aldea(x: int, y: int, c: Dictionary) -> Dictionary:
	var casas: Array = []
	var n := 3 + randi() % 3
	for i in range(n):
		casas.append(Data.CASAS_FORERAS[randi() % Data.CASAS_FORERAS.size()])
	return {
		"nome": _novo_nome_aldea(),
		"x": x, "y": y,
		"poboacion": 3 + randi() % 6,
		"zona": c["zona"],
		"casas": casas,
		"afinidade": 55,
	}

## Elige un cultivo propio de la zona indicada.
func _cultivo_por_zona(zona: String) -> String:
	var candidatos: Array = []
	for id in Data.CULTIVOS:
		if zona in Data.CULTIVOS[id]["zonas"]:
			candidatos.append(id)
	if candidatos.is_empty():
		return "centeno"
	return candidatos[randi() % candidatos.size()]

## Calidad de una celda de campo según el terreno real que la rodea: la
## cercanía al agua (río o regato) la hace más fértil, la cercanía al monte
## la empobrece. Así el mapa deja de ser decorado: dicta la calidad real de
## la leira que se plante ahí.
func _calidade_de_tile(x: int, y: int) -> int:
	var puntos := 1
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or nx >= MAPA_ANCHO or ny < 0 or ny >= MAPA_ALTO:
				continue
			match int(terreno[nx][ny]):
				3, 7: puntos += 1  # agua o regato cerca: veiga fértil
				6: puntos -= 1     # monte cerca: tierra pobre
	return clampi(puntos, 1, 3)

## Reserva una celda de campo libre para una nueva leira: preferentemente de
## la propia aldea, si no de otra de la misma parroquia. Devuelve (-1,-1) si
## no queda ninguna celda libre en todo el contorno.
func _asignar_campo(aldea_idx: int) -> Vector2i:
	if aldea_idx < 0 or aldea_idx >= aldeas.size():
		return Vector2i(-1, -1)
	var a: Dictionary = aldeas[aldea_idx]
	var libres: Array = a.get("campos_libres", [])
	if not libres.is_empty():
		return libres.pop_back()
	var parr_idx: int = int(a.get("parroquia_idx", -1))
	if parr_idx >= 0 and parr_idx < parroquias.size():
		for idx in parroquias[parr_idx]["aldeas"]:
			var vecina: Dictionary = aldeas[int(idx)]
			var libres_v: Array = vecina.get("campos_libres", [])
			if not libres_v.is_empty():
				return libres_v.pop_back()
	return Vector2i(-1, -1)

## Comprueba si queda campo libre para esta aldea (propio o de una vecina de
## la misma parroquia) sin reservarlo, para saber si una donación es posible.
func _hay_campo_libre(aldea_idx: int) -> bool:
	if aldea_idx < 0 or aldea_idx >= aldeas.size():
		return false
	var a: Dictionary = aldeas[aldea_idx]
	if not a.get("campos_libres", []).is_empty():
		return true
	var parr_idx: int = int(a.get("parroquia_idx", -1))
	if parr_idx >= 0 and parr_idx < parroquias.size():
		for idx in parroquias[parr_idx]["aldeas"]:
			if not aldeas[int(idx)].get("campos_libres", []).is_empty():
				return true
	return false

## Crea una leira nueva vinculada a una aldea al azar (según su zona), atada
## a una celda de campo real del mapa cuando queda alguna disponible.
## aldea_idx = -1 elige una aldea al azar (preferentemente con campos libres);
## si se indica un índice concreto, la heredad se planta ahí (obras pías).
func _nova_leira_en_aldea(aldea_idx: int = -1) -> Dictionary:
	var l := _nova_leira("centeno", 1)
	if aldeas.is_empty():
		return l
	var idx: int = aldea_idx
	if idx < 0 or idx >= aldeas.size():
		# Prefiere aldeas que aún tengan campos libres.
		var candidatas: Array = []
		for i in range(aldeas.size()):
			if not aldeas[i].get("campos_libres", []).is_empty():
				candidatas.append(i)
		idx = (candidatas[randi() % candidatas.size()] if not candidatas.is_empty()
			else randi() % aldeas.size())
	var a: Dictionary = aldeas[idx]
	l["aldea"] = a["nome"]
	l["cultivo"] = _cultivo_por_zona(a["zona"])
	l["nome"] = "%s de %s" % [
		Data.TOPONIMOS_LEIRA[randi() % Data.TOPONIMOS_LEIRA.size()], a["nome"]]
	var celda := _asignar_campo(idx)
	if celda.x >= 0:
		l["x"] = celda.x
		l["y"] = celda.y
		l["calidade"] = _calidade_de_tile(celda.x, celda.y)
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
	if terminado or not Data.BENS_MERCADO.has(recurso):
		return
	cantidad = min(cantidad, recursos.get(recurso, 0.0))
	if cantidad <= 0:
		return
	recursos[recurso] -= cantidad
	var ingreso: float = cantidad * precio_venta(recurso)
	recursos["plata"] += ingreso
	mensaje.emit("Vendido %d de %s por %d de plata." % [int(cantidad), recurso, int(ingreso)])
	estado_cambiado.emit()

## Compra un bien del mercado regional (p. ej. sal, que el monasterio no
## produce). El precio de compra es siempre algo mayor que el de venta.
func comprar(recurso: String, cantidad: float) -> bool:
	if terminado or not Data.BENS_MERCADO.has(recurso) or cantidad <= 0.0:
		return false
	var coste := cantidad * precio_compra(recurso)
	if recursos["plata"] < coste:
		return false
	recursos["plata"] -= coste
	recursos[recurso] = recursos.get(recurso, 0.0) + cantidad
	mensaje.emit("Comprado %d de %s por %d de plata." % [int(cantidad), recurso, int(coste)])
	estado_cambiado.emit()
	return true

# --- Explotaciones (muíño, canteira, pasto) ----------------------------------

## Activa el modo colocación: el siguiente clic válido en el territorio
## construirá una explotación de este tipo (ver Main._unhandled_input).
func iniciar_construccion(tipo: String) -> void:
	modo_construccion = tipo
	estado_cambiado.emit()

func cancelar_construccion() -> void:
	modo_construccion = ""
	estado_cambiado.emit()

## Construye una explotación sobre un tile del territorio (regato, monte o
## braña, según el tipo). No se comprueba solapamiento entre explotaciones:
## el jugador elige libremente la celda al hacer clic en el mapa.
func construir_explotacion(tipo: String, x: int, y: int) -> bool:
	if terminado or not Data.EXPLOTACIONS.has(tipo):
		return false
	var d: Dictionary = Data.EXPLOTACIONS[tipo]
	if x < 0 or x >= MAPA_ANCHO or y < 0 or y >= MAPA_ALTO or int(terreno[x][y]) != int(d["requiere_tile"]):
		mensaje.emit("Ahí no se puede levantar un(a) %s: hace falta %s." % [
			d["nombre"], _nome_tile_requirido(int(d["requiere_tile"]))])
		return false  # se mantiene el modo construcción para reintentar
	if recursos["plata"] < float(d["coste_plata"]) or recursos["piedra"] < float(d["coste_piedra"]):
		mensaje.emit("No hay recursos suficientes para el %s." % d["nombre"])
		modo_construccion = ""
		estado_cambiado.emit()
		return false
	recursos["plata"] -= float(d["coste_plata"])
	recursos["piedra"] -= float(d["coste_piedra"])
	explotacions.append({"tipo": tipo, "x": x, "y": y})
	mensaje.emit("Se levanta un(a) %s en el territorio." % d["nombre"])
	modo_construccion = ""
	estado_cambiado.emit()
	return true

func _nome_tile_requirido(id: int) -> String:
	match id:
		6: return "monte"
		7: return "regato"
		8: return "pasto"
		_: return "terreno adecuado"

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
	_reckoning_mercado()
	_reckoning_politico()
	# La afinidad decae hacia un poso de devoción antigua si no se cultiva:
	# obliga a mantener las obras pías, no solo a hacerlas una vez.
	for a in aldeas:
		a["afinidade"] = maxf(30.0, float(a["afinidade"]) - 6.0)
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

## Crea una nueva leira (parcela) yerma del cultivo y calidad dados.
func _nova_leira(cultivo: String, calidade: int) -> Dictionary:
	return {
		"nome": _nome_leira(),
		"cultivo": cultivo,          # centeno | trigo | mijo | vinha | souto
		"calidade": calidade,        # 1..3
		"estado": "yerma",           # yerma | directa | aforada
		"forero": "",
		"fraccion": 0.0,
		"voces": 0,                  # voces restantes del contrato
		"morosidade": 0.0,           # renta atrasada acumulada (en ferrados/azumbres)
		"aldea": "",                 # aldea a la que pertenece la heredad
		"x": -1, "y": -1,            # celda de campo real en el mapa (-1 = sin asignar)
		"pleito": false,             # ¿litigio en curso ante la Audiencia?
		"pleito_causa": "",          # impago | recuperacion
		"pleito_anos": 0,            # años que lleva el pleito
	}

## Definición del cultivo de una leira.
func cultivo_de(leira: Dictionary) -> Dictionary:
	return Data.CULTIVOS.get(leira.get("cultivo", "centeno"), Data.CULTIVOS["centeno"])

## Recurso del monasterio que alimenta este cultivo: "comida" o "vino".
func _recurso_de_cultivo(leira: Dictionary) -> String:
	return "vino" if cultivo_de(leira)["producto"] == "vino" else "comida"

## Producción anual bruta de una leira (en ferrados o azumbres), con su calidad.
func rendemento_leira(leira: Dictionary) -> float:
	var base: float = cultivo_de(leira)["base"]
	var mults := [0.0, 1.0, 1.4, 1.8]
	var mult: float = mults[int(leira["calidade"])]
	return base * mult

func contar_leiras(estado: String) -> int:
	var n := 0
	for l in leiras:
		if l["estado"] == estado:
			n += 1
	return n

## Renta foral anual estimada, separada en ferrados de grano/castañas y
## azumbres de vino (a calidad plena, sin clima).
func renta_foral_estimada() -> Dictionary:
	var grao := 0.0
	var vino := 0.0
	for l in leiras:
		if l["estado"] == "aforada":
			var r := rendemento_leira(l) * float(l["fraccion"])
			if cultivo_de(l)["producto"] == "vino":
				vino += r
			else:
				grao += r
	return {"grao": grao, "vino": vino}

## Renta esperada (en su unidad) de una leira concreta según su fracción.
func renta_leira(leira: Dictionary) -> float:
	return rendemento_leira(leira) * float(leira.get("fraccion", 0.0))

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

# --- Rivalidad: acciones del jugador sobre las parroquias -------------------

const COSTE_DOTAR_PLATA := 15.0
const COSTE_DOTAR_PIEDRA := 10.0
const COSTE_FAVOR := 15.0
const COSTE_DISPUTA := 20.0

## Dota la iglesia parroquial (obras, ornato, limosnas locales): gana
## influencia del monasterio en esa parroquia, a costa de quien más tenga.
func dotar_iglesia(indice: int) -> bool:
	if terminado or indice < 0 or indice >= parroquias.size():
		return false
	if recursos["plata"] < COSTE_DOTAR_PLATA or recursos["piedra"] < COSTE_DOTAR_PIEDRA:
		return false
	recursos["plata"] -= COSTE_DOTAR_PLATA
	recursos["piedra"] -= COSTE_DOTAR_PIEDRA
	var p: Dictionary = parroquias[indice]
	_mover_influencia(p, "monasterio", 6.0)
	prestigio += 1
	mensaje.emit("Se dota la iglesia de %s. Crece la devoción del monasterio en la parroquia." % p["nome"])
	estado_cambiado.emit()
	return true

## Envía un favor (regalo, gestión) a una facción para mejorar la relación con
## ella y aplacar temporalmente su empuje sobre el territorio.
func favor_faccion(id: String) -> bool:
	if terminado or not facciones.has(id):
		return false
	if recursos["plata"] < COSTE_FAVOR:
		return false
	recursos["plata"] -= COSTE_FAVOR
	var fac: Dictionary = facciones[id]
	fac["relacion"] = clampf(float(fac["relacion"]) + 15.0, -100.0, 100.0)
	mensaje.emit("Se envía un favor a %s. La relación mejora." % nome_faccion(id))
	estado_cambiado.emit()
	return true

## Disputa formalmente ante la autoridad (rey u obispo, según el caso) la
## influencia de una parroquia frente a su facción dominante. Resolución
## inmediata: la probabilidad de éxito depende del prestigio propio frente al
## poder de la facción rival.
func disputar_parroquia(indice: int) -> bool:
	if terminado or indice < 0 or indice >= parroquias.size():
		return false
	var p: Dictionary = parroquias[indice]
	var rival_id := faccion_dominante(p)
	if rival_id == "" or rival_id == "monasterio":
		return false
	if recursos["plata"] < COSTE_DISPUTA:
		return false
	recursos["plata"] -= COSTE_DISPUTA
	var poder_rival: float = float(facciones.get(rival_id, {}).get("poder", 1.0))
	var favorable := clampf(0.35 + prestigio * 0.002 - poder_rival * 0.15, 0.1, 0.75)
	if randf() < favorable:
		_mover_influencia(p, "monasterio", 18.0)
		mensaje.emit("El monasterio gana la disputa por %s frente a %s." % [p["nome"], nome_faccion(rival_id)])
	else:
		var fac: Dictionary = facciones.get(rival_id, {})
		if fac.has("relacion"):
			fac["relacion"] = clampf(float(fac["relacion"]) - 10.0, -100.0, 100.0)
		mensaje.emit("La disputa por %s se resuelve a favor de %s." % [p["nome"], nome_faccion(rival_id)])
	estado_cambiado.emit()
	return true

## Traslada puntos de influencia hacia "hacia_id" en una parroquia, restando
## proporcionalmente a las demás facciones (mantiene la suma en 100).
func _mover_influencia(p: Dictionary, hacia_id: String, cantidade: float) -> void:
	var inf: Dictionary = p["influencia"]
	var total_outros := 0.0
	for id in inf:
		if id != hacia_id:
			total_outros += float(inf[id])
	if total_outros <= 0.0:
		return
	cantidade = minf(cantidade, total_outros)
	for id in inf:
		if id != hacia_id:
			inf[id] = float(inf[id]) - cantidade * (float(inf[id]) / total_outros)
	inf[hacia_id] = float(inf[hacia_id]) + cantidade

# --- Obras pías: la vía activa para captar tierra ----------------------------
# Encargar obras pías sube la "afinidade" de una aldea (o de toda su
# parroquia). Con afinidade suficiente se puede "solicitar donación": una
# tirada de probabilidad que, si sale bien, añade una leira real en esa
# aldea. Compite con la rivalidad: cuanto más domine el obispo/la hidalguía/
# el rival esa parroquia, más difícil es conseguirla; y si sale bien, el
# monasterio gana algo de influencia allí.

func _def_obra_pia(id: String) -> Dictionary:
	for o in Data.OBRAS_PIAS:
		if o["id"] == id:
			return o
	return {}

func puede_encargar_obra(aldea_idx: int, obra_id: String) -> bool:
	if terminado or aldea_idx < 0 or aldea_idx >= aldeas.size():
		return false
	var o := _def_obra_pia(obra_id)
	if o.is_empty():
		return false
	if String(o.get("requiere", "")) != "" and get_nivel(o["requiere"]) <= 0:
		return false
	for recurso in o["coste"]:
		if recursos.get(recurso, 0.0) < float(o["coste"][recurso]):
			return false
	return true

## Encarga una obra pía (misa, misión, hospital…) en una aldea concreta.
func encargar_obra(aldea_idx: int, obra_id: String) -> bool:
	if not puede_encargar_obra(aldea_idx, obra_id):
		return false
	var o := _def_obra_pia(obra_id)
	var a: Dictionary = aldeas[aldea_idx]
	for recurso in o["coste"]:
		recursos[recurso] -= float(o["coste"][recurso])
	var subida := float(o["afinidade"])
	if o["ambito"] == "parroquia":
		var parr_idx: int = int(a.get("parroquia_idx", -1))
		if parr_idx >= 0 and parr_idx < parroquias.size():
			for idx in parroquias[parr_idx]["aldeas"]:
				var vecina: Dictionary = aldeas[int(idx)]
				vecina["afinidade"] = clampf(float(vecina["afinidade"]) + subida, 0.0, 100.0)
			mensaje.emit("%s celebrado en la parroquia de %s: crece la devoción por todo su contorno." % [
				o["nombre"], a["parroquia"]])
	else:
		a["afinidade"] = clampf(float(a["afinidade"]) + subida, 0.0, 100.0)
		mensaje.emit("%s en %s: los vecinos os miran con mejores ojos (afinidad %d%%)." % [
			o["nombre"], a["nome"], int(a["afinidade"])])
	estado_cambiado.emit()
	return true

## Probabilidad de éxito si se solicita la donación ahora mismo (0..1), para
## que el jugador la vea antes de arriesgarse. Depende de la afinidade de la
## aldea y de cuánto dominen la parroquia otras facciones.
func probabilidad_donacion(aldea_idx: int) -> float:
	if aldea_idx < 0 or aldea_idx >= aldeas.size():
		return 0.0
	var a: Dictionary = aldeas[aldea_idx]
	var afin: float = float(a["afinidade"])
	if afin < Data.UMBRAL_DONACION:
		return 0.0
	var base := clampf((afin - 40.0) / 65.0, 0.05, 0.92)  # 65%->~0.38, 100%->~0.92
	var parr_idx: int = int(a.get("parroquia_idx", -1))
	if parr_idx >= 0 and parr_idx < parroquias.size():
		var p: Dictionary = parroquias[parr_idx]
		var mon: float = float(p["influencia"].get("monasterio", 0.0)) / 100.0
		base -= (1.0 - mon) * 0.35  # cuanto menos domina el monasterio, más cuesta
	return clampf(base, 0.05, 0.95)

func puede_solicitar_donacion(aldea_idx: int) -> bool:
	if terminado or aldea_idx < 0 or aldea_idx >= aldeas.size():
		return false
	var a: Dictionary = aldeas[aldea_idx]
	return float(a["afinidade"]) >= Data.UMBRAL_DONACION and _hay_campo_libre(aldea_idx)

## Solicita formalmente la donación de tierras a una aldea con afinidade
## suficiente. Consume afinidade siempre (más si sale bien: el gesto se
## agradece pero también se agota); es una tirada, no algo garantizado.
func solicitar_donacion(aldea_idx: int) -> bool:
	if not puede_solicitar_donacion(aldea_idx):
		return false
	var a: Dictionary = aldeas[aldea_idx]
	var prob := probabilidad_donacion(aldea_idx)
	var exito := randf() < prob
	var parr_idx: int = int(a.get("parroquia_idx", -1))
	if exito:
		var l := _nova_leira_en_aldea(aldea_idx)
		leiras.append(l)
		aniversarios += 1
		prestigio += 4
		a["afinidade"] = clampf(float(a["afinidade"]) - 35.0, 0.0, 100.0)
		if parr_idx >= 0 and parr_idx < parroquias.size():
			_mover_influencia(parroquias[parr_idx], "monasterio", 8.0)
		evento.emit("Donación conseguida",
			"Los vecinos de %s, agradecidos por vuestras obras pías, donan «%s» al monasterio." % [
				a["nome"], l["nome"]])
	else:
		a["afinidade"] = clampf(float(a["afinidade"]) - 20.0, 0.0, 100.0)
		evento.emit("La aldea declina, por ahora",
			"%s aprecia vuestro celo, pero de momento no se decide a donar tierras. Seguid cultivando su devoción." % a["nome"])
	estado_cambiado.emit()
	return exito

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
	var larder := 0.0          # ferrados de sustento que entran en el cillero
	var azumbres := 0.0        # vino recaudado
	var renta_plata := 0.0     # sobreprecio del grano noble, foros miúdos y luctuosas
	var suma_presion := 0.0
	var n_aforadas := 0
	var ferrados_msg: Dictionary = {}   # nombre de cultivo -> ferrados recaudados
	var animais: Dictionary = {}        # descripciones de foros miúdos (animales)

	for l in leiras:
		if l.get("pleito", false):
			continue  # las tierras en litigio no rinden renta hasta la sentencia
		var cul := cultivo_de(l)
		var es_vino: bool = cul["producto"] == "vino"
		var premio: float = maxf(0.0, float(cul["valor"]) - 1.0)  # sobreprecio del grano noble
		match l["estado"]:
			"aforada":
				n_aforadas += 1
				suma_presion += _presion_fraccion(l["fraccion"])
				var renta := rendemento_leira(l) * clima * float(l["fraccion"])
				# Impago si el malestar es alto.
				if malestar > 50.0 and randf() < (malestar - 50.0) / 90.0:
					l["morosidade"] += renta
					mensaje.emit("%s no pudo pagar la renta de «%s»." % [l["forero"], l["nome"]])
				else:
					if es_vino:
						azumbres += renta
					else:
						larder += renta * float(cul["alimento"])
						renta_plata += renta * premio * 0.5
						ferrados_msg[cul["nombre"]] = float(ferrados_msg.get(cul["nombre"], 0.0)) + renta
					renta_plata += float(cul["animais"])   # foros miúdos (animales)
					animais[cul["animais_desc"]] = true
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
				else:
					fruto *= 0.5  # sin plata para serventes, solo se recoge la mitad
				if es_vino:
					azumbres += fruto
				else:
					larder += fruto * float(cul["alimento"])
					renta_plata += fruto * premio * 0.5
					ferrados_msg[cul["nombre"]] = float(ferrados_msg.get(cul["nombre"], 0.0)) + fruto

	recursos["comida"] = min(recursos["comida"] + larder, almacen_max("comida"))
	recursos["vino"] += azumbres
	recursos["plata"] += renta_plata

	# Diezmo de las parroquias, ponderado por la influencia del monasterio en
	# cada una: una parroquia dominada por el obispo o un hidalgo apenas rinde.
	var influencia_total := 0.0
	for p in parroquias:
		influencia_total += float(p["influencia"].get("monasterio", 0.0)) / 100.0
	var diezmo_comida := influencia_total * 3.0 + cotos * 4.0 + vasallos * 0.6
	var diezmo_plata := influencia_total * 2.0 + cotos * 3.0 + vasallos * 0.8 + prestigio * 0.05
	recursos["comida"] = min(recursos["comida"] + diezmo_comida, almacen_max("comida"))
	recursos["plata"] += diezmo_plata

	# Producción anual de las explotaciones (muíños, canteiras, pastos).
	for ex in explotacions:
		var d: Dictionary = Data.EXPLOTACIONS[ex["tipo"]]
		recursos[d["recurso"]] = recursos.get(d["recurso"], 0.0) + float(d["base"])

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

	if not ferrados_msg.is_empty() or azumbres > 0.0:
		var partes: Array = []
		for nome in ferrados_msg:
			partes.append("%d ferrados de %s" % [int(ferrados_msg[nome]), String(nome).to_lower()])
		if azumbres > 0.0:
			partes.append("%d azumbres de vino" % int(azumbres))
		var extra := ""
		if not animais.is_empty():
			extra = ", con foros miúdos (%s)" % ", ".join(animais.keys())
		mensaje.emit("Rentas forales de %s: %s%s. El monasterio ingresa %d de plata." % [
			estacion_txt, ", ".join(partes), extra, int(renta_plata + diezmo_plata)])

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
# --- Rivalidad: empuje anual de las facciones -------------------------------

## Cada año, obispo, hidalgos y monasterio rival empujan su influencia sobre
## las parroquias según su foco y poder, atenuados por su relación con el
## jugador. Puede desencadenar un evento político si el empuje es notable.
func _reckoning_politico() -> void:
	if parroquias.is_empty():
		return
	var mayor_empuje := 0.0
	var parroquia_afectada := ""
	for id in facciones:
		var fac: Dictionary = facciones[id]
		var poder: float = float(fac["poder"])
		var freno: float = clampf(1.0 - float(fac["relacion"]) / 150.0, 0.3, 1.6)
		for p in parroquias:
			if faccion_dominante(p) == "monasterio" and randf() > 0.4:
				continue  # las parroquias ya nuestras cuestan más de arrebatar
			var empuje := poder * freno * randf_range(0.5, 1.5)
			_mover_influencia(p, id, empuje)
			if empuje > mayor_empuje:
				mayor_empuje = empuje
				parroquia_afectada = p["nome"]
	# Relación deriva lentamente hacia neutral si no se cultiva.
	for id in facciones:
		var fac: Dictionary = facciones[id]
		fac["relacion"] = float(fac["relacion"]) * 0.95

# --- Mercado regional: precios dinámicos -------------------------------------

## Recalcula los precios según oferta (producción/especialización de las
## parroquias que controla el monasterio) y demanda (población propia y de las
## aldeas). Una comarca dominada por rivales exporta menos al monasterio y sus
## precios de venta caen; el privilegio de feira suaviza la horquilla a favor
## del jugador.
func _reckoning_mercado() -> void:
	var oferta_local: Dictionary = {"comida": 0.0, "vino": 0.0, "piedra": 0.0, "gando": 0.0}
	for l in leiras:
		if l["estado"] in ["directa", "aforada"]:
			var cul := cultivo_de(l)
			var r: bool = cul["producto"] == "vino"
			oferta_local["vino" if r else "comida"] += rendemento_leira(l)
	for ex in explotacions:
		var d: Dictionary = Data.EXPLOTACIONS[ex["tipo"]]
		oferta_local[d["recurso"]] = float(oferta_local.get(d["recurso"], 0.0)) + float(d["base"])
	var demanda := float(poblacion) + aldeas.size() * 4.0

	for ben in Data.BENS_MERCADO:
		var base: float = float(Data.BENS_MERCADO[ben]["base_prezo"])
		var of: float = float(oferta_local.get(ben, 0.0)) + 1.0
		var ratio := clampf(demanda / (of * 4.0), 0.5, 2.2)
		var precio := base * ratio
		if feira:
			precio *= 1.15  # portazgo y mejor colocación en la feria
		precios[ben] = precio

func precio_venta(ben: String) -> float:
	return float(precios.get(ben, float(Data.BENS_MERCADO.get(ben, {}).get("base_prezo", 1.0))))

func precio_compra(ben: String) -> float:
	return precio_venta(ben) * 1.25  # comprar siempre cuesta algo más que vender

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
		"obispo_reclama":
			if not parroquias.is_empty():
				var p: Dictionary = parroquias[randi() % parroquias.size()]
				_mover_influencia(p, "obispo", 12.0)
		"nobre_usurpa":
			var candidatas: Array = []
			for l in leiras:
				if l["estado"] == "aforada" and not l.get("pleito", false):
					candidatas.append(l)
			if not candidatas.is_empty():
				var l: Dictionary = candidatas[randi() % candidatas.size()]
				l["estado"] = "yerma"
				l["forero"] = ""
				l["voces"] = 0
				malestar = clampf(malestar + 5.0, 0.0, 100.0)
		"rival_atrae_donacion":
			if not parroquias.is_empty():
				var p: Dictionary = parroquias[randi() % parroquias.size()]
				_mover_influencia(p, "rival", 10.0)
		"fundacion_rival":
			var fac: Dictionary = facciones.get("rival", {})
			if fac.has("poder"):
				fac["poder"] = float(fac["poder"]) * 1.25
		"concesion_feira":
			feira = true
			prestigio += 5
		"buen_mercado":
			for ben in precios:
				precios[ben] = float(precios[ben]) * 1.2
		"mal_mercado":
			for ben in precios:
				precios[ben] = float(precios[ben]) * 0.8

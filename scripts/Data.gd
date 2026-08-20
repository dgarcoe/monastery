extends Node
## Datos estáticos del juego: recursos, oficios, edificios y eventos.
##
## Ambientación histórica: los monasterios benedictinos de la Galicia medieval,
## como San Pedro de Ansemil y Santa María de Carboeiro (comarca del Deza),
## fundados en torno a los siglos X–XII. La comunidad vivía de la agricultura,
## el viñedo, la copia de manuscritos en el scriptorium y la hospedería para
## peregrinos, bajo la regla de "ora et labora".

# --- Definición de recursos -------------------------------------------------
# id -> nombre visible e icono textual (emoji para no depender de assets).
const RECURSOS := {
	"comida":      {"nombre": "Comida",      "icono": "🌾"},
	"plata":       {"nombre": "Plata",       "icono": "🪙"},
	"fe":          {"nombre": "Devoción",    "icono": "✝"},
	"manuscritos": {"nombre": "Manuscritos", "icono": "📜"},
	"vino":        {"nombre": "Vino",        "icono": "🍷"},
	"piedra":      {"nombre": "Piedra",      "icono": "🪨"},
	"gando":       {"nombre": "Gando",       "icono": "🐖"},
}

# --- Oficios (a los que se asignan los monjes) ------------------------------
# base: producción por monje y mes.
# requiere: id del edificio necesario para desbloquear el oficio (o "").
const OFICIOS := [
	{
		"id": "oracion", "nombre": "Oración y liturgia", "recurso": "fe",
		"base": 1.5, "requiere": "",
		"desc": "Los monjes rezan en el coro. Genera devoción, que atrae novicios y peregrinos.",
	},
	{
		"id": "huerto", "nombre": "Huerto y campo", "recurso": "comida",
		"base": 2.5, "requiere": "",
		"desc": "Labranza y horticultura. La producción depende de la estación del año.",
	},
	{
		"id": "canteria", "nombre": "Cantería", "recurso": "piedra",
		"base": 1.0, "requiere": "",
		"desc": "Extracción y labra de sillares de granito para las obras del monasterio.",
	},
	{
		"id": "scriptorium", "nombre": "Scriptorium", "recurso": "manuscritos",
		"base": 0.6, "requiere": "scriptorium",
		"desc": "Copia e iluminación de códices. Los manuscritos dan prestigio y se venden muy caros.",
	},
	{
		"id": "vinedo", "nombre": "Viñedo y bodega", "recurso": "vino",
		"base": 1.2, "requiere": "bodega",
		"desc": "Cultivo de la vid en las laderas del Deza y elaboración de vino.",
	},
	{
		"id": "hospederia", "nombre": "Hospedería", "recurso": "plata",
		"base": 1.4, "requiere": "hospederia",
		"desc": "Acogida de peregrinos y viajeros a cambio de limosnas en plata.",
	},
]

# --- Edificios --------------------------------------------------------------
# coste_plata / coste_piedra: coste base (se multiplica por el nivel siguiente).
# max_nivel: cuántas veces puede ampliarse.
const EDIFICIOS := [
	{
		"id": "granero", "nombre": "Granero", "coste_plata": 15, "coste_piedra": 8,
		"max_nivel": 3,
		"desc": "Aumenta la capacidad de almacenamiento de comida (+120 por nivel).",
	},
	{
		"id": "molino", "nombre": "Molino", "coste_plata": 25, "coste_piedra": 12,
		"max_nivel": 2,
		"desc": "Mejora el rendimiento del huerto (+40% por nivel).",
	},
	{
		"id": "scriptorium", "nombre": "Scriptorium", "coste_plata": 40, "coste_piedra": 20,
		"max_nivel": 2,
		"desc": "Desbloquea la copia de manuscritos. El 2º nivel duplica su ritmo.",
	},
	{
		"id": "bodega", "nombre": "Bodega", "coste_plata": 30, "coste_piedra": 15,
		"max_nivel": 2,
		"desc": "Desbloquea la elaboración de vino a partir del viñedo.",
	},
	{
		"id": "hospederia", "nombre": "Hospedería", "coste_plata": 35, "coste_piedra": 18,
		"max_nivel": 2,
		"desc": "Desbloquea la acogida de peregrinos y aumenta el aforo de la comunidad.",
	},
	{
		"id": "enfermeria", "nombre": "Enfermería", "coste_plata": 30, "coste_piedra": 14,
		"max_nivel": 1,
		"desc": "Reduce el riesgo de perder monjes por enfermedades y pestes.",
	},
	{
		"id": "iglesia", "nombre": "Ampliación de la iglesia", "coste_plata": 70, "coste_piedra": 45,
		"max_nivel": 3,
		"desc": "Obra románica que aumenta la devoción, el aforo y, sobre todo, el prestigio.",
	},
]

# --- Mercado regional --------------------------------------------------------
# Catálogo de bienes comerciables. base_prezo es el precio de referencia
# (plata/unidad) alrededor del cual fluctúa el mercado según oferta y demanda
# (ver GameState._reckoning_mercado). "importado" = no lo produce la comarca,
# solo se compra (p. ej. la sal, imprescindible y traída de la costa).
const BENS_MERCADO := {
	"comida":      {"base_prezo": 1.0,  "importado": false},
	"vino":        {"base_prezo": 4.0,  "importado": false},
	"piedra":      {"base_prezo": 2.0,  "importado": false},
	"gando":       {"base_prezo": 6.0,  "importado": false},
	"manuscritos": {"base_prezo": 12.0, "importado": false},
	"sal":         {"base_prezo": 3.0,  "importado": true},
}

# --- Eventos aleatorios -----------------------------------------------------
# peso: probabilidad relativa. La lógica de cada evento se resuelve en
# GameState.aplicar_evento() mediante su id.
const EVENTOS := [
	{
		"id": "buena_cosecha", "peso": 12, "titulo": "Buena cosecha",
		"texto": "Las lluvias del Deza han sido generosas. Los graneros se llenan de trigo y centeno.",
	},
	{
		"id": "donacion_noble", "peso": 10, "titulo": "Donación de un noble",
		"texto": "Un señor de la comarca lega tierras y plata al monasterio a cambio de misas por su alma.",
	},
	{
		"id": "peregrinos", "peso": 12, "titulo": "Llegan peregrinos",
		"texto": "Romeros camino de Compostela se detienen a venerar las reliquias. Dejan limosnas y elevan la devoción.",
	},
	{
		"id": "milagro", "peso": 6, "titulo": "Milagro atribuido a las reliquias",
		"texto": "Se dice que un enfermo sanó ante el altar. La fama del monasterio crece por toda Galicia.",
	},
	{
		"id": "incursion_normanda", "peso": 8, "titulo": "Incursión normanda",
		"texto": "Los normandos remontan el río saqueando. Se llevan grano y plata antes de retirarse.",
	},
	{
		"id": "peste", "peso": 8, "titulo": "Enfermedad en la comunidad",
		"texto": "Unas fiebres se extienden por el dormitorio de los monjes.",
	},
	{
		"id": "incendio", "peso": 6, "titulo": "Incendio",
		"texto": "Una vela olvidada prende en las dependencias. El fuego devora provisiones y trabajo.",
	},
	{
		"id": "sequia", "peso": 7, "titulo": "Sequía",
		"texto": "El estío ha secado los campos. La cosecha de este mes se malogra.",
	},
	{
		"id": "visita_obispo", "peso": 7, "titulo": "Visita del obispo",
		"texto": "El obispo de Lugo inspecciona la observancia de la regla benedictina.",
	},
	{
		"id": "novicio_ilustre", "peso": 8, "titulo": "Un nuevo hermano",
		"texto": "Un joven letrado pide ingresar en la comunidad para consagrar su vida a Dios.",
	},
	{
		"id": "donacion_leira", "peso": 9, "titulo": "Donación de una heredad",
		"texto": "Un caballero, temeroso de su alma, dona una heredad al monasterio 'pro remedio animae', a cambio de un aniversario perpetuo por su memoria.",
	},
	{
		"id": "manda_testamentaria", "peso": 7, "titulo": "Manda testamentaria",
		"texto": "Un vecino lega en su testamento plata y bienes al cenobio, pidiendo misas por su alma y sepultura en el claustro.",
	},
	{
		"id": "concesion_coto", "peso": 3, "titulo": "Concesión de un coto",
		"texto": "El rey otorga al monasterio jurisdicción sobre un coto: sus vasallos quedan bajo el señorío del abad, con sus rentas y deberes.",
	},
	{
		"id": "obispo_reclama", "peso": 6, "titulo": "El obispo reclama el diezmo",
		"texto": "El obispado alega derecho preferente sobre el diezmo de una parroquia y presiona para reducir la influencia del monasterio en ella.",
	},
	{
		"id": "nobre_usurpa", "peso": 6, "titulo": "Un fidalgo usurpa una leira",
		"texto": "Un hidalgo de la comarca ocupa por la fuerza una heredad aforada, alegando derechos de señorío.",
	},
	{
		"id": "rival_atrae_donacion", "peso": 6, "titulo": "El monasterio rival gana una donación",
		"texto": "Una familia piadosa de la comarca prefiere dotar de tierras al otro cenobio antes que al vuestro.",
	},
	{
		"id": "fundacion_rival", "peso": 2, "titulo": "Un nuevo monasterio en la comarca",
		"texto": "Otra comunidad monástica se asienta en la comarca y empieza a disputar donaciones, peregrinos y parroquias.",
	},
	{
		"id": "concesion_feira", "peso": 3, "titulo": "Privilegio de feira",
		"texto": "El rey concede al monasterio el privilegio de celebrar feira y cobrar portazgo, con provecho para su comercio.",
	},
	{
		"id": "buen_mercado", "peso": 6, "titulo": "Año de buen mercado",
		"texto": "Los caminos están seguros y los mercaderes acuden en número: los precios de la comarca suben en favor de quien vende.",
	},
	{
		"id": "mal_mercado", "peso": 6, "titulo": "Año de mal mercado",
		"texto": "Malos caminos y pocos compradores: el mercado de la comarca languidece este año.",
	},
]

# --- Fundación: comarcas y familias -----------------------------------------
# Parámetros de generación del mapa y rasgos de partida por comarca.
# Ids de tile: 0 hierba, 1 camino, 2 piedra, 3 agua, 4 campo, 5 bosque, 6 monte,
# 7 regato, 8 pasto/braña.
const COMARCAS := [
	{
		"id": "deza", "nombre": "Val do Deza",
		"desc": "Tierras llanas y fértiles junto al río, de buen cereal y muchas aldeas. Próspera, pero expuesta a las incursiones.",
		"fertilidad": 0.8, "bosque": 0.15, "monte": 0.05, "parroquias": 4,
		"zona": "cereal", "riesgo": 1.2,
		"bonus": {"comida": 20.0},
	},
	{
		"id": "trasdeza", "nombre": "Trasdeza",
		"desc": "Comarca de montaña, con soutos de castaños y aldeas dispersas. Aislada y segura, pero de tierra pobre.",
		"fertilidad": 0.4, "bosque": 0.4, "monte": 0.3, "parroquias": 3,
		"zona": "souto", "riesgo": 0.6,
		"bonus": {"piedra": 20.0},
	},
	{
		"id": "ulla", "nombre": "Ribeira do Ulla",
		"desc": "Laderas de viñedo junto al gran río, en la ruta de los peregrinos. Buen comercio y donaciones.",
		"fertilidad": 0.6, "bosque": 0.2, "monte": 0.1, "parroquias": 4,
		"zona": "vinha", "riesgo": 1.0,
		"bonus": {"plata": 20.0},
	},
	{
		"id": "camba", "nombre": "Terra de Camba",
		"desc": "Comarca equilibrada de montes, prados y alguna veiga. Un comienzo sin extremos.",
		"fertilidad": 0.6, "bosque": 0.25, "monte": 0.15, "parroquias": 3,
		"zona": "mixta", "riesgo": 0.9,
		"bonus": {},
	},
]

# Familias fundadoras: dote inicial y rasgo propio.
const FAMILIAS := [
	{
		"id": "condal", "nombre": "Linaje condal",
		"desc": "Una casa noble dota el cenobio con plata y una heredad ya aforada. Empiezas con más prestigio.",
		"dote": {"plata": 60.0, "comida": 40.0, "piedra": 30.0},
		"monjes": 5, "leiras_aforadas": 1, "leiras_directas": 1,
		"vasallos": 4, "prestigio": 15, "fe": 10.0,
	},
	{
		"id": "labradores", "nombre": "Estirpe de labradores",
		"desc": "Familia de la tierra: llega con brazos, grano y una veiga propia en explotación directa. Más comida y vasallos.",
		"dote": {"plata": 25.0, "comida": 80.0, "piedra": 20.0},
		"monjes": 6, "leiras_aforadas": 0, "leiras_directas": 2,
		"vasallos": 6, "prestigio": 4, "fe": 8.0,
	},
	{
		"id": "eclesiastica", "nombre": "Estirpe eclesiástica",
		"desc": "De raíz clerical, aporta libros y devoción. Un hermano letrado y mayor fervor, aunque menos bienes.",
		"dote": {"plata": 35.0, "comida": 35.0, "piedra": 15.0},
		"monjes": 5, "leiras_aforadas": 1, "leiras_directas": 0,
		"vasallos": 2, "prestigio": 8, "fe": 20.0,
	},
]

# Advocaciones para nombrar las parroquias (San/Santa + lugar).
const ADVOCACIONS := [
	"San Pedro", "Santa María", "San Xoán", "San Martiño", "San Miguel",
	"Santa Baia", "San Salvador", "San Xurxo", "Santo Estevo", "San Cristovo",
	"Santa Cristina", "San Mamede", "San Lourenzo", "Santa Mariña", "San Fiz",
]

# Topónimos para las aldeas del contorno.
const NOMES_ALDEA := [
	"Vilameán", "Reboredo", "Fontao", "Castrelo", "A Bergaza", "Merza",
	"Piloño", "Ansemil", "Carboeiro", "Gresande", "Trasfontao", "Saídres",
	"Escuadro", "Dornelas", "Cristimil", "Toiriz", "Xestoso", "Bermés",
]

# --- Sistema foral: cultivos ------------------------------------------------
# Cultivo de cada leira. La renta foral se mide en FERRADOS (grano y castañas)
# o en AZUMBRES (vino).
#   producto : "grao" | "castañas" | "vino"  (grano y castañas alimentan; vino no)
#   base     : ferrados/azumbres por año a plena calidad
#   valor    : plata por unidad al venderse (los cereales nobles valen más)
#   alimento : ferrados de sustento que aporta cada unidad
#   zonas    : contornos donde se da este cultivo
#   animais  : renta accesoria en animales (plata) y su descripción ("foros miúdos")
const CULTIVOS := {
	"centeno": {
		"nombre": "Centeno", "producto": "grao", "unidad": "ferrados",
		"base": 24.0, "valor": 1.0, "alimento": 1.0, "zonas": ["cereal", "mixta"],
		"animais": 2.0, "animais_desc": "un par de capones",
	},
	"trigo": {
		"nombre": "Trigo", "producto": "grao", "unidad": "ferrados",
		"base": 14.0, "valor": 2.4, "alimento": 1.1, "zonas": ["cereal"],
		"animais": 3.0, "animais_desc": "capones y huevos",
	},
	"mijo": {
		"nombre": "Mijo", "producto": "grao", "unidad": "ferrados",
		"base": 18.0, "valor": 1.2, "alimento": 0.9, "zonas": ["cereal", "mixta"],
		"animais": 2.0, "animais_desc": "gallinas",
	},
	"vinha": {
		"nombre": "Viñedo", "producto": "vino", "unidad": "azumbres",
		"base": 16.0, "valor": 3.0, "alimento": 0.0, "zonas": ["vinha", "mixta"],
		"animais": 2.0, "animais_desc": "gallinas",
	},
	"souto": {
		"nombre": "Souto de castañas", "producto": "castañas", "unidad": "ferrados",
		"base": 15.0, "valor": 0.8, "alimento": 0.8, "zonas": ["souto", "mixta"],
		"animais": 6.0, "animais_desc": "un puerco cebado",
	},
}

# Fracciones de renta foral (parte de la cosecha que percibe el monasterio).
# A mayor fracción, mayor renta pero mayor malestar campesino.
const FRACCIONES := [
	{"nombre": "cuarto",  "valor": 0.25,   "presion": 9.0},
	{"nombre": "quinto",  "valor": 0.20,   "presion": 6.0},
	{"nombre": "sexto",   "valor": 0.1667, "presion": 4.0},
	{"nombre": "sétimo",  "valor": 0.1429, "presion": 2.5},
	{"nombre": "oitavo",  "valor": 0.125,  "presion": 1.0},
]

# Topónimos y lugares del Deza para nombrar leiras (aproximación histórica).
const TOPONIMOS_LEIRA := [
	"a Veiga", "o Souto", "a Chousa", "o Agro", "a Devesa", "o Cortiñal",
	"a Brea", "os Barreiros", "a Insua", "o Rieiro", "a Fraga", "o Cavado",
	"a Costa", "o Regueiro", "a Gándara", "o Outeiro",
]
const LUGARES := [
	"Merza", "Trasdeza", "Camba", "Dozón", "Chapa", "Carboeiro",
	"Ansemil", "Deza", "Vila de Cruces", "Piloño",
]
# Apellidos/casas campesinas para las familias foreras ("os de ...").
# --- Explotacións ligadas al terreno -----------------------------------------
# Se construyen sobre un tile válido (ver "requiere_tile") que el jugador
# controle. Producen cada año en el balance foral, como las leiras.
const EXPLOTACIONS := {
	"muino": {
		"nombre": "Muíño", "requiere_tile": 7,  # regato
		"coste_plata": 20, "coste_piedra": 15,
		"recurso": "plata", "base": 6.0,  # maquía: parte de la moienda en plata
		"desc": "Muele el grano de las aldeas cercanas a cambio de maquía. Se alza junto a un regato.",
	},
	"canteira": {
		"nombre": "Canteira", "requiere_tile": 6,  # monte
		"coste_plata": 15, "coste_piedra": 5,
		"recurso": "piedra", "base": 10.0,
		"desc": "Cantería de granito a cielo abierto. Se abre en el monte.",
	},
	"pasto": {
		"nombre": "Pasto", "requiere_tile": 8,  # braña
		"coste_plata": 12, "coste_piedra": 4,
		"recurso": "gando", "base": 4.0,
		"desc": "Braña de pasto para el ganado del monasterio. Da gando (carne y cuero) al año.",
	},
}

# --- Facciones rivales --------------------------------------------------------
# Disputan la influencia sobre las parroquias del territorio (competencia no
# militar): obispo, nobleza local y un monasterio rival de la comarca.
const FACCIONES := {
	"obispo": {
		"nombre": "El obispado",
		"desc": "El obispo diocesano reclama el diezmo y litiga con dureza en materia eclesiástica.",
		"color": Color(0.55, 0.35, 0.65),
		"foco": "diezmo", "agresividade": 0.8,
	},
	"nobreza": {
		"nombre": "La hidalguía local",
		"desc": "Un linaje de fidalgos de la comarca, ávido de foros y de señorío sobre los cotos.",
		"color": Color(0.65, 0.25, 0.2),
		"foco": "foros", "agresividade": 1.0,
	},
	"rival": {
		"nombre": "El monasterio rival",
		"desc": "Otro cenobio de la comarca compite por las mismas donaciones, reliquias y peregrinos.",
		"color": Color(0.2, 0.4, 0.6),
		"foco": "donacions", "agresividade": 0.7,
	},
}

const CASAS_FORERAS := [
	"Vilar", "Carballido", "Reboredo", "Souto", "Lamas", "Quintela",
	"Bergaza", "Casal", "Outeiro", "Ponte", "Fraga", "Rego", "Cerdeira",
	"Barreiro", "Nogueira", "Pereira", "Seixas", "Gándara", "Nine", "Bermés",
]

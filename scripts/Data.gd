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

# --- Precios de venta en el mercado (plata por unidad) ----------------------
const PRECIO_VENTA := {
	"manuscritos": 12,
	"vino": 4,
	"piedra": 2,
	"comida": 1,
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
]

# --- Sistema foral: patrimonio de tierras -----------------------------------
# Tipos de leira (parcela) y el recurso anual que rinden.
const TIPOS_LEIRA := {
	"cereal": {"nombre": "Cereal (centeo)", "recurso": "comida", "base": 20.0},
	"vinha":  {"nombre": "Viñedo",          "recurso": "vino",   "base": 12.0},
	"souto":  {"nombre": "Souto (castañas)", "recurso": "comida", "base": 14.0},
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
const CASAS_FORERAS := [
	"Vilar", "Carballido", "Reboredo", "Souto", "Lamas", "Quintela",
	"Bergaza", "Casal", "Outeiro", "Ponte", "Fraga", "Rego", "Cerdeira",
	"Barreiro", "Nogueira", "Pereira", "Seixas", "Gándara", "Nine", "Bermés",
]

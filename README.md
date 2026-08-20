# Monasterium — Gestión de un monasterio medieval gallego

Juego de gestión hecho en **Godot 4.7**, ambientado en los monasterios de la
Galicia altomedieval, inspirado en **San Pedro de Ansemil** y **Santa María de
Carboeiro** (comarca del Deza). En el **año 750**, una familia funda un cenobio
sobre sus tierras (a la manera de los *monasterios familiares* del monacato
galaico) y tú lo llevas adelante bajo la regla *ora et labora*: reza, cultiva,
copia códices, elabora vino, acoge peregrinos, levanta el monasterio en piedra
y administra su señorío, sobreviviendo a hambrunas, pestes e incursiones
normandas.

> Vista **top-down 2D** con TileMap y **mapa generado proceduralmente** (cada
> partida es distinta). Todos los gráficos son **placeholders** pensados para
> que sustituyas por tus propios sprites (ver más abajo).

## Cómo abrir y jugar

1. Abre el proyecto con Godot 4.7 (o 4.4+): *Import* → selecciona `project.godot`.
2. Pulsa **F5** (Play). Arranca la **pantalla de fundación**
   (`scenes/Fundacion.tscn`).

### Fundación

Antes de empezar eliges:

- **Comarca** (Val do Deza, Trasdeza, Ribeira do Ulla, Terra de Camba): define
  cómo se genera el mapa (fertilidad, bosque, monte, nº de aldeas), el cultivo
  dominante y una bonificación inicial.
- **Familia fundadora** (linaje condal, estirpe de labradores o eclesiástica):
  fija la dote de partida (recursos, monjes, tierras, vasallos, prestigio).

Al pulsar **Fundar el monasterio** se genera un mapa nuevo y comienza la partida.

### Dos vistas (estilo Heroes III)

El juego tiene dos mapas y se alterna entre ellos con el botón **«Ir al
territorio» / «Volver al monasterio»** (abajo):

- **Monasterio**: el patio propio del cenobio con sus edificios y monjes. Aquí
  se **construye/amplía** y se **reparten los oficios** (paneles a los lados).
- **Territorio**: el mapa grande con el **monasterio** en el centro, las
  **parroquias** y sus **aldeas**. Los paneles laterales se ocultan para dejar
  el mapa libre. Se entra al monasterio pulsando su **marcador**.

### Controles y bucle de juego

- **Navegación del mapa**: arrastra con el **botón derecho** (o central) para
  desplazarte; **rueda del ratón** para acercar/alejar.
- **Siguiente mes ▶** (abajo): avanza la simulación un mes. **Auto**: avanza solo.
- **Panel de oficios** (vista monasterio): reparte a los monjes con `-` / `+`
  entre oración, huerto, cantería, scriptorium, viñedo y hospedería. Los oficios
  con 🔒 necesitan su edificio construido.
- **Edificios del monasterio**: haz **clic** en cualquier solar para ver su
  ficha y **construir / ampliar** (cuesta plata 🪙 y piedra 🪨).
- **Parroquias y aldeas** (vista territorio): cada **parroquia** agrupa 3–6
  **aldeas** y rinde el **diezmo**. Haz **clic** en una parroquia o aldea para
  ver su ficha; de las casas de las aldeas salen los foreros y las donaciones.
- **Vender manuscritos / vino** (abajo): conviértelos en plata (o usa el panel
  **Mercado** para el resto de bienes).
- La **crónica** (vista monasterio) registra construcciones y eventos.

### Rivalidad: la «conquista» no militar del territorio (botón «Poderes»)

No hay ejércitos: la competencia es por **influencia**. Tres facciones disputan
el territorio con vosotros:

- **El obispado** — reclama el **diezmo** y litiga con dureza en lo eclesiástico.
- **La hidalguía local** — ávida de **foros** y señorío sobre los cotos; llega a
  **usurpar leiras** aforadas.
- **El monasterio rival** — otro cenobio de la comarca (marcador propio en el
  territorio) que compite por **donaciones**, reliquias y peregrinos.

Cada **parroquia** reparte su influencia entre el monasterio y estas tres
facciones (suma 100%); la que más tenga la **domina**, y el marcador de la
parroquia se tiñe de su color. El **diezmo que recaudáis depende de vuestra
influencia** en cada parroquia, no solo de su número. Cada año las facciones
empujan su influencia según su foco y poder (atenuado si tenéis buena
relación con ellas). Vuestras palancas:

- **Dotar la iglesia** (ficha de parroquia): obras y limosnas locales que ganan
  influencia a costa de las demás facciones.
- **Disputar** (ficha de parroquia): reclamación formal frente a la facción
  dominante; el éxito depende de vuestro prestigio frente a su poder.
- **Enviar favor** (panel Poderes): mejora la relación con una facción,
  atenuando su empuje futuro.

### Terreno funcional y explotaciones (panel «Poderes» → Construir)

Además de campos, bosque y monte, el territorio tiene **regatos** (arroyos que
bajan al río) y **pastos/brañas**. Sobre ellos se construyen explotaciones que
producen cada año:

- **Muíño** (sobre un regato) — muele el grano de la comarca a cambio de
  **maquía** (plata).
- **Canteira** (sobre un monte) — cantería de granito: **piedra**.
- **Pasto** (sobre una braña) — cría de **gando** (ganado).

Para construir: en el panel **Poderes**, pulsa el tipo de explotación deseado
(entras en «modo construcción») y luego haz **clic** en una casilla válida del
territorio.

### Mercado regional (botón «Mercado»)

Los precios de comida, vino, piedra, gando, manuscritos y **sal** (único bien
que no producís y solo se compra) **fluctúan** según vuestra producción y la
demanda de la comarca; las malas cosechas encarecen el grano, y un buen o mal
año de mercado (evento) los mueve a la vez. El privilegio real de **feira y
portazgo** (evento) mejora vuestra horquilla de precios.

**Objetivo**: mantener viva y próspera la comunidad y elevar el **prestigio**
del monasterio. Si te quedas sin monjes (hambruna o pestes), fin de la partida.

### El Señorío y el sistema foral (botón «Señorío»)

Modela el funcionamiento real de la economía monástica gallega bajomedieval:

- **Patrimonio de leiras (parcelas)**: cada heredad tiene un nombre real del
  Deza (p. ej. *o Cortiñal de Ansemil*), un **cultivo** y una calidad (★–★★★),
  y está **atada a una celda de campo real del territorio** (ver más abajo,
  «El mapa está vivo»). Puede estar **yerma**, en **explotación directa** del
  monasterio o **aforada**.
- **Cultivos y ferrados**: cada leira da un cultivo propio del contorno de su
  aldea, con rendimiento y valor distintos:
  - **Centeno** — el pan de Galicia: rústico, mucho rendimiento, poco valor.
  - **Trigo** — cereal noble: menos ferrados pero se vende caro (da plata).
  - **Mijo** — cereal tradicional, intermedio.
  - **Viñedo** — rinde **vino** (en *azumbres*), de gran valor.
  - **Souto de castañas** — alimento del monte; su renta suele incluir un puerco.

  El grano y las castañas se miden en **ferrados** y el vino en **azumbres**.
- **Foros**: cedes el *dominio útil* de una leira a una familia campesina
  (*os de Seixas*…) **por tres voces**, conservando el *dominio directo*. A
  cambio percibes una **renta foral** en especie —una fracción (*cuarto*,
  *quinto*, *sétimo*…) de la cosecha en ferrados o azumbres— más los **foros
  miúdos**: renta accesoria en **animales** (capones, gallinas, huevos o un
  puerco) según el cultivo y la zona, que se cobra cada año por **San Martiño**.
  Mayor fracción = más renta pero más **malestar**.
- **Voces y renovación**: al morir cada generación pasa una voz (y pagan la
  *luctuosa*). Agotadas las tres, el foro **caduca** y puedes **renovarlo**
  (normalmente subiendo la renta) o **recuperar** la tierra para explotarla
  directamente.
- **Explotación directa**: el monasterio se queda todo el fruto, pero paga a
  los serventes (coste en plata) y queda expuesto a las malas cosechas.
- **Donaciones *pro remedio animae***: nobles y vecinos donan tierras y bienes
  a cambio de **aniversarios** (misas perpetuas que cuestan devoción cada año).
- **Cotos y vasallos**: la corona concede jurisdicción sobre un coto; sus
  vasallos y el **diezmo** de las parroquias rinden comida y plata.
- **Malestar y conflictos**: rentas altas, cotos y malas cosechas suben el
  malestar → **impagos** (morosidad), y si es extremo, la **revuelta de los
  irmandiños**, que arrasa foros y rentas. Puedes **dar limosna** o
  **perdonar deudas** para apaciguar al campesinado.
- **Pleitos forales**: los foros litigaban durante generaciones ante la
  **Audiencia de Galicia**. Puedes **pleitear** contra un forero moroso para
  cobrar la deuda; y al intentar **recuperar** una tierra cuyo foro caducó, la
  familia puede resistirse y llevarlo a juicio. Una deuda enconada con mucho
  malestar deriva sola en pleito. Mientras dura, la tierra **no rinde renta** y
  el monasterio paga **costas** cada año. La sentencia depende del **prestigio**
  y del clima social: si el monasterio gana, cobra o recupera la tierra (y sube
  el malestar); si pierde, carga con las costas y el forero conserva la tierra
  con renta rebajada.

### El mapa está vivo: cultivos y aldeanos trabajando

El territorio no es decorado: cada leira ocupa una **celda de campo real**
junto a su aldea (hasta 6 por aldea) y se ve en el mapa como un **rombo**
coloreado según su producto — dorado para grano, morado para vino, marrón
para castañas — atenuado si está **yerma**. Haz **clic** en una leira del
mapa para abrir el Señorío y gestionarla.

- **La calidad depende del terreno real**, no de un número aleatorio: una
  celda junto a un **río o regato** es más fértil (veiga), una celda cerca
  del **monte** rinde peor. Las nuevas leiras (dote inicial, donaciones)
  ocupan una celda libre de su aldea automáticamente.
- **Los aldeanos trabajan**: si una aldea tiene alguna leira propia, parte de
  sus vecinos caminan periódicamente desde el poblado hasta ella, se detienen
  un rato «trabajando» y vuelven a casa, en vez de deambular sin más.

## Estructura del proyecto

```
project.godot                 Configuración y autoloads (Data, GameState)
scenes/
  Fundacion.tscn              Escena INICIAL: elección de comarca y familia
  Main.tscn                   Escena de juego: vistas Territorio y Mosteiro
  HUD.tscn                    Interfaz (recursos, oficios, mercado, crónica)
  Building.tscn               Edificio/solar con clic
  Aldea.tscn / Parroquia.tscn Aldea y parroquia del territorio (teñida por facción)
  MonMarker.tscn              Marcador del monasterio en el territorio
  RivalMarker.tscn            Marcador del monasterio rival
  ExplotacionMarker.tscn      Marcador de muíño/canteira/pasto construido
  LeiraMarker.tscn            Marcador de una leira sobre su celda real
  Monk.tscn                   Monje que deambula (Wanderer.gd)
  Villager.tscn                Aldeano que camina hasta su leira (Aldeano.gd)
  SenorioPanel.tscn           Panel del señorío (patrimonio y foros)
  LeiraRow.tscn               Fila de una leira dentro del señorío
  PoderesPanel.tscn           Panel de rivalidad (facciones, parroquias, construir)
  MercadoPanel.tscn           Panel del mercado regional
scripts/
  Data.gd                     Datos: recursos, oficios, edificios, eventos,
                              comarcas, familias, cultivos, facciones, bienes
                              de mercado, explotaciones, parroquias, topónimos
  GameState.gd                Lógica de simulación, fundación, mapa, señorío,
                              rivalidad (influencia por parroquia) y mercado
  Fundacion.gd                Pantalla de fundación
  Ground.gd                   Pinta el terreno del territorio con el TileSet
  MonasteryGround.gd          Pinta el patio del monasterio
  CameraController.gd         Cámara con desplazamiento y zoom (por mapa)
  Wanderer.gd                 Deambular al azar (monjes)
  Aldeano.gd                  Aldeano: camina a su leira y vuelve, o deambula
  Aldea.gd / Parroquia.gd     Aldeas y parroquias (fichas, teñido por facción)
  MonMarker.gd                Entrar al monasterio desde el territorio
  ExplotacionMarker.gd        Sprite de una explotación construida
  LeiraMarker.gd               Tiñe la leira por cultivo/estado; clic → Señorío
  Senorio.gd / LeiraRow.gd    Interfaz del sistema foral
  Poderes.gd                  Interfaz de rivalidad y construcción de explotaciones
  Mercado.gd                  Interfaz del mercado regional
  Building.gd / Main.gd / HUD.gd
resources/
  monastery_tileset.tres      TileSet (hierba, camino, piedra, agua, campo,
                              bosque, monte, regato, pasto)
assets/
  tiles/  buildings/  characters/  ui/   ← aquí van tus sprites
```

El mapa se **genera al fundar** (`GameState.fundar` → terreno + aldeas) según
la comarca elegida, de modo que cada partida es distinta. `Ground.gd` solo
pinta el terreno ya generado y `Main.gd` coloca los edificios alrededor del
emplazamiento y las aldeas sobre el mapa.

La **simulación** (`GameState.gd`) está separada de la **presentación**: los
scripts de escena solo leen el estado y reaccionan a sus señales, sin dibujar
gráficos por código.

## Sustituir los placeholders por tus sprites

Los PNG de `assets/` son marcadores de posición de color plano. Para usar tu
propio arte, **reemplaza cada archivo manteniendo el mismo nombre y tamaño** y
no tendrás que tocar ninguna escena.

| Carpeta / archivo | Tamaño | Uso |
|---|---|---|
| `tiles/grass.png` | 64×64 | Hierba (base del mapa) |
| `tiles/path.png` | 64×64 | Camino |
| `tiles/stone_floor.png` | 64×64 | Suelo de piedra (claustro) |
| `tiles/water.png` | 64×64 | Río |
| `tiles/field.png` | 64×64 | Campo de labor |
| `tiles/forest.png` | 64×64 | Bosque |
| `tiles/mountain.png` | 64×64 | Monte |
| `tiles/regato.png` | 64×64 | Regato (arroyo) |
| `tiles/pasto.png` | 64×64 | Pasto / braña |
| `buildings/plot.png` | 128×128 | Solar vacío (sin construir) |
| `buildings/aldea.png` | 96×96 | Aldea (poblado) |
| `buildings/parroquia.png` | 80×80 | Iglesia parroquial (marcador, teñible) |
| `buildings/monasterio.png` | 144×144 | Monasterio propio en el territorio |
| `buildings/monasterio_rival.png` | 144×144 | Monasterio rival en el territorio |
| `buildings/muino.png` | 96×96 | Explotación: muíño |
| `buildings/canteira.png` | 96×96 | Explotación: canteira |
| `buildings/pasto.png` (edificio) | 96×96 | Explotación: pasto/braña |
| `buildings/leira_marker.png` | 40×40 | Leira sobre el mapa (teñible por producto) |
| `buildings/church.png` | 128×128 | *(reservado)* |
| `buildings/iglesia.png` | 128×128 | Iglesia |
| `buildings/scriptorium.png` | 128×128 | Scriptorium |
| `buildings/bodega.png` | 128×128 | Bodega |
| `buildings/granero.png` | 128×128 | Granero |
| `buildings/molino.png` | 128×128 | Molino |
| `buildings/hospederia.png` | 128×128 | Hospedería |
| `buildings/enfermeria.png` | 128×128 | Enfermería |
| `characters/monk.png` | 32×32 | Monje |
| `characters/villager.png` | 28×28 | Aldeano |
| `ui/*.png` (incluye `ui/gando.png`, `ui/sal.png`) | 48×48 | Iconos de recursos del HUD |

Notas:
- Si usas otro **tamaño de tile**, ajústalo en `resources/monastery_tileset.tres`
  (`texture_region_size` y `tile_size`) y en `scripts/Ground.gd`.
- El nombre del sprite de cada edificio coincide con su `id` en `Data.gd`
  (`Building.gd` carga `res://assets/buildings/<id>.png`).
- Para animar al monje o al aldeano, añade un `AnimationPlayer`/
  `AnimatedSprite2D` en `Monk.tscn` / `Villager.tscn` sin cambiar
  `Wanderer.gd` / `Aldeano.gd`.
- Puedes **pintar el mapa a mano** en el editor con tus tiles y borrar
  `Ground.gd` si no quieres el terreno generado por defecto.

## Ampliar el juego

- **Nuevos edificios/oficios/eventos**: añádelos a las tablas de `Data.gd`.
  Los edificios se colocan como solares en `Main.tscn` (instancia de
  `Building.tscn` con su `edificio_id`).
- **Balance**: costes, producción y estaciones están en `GameState.gd`.
- **Colocación libre de edificios** (clic para elegir solar), estaciones
  visuales, sonido y un tema visual propio son buenas siguientes mejoras.

## Créditos

Proyecto base de código y diseño de sistemas. Los sprites definitivos los
aporta el autor del repositorio. Ambientación histórica libre inspirada en el
patrimonio románico gallego.

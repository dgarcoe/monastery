# Monasterium — Gestión de un monasterio medieval gallego

Juego de gestión hecho en **Godot 4.3**, ambientado en los monasterios
benedictinos de la Galicia medieval, inspirado en **San Pedro de Ansemil** y
**Santa María de Carboeiro** (comarca del Deza). Gestionas una comunidad de
monjes bajo la regla *ora et labora*: reza, cultiva, copia códices en el
scriptorium, elabora vino, acoge peregrinos y levanta el monasterio en piedra,
sobreviviendo a hambrunas, pestes, sequías e incursiones normandas.

> Vista **top-down 2D** con TileMap. Todos los gráficos son **placeholders**
> pensados para que sustituyas por tus propios sprites (ver más abajo).

## Cómo abrir y jugar

1. Abre el proyecto con Godot 4.3 (o 4.x): *Import* → selecciona `project.godot`.
2. Pulsa **F5** (Play) para ejecutar la escena principal `scenes/Main.tscn`.

### Controles y bucle de juego

- **Siguiente mes ▶** (abajo): avanza la simulación un mes. **Auto**: avanza solo.
- **Panel de oficios** (izquierda): reparte a los monjes con `-` / `+` entre
  oración, huerto, cantería, scriptorium, viñedo y hospedería. Los oficios con
  🔒 necesitan su edificio construido.
- **Edificios del mapa**: haz **clic** en cualquier solar para ver su ficha y
  **construir / ampliar** (cuesta plata 🪙 y piedra 🪨).
- **Vender manuscritos / vino** (abajo): conviértelos en plata.
- La **crónica** (derecha) registra construcciones y eventos.

**Objetivo**: mantener viva y próspera la comunidad y elevar el **prestigio**
del monasterio. Si te quedas sin monjes (hambruna o pestes), fin de la partida.

### El Señorío y el sistema foral (botón «Señorío»)

Modela el funcionamiento real de la economía monástica gallega bajomedieval:

- **Patrimonio de leiras (parcelas)**: cada heredad tiene un nombre real del
  Deza (p. ej. *o Cortiñal de Ansemil*), un tipo (cereal/centeo, viñedo o
  souto de castañas) y una calidad (★–★★★). Puede estar **yerma**, en
  **explotación directa** del monasterio o **aforada**.
- **Foros**: cedes el *dominio útil* de una leira a una familia campesina
  (*os de Seixas*…) **por tres voces**, conservando el *dominio directo*. A
  cambio percibes una **renta foral** en especie (un *cuarto*, *quinto*,
  *sétimo*…) que se cobra cada año por **San Martiño**. Mayor fracción = más
  renta pero más **malestar**.
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

## Estructura del proyecto

```
project.godot                 Configuración y autoloads (Data, GameState)
scenes/
  Main.tscn                   Escena principal: mapa, edificios y monjes
  HUD.tscn                    Interfaz (recursos, oficios, mercado, crónica)
  Building.tscn               Edificio/solar con clic
  Monk.tscn                   Monje que deambula
  SenorioPanel.tscn           Panel del señorío (patrimonio y foros)
  LeiraRow.tscn               Fila de una leira dentro del señorío
scripts/
  Data.gd                     Datos: recursos, oficios, edificios, eventos,
                              tipos de leira, fracciones forales, topónimos
  GameState.gd                Lógica de simulación y señorío (autoload)
  Ground.gd                   Pintado del terreno con el TileSet
  Senorio.gd / LeiraRow.gd    Interfaz del sistema foral
  Building.gd / Monk.gd / Main.gd / HUD.gd
resources/
  monastery_tileset.tres      TileSet (hierba, camino, piedra, agua, campo)
assets/
  tiles/  buildings/  characters/  ui/   ← aquí van tus sprites
```

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
| `buildings/plot.png` | 128×128 | Solar vacío (sin construir) |
| `buildings/church.png` | 128×128 | *(reservado)* |
| `buildings/iglesia.png` | 128×128 | Iglesia |
| `buildings/scriptorium.png` | 128×128 | Scriptorium |
| `buildings/bodega.png` | 128×128 | Bodega |
| `buildings/granero.png` | 128×128 | Granero |
| `buildings/molino.png` | 128×128 | Molino |
| `buildings/hospederia.png` | 128×128 | Hospedería |
| `buildings/enfermeria.png` | 128×128 | Enfermería |
| `characters/monk.png` | 32×32 | Monje |
| `ui/*.png` | 48×48 | Iconos de recursos del HUD |

Notas:
- Si usas otro **tamaño de tile**, ajústalo en `resources/monastery_tileset.tres`
  (`texture_region_size` y `tile_size`) y en `scripts/Ground.gd`.
- El nombre del sprite de cada edificio coincide con su `id` en `Data.gd`
  (`Building.gd` carga `res://assets/buildings/<id>.png`).
- Para animar al monje, añade un `AnimationPlayer`/`AnimatedSprite2D` en
  `Monk.tscn` sin cambiar `Monk.gd`.
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

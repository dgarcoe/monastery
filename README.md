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

## Estructura del proyecto

```
project.godot                 Configuración y autoloads (Data, GameState)
scenes/
  Main.tscn                   Escena principal: mapa, edificios y monjes
  HUD.tscn                    Interfaz (recursos, oficios, mercado, crónica)
  Building.tscn               Edificio/solar con clic
  Monk.tscn                   Monje que deambula
scripts/
  Data.gd                     Datos: recursos, oficios, edificios, eventos
  GameState.gd                Lógica de simulación (autoload, sin gráficos)
  Ground.gd                   Pintado del terreno con el TileSet
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

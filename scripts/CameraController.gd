extends Camera2D
## Cámara de un mapa: arrastra con el botón derecho o central para desplazarte
## y usa la rueda para acercar/alejar. Limitada a los bordes del mapa.
##
## ancho_tiles/alto_tiles fijan el tamaño del mapa en celdas de 64 px. Si son 0,
## se toma el tamaño del mapa principal (GameState).

@export var ancho_tiles: int = 0
@export var alto_tiles: int = 0
@export var zoom_inicial: float = 1.0

const ZOOM_MIN := 0.35
const ZOOM_MAX := 1.8

var _arrastrando := false

func _ready() -> void:
	var w := ancho_tiles if ancho_tiles > 0 else GameState.MAPA_ANCHO
	var h := alto_tiles if alto_tiles > 0 else GameState.MAPA_ALTO
	limit_left = 0
	limit_top = 0
	limit_right = w * 64
	limit_bottom = h * 64
	zoom = Vector2(zoom_inicial, zoom_inicial)

func _unhandled_input(event: InputEvent) -> void:
	if not is_current():
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_arrastrando = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_aplicar_zoom(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_aplicar_zoom(1.0 / 1.1)
	elif event is InputEventMouseMotion and _arrastrando:
		position -= event.relative / zoom

func _aplicar_zoom(factor: float) -> void:
	var z := clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)

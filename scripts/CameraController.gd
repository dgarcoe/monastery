extends Camera2D
## Cámara del mapa: arrastra con el botón derecho o central para desplazarte y
## usa la rueda para acercar/alejar. Limitada a los bordes del mapa.

const ZOOM_MIN := 0.4
const ZOOM_MAX := 1.6

var _arrastrando := false

func _ready() -> void:
	make_current()
	limit_left = 0
	limit_top = 0
	limit_right = GameState.MAPA_ANCHO * 64
	limit_bottom = GameState.MAPA_ALTO * 64

func _unhandled_input(event: InputEvent) -> void:
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

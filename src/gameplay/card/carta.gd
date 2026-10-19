extends Area2D
## Componente interactivo de carta deslizable (mecánica tipo Tinder/Reigns).
## Procesa eventos táctiles y de ratón para calcular arrastre horizontal, rotación dinámica,
## previsualización de opciones (overlay) y emisión de decisiones al superar el umbral.

## Emitida cuando la carta sale completamente de la pantalla tras una decisión (-1.0: Izq, 1.0: Der).
signal carta_procesada(direccion)
## Emitida cuando el jugador insinúa una decisión superando el umbral visual (-1: Izq, 0: Centro, 1: Der).
signal intencion_decision(estado)

var intencion_actual: int = 0

@onready var sprite = $Sprite2D
@onready var overlay = $SombraSuperpuesta
@onready var label = $SombraSuperpuesta/TextoDecision

var arrastrando: bool = false
var posicion_inicial: Vector2
var offset: Vector2
var tween_actual: Tween = null

var texto_izquierda: String
var texto_derecha: String
var respuesta_correcta: float

@export var umbral_decision: float = 200.0
@export var rotacion_maxima: float = 15.0
@export var velocidad_retorno: float = 0.3

func _ready() -> void:
	input_event.connect(_on_input_event)
	overlay.visible = false
	overlay.modulate.a = 0

## Configura el contenido de la carta: textos de decisión, textura e indicación de respuesta correcta.
func configurar(data, textura: Texture2D) -> void:
	sprite.texture = textura
	texto_izquierda = data["texto_izquierda"]
	texto_derecha = data["texto_derecha"]
	respuesta_correcta = data["correcto"]

func _on_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.pressed:
			iniciar_arrastre()

## Comienza el seguimiento del arrastre calculando el offset global con el puntero.
func iniciar_arrastre() -> void:
	arrastrando = true
	offset = get_global_mouse_position() - global_position
	
	if tween_actual:
		tween_actual.kill()
		
	overlay.visible = true

func _process(_delta: float) -> void:
	if arrastrando:
		mover_carta()
		actualizar_efecto_visual()

## Actualiza la posición global de la carta restringiendo el movimiento al eje horizontal.
func mover_carta() -> void:
	var nueva_pos = get_global_mouse_position() - offset
	nueva_pos.y = posicion_inicial.y
	global_position = nueva_pos

## Calcula la rotación angular y el nivel de opacidad del overlay según el desplazamiento lateral.
func actualizar_efecto_visual() -> void:
	var delta_x = global_position.x - posicion_inicial.x
	var porcentaje = clamp(delta_x / (umbral_decision * 1.5), -1.0, 1.0)
	rotation_degrees = porcentaje * rotacion_maxima
	actualizar_overlay(porcentaje)

## Modifica la etiqueta de texto y opacidad del overlay avisando del cambio de intención.
func actualizar_overlay(porcentaje: float) -> void:
	var nueva_intencion = 0
	
	if abs(porcentaje) < 0.05:
		overlay.modulate.a = 0
		nueva_intencion = 0
	else:
		var intensidad = clamp(abs(porcentaje) * 3.0, 0.0, 0.8)
		overlay.modulate.a = intensidad
		
		if porcentaje > 0:
			label.text = texto_derecha
			nueva_intencion = 1
		else:
			label.text = texto_izquierda
			nueva_intencion = -1
			
	if nueva_intencion != intencion_actual:
		intencion_actual = nueva_intencion
		intencion_decision.emit(intencion_actual)

func _input(event) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if not event.pressed and arrastrando:
			finalizar_arrastre()

## Evalúa si el desplazamiento supera el umbral para validar la decisión o retornar al centro.
func finalizar_arrastre() -> void:
	arrastrando = false
	var delta_x = global_position.x - posicion_inicial.x
	
	if abs(delta_x) > umbral_decision:
		var direccion = 1.0 if delta_x > 0 else -1.0
		ejecutar_salida(direccion)
	else:
		regresar_al_centro()

## Establece la posición central de referencia para la carta.
func set_posicion_inicial(pos: Vector2) -> void:
	posicion_inicial = pos
	global_position = pos
	rotation_degrees = 0.0
	arrastrando = false
	intencion_actual = 0
	if overlay:
		overlay.visible = false
		overlay.modulate.a = 0

## Anima suavemente el retorno de la carta al centro si no se alcanzó el umbral de decisión.
func regresar_al_centro() -> void:
	tween_actual = get_tree().create_tween()
	tween_actual.set_parallel(true)
	tween_actual.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	tween_actual.tween_property(self, "global_position", posicion_inicial, velocidad_retorno)
	tween_actual.tween_property(self, "rotation_degrees", 0.0, velocidad_retorno)
	
	overlay.visible = false
	overlay.modulate.a = 0	
	
	intencion_actual = 0
	intencion_decision.emit(0)

## Anima la salida de la carta hacia los bordes de la pantalla al confirmar la decisión.
func ejecutar_salida(direccion: float) -> void:
	var destino = posicion_inicial + Vector2(1000 * direccion, 0)
	
	tween_actual = get_tree().create_tween()
	tween_actual.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween_actual.tween_property(self, "global_position", destino, 0.4)
	tween_actual.finished.connect(func(): _on_carta_fuera(direccion))

## Limpia las transformaciones y emite la señal de carta procesada tras salir del encuadre.
func _on_carta_fuera(direccion) -> void:
	overlay.visible = false
	overlay.modulate.a = 0
	rotation_degrees = 0.0
	arrastrando = false
	intencion_actual = 0
	visible = false
	carta_procesada.emit(direccion)

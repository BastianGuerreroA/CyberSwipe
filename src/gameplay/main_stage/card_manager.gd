extends Node2D
## Administrador principal de la partida (CardManager).
## Controla el flujo de cartas de la cápsula, la aplicación de efectos sobre la tríada CID y presupuesto,
## la gestión de mecánicas activas LSG (subsidio, ciberseguro, consultoría), el cálculo de tiempos y penalizaciones,
## la visualización del menú pedagógico de retroalimentación ante errores y las condiciones de victoria y derrota.

## Emitida para actualizar los medidores e indicadores con los valores de las métricas (p, c, i, d).
signal metricas_actualizadas(p, c, i, d)

@export var carta_escena: PackedScene
@export var imagenes: Array[Texture2D] = []
@export var label_contexto: Label
@export var typing_sound: AudioStreamPlayer2D
@export var feedback_menu: Control = null

const GAME_OVER_SCENE = preload("res://src/ui/game_over/Game_over.tscn")
const GAME_WINNER_SCENE = preload("res://src/ui/game_winner/game_winner.tscn")

@onready var spawn_point = $SpawnPoint

var tween_texto: Tween = null
var texto_actual: String = ""
var chars_mostrados: int = 0

var presupuesto_actual: int = 50
var confidencialidad_actual: int = 50
var integridad_actual: int = 50
var disponibilidad_actual: int = 50
var cartas = []
var nodo_carta = null
var tiempo_transcurrido: float = 0.0
var tiempo_base_puro: float = 0.0
var cantidad_errores: int = 0
const PENALIZACION_ERROR_SEGUNDOS: float = 8.0

func _process(delta: float) -> void:
	if not get_tree().paused and not cartas.is_empty():
		tiempo_base_puro += delta
		tiempo_transcurrido += delta

func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	CapsulaManager.puntaje_ronda_actual = 0
	CapsulaManager.tiempo_ronda_actual = 0.0
	CapsulaManager.tiempo_base_ronda = 0.0
	CapsulaManager.cantidad_errores_ronda = 0
	CapsulaManager.tiempo_penalizacion_ronda = 0.0
	tiempo_transcurrido = 0.0
	tiempo_base_puro = 0.0
	cantidad_errores = 0
	
	var cartas_dinamicas = CapsulaManager.obtener_cartas_de_capsula_activa()
	if not cartas_dinamicas.is_empty():
		cartas = _aleatorizar_direcciones_cartas(cartas_dinamicas)
	
	if not feedback_menu:
		feedback_menu = get_node_or_null("../CanvasLayer/MarginContainer/FeedbackMenu")
	
	if feedback_menu:
		var boton_continuar = feedback_menu.get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/Continuar")
		if boton_continuar:
			if boton_continuar.pressed.is_connected(_on_feedback_continuar_pressed):
				boton_continuar.pressed.disconnect(_on_feedback_continuar_pressed)
			boton_continuar.pressed.connect(_on_feedback_continuar_pressed)
	
	if LsgCore.active_mechanics.get("consultoria", false):
		presupuesto_actual = 60
		confidencialidad_actual = 60
		integridad_actual = 60
		disponibilidad_actual = 60
		print("LSG-Core: Aplicada Consultoria Preventiva. Recursos iniciales en 60.")
		
	metricas_actualizadas.emit(presupuesto_actual, confidencialidad_actual, integridad_actual, disponibilidad_actual)
	generar_carta()

## Efecto de máquina de escribir que reproduce un audio por cada carácter visible.
func _actualizar_caracteres_visibles(actuales: int) -> void:
	if label_contexto:
		label_contexto.visible_characters = actuales
	if actuales > chars_mostrados:
		chars_mostrados = actuales
		if chars_mostrados <= texto_actual.length():
			var char_actual = texto_actual[chars_mostrados - 1]
			if char_actual != " " and typing_sound:
				typing_sound.play()

## Instancia la siguiente carta de la baraja o dispara la victoria si no quedan cartas.
func generar_carta() -> void:
	if cartas.is_empty():
		if nodo_carta and is_instance_valid(nodo_carta):
			nodo_carta.visible = false
		ganar_juego()
		return
		
	if imagenes.is_empty():
		return
	
	if not nodo_carta or not is_instance_valid(nodo_carta):
		nodo_carta = carta_escena.instantiate()
		nodo_carta.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(nodo_carta)
	
	nodo_carta.visible = true
	nodo_carta.rotation_degrees = 0.0
	nodo_carta.set_posicion_inicial(spawn_point.global_position)
	
	var indice = obtener_indice_carta()
	var data = cartas[indice]
	cartas.remove_at(indice)
	
	var textura = imagenes[data["imagen"]]
	nodo_carta.configurar(data, textura)
	
	if nodo_carta.carta_procesada.is_connected(_on_carta_procesada):
		nodo_carta.carta_procesada.disconnect(_on_carta_procesada)
	if nodo_carta.intencion_decision.is_connected(_on_intencion_decision):
		nodo_carta.intencion_decision.disconnect(_on_intencion_decision)
		
	nodo_carta.carta_procesada.connect(_on_carta_procesada.bind(data))
	nodo_carta.intencion_decision.connect(_on_intencion_decision.bind(data))
	
	mostrar_contexto(data["contexto"])

## Retorna un índice aleatorio dentro del rango de cartas disponibles.
func obtener_indice_carta() -> int:
	return randi() % cartas.size()

## Inicia la animación de revelado de texto contextual para la situación actual.
func mostrar_contexto(texto: String) -> void:
	if tween_texto:
		tween_texto.kill()
	
	texto_actual = texto
	label_contexto.text = texto
	label_contexto.visible_characters = 0
	chars_mostrados = 0
	
	tween_texto = get_tree().create_tween()
	var duracion = texto.length() * 0.04
	tween_texto.tween_method(_actualizar_caracteres_visibles, 0, texto.length(), duracion)

## Aplica las bonificaciones activas de mecánicas LSG sobre los deltas de las métricas.
func obtener_efectos_modificados(efecto: Dictionary, es_correcta: bool) -> Dictionary:
	var modificado = efecto.duplicate()
	
	# Subsidio de Seguridad (ID 47, Dimensión Social 1): reduce pérdidas de presupuesto un 20%
	if LsgCore.active_mechanics.get("subsidio", false) and es_correcta:
		if modificado.get("presupuesto", 0) < 0:
			modificado["presupuesto"] = int(round(modificado["presupuesto"] * 0.8))
			
	# Ciberseguro Activo (ID 48, Dimensión Físico 2): mitiga un 50% daños a Integridad y Disponibilidad
	if LsgCore.active_mechanics.get("ciberseguro", false):
		if modificado.get("integridad", 0) < 0:
			modificado["integridad"] = int(round(modificado["integridad"] * 0.5))
		if modificado.get("disponibilidad", 0) < 0:
			modificado["disponibilidad"] = int(round(modificado["disponibilidad"] * 0.5))
			
	return modificado

## Procesa la dirección elegida por el jugador, actualiza métricas, tiempo y gestiona retroalimentación.
func _on_carta_procesada(direccion: float, data) -> void:
	var efecto_base = data["efecto_izquierda"] if direccion == -1.0 else data["efecto_derecha"]
	var es_correcta = (direccion == data["correcto"])
	
	var efecto = obtener_efectos_modificados(efecto_base, es_correcta)
	
	presupuesto_actual = clamp(presupuesto_actual + efecto["presupuesto"], 0, 100)
	confidencialidad_actual = clamp(confidencialidad_actual + efecto["confidencialidad"], 0, 100)
	integridad_actual = clamp(integridad_actual + efecto["integridad"], 0, 100)
	disponibilidad_actual = clamp(disponibilidad_actual + efecto["disponibilidad"], 0, 100)
	
	metricas_actualizadas.emit(presupuesto_actual, confidencialidad_actual, integridad_actual, disponibilidad_actual)

	var correcta = true
	if direccion == data["correcto"]:
		var contador = get_node_or_null("../CanvasLayer/MarginContainer/ContadorScore")
		if contador and contador.has_method("sumar_punto"):
			contador.sumar_punto(1)
			CapsulaManager.puntaje_ronda_actual = contador.puntaje_actual
	else:
		correcta = false
		cantidad_errores += 1
		tiempo_transcurrido += PENALIZACION_ERROR_SEGUNDOS
		print("CardManager: Error cometido. Penalización +", PENALIZACION_ERROR_SEGUNDOS, "s añadida. Total errores: ", cantidad_errores)
	
	var nodo_iconos = get_node_or_null("../FondoCarta/TextureRect/Iconos")
	if nodo_iconos and nodo_iconos.has_method("mostrar_indicadores"):
		nodo_iconos.mostrar_indicadores(null)

	if not feedback_menu:
		feedback_menu = get_node_or_null("../CanvasLayer/MarginContainer/FeedbackMenu")
		if feedback_menu:
			var boton_continuar = feedback_menu.get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/Continuar")
			if boton_continuar and not boton_continuar.pressed.is_connected(_on_feedback_continuar_pressed):
				boton_continuar.pressed.connect(_on_feedback_continuar_pressed)

	if not correcta and feedback_menu:
		var rich_explicacion = feedback_menu.get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/Explicacion")
		if rich_explicacion:
			var txt = "[b]¿Qué falló en tu decisión?[/b]\n"
			txt += data.get("explicacion", "No hay explicación disponible.") + "\n\n"
			
			var metricas_afectadas = []
			for m in ["presupuesto", "confidencialidad", "integridad", "disponibilidad"]:
				if efecto.get(m, 0) < 0:
					metricas_afectadas.append(m)
			
			if not metricas_afectadas.is_empty():
				txt += "[b][color=#ff5555]Recursos Afectados Negativamente:[/color][/b]\n"
				var metricas_nombres_es = {
					"presupuesto": "Presupuesto",
					"confidencialidad": "Confidencialidad",
					"integridad": "Integridad",
					"disponibilidad": "Disponibilidad"
				}
				for m in metricas_afectadas:
					txt += "• " + metricas_nombres_es[m] + "\n"
			
			txt += "\n[b][color=#ffaa00]Penalización aplicada : +" + str(int(PENALIZACION_ERROR_SEGUNDOS)) + " segundos.[/color][/b]"
			rich_explicacion.text = txt
		
		var boton_pausa = get_node_or_null("../CanvasLayer/MarginContainer/BotonPausa")
		if boton_pausa:
			boton_pausa.visible = false
			
		var boton_continuar = feedback_menu.get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/Continuar")
		if boton_continuar:
			boton_continuar.disabled = true
			boton_continuar.text = "Analizando incidente..."
			var timer_cooldown = get_tree().create_timer(1.5, true)
			timer_cooldown.timeout.connect(func():
				if is_instance_valid(boton_continuar):
					boton_continuar.disabled = false
					boton_continuar.text = "Continuar"
			)
			
		feedback_menu.visible = true
		get_tree().paused = true
	else:
		if chequear_derrota():
			return
		generar_carta()

## Cierra el panel de retroalimentación pedagógica y verifica derrota antes de la siguiente carta.
func _on_feedback_continuar_pressed() -> void:
	if feedback_menu:
		feedback_menu.visible = false
		
	var boton_pausa = get_node_or_null("../CanvasLayer/MarginContainer/BotonPausa")
	if boton_pausa:
		boton_pausa.visible = true
		
	get_tree().paused = false
	
	if chequear_derrota():
		return
		
	generar_carta()

## Actualiza los indicadores visuales predictivos de la carta según la inclinación del arrastre.
func _on_intencion_decision(estado: int, data) -> void:
	var efecto = null
	
	if estado != 0:
		var efecto_base = data["efecto_izquierda"] if estado == -1 else data["efecto_derecha"]
		var es_correcta = (estado == int(data["correcto"]))
		efecto = obtener_efectos_modificados(efecto_base, es_correcta)
	
	var nodo_iconos = get_node_or_null("../FondoCarta/TextureRect/Iconos")
	if nodo_iconos and nodo_iconos.has_method("mostrar_indicadores"):
		nodo_iconos.mostrar_indicadores(efecto)

## Concluye exitosamente la partida, registra métricas, acredita puntos LSG y muestra pantalla de victoria.
func ganar_juego() -> void:
	var ya_completada = CapsulaManager.capsula_activa_id < CapsulaManager.progreso_general
	
	var penalizacion_total = float(cantidad_errores) * PENALIZACION_ERROR_SEGUNDOS
	CapsulaManager.registrar_fin_de_juego(true, tiempo_transcurrido, cantidad_errores, penalizacion_total, tiempo_base_puro)
	
	if LsgAuth.logged_in:
		LsgLogger.log_game_result(
			CapsulaManager.capsula_activa_id,
			"win",
			CapsulaManager.puntaje_ronda_actual,
			cantidad_errores,
			tiempo_base_puro,
			penalizacion_total,
			tiempo_transcurrido
		)
		LsgLogger.submit_capsule_checkpoint(
			CapsulaManager.capsula_activa_id,
			"win",
			CapsulaManager.puntaje_ronda_actual,
			cantidad_errores,
			tiempo_base_puro,
			penalizacion_total,
			tiempo_transcurrido
		)
		
		if not ya_completada:
			var puntos_a_cargar = 15 + (CapsulaManager.puntaje_ronda_actual * 2)
			print("LSG-Core: Intentando acreditar ", puntos_a_cargar, " puntos en Mental por completar capsula.")
			LsgCore.adjust_points(4, "CREDIT", puntos_a_cargar, "capsule_completed")
		else:
			print("LSG-Core: Capsula ya completada anteriormente. No se acreditan puntos de recompensa.")
	
	var canvas = get_node_or_null("../CanvasLayer")
	if canvas:
		var boton_pausa = canvas.get_node_or_null("MarginContainer/BotonPausa")
		if boton_pausa:
			boton_pausa.visible = false
			
		var win_overlay = GAME_WINNER_SCENE.instantiate()
		canvas.add_child(win_overlay)
		
	get_tree().paused = true

## Registra la derrota, envía telemetría de cierre de ronda y despliega la pantalla de Game Over.
func perder_juego() -> void:
	var penalizacion_total = float(cantidad_errores) * PENALIZACION_ERROR_SEGUNDOS
	CapsulaManager.registrar_fin_de_juego(false, tiempo_transcurrido, cantidad_errores, penalizacion_total, tiempo_base_puro)
	if LsgAuth.logged_in:
		LsgLogger.log_game_result(
			CapsulaManager.capsula_activa_id,
			"lose",
			CapsulaManager.puntaje_ronda_actual,
			cantidad_errores,
			tiempo_base_puro,
			penalizacion_total,
			tiempo_transcurrido
		)
		LsgLogger.submit_capsule_checkpoint(
			CapsulaManager.capsula_activa_id,
			"lose",
			CapsulaManager.puntaje_ronda_actual,
			cantidad_errores,
			tiempo_base_puro,
			penalizacion_total,
			tiempo_transcurrido
		)
	
	var canvas = get_node_or_null("../CanvasLayer")
	if canvas:
		var boton_pausa = canvas.get_node_or_null("MarginContainer/BotonPausa")
		if boton_pausa:
			boton_pausa.visible = false
			
		var lose_overlay = GAME_OVER_SCENE.instantiate()
		canvas.add_child(lose_overlay)
		
	get_tree().paused = true

## Evalúa si alguna de las métricas cayó a 0 o menos, detonando la condición de derrota.
func chequear_derrota() -> bool:
	if presupuesto_actual <= 0:
		CapsulaManager.metrica_fallida = "presupuesto"
		perder_juego()
		return true
	elif confidencialidad_actual <= 0:
		CapsulaManager.metrica_fallida = "confidencialidad"
		perder_juego()
		return true
	elif integridad_actual <= 0:
		CapsulaManager.metrica_fallida = "integridad"
		perder_juego()
		return true
	elif disponibilidad_actual <= 0:
		CapsulaManager.metrica_fallida = "disponibilidad"
		perder_juego()
		return true
	return false

## Restaura la métrica que detonó la derrota a 50 y reanuda la partida tras comprar el salvavidas LSG.
func revivir_jugador() -> void:
	var fallida = CapsulaManager.metrica_fallida
	print("LSG-Core: Reviviendo jugador. Restaurando metrica fallida '", fallida, "' a 50.")
	match fallida:
		"presupuesto":
			presupuesto_actual = 50
		"confidencialidad":
			confidencialidad_actual = 50
		"integridad":
			integridad_actual = 50
		"disponibilidad":
			disponibilidad_actual = 50
			
	CapsulaManager.metrica_fallida = ""
	metricas_actualizadas.emit(presupuesto_actual, confidencialidad_actual, integridad_actual, disponibilidad_actual)
	generar_carta()

## Aleatoriza con 50% de probabilidad la posición (izquierda/derecha) de las opciones de cada carta.
func _aleatorizar_direcciones_cartas(lista_original: Array) -> Array:
	var lista_resultado: Array = []
	
	for carta_dict in lista_original:
		var c = carta_dict.duplicate(true)
		
		if randf() < 0.5:
			var temp_texto = c.get("texto_izquierda", "")
			c["texto_izquierda"] = c.get("texto_derecha", "")
			c["texto_derecha"] = temp_texto
			
			var temp_efecto = c.get("efecto_izquierda", {}).duplicate()
			c["efecto_izquierda"] = c.get("efecto_derecha", {}).duplicate()
			c["efecto_derecha"] = temp_efecto
			
			if c.has("correcto"):
				c["correcto"] = -float(c["correcto"])
				
		lista_resultado.append(c)
		
	return lista_resultado

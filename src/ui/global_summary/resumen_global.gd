extends Control
## Vista final de resumen global y certificación formativa de competencias.
## Consolida los resultados acumulados de todas las cápsulas, calcula porcentajes de logro
## frente al total teórico posible y emite un diagnóstico cualitativo de competencias en ciberseguridad.

@export var escena_capsulas: PackedScene = preload("res://src/ui/capsula_selector/capsula_selector.tscn")
@export var escena_menu: PackedScene = preload("res://src/ui/main_menu/menu_principal.tscn")

@onready var label_puntos_totales = $PanelPrincipal/MarginContainer/VBoxMain/PanelMetricas/MarginContainer/VBoxMetricas/HBoxPuntos/ValorPuntos
@onready var label_progreso = $PanelPrincipal/MarginContainer/VBoxMain/PanelMetricas/MarginContainer/VBoxMetricas/HBoxProgreso/ValorProgreso
@onready var contenedor_desglose = $PanelPrincipal/MarginContainer/VBoxMain/ScrollContainer/VBoxDesglose
@onready var scroll_container = $PanelPrincipal/MarginContainer/VBoxMain/ScrollContainer
@onready var label_diagnostico_titulo = $PanelPrincipal/MarginContainer/VBoxMain/PanelDiagnostico/MarginContainer/VBoxDiagnostico/TituloDiagnostico
@onready var label_diagnostico_texto = $PanelPrincipal/MarginContainer/VBoxMain/PanelDiagnostico/MarginContainer/VBoxDiagnostico/TextoDiagnostico
@onready var boton_repasar = $PanelPrincipal/MarginContainer/VBoxMain/VBoxBotones/BotonRepasar
@onready var boton_menu = $PanelPrincipal/MarginContainer/VBoxMain/VBoxBotones/BotonMenu
@onready var musica_fondo: AudioStreamPlayer = $MusicaFondo

const FUENTE_PIXEL = preload("res://assets/Fuente/acknowtt.ttf")

var arrastrando_scroll: bool = false
var ultimo_pos_y: float = 0.0

func _ready() -> void:
	boton_repasar.pressed.connect(_on_repasar_pressed)
	boton_menu.pressed.connect(_on_menu_pressed)
	
	if musica_fondo:
		if not musica_fondo.finished.is_connected(_on_musica_finished):
			musica_fondo.finished.connect(_on_musica_finished)
		musica_fondo.volume_db = -10.0
		musica_fondo.play()
	
	_cargar_datos_resumen()

func _on_musica_finished() -> void:
	if musica_fondo:
		musica_fondo.play()

## Permite el desplazamiento táctil de la lista de desglose en dispositivos móviles.
func _input(event: InputEvent) -> void:
	if not is_inside_tree() or not visible:
		return

	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			var mouse_pos = get_global_mouse_position()
			if scroll_container and scroll_container.get_global_rect().has_point(mouse_pos):
				arrastrando_scroll = true
				ultimo_pos_y = event.position.y
		else:
			arrastrando_scroll = false

	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and arrastrando_scroll:
		var delta_y = ultimo_pos_y - event.position.y
		scroll_container.scroll_vertical += int(delta_y)
		ultimo_pos_y = event.position.y

## Carga y totaliza las métricas de rendimiento por cápsula y genera las tarjetas de desglose.
func _cargar_datos_resumen() -> void:
	var max_puntos_posibles: int = 0
	for cap in CapsulaManager.lista_capsulas:
		var cartas_array = cap.get("cartas", [])
		if cartas_array is Array:
			max_puntos_posibles += cartas_array.size()
			
	var puntos = CapsulaManager.puntos_totales
	var total_capsulas = CapsulaManager.lista_capsulas.size()
	var completadas = clampi(CapsulaManager.progreso_general - 1, 0, total_capsulas)
	var porcentaje = int(round((float(completadas) / float(max(total_capsulas, 1))) * 100.0))
	
	label_puntos_totales.text = str(puntos) + " / " + str(max_puntos_posibles) + " PTS"
	label_progreso.text = str(completadas) + " / " + str(total_capsulas) + " (" + str(porcentaje) + "%)"
	
	for child in contenedor_desglose.get_children():
		child.queue_free()
		
	for cap in CapsulaManager.lista_capsulas:
		var id_cap = int(cap.get("id", 1))
		var titulo_cap = cap.get("titulo", "Cápsula " + str(id_cap))
		var record_cap = CapsulaManager.obtener_record_capsula(id_cap)
		var max_cartas_cap = cap.get("cartas", []).size() if cap.get("cartas") is Array else 10
		
		var item_panel = PanelContainer.new()
		var box_flat = StyleBoxFlat.new()
		box_flat.bg_color = Color(0.08, 0.12, 0.2, 0.85)
		box_flat.border_width_left = 1
		box_flat.border_width_top = 1
		box_flat.border_width_right = 1
		box_flat.border_width_bottom = 1
		box_flat.border_color = Color(0.0, 0.8, 0.7, 0.6)
		box_flat.set_corner_radius_all(6)
		item_panel.add_theme_stylebox_override("panel", box_flat)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 6)
		item_panel.add_child(margin)
		
		var hbox = HBoxContainer.new()
		margin.add_child(hbox)
		
		var lbl_info = Label.new()
		lbl_info.text = "Capsula " + str(id_cap) + ": " + titulo_cap
		lbl_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_info.add_theme_font_override("font", FUENTE_PIXEL)
		lbl_info.add_theme_font_size_override("font_size", 19)
		lbl_info.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD
		hbox.add_child(lbl_info)
		
		var lbl_rec = Label.new()
		lbl_rec.text = "Record: " + str(record_cap) + " / " + str(max_cartas_cap) + " pts"
		lbl_rec.add_theme_font_override("font", FUENTE_PIXEL)
		lbl_rec.add_theme_font_size_override("font_size", 19)
		lbl_rec.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1))
		hbox.add_child(lbl_rec)
		
		contenedor_desglose.add_child(item_panel)
		
	_generar_diagnostico_cualitativo(puntos, max_puntos_posibles, completadas, total_capsulas)

## Redacta el dictamen formativo según porcentaje de acierto y avance del programa.
func _generar_diagnostico_cualitativo(puntos: int, max_posibles: int, completadas: int, total: int) -> void:
	if completadas >= total and total > 0:
		var porcentaje_aciertos = (float(puntos) / float(max(max_posibles, 1))) * 100.0
		
		if porcentaje_aciertos >= 80.0:
			label_diagnostico_titulo.text = "DIAGNOSTICO: NIVEL EXPERTO EN CIBERSEGURIDAD (" + str(int(round(porcentaje_aciertos))) + "%)"
			label_diagnostico_texto.text = "Has demostrado un dominio sobresaliente en la toma de decisiones preventivas. Posees una solida capacidad para reconocer intentos de Phishing, proteger credenciales con MFA, aplicar reglas de respaldo 3-2-1 y mantener la integridad operacional de la empresa."
		else:
			label_diagnostico_titulo.text = "DIAGNOSTICO: NIVEL INTERMEDIO DE COMPETENCIAS (" + str(int(round(porcentaje_aciertos))) + "%)"
			label_diagnostico_texto.text = "Has completado todas las capsulas educativas con exito. Tienes una buena base conceptual sobre amenazas digitales. Se sugiere repasar aquellas capsulas con menor puntaje para optimizar la gestion de recursos de tu PYME."
	else:
		label_diagnostico_titulo.text = "DIAGNOSTICO: EN PROCESO DE APRENDIZAJE"
		label_diagnostico_texto.text = "Has avanzado en el programa de capacitacion. Continua completando los niveles pendientes para certificar tus competencias en ciberseguridad corporativa."

## Vuelve al selector de cápsulas para reintentar niveles.
func _on_repasar_pressed() -> void:
	get_tree().change_scene_to_packed(escena_capsulas)

## Regresa a la pantalla del menú principal del juego.
func _on_menu_pressed() -> void:
	get_tree().change_scene_to_packed(escena_menu)

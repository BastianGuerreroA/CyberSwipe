extends Control
## Pantalla de victoria y evaluación de desempeño (Game Winner).
## Presenta el desglose de resultados de la cápsula completada: puntaje obtenido, récord previo,
## tiempo total con desglose de penalizaciones por errores, animación de nuevo récord de velocidad
## y retroalimentación pedagógica de refuerzo positivo.

@export var escena_capsulas: PackedScene

@onready var label_valor_puntaje = $PanelContainer/MarginContainer/VBoxContainer/ContenedorEstadisticas/PanelPuntaje/MarginContainer/HBoxContainer/ValorPuntaje
@onready var label_valor_tiempo = $PanelContainer/MarginContainer/VBoxContainer/ContenedorEstadisticas/PanelTiempo/MarginContainer/HBoxContainer/ValorTiempo
@onready var label_detalle_penalizacion = $PanelContainer/MarginContainer/VBoxContainer/LabelDetallePenalizacion
@onready var label_valor_record = $PanelContainer/MarginContainer/VBoxContainer/HBoxRecords/Record
@onready var label_valor_record_tiempo = $PanelContainer/MarginContainer/VBoxContainer/HBoxRecords/RecordTiempo
@onready var badge_nuevo_record = $PanelContainer/MarginContainer/VBoxContainer/BadgeNuevoRecord
@onready var label_titulo_logro = $PanelContainer/MarginContainer/VBoxContainer/PanelFeedback/MarginContainer/VBoxContainer/TituloLogro
@onready var label_consejo = $PanelContainer/MarginContainer/VBoxContainer/PanelFeedback/MarginContainer/VBoxContainer/Consejo
@onready var boton_exit = $PanelContainer/MarginContainer/VBoxContainer/ExitGame

func _ready() -> void:
	var id_capsula = CapsulaManager.capsula_activa_id
	
	var record_pts = CapsulaManager.obtener_record_capsula(id_capsula)
	label_valor_puntaje.text = str(CapsulaManager.puntaje_ronda_actual)
	label_valor_record.text = "Récord: " + str(record_pts) + " pts"
	
	var tiempo_ronda_total = CapsulaManager.tiempo_ronda_actual
	var mejor_tiempo = CapsulaManager.obtener_mejor_tiempo_capsula(id_capsula)
	var errores = CapsulaManager.cantidad_errores_ronda
	var penalizacion = CapsulaManager.tiempo_penalizacion_ronda
	var tiempo_base = CapsulaManager.tiempo_base_ronda
	
	label_valor_tiempo.text = CapsulaManager.formatear_tiempo(tiempo_ronda_total)
	label_valor_record_tiempo.text = "Mejor: " + CapsulaManager.formatear_tiempo(mejor_tiempo)
	
	if label_detalle_penalizacion:
		if errores == 0:
			label_detalle_penalizacion.text = "🌟 ¡RONDA PERFECTA! (0 Fallos)"
			label_detalle_penalizacion.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		else:
			label_detalle_penalizacion.text = "⚠️ +" + str(int(penalizacion)) + " seg. de penalización (" + str(errores) + " " + ("fallo" if errores == 1 else "fallos") + " | Base: " + CapsulaManager.formatear_tiempo(tiempo_base) + ")"
			label_detalle_penalizacion.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2, 1.0))
	
	if CapsulaManager.es_nuevo_record_tiempo and badge_nuevo_record:
		badge_nuevo_record.visible = true
		_animar_badge_record()
	
	label_titulo_logro.text = "CAPSULA " + str(id_capsula) + " COMPLETADA"
	label_consejo.text = CapsulaManager.obtener_consejo_victoria(id_capsula)
	
	if id_capsula >= CapsulaManager.lista_capsulas.size():
		boton_exit.text = "VER RESUMEN GLOBAL"

## Ejecuta una animación continua de pulsación sobre el badge de nuevo récord de velocidad.
func _animar_badge_record() -> void:
	badge_nuevo_record.pivot_offset = badge_nuevo_record.size / 2.0
	var tween = create_tween().set_loops()
	tween.tween_property(badge_nuevo_record, "scale", Vector2(1.06, 1.06), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(badge_nuevo_record, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Reinicia la cápsula actual restableciendo ventajas de ronda.
func _on_reintentar_pressed() -> void:
	get_tree().paused = false
	LsgCore.reset_active_mechanics()
	get_tree().change_scene_to_file("res://src/gameplay/main_stage/escena_principal.tscn")

## Sale hacia el selector de cápsulas o al resumen global si era la última cápsula disponible.
func _on_exit_game_pressed() -> void:
	get_tree().paused = false
	LsgCore.reset_active_mechanics()
	
	if CapsulaManager.capsula_activa_id >= CapsulaManager.lista_capsulas.size():
		get_tree().change_scene_to_file("res://src/ui/global_summary/resumen_global.tscn")
	else:
		get_tree().change_scene_to_packed(escena_capsulas)

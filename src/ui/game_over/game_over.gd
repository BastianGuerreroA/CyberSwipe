extends Control
## Pantalla de derrota pedagógica (Game Over).
## Muestra la puntuación alcanzada, la causa de la derrota según la métrica agotada
## con su consejo pedagógico preventivo, y ofrece la opción de reanimación mediante
## la ventaja 'Salvavidas' (canje de puntos afectivos en LSG) o reiniciar la partida.

@onready var label_valor_puntaje = $PanelContainer/MarginContainer/VBoxContainer/PanelContainer/MarginContainer/HBoxContainer/ValorPuntaje
@onready var label_valor_record = $PanelContainer/MarginContainer/VBoxContainer/Record
@onready var label_causa_fallo = $PanelContainer/MarginContainer/VBoxContainer/PanelFeedback/MarginContainer/VBoxContainer/CausaFallo
@onready var label_consejo = $PanelContainer/MarginContainer/VBoxContainer/PanelFeedback/MarginContainer/VBoxContainer/Consejo

func _ready() -> void:
	var record = CapsulaManager.obtener_record_capsula(CapsulaManager.capsula_activa_id)
	label_valor_puntaje.text = str(CapsulaManager.puntaje_ronda_actual)
	label_valor_record.text = "Récord: " + str(record)
	
	var metrica = CapsulaManager.metrica_fallida
	if metrica != "":
		label_causa_fallo.text = "⚠️ RECURSO AGOTADO: " + metrica.to_upper()
		if CapsulaManager.CONSEJOS_DERROTA.has(metrica):
			label_consejo.text = CapsulaManager.CONSEJOS_DERROTA[metrica]
		else:
			label_consejo.text = "Recuerda vigilar todas las métricas de ciberseguridad."
	else:
		label_causa_fallo.text = "⚠️ INCIDENTE DE SEGURIDAD"
		label_consejo.text = "Intenta mantener el balance de tus métricas."

	var reanudar_btn = $PanelContainer/MarginContainer/VBoxContainer/Reanudar
	if not LsgAuth.logged_in:
		reanudar_btn.visible = false
	else:
		reanudar_btn.text = "Reanudar LSG\n(50 ptos Afectivo)"

## Inicia el proceso de compra de la ventaja 'Salvavidas' (50 puntos en dimensión Afectiva).
func _on_reanudar_pressed() -> void:
	var reanudar_btn = $PanelContainer/MarginContainer/VBoxContainer/Reanudar
	reanudar_btn.disabled = true
	reanudar_btn.text = "PROCESANDO COMPRA..."
	
	if not LsgCore.redeem_completed.is_connected(_on_redeem_completed):
		LsgCore.redeem_completed.connect(_on_redeem_completed)
		
	LsgCore.redeem_mechanic(44, 3, 50)

## Procesa la respuesta de la API de canje: restaura métricas si tuvo éxito o despliega error.
func _on_redeem_completed(success: bool, response_data: Dictionary) -> void:
	if LsgCore.redeem_completed.is_connected(_on_redeem_completed):
		LsgCore.redeem_completed.disconnect(_on_redeem_completed)
		
	var reanudar_btn = $PanelContainer/MarginContainer/VBoxContainer/Reanudar
	
	if success:
		print("LSG-Core: Salvavidas comprado con éxito. Reanudando partida...")
		LsgLogger.log_redemption("Salvavidas", 50, 3)
		
		var card_manager = get_node_or_null("/root/EscenaPrincipal/CardManager")
		if not card_manager:
			var main_node = get_parent().get_parent()
			if main_node:
				card_manager = main_node.get_node_or_null("CardManager")
				
		if card_manager and card_manager.has_method("revivir_jugador"):
			card_manager.revivir_jugador()
			
		var canvas = get_parent()
		if canvas:
			var boton_pausa = canvas.get_node_or_null("MarginContainer/BotonPausa")
			if boton_pausa:
				boton_pausa.visible = true
				
		get_tree().paused = false
		queue_free()
	else:
		reanudar_btn.disabled = false
		reanudar_btn.text = "Reanudar LSG\n(50 ptos Afectivo)"
		
		var err_data = response_data
		if response_data.has("detail"):
			var detail = response_data["detail"]
			if detail is Dictionary:
				err_data = detail
			elif detail is String:
				err_data = {"message": detail}
				
		var msg = ""
		if err_data.has("message"):
			msg = err_data["message"]
		elif err_data.has("code"):
			msg = err_data["code"]
		elif err_data.has("error"):
			msg = err_data["error"]
		else:
			msg = "Puntos insuficientes o error de red."
			
		label_causa_fallo.text = "❌ " + msg.to_upper()
		label_causa_fallo.add_theme_color_override("font_color", Color(1, 0.25, 0.25, 1))

## Reinicia la partida desde la primera carta de la cápsula activa restableciendo ventajas.
func _on_reintentar_pressed() -> void:
	get_tree().paused = false
	LsgCore.reset_active_mechanics()
	get_tree().change_scene_to_file("res://src/gameplay/main_stage/escena_principal.tscn")

## Abandona la ronda actual y retorna a la pantalla de selección de cápsulas.
func _on_exit_game_pressed() -> void:
	get_tree().paused = false
	LsgCore.reset_active_mechanics()
	get_tree().change_scene_to_file("res://src/ui/capsula_selector/capsula_selector.tscn")

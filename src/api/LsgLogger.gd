extends Node
## Módulo de telemetría y registro de sesiones para la plataforma de investigación (LSG-Logger).
## Registra eventos del ciclo de vida del juego (decisiones, canjes, puntos, resultados de rondas),
## gestiona micro-reportes (checkpoints) por cápsula jugada con persistencia preventiva offline
## y emite el reporte consolidado global al cerrar la sesión de juego.

const RUTA_BUFFER_OFFLINE = "user://telemetry_queue.json"

# Variables de estado del Logger
var session_start_time: String = ""
var events: Array = []
var total_points_earned: int = 0
var total_points_spent: int = 0
var redemptions_count: int = 0
var total_rounds_played: int = 0
var total_wins: int = 0
var total_losses: int = 0
var total_errors_committed: int = 0
var total_decision_time_seconds: float = 0.0
var round_sequence_counter: int = 0
var is_active: bool = false
var is_flushing_buffer: bool = false

# Mapeo dinámico y estático de id_point_dimension a dimension_code
var dimension_code_map: Dictionary = {
	1: "SOCIAL_BASE",
	2: "FISICO_BASE",
	3: "AFECTIVO_BASE",
	4: "MENTAL_BASE",
	6: "CONDICION_FISICA",
	11: "REG_EMOCIONAL"
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Retorna la estampa de tiempo actual del sistema en formato ISO 8601 (YYYY-MM-DDTHH:MM:SS).
func get_iso_datetime() -> String:
	return Time.get_datetime_string_from_system()

## Inicializa las variables acumuladoras y abre una nueva sesión de telemetría local.
func start_session() -> void:
	session_start_time = get_iso_datetime()
	events.clear()
	total_points_earned = 0
	total_points_spent = 0
	redemptions_count = 0
	total_rounds_played = 0
	total_wins = 0
	total_losses = 0
	total_errors_committed = 0
	total_decision_time_seconds = 0.0
	round_sequence_counter = 0
	is_active = true

	log_event("session_start", {})
	print("LSG-Logger: Sesión de telemetría iniciada localmente (UTC: ", session_start_time, ", ID Sesión: ", LsgCore.active_session_id, ")")

## Retorna el código textual correspondiente al identificador de dimensión de puntos.
func get_dimension_code(dimension_id: int) -> String:
	if dimension_code_map.has(dimension_id):
		return dimension_code_map[dimension_id]
	return "DIMENSION_" + str(dimension_id)

## Registra un evento con marca de tiempo en la lista cronológica de eventos de la sesión.
func log_event(type: String, data: Dictionary) -> void:
	if not is_active:
		return
		
	var event = {
		"type": type,
		"timestamp": get_iso_datetime(),
		"data": data
	}
	events.append(event)
	print("LSG-Logger: Evento registrado -> ", type)

## Registra un evento de canje de ventaja en la tienda o reanudación desde Game Over.
func log_redemption(mechanic_name: String, cost: int, dimension_id: int) -> void:
	if not is_active:
		return
		
	total_points_spent += cost
	redemptions_count += 1
	
	var dim_code = get_dimension_code(dimension_id)
	
	log_event("mechanic_redeemed", {
		"mechanic": mechanic_name,
		"cost": cost,
		"dimension_id": dimension_id,
		"dimension_code": dim_code
	})

## Registra la acreditación de puntos otorgados al jugador por completar objetivos.
func log_points_earned(amount: int, reason: String, dimension_id: int, dimension_code: String = "") -> void:
	if not is_active:
		return
		
	total_points_earned += amount
	
	var dim_code = dimension_code
	if dim_code.is_empty():
		dim_code = get_dimension_code(dimension_id)
		
	log_event("points_earned", {
		"amount": amount,
		"reason": reason,
		"dimension_id": dimension_id,
		"dimension_code": dim_code
	})

## Registra el desenlace de una ronda (victoria/derrota), tiempos de decisión y errores cometidos.
func log_game_result(capsule_id: int, result: String, score: int, errors_count: int = 0, raw_time: float = 0.0, penalty_time: float = 0.0, total_time: float = 0.0) -> void:
	if not is_active:
		return
		
	total_rounds_played += 1
	if result == "win":
		total_wins += 1
	else:
		total_losses += 1
	total_errors_committed += errors_count
	total_decision_time_seconds += raw_time
	
	log_event("game_completed", {
		"capsule_id": capsule_id,
		"result": result,
		"score_on_round": score,
		"errors_count": errors_count,
		"raw_time_seconds": snappedf(raw_time, 0.01),
		"penalty_time_seconds": snappedf(penalty_time, 0.01),
		"total_time_seconds": snappedf(total_time, 0.01)
	})

## Genera y transmite un micro-reporte (checkpoint) de la ronda, guardándolo preventivamente en buffer offline.
func submit_capsule_checkpoint(capsule_id: int, result: String, score: int, errors_count: int, raw_time: float, penalty_time: float, total_time: float) -> void:
	if not LsgAuth.logged_in or LsgAuth.access_token.is_empty():
		return
		
	round_sequence_counter += 1
	var round_num = round_sequence_counter
	var session_id = LsgCore.active_session_id
	var time_clean = Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "").replace("T", "_")
	var sub_session_id = "SESSION_%s_CAP_%s_R%d_%s" % [str(session_id if session_id != -1 else "LOCAL"), str(capsule_id), round_num, time_clean]
	var checkpoint_time = get_iso_datetime()
	
	var payload = {
		"player_id": LsgAuth.player_id,
		"videogame_id": LsgCore.GAME_ID,
		"id_lsg_game_session": session_id if session_id != -1 else null,
		"session_start": session_start_time if not session_start_time.is_empty() else checkpoint_time,
		"session_end": checkpoint_time,
		"mod_version": "2.0.0",
		"experiment_tag": "LSG_C1_T1_CV",
		"total_points_earned": (15 + (score * 2)) if result == "win" else 0,
		"total_points_spent": 0,
		"redemptions_count": 0,
		"raw_log": {
			"log_type": "capsule_checkpoint",
			"sub_session_id": sub_session_id,
			"capsule_id": capsule_id,
			"round_number": round_num,
			"events": [
				{
					"type": "game_completed",
					"timestamp": checkpoint_time,
					"data": {
						"capsule_id": capsule_id,
						"result": result,
						"score_on_round": score,
						"errors_count": errors_count,
						"raw_time_seconds": snappedf(raw_time, 0.01),
						"penalty_time_seconds": snappedf(penalty_time, 0.01),
						"total_time_seconds": snappedf(total_time, 0.01)
					}
				}
			],
			"summary": {
				"sub_session_id": sub_session_id,
				"round_number": round_num,
				"capsule_id": capsule_id,
				"result": result,
				"score": score,
				"errors_count": errors_count,
				"raw_time_seconds": snappedf(raw_time, 0.01),
				"penalty_time_seconds": snappedf(penalty_time, 0.01),
				"total_time_seconds": snappedf(total_time, 0.01)
			}
		}
	}
	
	_agregar_a_buffer_offline(payload)
	_enviar_payload_http(payload, true, sub_session_id)

## Consolida el informe final de telemetría de toda la sesión y lo transmite al servidor.
func submit_session_log() -> void:
	if not is_active:
		print("LSG-Logger: No hay sesión de telemetría activa para enviar.")
		return
		
	if not LsgAuth.logged_in or LsgAuth.access_token.is_empty():
		print("LSG-Logger: Imposible enviar telemetría sin usuario autenticado.")
		is_active = false
		return
		
	is_active = false
	
	var session_end_time = get_iso_datetime()
	log_event("session_end", {})
	
	var start_unix = Time.get_unix_time_from_datetime_string(session_start_time)
	var end_unix = Time.get_unix_time_from_datetime_string(session_end_time)
	var play_time_seconds = int(max(0, end_unix - start_unix))
	
	var session_id = LsgCore.active_session_id
	var payload = {
		"player_id": LsgAuth.player_id,
		"videogame_id": LsgCore.GAME_ID,
		"id_lsg_game_session": session_id if session_id != -1 else null,
		"session_start": session_start_time,
		"session_end": session_end_time,
		"mod_version": "2.0.0",
		"experiment_tag": "LSG_C1_T1_CV",
		"total_points_earned": total_points_earned,
		"total_points_spent": total_points_spent,
		"redemptions_count": redemptions_count,
		"raw_log": {
			"log_type": "session_final",
			"events": events,
			"summary": {
				"total_play_time_seconds": play_time_seconds,
				"total_points_earned": total_points_earned,
				"total_points_spent": total_points_spent,
				"redemptions_count": redemptions_count,
				"total_rounds_played": total_rounds_played,
				"total_wins": total_wins,
				"total_losses": total_losses,
				"total_errors_committed": total_errors_committed,
				"total_decision_time_seconds": snappedf(total_decision_time_seconds, 0.01)
			}
		}
	}

	print("LSG-Logger: Enviando reporte global consolidado al servidor...")
	await _enviar_payload_http(payload, false)

## Envía asíncronamente un payload HTTP al endpoint de logs de sesiones.
func _enviar_payload_http(payload: Dictionary, es_checkpoint: bool = false, sub_session_id: String = "") -> void:
	var url = LsgCore.BASE_URL + "/game-logs/sessions"
	var headers = PackedStringArray([
		"Authorization: Bearer " + LsgAuth.access_token,
		"Content-Type: application/json"
	])
	
	var http = HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.use_threads = true
	if url.begins_with("https://"):
		http.set_tls_options(TLSOptions.client_unsafe())
	add_child(http)
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		print("LSG-Logger: Error al iniciar petición HTTP de telemetría (conservado en buffer offline).")
		remove_child(http)
		http.queue_free()
		return
		
	var response = await http.request_completed
	remove_child(http)
	http.queue_free()
	
	var response_code = response[1]
	var body = response[3]
	if response_code == 200 or response_code == 201:
		if es_checkpoint:
			print("LSG-Logger: Checkpoint de cápsula enviado con éxito (Sub-ID: ", sub_session_id, ").")
			_eliminar_de_buffer_offline(sub_session_id)
		else:
			print("LSG-Logger: Reporte global consolidado enviado con éxito.")
	else:
		var err_msg = body.get_string_from_utf8()
		print("LSG-Logger: Falló envío de telemetría (Código ", response_code, "): ", err_msg, ". Queda guardado en buffer offline.")

## Envía síncronamente un payload para el proceso de vaciado secuencial del buffer offline.
func _enviar_payload_http_sync(payload: Dictionary) -> bool:
	var url = LsgCore.BASE_URL + "/game-logs/sessions"
	var headers = PackedStringArray([
		"Authorization: Bearer " + LsgAuth.access_token,
		"Content-Type: application/json"
	])
	
	var http = HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.use_threads = true
	if url.begins_with("https://"):
		http.set_tls_options(TLSOptions.client_unsafe())
	add_child(http)
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		remove_child(http)
		http.queue_free()
		return false
		
	var response = await http.request_completed
	remove_child(http)
	http.queue_free()
	
	var response_code = response[1]
	var body = response[3]
	if response_code != 200 and response_code != 201:
		print("LSG-Logger: Reintento fallido (Código ", response_code, "): ", body.get_string_from_utf8())
	return (response_code == 200 or response_code == 201)

## Lee y decodifica la cola de payloads pendientes almacenada en el archivo local JSON.
func _cargar_buffer_offline() -> Array:
	if not FileAccess.file_exists(RUTA_BUFFER_OFFLINE):
		return []
	var file = FileAccess.open(RUTA_BUFFER_OFFLINE, FileAccess.READ)
	if not file:
		return []
	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) == OK and json.data is Array:
		return json.data
	return []

## Serializa y guarda la lista de payloads pendientes en el almacenamiento local.
func _guardar_buffer_offline(cola: Array) -> void:
	var file = FileAccess.open(RUTA_BUFFER_OFFLINE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(cola, "\t"))
		file.close()

## Agrega un nuevo payload a la cola persistente del buffer offline.
func _agregar_a_buffer_offline(payload: Dictionary) -> void:
	var cola = _cargar_buffer_offline()
	cola.append(payload)
	_guardar_buffer_offline(cola)

## Remueve del buffer offline el reporte asociado al sub_session_id confirmado por el backend.
func _eliminar_de_buffer_offline(sub_session_id: String) -> void:
	var cola = _cargar_buffer_offline()
	var nueva_cola = []
	for item in cola:
		var item_sub_id = item.get("raw_log", {}).get("sub_session_id", "")
		if item_sub_id != sub_session_id:
			nueva_cola.append(item)
	_guardar_buffer_offline(nueva_cola)

## Reintenta secuencialmente el envío de todos los reportes pendientes guardados en el buffer offline.
func flush_offline_buffer() -> void:
	if is_flushing_buffer or not LsgAuth.logged_in or LsgAuth.access_token.is_empty():
		return
	var cola = _cargar_buffer_offline()
	if cola.is_empty():
		return
		
	is_flushing_buffer = true
	print("LSG-Logger: Reintentando envío de ", cola.size(), " reporte(s) guardado(s) en buffer offline...")
	
	var elementos_a_procesar = cola.duplicate()
	for payload in elementos_a_procesar:
		var sub_id = payload.get("raw_log", {}).get("sub_session_id", "")
		var exito = await _enviar_payload_http_sync(payload)
		if exito and not sub_id.is_empty():
			_eliminar_de_buffer_offline(sub_id)
			print("LSG-Logger: Reporte pendiente reenviado con éxito (Sub-ID: ", sub_id, ").")
			
	is_flushing_buffer = false

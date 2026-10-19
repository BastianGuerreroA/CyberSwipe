extends Node
## Gestor de autenticación con la API de Learning Serious Games (LSG-Auth).
## Administra la obtención y validación del JWT, la consulta del perfil del jugador (whoami)
## y la sincronización del ciclo de vida de la sesión autenticada con los demás módulos.

## Emitida cuando el inicio de sesión es exitoso, transmitiendo el nombre del jugador.
signal login_success(name: String)
## Emitida ante fallos de conexión, credenciales incorrectas o respuestas erróneas del backend.
signal login_failed(error_msg: String)
## Emitida inmediatamente antes de iniciar el procedimiento de desautenticación.
signal logging_out
## Emitida una vez concluido el cierre de sesión local y remoto.
signal logged_out

# Variables de estado de sesión
var access_token: String = ""
var logged_in: bool = false
var player_id: int = -1
var player_name: String = ""
var player_email: String = ""
var player_roles: Array = []

const BASE_URL = "https://lsg.diinf.usach.cl/lsg-auth"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Envía las credenciales del usuario (x-www-form-urlencoded) al endpoint /login para solicitar un JWT.
func login(email: String, password: String) -> void:
	var url = BASE_URL + "/login"
	var headers = PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	
	var request_data = "username=" + email.uri_encode() + "&password=" + password.uri_encode()
	
	var http = HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.use_threads = true
	if url.begins_with("https://"):
		http.set_tls_options(TLSOptions.client_unsafe())
	add_child(http)
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, request_data)
	if error != OK:
		login_failed.emit("Error al iniciar la petición de red (" + str(error) + ").")
		remove_child(http)
		http.queue_free()
		return
		
	var response = await http.request_completed
	remove_child(http)
	http.queue_free()
	
	var result = response[0]
	var response_code = response[1]
	var body = response[3]
	
	if result != HTTPRequest.RESULT_SUCCESS:
		if result == HTTPRequest.RESULT_CANT_RESOLVE:
			login_failed.emit("No se pudo resolver lsg.diinf.usach.cl. Verifica tu conexión a Wi-Fi/VPN USACH (Código 3).")
		else:
			login_failed.emit("Error de conexión al servidor (Código: " + str(result) + ").")
		return
		
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.data
			if data.has("access_token"):
				access_token = data["access_token"]
				logged_in = true
				print("LSG-Auth: Token recibido correctamente.")
				await fetch_whoami()
			else:
				login_failed.emit("Respuesta del servidor inválida (sin token).")
		else:
			login_failed.emit("Error al decodificar la respuesta JSON del servidor.")
	elif response_code == 401:
		login_failed.emit("Correo o contraseña incorrectos.")
	elif response_code == 422:
		login_failed.emit("Formato de petición inválido (422).")
	else:
		login_failed.emit("Error del servidor (Código " + str(response_code) + ").")

## Consulta la identidad y roles del jugador autenticado en el endpoint /whoami.
func fetch_whoami() -> void:
	if not logged_in or access_token.is_empty():
		login_failed.emit("No hay sesión activa.")
		return
		
	var url = BASE_URL + "/whoami"
	var headers = PackedStringArray(["Authorization: Bearer " + access_token])
	
	var http = HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.use_threads = true
	if url.begins_with("https://"):
		http.set_tls_options(TLSOptions.client_unsafe())
	add_child(http)
	
	var error = http.request(url, headers, HTTPClient.METHOD_GET, "")
	if error != OK:
		login_failed.emit("Error al consultar el perfil.")
		remove_child(http)
		http.queue_free()
		return
		
	var response = await http.request_completed
	remove_child(http)
	http.queue_free()
	
	var result = response[0]
	var response_code = response[1]
	var body = response[3]
	
	if result != HTTPRequest.RESULT_SUCCESS:
		login_failed.emit("Error de conexión al consultar el perfil.")
		return
		
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.data
			player_id = int(data.get("id_players", -1))
			player_name = data.get("name", "Usuario LSG")
			player_email = data.get("email", "")
			player_roles = data.get("roles", [])
			
			CapsulaManager.nombre_usuario = player_name
			CapsulaManager.guardar_progreso()
			
			print("LSG-Auth: Sesión iniciada para ", player_name, " (ID: ", player_id, ")")
			login_success.emit(player_name)
		else:
			login_failed.emit("Error al parsear el JSON del perfil.")
	else:
		logout()
		login_failed.emit("Error al validar el token del perfil (Código " + str(response_code) + ").")

## Cierra la sesión activa localmente, enviando telemetría pendiente y finalizando la sesión remota.
func logout() -> void:
	logging_out.emit()
	
	if LsgLogger.is_active:
		print("LSG-Auth: Enviando reporte de telemetria acumulado al cerrar sesion...")
		await LsgLogger.submit_session_log()
		
	if LsgCore.active_session_id != -1:
		print("LSG-Auth: Cerrando sesion activa en el servidor...")
		await LsgCore.end_session()
	
	access_token = ""
	logged_in = false
	player_id = -1
	player_name = ""
	player_email = ""
	player_roles = []
	
	CapsulaManager.nombre_usuario = "Usuario"
	CapsulaManager.guardar_progreso()
	
	print("LSG-Auth: Sesión cerrada localmente.")
	logged_out.emit()

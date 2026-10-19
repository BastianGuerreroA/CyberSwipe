extends Node
## Administrador de sincronización y almacenamiento local de cápsulas (.lsg).
## Garantiza la existencia del directorio local 'user://capsules/', copia las semillas base iniciales
## y gestiona la descarga y actualización de contenido dinámico desde el repositorio de GitHub.

## Emitida al finalizar el proceso de sincronización con GitHub (indica si fue exitosa).
signal content_sync_completed(success: bool)

var is_syncing: bool = false
var last_sync_success: bool = false

const RUTA_USER_CAPSULAS = "user://capsules/"
const RUTA_RES_CAPSULAS = "res://resources/data/capsules/"
const GITHUB_API_URL = "https://api.github.com/repos/BastianGuerreroA/CyberSwipe-Content/contents/content"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	preparar_directorio_local()

## Verifica y crea la carpeta 'user://capsules/' si no existe, y copia las semillas iniciales si está vacía.
func preparar_directorio_local() -> void:
	var dir_user := DirAccess.open("user://")
	if dir_user:
		if not dir_user.dir_exists("capsules"):
			dir_user.make_dir("capsules")
			print("ContentManager: Creada carpeta de usuario 'user://capsules/'")
			
	if not _tiene_capsulas_locales():
		print("ContentManager: La carpeta 'user://capsules/' está vacía. Copiando semillas base desde res://...")
		_copiar_semillas_base()

## Determina si ya existen archivos .lsg en el almacenamiento del usuario.
func _tiene_capsulas_locales() -> bool:
	var dir := DirAccess.open(RUTA_USER_CAPSULAS)
	if not dir:
		return false
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".lsg"):
			dir.list_dir_end()
			return true
		file_name = dir.get_next()
	dir.list_dir_end()
	return false

## Copia los archivos .lsg empaquetados por defecto en 'res://' hacia la carpeta 'user://' del dispositivo.
func _copiar_semillas_base() -> void:
	var dir_res := DirAccess.open(RUTA_RES_CAPSULAS)
	if not dir_res:
		print("ContentManager: No se encontró la carpeta base de recursos: ", RUTA_RES_CAPSULAS)
		return
		
	dir_res.list_dir_begin()
	var file_name := dir_res.get_next()
	while file_name != "":
		if not dir_res.current_is_dir() and file_name.ends_with(".lsg"):
			var origen := RUTA_RES_CAPSULAS + file_name
			var destino := RUTA_USER_CAPSULAS + file_name
			
			var bytes := FileAccess.get_file_as_bytes(origen)
			if not bytes.is_empty():
				var f_out := FileAccess.open(destino, FileAccess.WRITE)
				if f_out:
					f_out.store_buffer(bytes)
					f_out.close()
					print("ContentManager: Copiada semilla exitosa -> ", file_name)
		file_name = dir_res.get_next()
	dir_res.list_dir_end()

## Consulta la API de GitHub para descargar y sincronizar cápsulas (.lsg) actualizadas.
func sincronizar_con_github() -> void:
	is_syncing = true
	print("ContentManager: Consultando repositorio de GitHub (BastianGuerreroA/CyberSwipe-Content)...")
	
	var http := HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.use_threads = true
	if GITHUB_API_URL.begins_with("https://"):
		http.set_tls_options(TLSOptions.client_unsafe())
	add_child(http)
	
	var headers := PackedStringArray([
		"User-Agent: GodotEngine/CyberSwipe",
		"Accept: application/vnd.github.v3+json"
	])
	
	var err := http.request(GITHUB_API_URL, headers, HTTPClient.METHOD_GET, "")
	if err != OK:
		print("ContentManager: Error al iniciar petición HTTP a GitHub (", err, ")")
		remove_child(http)
		http.queue_free()
		_finalizar_sincronizacion(false)
		return
		
	var response = await http.request_completed
	remove_child(http)
	http.queue_free()
	
	var result: int = response[0]
	var code: int = response[1]
	var body: PackedByteArray = response[3]
	
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		print("ContentManager: No se pudo obtener la lista de contenido de GitHub (Código HTTP ", code, ", Resultado ", result, ")")
		_finalizar_sincronizacion(false)
		return
		
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		print("ContentManager: Error al parsear JSON devuelto por la API de GitHub.")
		_finalizar_sincronizacion(false)
		return
		
	var lista_archivos: Array = json.data as Array
	if lista_archivos.is_empty():
		print("ContentManager: Repositorio de GitHub vacío o sin cápsulas.")
		_finalizar_sincronizacion(false)
		return
		
	var descargados: int = 0
	for item in lista_archivos:
		if item is Dictionary and item.get("type") == "file":
			var name: String = item.get("name", "")
			var download_url: String = item.get("download_url", "")
			
			if name.ends_with(".lsg") and not download_url.is_empty():
				var ok := await _descargar_un_archivo(download_url, RUTA_USER_CAPSULAS + name)
				if ok:
					descargados += 1
					
	print("ContentManager: Sincronización completada. Se descargaron ", descargados, " cápsulas desde GitHub.")
	_finalizar_sincronizacion(true)

## Actualiza las banderas de sincronización y emite la señal de término.
func _finalizar_sincronizacion(success: bool) -> void:
	is_syncing = false
	last_sync_success = success
	content_sync_completed.emit(success)

## Descarga un archivo binario individual (.lsg) desde la URL dada y lo persiste en disco.
func _descargar_un_archivo(url: String, destino: String) -> bool:
	var http := HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.use_threads = true
	if url.begins_with("https://"):
		http.set_tls_options(TLSOptions.client_unsafe())
	add_child(http)
	
	var headers := PackedStringArray(["User-Agent: GodotEngine/CyberSwipe"])
	var err := http.request(url, headers, HTTPClient.METHOD_GET, "")
	if err != OK:
		remove_child(http)
		http.queue_free()
		return false
		
	var response = await http.request_completed
	remove_child(http)
	http.queue_free()
	
	var result: int = response[0]
	var code: int = response[1]
	var body: PackedByteArray = response[3]
	
	if result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 304):
		var file := FileAccess.open(destino, FileAccess.WRITE)
		if file:
			file.store_buffer(body)
			file.close()
			print("ContentManager: Descargado y guardado -> ", destino)
			return true
	return false


extends Node
## Administrador central de cápsulas de contenido y estado de progreso del jugador (Autoload).
## Gestiona el desbloqueo progresivo de niveles, la carga de datos cifrados (.lsg),
## la persistencia local (.tres) de puntuaciones y récords de velocidad, y la provisión
## de retroalimentación pedagógica en victorias y derrotas.

# Variables de estado global
var nombre_usuario: String = "Usuario"
var puntos_totales: int = 0
var progreso_general: int = 1
var lista_capsulas: Array = []
var capsula_activa_id: int = 1
var puntaje_ronda_actual: int = 0
var puntajes_maximos: Dictionary = {}
var tiempo_ronda_actual: float = 0.0
var tiempo_base_ronda: float = 0.0
var cantidad_errores_ronda: int = 0
var tiempo_penalizacion_ronda: float = 0.0
var mejores_tiempos: Dictionary = {}
var es_nuevo_record_tiempo: bool = false

# Variable global para registrar la métrica que causó la derrota en la última ronda
var metrica_fallida: String = ""

# Diccionario centralizado de consejos pedagógicos por derrota
const CONSEJOS_DERROTA = {
	"presupuesto": "El presupuesto se agotó. Recuerda que la ciberseguridad no es solo un gasto, sino una inversión necesaria para mitigar incidentes costosos.",
	"confidencialidad": "Fallo de Confidencialidad. Protege tus accesos utilizando contraseñas seguras, gestores y activando doble factor (MFA).",
	"integridad": "Fallo de Integridad. La información crítica se alteró o borró. Mantén respaldos constantes para garantizar que tus datos sean confiables.",
	"disponibilidad": "Fallo de Disponibilidad. Los sistemas quedaron inoperativos (ej. Ransomware). Implementa respaldos offline (fuera de red) y climatiza tus racks."
}

# Colección centralizada de consejos pedagógicos genéricos por victoria
const CONSEJOS_VICTORIA_GENERICOS = [
	"¡Excelente trabajo! Has demostrado una gran capacidad para tomar decisiones seguras y proteger los activos de la empresa.",
	"¡Felicitaciones! Aplicaste correctamente las mejores prácticas de ciberseguridad para mitigar los riesgos digitales.",
	"¡Gran desempeño! Mantener una postura preventiva es clave para defender la infraestructura y los datos de tu PYME.",
	"¡Nivel superado! Demostraste un excelente criterio ante las amenazas y vulnerabilidades presentadas.",
	"¡Fantástico! Tu gestión oportuna de los recursos evitó incidentes graves y fortaleció la ciberseguridad corporativa."
]

## Retorna el consejo de victoria pedagógico correspondiente a la cápsula, priorizando su texto específico.
func obtener_consejo_victoria(id: int) -> String:
	var cap = obtener_capsula(id)
	if not cap.is_empty() and cap.has("consejo_victoria") and str(cap["consejo_victoria"]).strip_edges() != "":
		return cap["consejo_victoria"]
		
	if CONSEJOS_VICTORIA_GENERICOS.size() > 0:
		var idx = posmod(id - 1, CONSEJOS_VICTORIA_GENERICOS.size())
		return CONSEJOS_VICTORIA_GENERICOS[idx]
		
	return "¡Buen trabajo manteniendo protegida la ciberseguridad de tu PYME!"

const RUTA_GUARDADO_TRES = "user://progreso_usuario.tres"
const RUTA_CARPETA_CAPSULAS = "user://capsules/"

const RUTA_ICONOS_CAPSULAS = "res://assets/IconosCapsulas/capsula_"
const RUTA_ICONO_DEFECTO = "res://assets/IconosPixelArt/MedallaPixelArt.png"

## Retorna dinámicamente la textura del icono asociado a la cápsula indicada, o un fallback por defecto.
func obtener_icono_capsula(id: int) -> Texture2D:
	var ruta_icono = RUTA_ICONOS_CAPSULAS + str(id) + ".png"
	if ResourceLoader.exists(ruta_icono):
		return load(ruta_icono) as Texture2D
		
	if ResourceLoader.exists(RUTA_ICONO_DEFECTO):
		return load(RUTA_ICONO_DEFECTO) as Texture2D
		
	return null

func _ready() -> void:
	ContentManager.preparar_directorio_local()
	cargar_contenido_capsulas()
	cargar_progreso_jugador()
	
	if not ContentManager.content_sync_completed.is_connected(_on_content_sync_completed):
		ContentManager.content_sync_completed.connect(_on_content_sync_completed)
		
	ContentManager.sincronizar_con_github()

func _on_content_sync_completed(_success: bool) -> void:
	print("CapsulaManager: Sincronización finalizada. Recargando cápsulas...")
	cargar_contenido_capsulas()

## Lee y descifra los archivos .lsg desde el almacenamiento local, ordenando las cápsulas por su ID.
func cargar_contenido_capsulas() -> void:
	lista_capsulas.clear()

	var dir := DirAccess.open(RUTA_CARPETA_CAPSULAS)
	if dir == null:
		push_error("No existe la carpeta de cápsulas: " + RUTA_CARPETA_CAPSULAS)
		return

	dir.list_dir_begin()
	var file := dir.get_next()

	while file != "":
		if !dir.current_is_dir():
			if file.ends_with(".lsg"):
				if file == "index.lsg":
					file = dir.get_next()
					continue

				var path := RUTA_CARPETA_CAPSULAS + file
				var capsule := CryptoManager.load_capsule(path)

				if !capsule.is_empty():
					lista_capsulas.append(capsule)
				else:
					push_warning("No se pudo cargar " + file)

		file = dir.get_next()

	dir.list_dir_end()

	lista_capsulas.sort_custom(
		func(a, b):
			return a.get("id", 0) < b.get("id", 0)
	)

	print("Capsulas cargadas: ", lista_capsulas.size())

## Carga los récords y datos persistentes del jugador desde el recurso local (.tres).
func cargar_progreso_jugador() -> void:
	if ResourceLoader.exists(RUTA_GUARDADO_TRES):
		var progreso = ResourceLoader.load(RUTA_GUARDADO_TRES) as ProgresoUsuario
		if progreso:
			nombre_usuario = progreso.nombre_usuario
			puntos_totales = progreso.puntos_totales
			progreso_general = progreso.progreso_general
			puntajes_maximos = progreso.puntajes_maximos
			mejores_tiempos = progreso.mejores_tiempos if progreso.mejores_tiempos != null else {}
			if progreso_general < 1:
				progreso_general = 1
			print("Progreso del usuario cargado desde Resource (.tres)")

## Serializa el estado actual del jugador y lo persiste en disco como ProgresoUsuario (.tres).
func guardar_progreso() -> void:
	var progreso = ProgresoUsuario.new()
	progreso.nombre_usuario = nombre_usuario
	progreso.puntos_totales = puntos_totales
	progreso.progreso_general = progreso_general
	progreso.puntajes_maximos = puntajes_maximos
	progreso.mejores_tiempos = mejores_tiempos
	
	var error = ResourceSaver.save(progreso, RUTA_GUARDADO_TRES)
	if error == OK:
		print("Progreso guardado exitosamente en formato Resource (.tres)")
	else:
		print("Error al guardar el Resource (.tres): ", error)

## Retorna el diccionario de datos de una cápsula específica buscando por su ID.
func obtener_capsula(id: int) -> Dictionary:
	for cap in lista_capsulas:
		if cap["id"] == id:
			return cap
	return {}

## Retorna la lista de cartas de la cápsula activa actual.
func obtener_cartas_de_capsula_activa() -> Array:
	var cap = obtener_capsula(capsula_activa_id)
	if not cap.is_empty() and cap.has("cartas"):
		return cap["cartas"]
	return []

## Retorna la puntuación récord alcanzada en la cápsula especificada.
func obtener_record_capsula(id: int) -> int:
	if puntajes_maximos.has(id):
		return puntajes_maximos[id]
	return 0

## Retorna el mejor tiempo registrado en segundos para la cápsula dada, o 0.0 si no existe.
func obtener_mejor_tiempo_capsula(id: int) -> float:
	if mejores_tiempos.has(id):
		return float(mejores_tiempos[id])
	return 0.0

## Formatea una cantidad de segundos a una cadena con formato cronómetro 'MM:SS.cs'.
func formatear_tiempo(segundos: float) -> String:
	if segundos <= 0.0:
		return "--:--"
	var mins: int = int(segundos) / 60
	var segs: int = int(segundos) % 60
	var centesimas: int = int((segundos - int(segundos)) * 100.0)
	return "%02d:%02d.%02d" % [mins, segs, centesimas]

## Registra el desenlace de la ronda (victoria o derrota), actualiza récords y desbloquea niveles.
func registrar_fin_de_juego(victoria: bool, tiempo_final: float = 0.0, errores: int = 0, penalizacion_total: float = 0.0, tiempo_base: float = 0.0) -> void:
	tiempo_ronda_actual = tiempo_final
	cantidad_errores_ronda = errores
	tiempo_penalizacion_ronda = penalizacion_total
	tiempo_base_ronda = tiempo_base
	es_nuevo_record_tiempo = false
	var record_actual = obtener_record_capsula(capsula_activa_id)
	
	# 1. Registrar récord de puntaje si fue superado
	if puntaje_ronda_actual > record_actual:
		puntajes_maximos[capsula_activa_id] = puntaje_ronda_actual
		
		var suma = 0
		for record in puntajes_maximos.values():
			suma += record
		puntos_totales = suma
	
	# 2. Registrar el mejor tiempo de velocidad si se ganó la cápsula
	if victoria and tiempo_final > 0.0:
		var record_tiempo_previo = obtener_mejor_tiempo_capsula(capsula_activa_id)
		if record_tiempo_previo <= 0.0 or tiempo_final < record_tiempo_previo:
			mejores_tiempos[capsula_activa_id] = tiempo_final
			es_nuevo_record_tiempo = true
			print("CapsulaManager: ¡Nuevo récord de tiempo para cápsula ", capsula_activa_id, "! -> ", formatear_tiempo(tiempo_final), " (Errores: ", errores, ", Penalización: +", penalizacion_total, " seg.)")
	
	# 3. Desbloquear la siguiente cápsula si el jugador ganó su nivel máximo alcanzado
	if victoria and capsula_activa_id == progreso_general:
		progreso_general = clampi(progreso_general + 1, 1, lista_capsulas.size() + 1)
	
	# 4. Guardar cambios en el recurso .tres
	guardar_progreso()

## Verifica si existe al menos una cápsula (.lsg) válida en la carpeta de usuario.
func existen_capsulas() -> bool:
	var dir := DirAccess.open(RUTA_CARPETA_CAPSULAS)
	if dir == null:
		return false

	dir.list_dir_begin()
	var file := dir.get_next()

	while file != "":
		if file.ends_with(".lsg"):
			if file != "index.lsg":
				dir.list_dir_end()
				return true

		file = dir.get_next()
	dir.list_dir_end()
	return false

## Retorna la cantidad total de cápsulas cargadas en memoria.
func obtener_total_capsulas() -> int:
	return lista_capsulas.size()

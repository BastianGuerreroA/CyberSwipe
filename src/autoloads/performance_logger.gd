extends Node
## Registrador singleton de rendimiento y métricas energéticas (Autoload).
## Realiza muestreo periódico (FPS, tiempos de cuadro, memoria) y telemetría de batería en Android
## a través de la API BatteryManager, exportando los datos en formato CSV (muestras y resumen consolidado).

const LOG_FILE_PATH := "user://performance_log.csv"
const SUMMARY_FILE_PATH := "user://performance_summary.csv"
const SAMPLE_INTERVAL := 1.0
const UNAVAILABLE_VALUE := -1.0
const INT_MIN := -2147483648
const LONG_MIN := -9223372036854775808

var _start_timestamp_msec := 0
var _start_datetime_str := ""
var _timer_accumulator := 0.0
var _sample_count := 0

var _initial_load_time := -1.0
var _is_initial_load_done := false
var _total_gameplay_time := 0.0

var _log_entries: Array[Dictionary] = []
var _file_log: FileAccess = null
var _summary_saved := false

# Android BatteryManager
var _android_battery_class = null
var _android_battery_manager = null

var _initial_battery_percent := UNAVAILABLE_VALUE
var _initial_battery_charge_mah := UNAVAILABLE_VALUE
var _initial_battery_energy_wh := UNAVAILABLE_VALUE

var _final_battery_percent := UNAVAILABLE_VALUE
var _final_battery_charge_mah := UNAVAILABLE_VALUE
var _final_battery_energy_wh := UNAVAILABLE_VALUE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_start_timestamp_msec = Time.get_ticks_msec()
	_start_datetime_str = Time.get_datetime_string_from_system(false, true)

	_initialize_android_metrics()
	_abrir_archivo_log()

	_initial_battery_percent = _get_battery_percent()
	_initial_battery_charge_mah = _get_battery_charge_counter()
	_initial_battery_energy_wh = _get_battery_energy_counter()


## Inicializa la conexión con BatteryManager en Android mediante JavaClassWrapper.
func _initialize_android_metrics() -> void:
	if OS.get_name() != "Android":
		return

	_android_battery_class = JavaClassWrapper.wrap(
		"android.os.BatteryManager"
	)

	if _android_battery_class == null:
		return

	if JavaClassWrapper.get_exception() != null:
		_android_battery_class = null
		return

	if not Engine.has_singleton("AndroidRuntime"):
		return

	var android_runtime = Engine.get_singleton("AndroidRuntime")

	if android_runtime == null:
		return

	var context = android_runtime.getApplicationContext()

	if JavaClassWrapper.get_exception() != null or context == null:
		return

	_android_battery_manager = context.getSystemService(
		"batterymanager"
	)

	if JavaClassWrapper.get_exception() != null:
		_android_battery_manager = null


## Inicializa y escribe la cabecera del archivo CSV de muestras temporales.
func _abrir_archivo_log() -> void:
	_file_log = FileAccess.open(
		LOG_FILE_PATH,
		FileAccess.WRITE
	)

	if _file_log:
		_file_log.store_string("\uFEFF")
		_file_log.store_string(
			"Tiempo,FPS,FrameTime(ms),Memoria(MB)," +
			"MemoriaMax(MB),EscenaActual," +
			"Bateria(%),Carga(mAh),Corriente(mA),Energia(Wh)\n"
		)
		_file_log.flush()
	else:
		push_error(
			"[PerformanceLogger] No se pudo crear el archivo log."
		)


func _process(delta: float) -> void:
	_timer_accumulator += delta

	if _timer_accumulator >= SAMPLE_INTERVAL:
		_timer_accumulator -= SAMPLE_INTERVAL
		_registrar_muestra()


## Registra el tiempo de carga transcurrido desde el inicio de la app hasta que la primera escena está lista.
func mark_initial_load_complete() -> void:
	if not _is_initial_load_done:
		_is_initial_load_done = true
		_initial_load_time = (
			Time.get_ticks_msec() - _start_timestamp_msec
		) / 1000.0


## Registra periódicamente las métricas de rendimiento y energía en memoria y en el archivo CSV.
func _registrar_muestra() -> void:
	var tiempo_seg := _sample_count
	_sample_count += 1

	if not _is_initial_load_done:
		if get_tree().current_scene != null:
			mark_initial_load_complete()

	# Rendimiento
	var fps := Performance.get_monitor(
		Performance.TIME_FPS
	)

	var frame_time_ms := Performance.get_monitor(
		Performance.TIME_PROCESS
	) * 1000.0

	var memory_mb := Performance.get_monitor(
		Performance.MEMORY_STATIC
	) / (1024.0 * 1024.0)

	var memory_max_mb := Performance.get_monitor(
		Performance.MEMORY_STATIC_MAX
	) / (1024.0 * 1024.0)

	# Escena actual
	var scene_name := "Desconocida"
	var current_scene = get_tree().current_scene

	if current_scene:
		scene_name = current_scene.name

		var scene_path: String = current_scene.scene_file_path.to_lower() if current_scene.scene_file_path else ""

		if (
			"gameplay" in scene_path
			or "escena_principal" in scene_path
			or "escena_estudio" in scene_path
		):
			_total_gameplay_time += SAMPLE_INTERVAL

	# Batería
	var battery_percent := _get_battery_percent()
	var battery_charge_mah := _get_battery_charge_counter()
	var battery_current_ma := _get_battery_current_now()
	var battery_energy_wh := _get_battery_energy_counter()

	if battery_percent > 0.0:
		_final_battery_percent = battery_percent
	if battery_charge_mah > 0.0:
		_final_battery_charge_mah = battery_charge_mah
	if battery_energy_wh > 0.0:
		_final_battery_energy_wh = battery_energy_wh

	var record := {
		"tiempo": tiempo_seg,
		"fps": fps,
		"frame_time": frame_time_ms,
		"memoria": memory_mb,
		"memoria_max": memory_max_mb,
		"escena": scene_name,
		"bateria_percent": battery_percent,
		"bateria_charge_mah": battery_charge_mah,
		"bateria_current_ma": battery_current_ma,
		"bateria_energy_wh": battery_energy_wh
	}

	_log_entries.append(record)

	if _file_log:
		_file_log.store_string(
			"%d,%.1f,%.2f,%.2f,%.2f,%s,%.1f,%.2f,%.2f,%.6f\n"
			% [
				tiempo_seg,
				fps,
				frame_time_ms,
				memory_mb,
				memory_max_mb,
				scene_name,
				battery_percent,
				battery_charge_mah,
				battery_current_ma,
				battery_energy_wh
			]
		)
		_file_log.flush()


## Obtiene el porcentaje de batería actual (0.0 - 100.0) a través de Android BatteryManager.
func _get_battery_percent() -> float:
	if (
		OS.get_name() != "Android"
		or _android_battery_manager == null
		or _android_battery_class == null
	):
		return UNAVAILABLE_VALUE

	var value = _android_battery_manager.getIntProperty(
		_android_battery_class.BATTERY_PROPERTY_CAPACITY
	)

	if JavaClassWrapper.get_exception() != null:
		return UNAVAILABLE_VALUE

	if value == INT_MIN or value <= 0:
		return UNAVAILABLE_VALUE

	var result := float(value)

	if result < 0.0 or result > 100.0:
		return UNAVAILABLE_VALUE

	return result


## Obtiene la carga restante de la batería en mAh (miliamperios-hora).
func _get_battery_charge_counter() -> float:
	if (
		OS.get_name() != "Android"
		or _android_battery_manager == null
		or _android_battery_class == null
	):
		return UNAVAILABLE_VALUE

	var value = _android_battery_manager.getIntProperty(
		_android_battery_class.BATTERY_PROPERTY_CHARGE_COUNTER
	)

	if JavaClassWrapper.get_exception() != null:
		return UNAVAILABLE_VALUE

	if value == INT_MIN or value <= 0:
		return UNAVAILABLE_VALUE

	# Android entrega μAh
	return float(value) / 1000.0


## Obtiene la corriente instantánea de la batería en mA (miliamperios).
func _get_battery_current_now() -> float:
	if (
		OS.get_name() != "Android"
		or _android_battery_manager == null
		or _android_battery_class == null
	):
		return UNAVAILABLE_VALUE

	var value = _android_battery_manager.getIntProperty(
		_android_battery_class.BATTERY_PROPERTY_CURRENT_NOW
	)

	if JavaClassWrapper.get_exception() != null:
		return UNAVAILABLE_VALUE

	if value == INT_MIN:
		return UNAVAILABLE_VALUE

	# Android entrega μA
	return float(value) / 1000.0


## Obtiene la energía restante de la batería en Wh (vatios-hora).
func _get_battery_energy_counter() -> float:
	if (
		OS.get_name() != "Android"
		or _android_battery_manager == null
		or _android_battery_class == null
	):
		return UNAVAILABLE_VALUE

	var value = _android_battery_manager.getLongProperty(
		_android_battery_class.BATTERY_PROPERTY_ENERGY_COUNTER
	)

	if JavaClassWrapper.get_exception() != null:
		return UNAVAILABLE_VALUE

	if value == LONG_MIN or value <= 0:
		return UNAVAILABLE_VALUE

	# Android entrega nWh
	return float(value) / 1_000_000_000.0


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_WM_CLOSE_REQUEST
		or what == NOTIFICATION_PREDELETE
	):
		guardar_resumen()


## Consolida todas las muestras recolectadas y genera el archivo CSV final de resumen de sesión.
func guardar_resumen() -> void:
	if _summary_saved:
		return

	_summary_saved = true

	if _file_log:
		_file_log.close()
		_file_log = null

	var fresh_pct := _get_battery_percent()
	if fresh_pct > 0.0:
		_final_battery_percent = fresh_pct

	var fresh_charge := _get_battery_charge_counter()
	if fresh_charge > 0.0:
		_final_battery_charge_mah = fresh_charge

	var fresh_energy := _get_battery_energy_counter()
	if fresh_energy > 0.0:
		_final_battery_energy_wh = fresh_energy

	var summary_file := FileAccess.open(
		SUMMARY_FILE_PATH,
		FileAccess.WRITE
	)

	if not summary_file:
		push_error(
			"[PerformanceLogger] No se pudo crear el resumen."
		)
		return

	summary_file.store_string("\uFEFF")

	var end_datetime_str := Time.get_datetime_string_from_system(
		false,
		true
	)

	var total_session_time := (
		Time.get_ticks_msec() - _start_timestamp_msec
	) / 1000.0

	var total_fps := 0.0
	var min_fps := 9999.0
	var max_fps := 0.0
	var total_frame_time := 0.0
	var total_memory := 0.0
	var max_memory := 0.0

	for entry in _log_entries:
		var fps: float = entry["fps"]

		total_fps += fps
		min_fps = min(min_fps, fps)
		max_fps = max(max_fps, fps)

		total_frame_time += entry["frame_time"]

		var memory: float = entry["memoria"]

		total_memory += memory
		max_memory = max(
			max_memory,
			float(entry["memoria_max"]),
			memory
		)

	if _log_entries.is_empty():
		min_fps = 0.0

	var count: float = float(max(1, _log_entries.size()))

	var avg_fps: float = total_fps / count
	var avg_frame_time: float = total_frame_time / count
	var avg_memory: float = total_memory / count

	# Consumo energético observado
	var battery_percent_drop := UNAVAILABLE_VALUE
	var battery_charge_consumed := UNAVAILABLE_VALUE
	var battery_energy_consumed := UNAVAILABLE_VALUE
	var average_power := UNAVAILABLE_VALUE

	if (
		_initial_battery_percent >= 0.0
		and _final_battery_percent >= 0.0
	):
		battery_percent_drop = (
			_initial_battery_percent
			- _final_battery_percent
		)

	if (
		_initial_battery_charge_mah >= 0.0
		and _final_battery_charge_mah >= 0.0
	):
		battery_charge_consumed = (
			_initial_battery_charge_mah
			- _final_battery_charge_mah
		)

	if (
		_initial_battery_energy_wh >= 0.0
		and _final_battery_energy_wh >= 0.0
	):
		battery_energy_consumed = (
			_initial_battery_energy_wh
			- _final_battery_energy_wh
		)

	if (
		battery_energy_consumed >= 0.0
		and total_session_time > 0.0
	):
		average_power = battery_energy_consumed / (
			total_session_time / 3600.0
		)

	var initial_load := "N/A"

	if _initial_load_time >= 0.0:
		initial_load = "%.2f" % _initial_load_time

	# Rendimiento
	summary_file.store_string("Metrica,Valor\n")
	summary_file.store_string("FPS promedio,%.1f\n" % avg_fps)
	summary_file.store_string("FPS minimo,%.1f\n" % min_fps)
	summary_file.store_string("FPS maximo,%.1f\n" % max_fps)
	summary_file.store_string(
		"FrameTime promedio (ms),%.2f\n" % avg_frame_time
	)
	summary_file.store_string(
		"Memoria promedio (MB),%.2f\n" % avg_memory
	)
	summary_file.store_string(
		"Memoria maxima (MB),%.2f\n" % max_memory
	)
	summary_file.store_string(
		"Tiempo carga inicial (s),%s\n" % initial_load
	)
	summary_file.store_string(
		"Tiempo partida (s),%.1f\n" % _total_gameplay_time
	)
	summary_file.store_string(
		"Tiempo total sesion (s),%.1f\n" % total_session_time
	)

	# Batería
	summary_file.store_string(
		"Bateria inicial (%),"
		+ _format_metric(_initial_battery_percent, "%.1f") + "\n"
	)
	summary_file.store_string(
		"Bateria final (%),"
		+ _format_metric(_final_battery_percent, "%.1f") + "\n"
	)
	summary_file.store_string(
		"Disminucion bateria (puntos),"
		+ _format_metric(battery_percent_drop, "%.1f") + "\n"
	)
	summary_file.store_string(
		"Carga inicial (mAh),"
		+ _format_metric(_initial_battery_charge_mah, "%.2f") + "\n"
	)
	summary_file.store_string(
		"Carga final (mAh),"
		+ _format_metric(_final_battery_charge_mah, "%.2f") + "\n"
	)
	summary_file.store_string(
		"Carga disminuida (mAh),"
		+ _format_metric(battery_charge_consumed, "%.2f") + "\n"
	)
	summary_file.store_string(
		"Energia inicial (Wh),"
		+ _format_metric(_initial_battery_energy_wh, "%.6f") + "\n"
	)
	summary_file.store_string(
		"Energia final (Wh),"
		+ _format_metric(_final_battery_energy_wh, "%.6f") + "\n"
	)
	summary_file.store_string(
		"Energia disminuida (Wh),"
		+ _format_metric(battery_energy_consumed, "%.6f") + "\n"
	)
	summary_file.store_string(
		"Potencia media observada (W),"
		+ _format_metric(average_power, "%.4f") + "\n"
	)

	# Dispositivo
	summary_file.store_string(
		"Sistema Operativo,%s\n" % OS.get_name()
	)
	summary_file.store_string(
		"Modelo Dispositivo,%s\n" % OS.get_model_name()
	)
	summary_file.store_string(
		"Total registros,%d\n" % _log_entries.size()
	)
	summary_file.store_string(
		"Fecha y Hora Inicio,%s\n" % _start_datetime_str
	)
	summary_file.store_string(
		"Fecha y Hora Fin,%s\n" % end_datetime_str
	)

	summary_file.flush()
	summary_file.close()


## Formatea un valor numérico de métrica con el formato especificado o retorna 'N/A' si es negativo.
func _format_metric(value: float, format: String) -> String:
	if value < 0.0:
		return "N/A"

	return format % value

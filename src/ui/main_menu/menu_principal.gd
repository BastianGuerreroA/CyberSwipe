extends Control
## Controlador del menú principal del juego (Main Menu).
## Gestiona la música de ambientación, el indicador visual de sincronización de contenido remoto
## y el despliegue del badge de estado de conexión/modo offline.

@onready var music_menu: AudioStreamPlayer = $MusicMenu
@onready var contenedor_botones: VBoxContainer = $MarginContainer/VBoxContainer
@onready var contenedor_cargando: VBoxContainer = $MarginContainer/ContenedorCargando
@onready var icono_spinner: TextureRect = $MarginContainer/ContenedorCargando/IconoSpinner
@onready var badge_estado: Label = $MarginContainer/CanvasLayer/BadgeEstado

func _ready() -> void:
	if not music_menu.finished.is_connected(_on_music_finished):
		music_menu.finished.connect(_on_music_finished)
	music_menu.play()
	
	if not ContentManager.content_sync_completed.is_connected(_on_content_sync_completed):
		ContentManager.content_sync_completed.connect(_on_content_sync_completed)
		
	_actualizar_estado_interfaz()

## Anima la rotación del icono spinner mientras se descargan contenidos en segundo plano.
func _process(delta: float) -> void:
	if contenedor_cargando and contenedor_cargando.visible and icono_spinner:
		icono_spinner.pivot_offset = icono_spinner.size / 2.0
		icono_spinner.rotation += delta * 6.0

## Alterna entre la vista de botones o spinner de carga y notifica el tiempo de carga a PerformanceLogger.
func _actualizar_estado_interfaz() -> void:
	if ContentManager.is_syncing:
		contenedor_botones.visible = false
		contenedor_cargando.visible = true
		badge_estado.text = ""
		set_process(true)
	else:
		contenedor_cargando.visible = false
		contenedor_botones.visible = true
		set_process(false)
		if PerformanceLogger:
			PerformanceLogger.mark_initial_load_complete()
		if ContentManager.last_sync_success:
			badge_estado.text = ""
		else:
			badge_estado.text = "📡 Modo Offline (Cápsulas locales)"
			badge_estado.add_theme_color_override("font_color", Color(1, 0.82, 0.4, 1))

func _on_content_sync_completed(_success: bool) -> void:
	_actualizar_estado_interfaz()

func _on_music_finished() -> void:
	music_menu.play()

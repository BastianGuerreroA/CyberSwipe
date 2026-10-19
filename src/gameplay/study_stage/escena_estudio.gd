extends Control
## Vista formativa de lectura y aprendizaje conceptual (Study Stage).
## Presenta los contenidos teóricos y buenas prácticas de ciberseguridad asociadas a la cápsula
## seleccionada antes de que el jugador ingrese a la etapa de toma de decisiones.

@onready var label_etapa = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/HBoxContainer/LabelEtapa
@onready var label_titulo = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/VBoxScrollContent/TitlePanel/MarginContainer/VBoxContainer/LabelTitulo
@onready var label_subtitulo = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/VBoxScrollContent/TitlePanel/MarginContainer/VBoxContainer/LabelSubtitulo
@onready var rich_text_contenido = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/VBoxScrollContent/ContentPanel/MarginContainer/VBoxContainer/TextoEstudio
@onready var boton_volver = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/HBoxContainer/BotonVolver
@onready var icon_rect = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/VBoxScrollContent/IconPanel/MarginContainer/IconRect
@onready var scroll_container = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer
@onready var musica_fondo = $MusicaFondo

var arrastrando_scroll: bool = false
var ultimo_pos_y: float = 0.0

func _ready() -> void:
	boton_volver.pressed.connect(_on_volver_pressed)
	
	if not musica_fondo.finished.is_connected(_on_musica_finished):
		musica_fondo.finished.connect(_on_musica_finished)
	
	rich_text_contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var id_capsula = CapsulaManager.capsula_activa_id
	var datos_capsula = CapsulaManager.obtener_capsula(id_capsula)
	if not datos_capsula.is_empty():
		label_etapa.text = "📖 ETAPA " + str(id_capsula) + ": ESTUDIAR"
		label_titulo.text = datos_capsula.get("titulo", "Cápsula de Estudio")
		label_subtitulo.text = datos_capsula.get("subtitulo", "")
		rich_text_contenido.text = datos_capsula.get("contenido_estudio", "")
		icon_rect.texture = CapsulaManager.obtener_icono_capsula(id_capsula)

func _on_musica_finished() -> void:
	musica_fondo.play()

## Permite el desplazamiento vertical del contenido mediante arrastre táctil o ratón.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			arrastrando_scroll = true
			ultimo_pos_y = event.position.y
		else:
			arrastrando_scroll = false

	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and arrastrando_scroll:
		var delta_y = ultimo_pos_y - event.position.y
		scroll_container.scroll_vertical += int(delta_y)
		ultimo_pos_y = event.position.y

## Retorna a la interfaz de selección de cápsulas.
func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/capsula_selector/capsula_selector.tscn")

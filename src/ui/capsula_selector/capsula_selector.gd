extends Control
## Vista de selección de cápsulas y panel de estado general del jugador.
## Despliega el avance del jugador, el total de puntos, la lista de cápsulas educativas
## con sus estados dinámicos (Bloqueado/Disponible/Completada), el acceso al certificado global
## y el botón flotante del perfil multidimensional LSG.

@onready var label_usuario = $MarginContainer/VBoxMain/PanelContainer/MarginContainer/VBoxContainer/HContainer_Usuario/Usuario
@onready var label_puntos = $MarginContainer/VBoxMain/PanelContainer/MarginContainer/VBoxContainer/HContainer_Usuario/HBoxContainer/Puntos
@onready var label_progreso = $MarginContainer/VBoxMain/PanelContainer/MarginContainer/VBoxContainer/Hcontainer_Progreso/HBoxContainer/Label
@onready var label_total_capsulas = $MarginContainer/VBoxMain/PanelContainer/MarginContainer/VBoxContainer/Hcontainer_Progreso/HBoxContainer/TotalCapsulas
@onready var contenedor_capsulas = $MarginContainer/VBoxMain/ScrollContainer/VBoxContainer_capsulas
@onready var progress_bar = $MarginContainer/VBoxMain/PanelContainer/MarginContainer/VBoxContainer/ProgressBar
@onready var boton_volver = $MarginContainer/VBoxMain/BotonVolver
@onready var boton_editar = $MarginContainer/VBoxMain/PanelContainer/MarginContainer/VBoxContainer/HContainer_Usuario/BotonEditar
@onready var edit_usuario = $MarginContainer/VBoxMain/PanelContainer/MarginContainer/VBoxContainer/HContainer_Usuario/EditUsuario
@onready var musica_fondo = $MusicaFondo

const CAPSULA_ITEM_ESCENA = preload("res://src/gameplay/capsula_item/capsula_item.tscn")

func _ready() -> void:
	boton_volver.pressed.connect(_on_volver_pressed)
	
	if not musica_fondo.finished.is_connected(_on_musica_finished):
		musica_fondo.finished.connect(_on_musica_finished)

	if LsgAuth.logged_in:
		label_usuario.text = LsgAuth.player_name
		
		var perfil_escena = load("res://src/ui/multidimensional_profile/escena_perfil_multidimensional.tscn")
		var perfil_instancia = perfil_escena.instantiate()
		perfil_instancia.name = "PerfilLSG"
		add_child(perfil_instancia)
		
		var placeholder = Control.new()
		placeholder.custom_minimum_size = Vector2(50, 50)
		placeholder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var hcontainer = label_usuario.get_parent()
		hcontainer.add_child(placeholder)
		hcontainer.move_child(placeholder, 0)
		
		await get_tree().process_frame
		perfil_instancia.global_position = placeholder.global_position
		boton_editar.visible = false
	else:
		label_usuario.text = CapsulaManager.nombre_usuario
		boton_editar.visible = true
		boton_editar.pressed.connect(_on_editar_pressed)
		edit_usuario.visible = false
		edit_usuario.text_submitted.connect(_on_nombre_submitted)
		
	label_puntos.text = str(CapsulaManager.puntos_totales)
	
	var completadas = clampi(CapsulaManager.progreso_general - 1, 0, CapsulaManager.lista_capsulas.size())
	label_progreso.text = str(completadas)
	label_total_capsulas.text = "/" + str(CapsulaManager.lista_capsulas.size())
	
	progress_bar.max_value = CapsulaManager.lista_capsulas.size()
	progress_bar.value = completadas
	
	for child in contenedor_capsulas.get_children():
		contenedor_capsulas.remove_child(child)
		child.queue_free()
		
	for datos_capsula in CapsulaManager.lista_capsulas:
		var id_cap = datos_capsula["id"]
		
		if id_cap < CapsulaManager.progreso_general:
			datos_capsula["estado"] = "Completada"
		elif id_cap == CapsulaManager.progreso_general:
			datos_capsula["estado"] = "Disponible"
		else:
			datos_capsula["estado"] = "Bloqueado"
			
		var instancia = CAPSULA_ITEM_ESCENA.instantiate()
		contenedor_capsulas.add_child(instancia)
		instancia.configurar(datos_capsula)
		
	if CapsulaManager.progreso_general > CapsulaManager.lista_capsulas.size() and CapsulaManager.lista_capsulas.size() > 0:
		var boton_cert = Button.new()
		boton_cert.text = "VER RESUMEN GLOBAL"
		
		var font_pixel = load("res://assets/Fuente/acknowtt.ttf")
		if font_pixel:
			boton_cert.add_theme_font_override("font", font_pixel)
		boton_cert.add_theme_font_size_override("font_size", 22)
		boton_cert.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1))
		boton_cert.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1))
		boton_cert.add_theme_color_override("font_pressed_color", Color(0.9, 0.7, 0.2, 1))
		
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.06, 0.1, 0.18, 0.95)
		style_normal.border_width_left = 2
		style_normal.border_width_top = 2
		style_normal.border_width_right = 2
		style_normal.border_width_bottom = 2
		style_normal.border_color = Color(1.0, 0.85, 0.3, 1)
		style_normal.set_corner_radius_all(8)
		
		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color(0.25, 0.2, 0.05, 0.95)
		
		boton_cert.add_theme_stylebox_override("normal", style_normal)
		boton_cert.add_theme_stylebox_override("hover", style_hover)
		boton_cert.add_theme_stylebox_override("pressed", style_normal)
		boton_cert.add_theme_stylebox_override("focus", style_normal)
		
		boton_cert.custom_minimum_size = Vector2(300, 48)
		boton_cert.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		boton_volver.get_parent().add_child(boton_cert)
		boton_volver.get_parent().move_child(boton_cert, boton_volver.get_index())
		boton_cert.pressed.connect(_on_certificado_pressed)

## Transiciona a la vista del resumen global y diagnóstico cualitativo final.
func _on_certificado_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/global_summary/resumen_global.tscn")

func _on_musica_finished() -> void:
	musica_fondo.play()

## Retorna a la pantalla del menú principal.
func _on_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu/menu_principal.tscn")

## Alterna entre la visualización de la etiqueta de usuario y el campo de edición de texto.
func _on_editar_pressed() -> void:
	if not edit_usuario.visible:
		edit_usuario.text = label_usuario.text
		label_usuario.visible = false
		edit_usuario.visible = true
		edit_usuario.grab_focus()
		boton_editar.icon = load("res://assets/IconosPixelArt/Down.png")
	else:
		_confirmar_cambio_nombre()

func _on_nombre_submitted(_new_text: String) -> void:
	_confirmar_cambio_nombre()

## Guarda y persiste el nuevo nombre de usuario ingresado en modo local.
func _confirmar_cambio_nombre() -> void:
	var nuevo_nombre = edit_usuario.text.strip_edges()
	if nuevo_nombre != "":
		CapsulaManager.nombre_usuario = nuevo_nombre
		CapsulaManager.guardar_progreso()
		label_usuario.text = nuevo_nombre
	
	label_usuario.visible = true
	edit_usuario.visible = false
	boton_editar.icon = load("res://assets/IconosPixelArt/pencil_icon.png")

@onready var scroll_container = $MarginContainer/VBoxMain/ScrollContainer
var arrastrando_scroll: bool = false
var ultimo_pos_y: float = 0.0

## Permite el desplazamiento táctil de la lista de cápsulas cuando no hay modales superpuestos.
func _input(event: InputEvent) -> void:
	if _hay_modal_activo():
		arrastrando_scroll = false
		return

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

## Verifica si existe un modal activo en primer plano (ej. Tienda LSG) para suspender el scroll.
func _hay_modal_activo() -> bool:
	for child in get_children():
		if child.name.begins_with("TiendaLSG") or child.name.contains("Tienda") or child.name.contains("Modal"):
			return true
	return false

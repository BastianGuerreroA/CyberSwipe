extends PanelContainer
## Componente de interfaz tipo acordeón que representa un elemento de cápsula en el selector.
## Muestra el estado (Bloqueado, Disponible, Completada), el puntaje récord,
## y permite desplegar la descripción y botones para estudiar o practicar la cápsula.

@onready var label_titulo = $MarginContainer/VBoxHeader/HBoxContainer/VBoxContainer/LabelTitulo
@onready var label_Subtitulo = $MarginContainer/VBoxHeader/HBoxContainer/VBoxContainer/Subtitulo
@onready var label_estado = $MarginContainer/VBoxHeader/HBoxContainer/VBoxDerecha/HBoxStatus/PanelContainer/MarginContainer/Estado
@onready var boton_chevron = $MarginContainer/VBoxHeader/HBoxContainer/VBoxDerecha/HBoxStatus/TextureButton
@onready var contenedor_desplegable = $MarginContainer/VBoxHeader/VBoxContainer
@onready var rich_text_mini_desc = $MarginContainer/VBoxHeader/VBoxContainer/MiniDescripcion
@onready var boton_estudiar = $MarginContainer/VBoxHeader/VBoxContainer/HBoxContainer/VBoxContainer/Button
@onready var boton_practicar = $MarginContainer/VBoxHeader/VBoxContainer/HBoxContainer/VBoxContainer2/Button2
@onready var panel_estado = $MarginContainer/VBoxHeader/HBoxContainer/VBoxDerecha/HBoxStatus/PanelContainer
@onready var icon_rect = $MarginContainer/VBoxHeader/HBoxContainer/Icono
@onready var label_record = $MarginContainer/VBoxHeader/HBoxContainer/VBoxDerecha/Record

var id_capsula: int = -1

func _ready() -> void:
	if boton_chevron.texture_normal:
		boton_chevron.pivot_offset = boton_chevron.texture_normal.get_size() / 2
		
	contenedor_desplegable.visible = false
	
	boton_chevron.pressed.connect(_on_chevron_pressed)
	boton_estudiar.pressed.connect(_on_estudiar_pressed)
	boton_practicar.pressed.connect(_on_practicar_pressed)

## Configura visualmente los datos de la cápsula (título, subtítulo, estado, icono y récord).
func configurar(datos: Dictionary) -> void:
	if not is_node_ready():
		await ready
		
	id_capsula = datos["id"]
	label_titulo.text = datos["titulo"]
	label_estado.text = datos["estado"]
	
	label_Subtitulo.text = datos["subtitulo"]
	rich_text_mini_desc.text = datos["mini_descripcion"]
	
	icon_rect.texture = CapsulaManager.obtener_icono_capsula(id_capsula)
	
	if datos["estado"] == "Bloqueado":
		boton_practicar.disabled = true
		boton_estudiar.disabled = true
		label_record.visible = false
		
		panel_estado.theme_type_variation = &"PanelVarianteRojo"
		modulate = Color(0.64, 0.64, 0.64, 1.0)
		
	elif datos["estado"] == "Disponible":
		boton_practicar.disabled = false
		boton_estudiar.disabled = false
		label_record.visible = true
		var record_val = CapsulaManager.obtener_record_capsula(id_capsula)
		label_record.text = "Récord: " + str(record_val) + " pts"
		
		panel_estado.theme_type_variation = &"PanelVarianteAzul"
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		
	else: # "Completada"
		boton_practicar.disabled = false
		boton_estudiar.disabled = false
		label_record.visible = true
		var record_val = CapsulaManager.obtener_record_capsula(id_capsula)
		label_record.text = "Récord: " + str(record_val) + " pts"
		
		panel_estado.theme_type_variation = &"PanelVarianteVerde"
		modulate = Color(1.0, 1.0, 1.0, 1.0)

## Alterna la visibilidad del contenedor desplegable animando la rotación del botón chevron.
func _on_chevron_pressed() -> void:
	var esta_visible = contenedor_desplegable.visible
	contenedor_desplegable.visible = !esta_visible
	
	var tween = create_tween()
	var angulo_destino = 180.0 if !esta_visible else 0.0
	tween.tween_property(boton_chevron, "rotation_degrees", angulo_destino, 0.25).set_trans(Tween.TRANS_SINE)

## Establece la cápsula activa y transiciona a la escena de lectura y estudio de conceptos.
func _on_estudiar_pressed() -> void:
	CapsulaManager.capsula_activa_id = id_capsula
	get_tree().change_scene_to_file("res://src/gameplay/study_stage/escena_estudio.tscn")

## Establece la cápsula activa y abre la tienda LSG si está autenticado, o inicia directamente la partida.
func _on_practicar_pressed() -> void:
	CapsulaManager.capsula_activa_id = id_capsula
	
	if LsgAuth.logged_in:
		var tienda_escena = load("res://src/ui/store/tienda_lsg.tscn")
		var tienda_instancia = tienda_escena.instantiate()
		tienda_instancia.name = "TiendaLSG"
		get_tree().current_scene.add_child(tienda_instancia)
		print("LSG-Core: Mostrando Tienda de Ventajas pre-partida.")
	else:
		get_tree().change_scene_to_file("res://src/gameplay/main_stage/escena_principal.tscn")

extends Control
## Componente visual del Perfil Multidimensional del jugador.
## Permite consultar y desplegar en tiempo real los balances acumulados en cada una de las dimensiones
## de desarrollo (Social, Físico, Afectivo, Mental, etc.) provistos por el backend de LSG.

@onready var panel_perfil = $PanelPerfil
@onready var contenedor_dimensiones = $PanelPerfil/MarginContainer/VBoxContainer/ContenedorDimensiones
@onready var boton_cerrar = $PanelPerfil/MarginContainer/VBoxContainer/BotonCerrar

const FUENTE_PIXEL = preload("res://assets/Fuente/acknowtt.ttf")

func _ready() -> void:
	panel_perfil.visible = false
	LsgCore.attributes_loaded.connect(_on_attributes_loaded)
	
	if LsgAuth.logged_in:
		LsgCore.get_attributes_points()

## Alterna la apertura o cierre del panel de perfil al presionar el botón de medalla.
func _on_boton_perfil_pressed() -> void:
	if panel_perfil.visible:
		_cerrar_panel()
	else:
		_abrir_panel()

func _on_boton_cerrar_pressed() -> void:
	_cerrar_panel()

## Despliega el panel solicitando los atributos actualizados al servidor y ejecutando animación de entrada.
func _abrir_panel() -> void:
	if LsgAuth.logged_in:
		LsgCore.get_attributes_points()
		
	panel_perfil.visible = true
	panel_perfil.scale = Vector2(0.8, 0.8)
	panel_perfil.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel_perfil, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_perfil, "modulate:a", 1.0, 0.2)

## Oculta el panel ejecutando una animación de desvanecimiento y encogimiento.
func _cerrar_panel() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel_perfil, "scale", Vector2(0.8, 0.8), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(panel_perfil, "modulate:a", 0.0, 0.15)
	await tween.finished
	panel_perfil.visible = false

## Construye dinámicamente las filas de cada dimensión con su respectivo saldo de puntos.
func _on_attributes_loaded(attributes: Array) -> void:
	for child in contenedor_dimensiones.get_children():
		child.queue_free()
		
	if attributes.is_empty():
		var label_vacio = Label.new()
		label_vacio.text = "Sin atributos disponibles."
		label_vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_vacio.add_theme_font_override("font", FUENTE_PIXEL)
		label_vacio.add_theme_font_size_override("font_size", 18)
		contenedor_dimensiones.add_child(label_vacio)
		return
		
	for item in attributes:
		var attribute_name = item.get("attribute_name", "Dimensión")
		var points = int(item.get("balance_ledger", 0))
		
		var fila = HBoxContainer.new()
		contenedor_dimensiones.add_child(fila)
		
		var label_nombre = Label.new()
		label_nombre.text = attribute_name + ":"
		label_nombre.add_theme_font_override("font", FUENTE_PIXEL)
		label_nombre.add_theme_font_size_override("font_size", 18)
		label_nombre.add_theme_color_override("font_color", Color(0, 0.96, 0.83, 1))
		fila.add_child(label_nombre)
		
		var spacer = Control.new()
		spacer.size_flags_horizontal = SIZE_EXPAND_FILL
		fila.add_child(spacer)
		
		var label_puntos = Label.new()
		label_puntos.text = str(points) + " ptos."
		label_puntos.add_theme_font_override("font", FUENTE_PIXEL)
		label_puntos.add_theme_font_size_override("font_size", 18)
		label_puntos.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		fila.add_child(label_puntos)

## Interfaz de la tienda de ventajas modificables vinculada a la API de LSG.
##
## Permite al jugador canjear puntos acumulados en sus dimensiones pedagógicas
## (Mental, Afectivo, Social, Físico) por modificadores temporales para la partida en curso.
## Gestiona la simulación de balances locales y procesa las transacciones HTTP
## asíncronas con el servidor antes de lanzar la escena principal.
extends PanelContainer

@onready var saldos_lista = $MarginContainer/VBoxMain/ContenedorSaldos/SaldosLista
@onready var lista_mecanicas = $MarginContainer/VBoxMain/ScrollContainer/ListaMecanicas
@onready var boton_jugar = $MarginContainer/VBoxMain/VBoxBotones/BotonJugar
@onready var boton_cancelar = $MarginContainer/VBoxMain/VBoxBotones/BotonCancelar

const FUENTE_PIXEL = preload("res://assets/Fuente/acknowtt.ttf")

## Catálogo de ventajas disponibles con costo, dimensión asociada y clave interna de activación.
var MECANICAS_DATA = [
	{
		"id": 45,
		"nombre": "Consultoria Preventiva",
		"descripcion": "Comienza la partida con +10 puntos extra en todos los recursos (60 en lugar de 50).",
		"costo": 25,
		"dimension_id": 4, # Mental (Valor por defecto)
		"dimension_nombre": "Mental",
		"key": "consultoria",
		"attribute_id": 4
	},
	{
		"id": 46,
		"nombre": "Analisis de Impacto",
		"descripcion": "Revela predictivamente el valor exacto de los cambios de recursos al arrastrar la carta.",
		"costo": 40,
		"dimension_id": 3, # Afectivo
		"dimension_nombre": "Afectivo",
		"key": "analisis",
		"attribute_id": 3
	},
	{
		"id": 47,
		"nombre": "Subsidio de Seguridad",
		"descripcion": "Reduce en un 20% las perdidas en Presupuesto en decisiones correctas.",
		"costo": 30,
		"dimension_id": 1, # Social
		"dimension_nombre": "Social",
		"key": "subsidio",
		"attribute_id": 1
	},
	{
		"id": 48,
		"nombre": "Ciberseguro Activo",
		"descripcion": "Mitiga a la mitad (50%) todos los daños a la Integridad y Disponibilidad.",
		"costo": 35,
		"dimension_id": 2, # Físico
		"dimension_nombre": "Fisico",
		"key": "ciberseguro",
		"attribute_id": 2
	}
]

## Saldos reales obtenidos del servidor indexados por id_point_dimension.
var real_balances: Dictionary = {}
## Saldos virtuales que simulan en tiempo real el gasto de puntos previo a la confirmación.
var virtual_balances: Dictionary = {}
## Estado local de selección de ventajas: { "key": bool }.
var selected_mechanics: Dictionary = {}

## Inicializa la selección local, conecta las señales del núcleo LSG y solicita balances.
func _ready() -> void:
	for item in MECANICAS_DATA:
		selected_mechanics[item["key"]] = false
		
	LsgCore.balance_loaded.connect(_on_balance_loaded)
	
	if LsgAuth.logged_in:
		LsgCore.get_points_balance()

## Procesa los balances por dimensión recibidos desde la API y mapea dimensiones a las ventajas.
func _on_balance_loaded(balances: Array) -> void:
	real_balances.clear()
	
	var attribute_to_dimension: Dictionary = {}
	var dimension_to_balance: Dictionary = {}
	
	for item in balances:
		var attr_id = item.get("id_attributes")
		var subattr_id = item.get("id_subattributes")
		var dim_id = int(item.get("id_point_dimension", -1))
		var balance_val = int(item.get("balance", 0))
		
		# Considerar solo dimensiones base (atributo definido y subatributo nulo)
		if attr_id != null and (subattr_id == null or typeof(subattr_id) == TYPE_NIL):
			var attr_id_int = int(attr_id)
			attribute_to_dimension[attr_id_int] = dim_id
			dimension_to_balance[dim_id] = balance_val
			
	for item in MECANICAS_DATA:
		var attr_id = item["attribute_id"]
		if attribute_to_dimension.has(attr_id):
			item["dimension_id"] = attribute_to_dimension[attr_id]
			
		var current_dim_id = item["dimension_id"]
		# Si la dimensión no registra movimientos previos en el backend, su balance es 0
		real_balances[current_dim_id] = dimension_to_balance.get(current_dim_id, 0)
		
	virtual_balances = real_balances.duplicate()
	_actualizar_tienda_ui()


## Refresca los saldos virtuales y redibuja dinámicamente las tarjetas de ventajas en el contenedor.
func _actualizar_tienda_ui() -> void:
	# 1. Actualizar el panel de saldos consolidados
	var saldos_texto = ""
	for item in MECANICAS_DATA:
		var dim_id = item["dimension_id"]
		var dim_nombre = item["dimension_nombre"]
		var virtual_ptos = virtual_balances.get(dim_id, 0)
		saldos_texto += dim_nombre + ": " + str(virtual_ptos) + " ptos | "
	saldos_lista.text = saldos_texto.left(-3)

	# 2. Limpiar la lista previa de ventajas
	for child in lista_mecanicas.get_children():
		child.queue_free()
		
	# 3. Dibujar cada ventaja en la lista
	for item in MECANICAS_DATA:
		var key = item["key"]
		var dim_id = item["dimension_id"]
		var cost = item["costo"]
		var ya_seleccionado = selected_mechanics.get(key, false)
		
		var panel = PanelContainer.new()
		var box_flat = StyleBoxFlat.new()
		box_flat.bg_color = Color(0.09, 0.12, 0.22, 0.8)
		box_flat.border_width_left = 1
		box_flat.border_width_top = 1
		box_flat.border_width_right = 1
		box_flat.border_width_bottom = 1
		box_flat.border_color = Color(0, 0.96, 0.83, 0.5) if ya_seleccionado else Color(0.2, 0.2, 0.3, 0.5)
		box_flat.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", box_flat)
		lista_mecanicas.add_child(panel)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		panel.add_child(margin)
		
		var v_box = VBoxContainer.new()
		margin.add_child(v_box)
		
		var label_nombre = Label.new()
		label_nombre.text = item["nombre"]
		label_nombre.add_theme_font_override("font", FUENTE_PIXEL)
		label_nombre.add_theme_font_size_override("font_size", 24)
		label_nombre.add_theme_color_override("font_color", Color(0, 0.96, 0.83, 1))
		v_box.add_child(label_nombre)
		
		var label_desc = Label.new()
		label_desc.text = item["descripcion"]
		label_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		label_desc.add_theme_font_override("font", FUENTE_PIXEL)
		label_desc.add_theme_font_size_override("font_size", 18)
		label_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		v_box.add_child(label_desc)
		
		var label_costo = Label.new()
		label_costo.text = "Costo: " + str(cost) + " ptos de la Dimension " + item["dimension_nombre"]
		label_costo.add_theme_font_override("font", FUENTE_PIXEL)
		label_costo.add_theme_font_size_override("font_size", 18)
		label_costo.add_theme_color_override("font_color", Color(1, 1, 0, 1))
		v_box.add_child(label_costo)
		
		var btn = Button.new()
		btn.add_theme_font_override("font", FUENTE_PIXEL)
		btn.add_theme_font_size_override("font_size", 20)
		
		if ya_seleccionado:
			btn.text = "SELECCIONADO (Desmarcar)"
			btn.self_modulate = Color(0, 1, 1, 1)
		else:
			var saldo_actual = virtual_balances.get(dim_id, 0)
			if saldo_actual < cost:
				btn.text = "SALDO INSUFICIENTE"
				btn.disabled = true
				btn.self_modulate = Color(0.5, 0.5, 0.5, 1)
			else:
				btn.text = "ADQUIRIR"
				btn.self_modulate = Color(1, 1, 1, 1)
				
		btn.pressed.connect(func(): _on_toggle_mecanica(key, dim_id, cost))
		v_box.add_child(btn)

## Alterna la selección de una ventaja recalculando el saldo virtual disponible.
func _on_toggle_mecanica(key: String, dim_id: int, cost: int) -> void:
	if selected_mechanics[key]:
		selected_mechanics[key] = false
		virtual_balances[dim_id] += cost
	else:
		selected_mechanics[key] = true
		virtual_balances[dim_id] -= cost
		
	_actualizar_tienda_ui()

## Cierra el diálogo de la tienda sin aplicar cobros ni guardar ventajas.
func _on_boton_cancelar_pressed() -> void:
	print("LSG-Core: Compra cancelada por el usuario. No se aplican cobros.")
	queue_free()

## Procesa los canjes de las ventajas seleccionadas contra la API y lanza la partida al finalizar.
func _on_boton_jugar_pressed() -> void:
	boton_jugar.disabled = true
	boton_cancelar.disabled = true
	
	LsgCore.reset_active_mechanics()
	
	var transacciones_exitosas = true
	
	for item in MECANICAS_DATA:
		var key = item["key"]
		if selected_mechanics[key]:
			boton_jugar.text = "COBRANDO " + item["nombre"].to_upper() + "..."
			var exito = await _realizar_canje_en_servidor(item["id"], item["dimension_id"], item["costo"])
			if exito:
				LsgCore.active_mechanics[key] = true
				LsgLogger.log_redemption(item["nombre"], item["costo"], item["dimension_id"])
				print("LSG-Core: Canje exitoso en servidor para ventaja: ", key)
			else:
				transacciones_exitosas = false
				print("LSG-Core: ERROR en transacción de servidor para ventaja: ", key)
				break
				
	if transacciones_exitosas:
		print("LSG-Core: Todas las compras procesadas correctamente. Cargando partida...")
		get_tree().change_scene_to_file("res://src/gameplay/main_stage/escena_principal.tscn")
		queue_free()
	else:
		boton_jugar.disabled = false
		boton_cancelar.disabled = false
		boton_jugar.text = "REINTENTAR COMPRAS / JUGAR"
		
		saldos_lista.text = "ERROR: Falló el cobro en una o más ventajas. Inténtalo de nuevo."
		saldos_lista.add_theme_color_override("font_color", Color(1, 0, 0, 1))

## Ejecuta la petición POST de canje en el endpoint /redeem de la API de LSG de forma asíncrona.
func _realizar_canje_en_servidor(mechanic_id: int, dimension_id: int, amount: int) -> bool:
	var url = LsgCore.BASE_URL + "/videogames/" + str(LsgCore.GAME_ID) + "/players/" + str(LsgAuth.player_id) + "/redeem"
	var headers = PackedStringArray([
		"Authorization: Bearer " + LsgAuth.access_token,
		"Content-Type: application/json"
	])
	
	var payload = {
		"modifiable_mechanic_videogame_id": mechanic_id,
		"point_dimension_id": dimension_id,
		"amount": amount,
		"metadata": {"session_id": LsgCore.active_session_id}
	}
	
	var http = HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
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
	return (response_code == 200 or response_code == 201)

@onready var scroll_container = $MarginContainer/VBoxMain/ScrollContainer
var arrastrando_scroll_tienda: bool = false
var ultimo_pos_y_tienda: float = 0.0

## Gestiona el desplazamiento táctil y con mouse sobre la lista con scroll de la tienda.
func _input(event: InputEvent) -> void:
	if not is_inside_tree() or not visible:
		return

	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			var mouse_pos = get_global_mouse_position()
			if scroll_container and scroll_container.get_global_rect().has_point(mouse_pos):
				arrastrando_scroll_tienda = true
				ultimo_pos_y_tienda = event.position.y
		else:
			arrastrando_scroll_tienda = false

	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and arrastrando_scroll_tienda:
		var delta_y = ultimo_pos_y_tienda - event.position.y
		scroll_container.scroll_vertical += int(delta_y)
		ultimo_pos_y_tienda = event.position.y


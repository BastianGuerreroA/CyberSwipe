extends Control
## Interfaz de usuario para autenticación de jugadores con LSG (Learning Serious Games).
## Controla la apertura/cierre animado del modal, el envío de credenciales mediante ApiAuth,
## la retroalimentación visual de errores y el despliegue del estado de sesión activa.

@onready var panel = $PanelLogin
@onready var boton_lsg = $BotonLSG

@onready var formulario_login = $PanelLogin/MarginContainer/VBoxContainer/FormularioLogin
@onready var info_sesion = $PanelLogin/MarginContainer/VBoxContainer/InfoSesion

@onready var input_usuario = $PanelLogin/MarginContainer/VBoxContainer/FormularioLogin/InputUsuario
@onready var input_clave = $PanelLogin/MarginContainer/VBoxContainer/FormularioLogin/InputClave
@onready var boton_iniciar = $PanelLogin/MarginContainer/VBoxContainer/FormularioLogin/Button
@onready var label_bienvenida = $PanelLogin/MarginContainer/VBoxContainer/InfoSesion/LabelBienvenida
@onready var label_error = $PanelLogin/MarginContainer/VBoxContainer/LabelError

func _ready() -> void:
	panel.visible = false
	
	LsgAuth.login_success.connect(_on_lsg_login_success)
	LsgAuth.login_failed.connect(_on_lsg_login_failed)
	LsgAuth.logged_out.connect(_on_lsg_logged_out)
	
	_actualizar_interfaz_sesion()

## Abre el panel modal de login con animación de escala y desvanecimiento.
func _on_boton_lsg_pressed() -> void:
	panel.visible = true
	boton_lsg.visible = false
	
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(1,1), 0.2)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	
	_actualizar_interfaz_sesion()

## Cierra el panel de login y restaura la visibilidad del botón de acceso.
func _on_boton_cerrar_pressed() -> void:
	panel.visible = false
	boton_lsg.visible = true

## Valida los campos del formulario y despacha la petición de autenticación a ApiAuth.
func _on_iniciar_sesion_pressed() -> void:
	var email = input_usuario.text.strip_edges()
	var password = input_clave.text.strip_edges()
	
	if email.is_empty() or password.is_empty():
		label_error.text = "Por favor, completa todos los campos."
		label_error.visible = true
		return
		
	label_error.visible = false
	boton_iniciar.disabled = true
	boton_iniciar.text = "CONECTANDO..."
	
	LsgAuth.login(email, password)

## Despacha la solicitud de desautenticación a ApiAuth.
func _on_boton_cerrar_sesion_pressed() -> void:
	LsgAuth.logout()

## Alterna entre la vista de formulario de acceso o ficha de bienvenida según si el usuario está autenticado.
func _actualizar_interfaz_sesion() -> void:
	if LsgAuth.logged_in:
		label_bienvenida.text = "Bienvenido,\n" + LsgAuth.player_name
		formulario_login.visible = false
		info_sesion.visible = true
		label_error.visible = false
	else:
		formulario_login.visible = true
		info_sesion.visible = false
		label_error.visible = false
		
		boton_iniciar.disabled = false
		boton_iniciar.text = "INICIAR SESIÓN"

func _on_lsg_login_success(_username: String) -> void:
	_actualizar_interfaz_sesion()

func _on_lsg_login_failed(error_msg: String) -> void:
	boton_iniciar.disabled = false
	boton_iniciar.text = "INICIAR SESIÓN"
	label_error.text = error_msg
	label_error.visible = true

func _on_lsg_logged_out() -> void:
	input_usuario.text = ""
	input_clave.text = ""
	_actualizar_interfaz_sesion()

extends Node2D
## Controlador de la escena principal de juego (Main Stage).
## Gestiona la reproducción musical de fondo, la instanciación dinámica del HUD de perfil LSG
## y la apertura del menú de pausa durante la partida.

@export var MusicaFondo: AudioStreamPlayer2D

func _ready() -> void:
	MusicaFondo.play()
	LsgAuth.login_success.connect(func(_name): _configurar_interfaz_lsg())
	LsgAuth.logged_out.connect(func(): _configurar_interfaz_lsg())
	_configurar_interfaz_lsg()

## Instancia o refresca el panel de perfil multidimensional en el HUD cuando hay un usuario autenticado.
func _configurar_interfaz_lsg() -> void:
	var margin_container = get_node_or_null("CanvasLayer/MarginContainer")
	if not margin_container:
		return
		
	var login_previo = margin_container.get_node_or_null("LoginPanel")
	if login_previo:
		login_previo.queue_free()
		
	var perfil_previo = margin_container.get_node_or_null("PerfilLSG")
	if perfil_previo:
		perfil_previo.queue_free()
		
	if LsgAuth.logged_in:
		var perfil_escena = load("res://src/ui/multidimensional_profile/escena_perfil_multidimensional.tscn")
		var perfil_instancia = perfil_escena.instantiate()
		perfil_instancia.name = "PerfilLSG"
		
		perfil_instancia.layout_mode = 2
		perfil_instancia.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		perfil_instancia.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		
		margin_container.add_child(perfil_instancia)
		print("LSG-Core: Cargada escena de Perfil Multidimensional en partida.")

## Pausa la partida y despliega el menú de pausa superpuesto.
func _on_boton_pausa_pressed() -> void:
	$CanvasLayer/MarginContainer/BotonPausa.visible = false
	$CanvasLayer/MarginContainer/PauseMenu.visible = true
	get_tree().paused = true

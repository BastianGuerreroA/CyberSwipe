extends Button
## Botón del menú principal que inicia la transición hacia la selección de cápsulas.

@export var escena_capsulas: PackedScene
@onready var hover_audio: AudioStreamPlayer = $"../HoverAudio"

func _ready() -> void:
	pressed.connect(_comenzar, 4)

## Cambia la escena a la pantalla de selección de cápsulas.
func _comenzar() -> void:
	get_tree().change_scene_to_packed(escena_capsulas)

func _on_mouse_entered() -> void:
	hover_audio.play()

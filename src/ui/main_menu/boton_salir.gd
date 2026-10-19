extends Button
## Botón del menú principal que gatilla la salida ordenada de la aplicación.

@onready var hover_audio: AudioStreamPlayer = $"../HoverAudio"

func _ready() -> void:
	pressed.connect(_salir)

## Invoca el procedimiento de guardado y cierre limpio a través de LsgCore.
func _salir() -> void:
	LsgCore.clean_up_and_exit()

func _on_mouse_entered() -> void:
	hover_audio.play()

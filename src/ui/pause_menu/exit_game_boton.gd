## Botón para salir de la partida en curso desde el menú de pausa y regresar al selector de cápsulas.
extends Button

## Reanuda el árbol de nodos para evitar bloqueos y transiciona la escena hacia el selector de cápsulas.
func _on_pressed() -> void:
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://src/ui/capsula_selector/capsula_selector.tscn")

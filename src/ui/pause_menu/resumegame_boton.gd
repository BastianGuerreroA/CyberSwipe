## Botón para reanudar la partida en curso desde el menú de pausa.
extends Button

## Descongela el árbol de ejecución, oculta el modal de pausa y restablece la visibilidad del botón de pausa en el HUD.
func _on_pressed() -> void:
	get_tree().paused = false
	owner.visible = false
	if owner.get_parent().has_node("BotonPausa"):
		owner.get_parent().get_node("BotonPausa").visible = true

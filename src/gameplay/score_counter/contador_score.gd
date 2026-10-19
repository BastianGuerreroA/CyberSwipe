extends Control
## Marcador visual de puntuación acumulada durante la ronda activa.

var puntaje_actual: int = 0

@onready var label_numero = $PanelContainer/MarginContainer/HBoxContainer/Numero

## Incrementa la puntuación obtenida y actualiza la etiqueta de texto en pantalla.
func sumar_punto(cantidad: int = 1) -> void:
	puntaje_actual += cantidad
	label_numero.text = str(puntaje_actual)

class_name ProgresoUsuario
extends Resource
## Recurso de datos serializable para persistir el progreso local del jugador en disco.
## Almacena identidad, puntos acumulados, nivel de desbloqueo, puntajes récord y mejores tiempos por cápsula.

@export var nombre_usuario: String = "Usuario"
@export var puntos_totales: int = 0
@export var progreso_general: int = 1
## Diccionario de puntuación récord por cápsula: { capsula_id (int): record (int) }
@export var puntajes_maximos: Dictionary = {}
## Diccionario de mejor tiempo en segundos por cápsula: { capsula_id (int): mejor_tiempo (float) }
@export var mejores_tiempos: Dictionary = {}


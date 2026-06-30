extends Node

signal boss_defeated
signal player_died
signal restart_requested

var _ui_count: int = 0

func open_ui() -> void:
	_ui_count += 1
	get_tree().paused = true

func close_ui() -> void:
	_ui_count = max(0, _ui_count - 1)
	if _ui_count == 0:
		get_tree().paused = false

func reset_ui() -> void:
	_ui_count = 0
	get_tree().paused = false

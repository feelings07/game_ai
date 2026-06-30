extends CanvasLayer

var game_started: bool = false

var title_label: Label = null
var play_button: Button = null
var restart_button: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build_ui()
	get_tree().paused = true

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	title_label = Label.new()
	title_label.text = "GAME AI"
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	play_button = Button.new()
	play_button.text = "Играть"
	play_button.custom_minimum_size = Vector2(220, 50)
	play_button.pressed.connect(_on_play_pressed)
	vbox.add_child(play_button)

	restart_button = Button.new()
	restart_button.text = "Начать заново"
	restart_button.custom_minimum_size = Vector2(220, 50)
	restart_button.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_button)

	var quit_button := Button.new()
	quit_button.text = "Выход"
	quit_button.custom_minimum_size = Vector2(220, 50)
	quit_button.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_button)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu") and game_started:
		if visible:
			_resume()
		else:
			_open_as_pause()

func _open_as_pause() -> void:
	visible = true
	title_label.text = "Пауза"
	play_button.text = "Продолжить"
	get_tree().paused = true

func _on_play_pressed() -> void:
	game_started = true
	restart_button.visible = true
	_resume()

func _on_restart_pressed() -> void:
	GameEvents.restart_requested.emit()
	_resume()

func _resume() -> void:
	visible = false
	get_tree().paused = false

func _on_quit_pressed() -> void:
	get_tree().quit()

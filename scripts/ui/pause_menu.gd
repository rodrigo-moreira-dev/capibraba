extends CanvasLayer

@onready var resume_btn: Button = $CC/PC/MC/VBox/ResumeBtn
@onready var menu_btn:   Button = $CC/PC/MC/VBox/MenuBtn
@onready var quit_btn:   Button = $CC/PC/MC/VBox/QuitBtn


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_style(resume_btn, Color(0.18, 0.50, 0.22), 18)
	_style(menu_btn,   Color(0.18, 0.22, 0.35), 16)
	_style(quit_btn,   Color(0.35, 0.12, 0.12), 16)
	resume_btn.pressed.connect(_resume)
	menu_btn.pressed.connect(_go_menu)
	quit_btn.pressed.connect(get_tree().quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_resume()
		else:
			_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	show()
	get_tree().paused = true
	Input.mouse_mode  = Input.MOUSE_MODE_VISIBLE


func _resume() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode  = Input.MOUSE_MODE_CAPTURED


func _go_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode  = Input.MOUSE_MODE_VISIBLE
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _style(btn: Button, color: Color, fsize: int) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = color if state == "normal" else (color.lightened(0.18) if state == "hover" else color.darkened(0.18))
		s.set_corner_radius_all(8)
		s.content_margin_left   = 20
		s.content_margin_right  = 20
		s.content_margin_top    = 10
		s.content_margin_bottom = 10
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", fsize)

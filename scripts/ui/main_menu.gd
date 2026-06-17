extends Control

@onready var title_lbl:    Label  = $CC/VBox/Title
@onready var play_btn:     Button = $CC/VBox/PlayBtn
@onready var settings_btn: Button = $CC/VBox/SettingsBtn
@onready var credits_btn:  Button = $CC/VBox/CreditsBtn
@onready var quit_btn:     Button = $CC/VBox/QuitBtn


func _ready() -> void:
	NetworkManager.disconnect_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false

	title_lbl.modulate = Color(0.95, 0.72, 0.15)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	title_lbl.add_theme_constant_override("shadow_offset_x", 4)
	title_lbl.add_theme_constant_override("shadow_offset_y", 4)

	_style(play_btn,     Color(0.85, 0.50, 0.08), 22)
	_style(settings_btn, Color(0.18, 0.22, 0.35), 16)
	_style(credits_btn,  Color(0.18, 0.22, 0.35), 16)
	_style(quit_btn,     Color(0.35, 0.12, 0.12), 16)

	play_btn.pressed.connect(
		func(): get_tree().change_scene_to_file("res://scenes/ui/mode_select.tscn")
	)
	settings_btn.pressed.connect(
		func(): get_tree().change_scene_to_file("res://scenes/ui/settings.tscn")
	)
	credits_btn.pressed.connect(
		func(): get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")
	)
	quit_btn.pressed.connect(get_tree().quit)


func _style(btn: Button, color: Color, fsize: int) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		match state:
			"normal":   s.bg_color = color
			"hover":    s.bg_color = color.lightened(0.18)
			"pressed":  s.bg_color = color.darkened(0.18)
			"focus":    s.bg_color = color.lightened(0.08)
			"disabled": s.bg_color = color.darkened(0.40)
		s.set_corner_radius_all(8)
		s.content_margin_left   = 20
		s.content_margin_right  = 20
		s.content_margin_top    = 10
		s.content_margin_bottom = 10
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", fsize)

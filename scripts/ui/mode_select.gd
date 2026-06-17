extends Control

const MODES := [
	{id = "last_standing", name = "Last Capivara\nStanding",  desc = "Plataformas somem.\nÚltimo de pé vence.",  color = Color(0.80, 0.25, 0.15), available = true},
	{id = "capivara_bomb", name = "Capivara Bomb",            desc = "Passe a bomba antes\nque exploda.",         color = Color(0.90, 0.55, 0.05), available = false},
	{id = "king_of_hill",  name = "King of the Hill",         desc = "Domine a zona e\nacumule pontos.",          color = Color(0.15, 0.55, 0.80), available = false},
	{id = "race",          name = "Corrida de\nObstáculos",   desc = "Primeiro ao fim\nvence.",                   color = Color(0.25, 0.70, 0.30), available = false},
	{id = "food_theft",    name = "Roubo de Comida",          desc = "Roube comida da\ntoca dos rivais.",         color = Color(0.60, 0.25, 0.75), available = false},
]

@onready var modes_grid: GridContainer = $Layout/CC/ModesGrid
@onready var back_btn:   Button        = $Layout/Header/BackBtn


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_btn.pressed.connect(
		func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	_style_back(back_btn)
	for m: Dictionary in MODES:
		modes_grid.add_child(_make_card(m))


func _make_card(mode: Dictionary) -> Control:
	var available: bool = mode.get("available", false)
	var color: Color    = mode.get("color", Color.GRAY)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(210, 0)

	var btn := Button.new()
	btn.text                = mode.get("name", "?")
	btn.custom_minimum_size = Vector2(0, 90)
	btn.disabled            = not available
	btn.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	_style_card_btn(btn, color, available)
	if available:
		var mode_id: String = mode.get("id", "")
		btn.pressed.connect(func(): _select(mode_id))
	vbox.add_child(btn)

	var desc := Label.new()
	desc.text                 = mode.get("desc", "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.modulate             = Color(0.85, 0.85, 0.85) if available else Color(0.45, 0.45, 0.45)
	vbox.add_child(desc)

	if not available:
		var soon := Label.new()
		soon.text                 = "— Em Breve —"
		soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		soon.add_theme_font_size_override("font_size", 11)
		soon.modulate             = Color(0.45, 0.45, 0.45)
		vbox.add_child(soon)

	return vbox


func _style_card_btn(btn: Button, color: Color, available: bool) -> void:
	var off := Color(0.18, 0.18, 0.22)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		match state:
			"normal":   s.bg_color = color if available else off
			"hover":    s.bg_color = color.lightened(0.20) if available else off.lightened(0.08)
			"pressed":  s.bg_color = color.darkened(0.20)  if available else off
			"disabled": s.bg_color = off
		s.set_corner_radius_all(10)
		s.content_margin_left   = 12
		s.content_margin_right  = 12
		s.content_margin_top    = 8
		s.content_margin_bottom = 8
		btn.add_theme_stylebox_override(state, s)
	var fc := Color.WHITE if available else Color(0.45, 0.45, 0.45)
	btn.add_theme_color_override("font_color", fc)
	btn.add_theme_color_override("font_disabled_color", fc)
	btn.add_theme_font_size_override("font_size", 16)


func _style_back(btn: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.18, 0.22, 0.35) if state == "normal" else Color(0.25, 0.30, 0.45)
		s.set_corner_radius_all(6)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", Color.WHITE)


func _select(mode_id: String) -> void:
	GameSettings.selected_mode = mode_id
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")

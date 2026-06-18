extends Control

const ARENAS := [
	{
		id    = "lava_flat",
		name  = "Plataforma Central",
		desc  = "Uma arena plana cercada de lava.\nSobreviva na última plataforma.",
		color = Color(0.80, 0.30, 0.08),
	},
	{
		id    = "lava_islands",
		name  = "Ilhas de Lava",
		desc  = "Cinco ilhas sobre um mar de lava.\nPule entre elas e derrube os rivais.",
		color = Color(0.65, 0.22, 0.06),
	},
	{
		id    = "lava_shrinking",
		name  = "Plataforma Maldita",
		desc  = "A plataforma some aos poucos.\nFique em pé até o fim.",
		color = Color(0.50, 0.15, 0.05),
	},
]

@onready var arenas_box: HBoxContainer = $Layout/CC/ArenasBox
@onready var back_btn:   Button        = $Layout/Header/BackBtn


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_btn.pressed.connect(
		func(): get_tree().change_scene_to_file("res://scenes/ui/mode_select.tscn")
	)
	_style_back(back_btn)
	for a: Dictionary in ARENAS:
		arenas_box.add_child(_make_card(a))


func _make_card(arena: Dictionary) -> Control:
	var color: Color = arena.get("color", Color.GRAY)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(240, 0)

	var btn := Button.new()
	btn.text                = arena.get("name", "?")
	btn.custom_minimum_size = Vector2(0, 100)
	btn.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	_style_card(btn, color)
	var arena_id: String = arena.get("id", "")
	btn.pressed.connect(func(): _select(arena_id))
	vbox.add_child(btn)

	var desc := Label.new()
	desc.text                 = arena.get("desc", "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.modulate             = Color(0.82, 0.82, 0.82)
	vbox.add_child(desc)

	return vbox


func _style_card(btn: Button, color: Color) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = color if state == "normal" else (
			color.lightened(0.20) if state == "hover" else color.darkened(0.18)
		)
		s.set_corner_radius_all(10)
		s.content_margin_left   = 12
		s.content_margin_right  = 12
		s.content_margin_top    = 8
		s.content_margin_bottom = 8
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 17)


func _style_back(btn: Button) -> void:
	for state: String in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.18, 0.22, 0.35) if state == "normal" else Color(0.25, 0.30, 0.45)
		s.set_corner_radius_all(6)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color", Color.WHITE)


func _select(arena_id: String) -> void:
	GameSettings.selected_arena = arena_id
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")

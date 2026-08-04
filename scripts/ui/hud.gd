extends CanvasLayer

const MODE_NAMES := {
	"last_standing": "Last Capivara Standing",
	"hellball":      "Hellball",
	"hellball_platform": "Hellball Plataforma",
	"hellball_topdown":  "Hellball Topdown",
	"magnet": "Ímãs",
	"swords": "Espadas",
	"capivara_bomb": "Capivara Bomb",
	"king_of_hill":  "King of the Hill",
	"race":          "Corrida de Obstáculos",
	"food_theft":    "Roubo de Comida",
}

@onready var mode_lbl:   Label         = $VBox/ModeLbl
@onready var player_list: VBoxContainer = $VBox/PlayerList

var _scoreboard:  PanelContainer
var _score_vbox:  VBoxContainer
var _last_deaths: Dictionary = {}
var _last_kills:  Dictionary = {}
var _event_panel: PanelContainer
var _kill_streak_panel: PanelContainer
var _announce_panel: PanelContainer
var _announce_lbl: Label
var _hint_lbl: Label


func _ready() -> void:
	add_to_group("hud")
	mode_lbl.text = MODE_NAMES.get(GameSettings.selected_mode, "Modo Livre")
	NetworkManager.players_updated.connect(_refresh)
	_refresh()
	_build_scoreboard()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.physical_keycode == KEY_TAB:
			_scoreboard.visible = ke.pressed
			get_viewport().set_input_as_handled()


# ── Side panel ────────────────────────────────────────────────────────────────

func _refresh() -> void:
	for child in player_list.get_children():
		child.queue_free()
	for id: int in NetworkManager.players:
		var data: Dictionary = NetworkManager.players[id]
		var lbl := Label.new()
		lbl.text = "• " + data.get("name", "Capivara")
		lbl.add_theme_font_size_override("font_size", 14)
		player_list.add_child(lbl)


func update_lives(lives: Dictionary) -> void:
	var max_lives := MatchSettings.lives_per_player
	for child in player_list.get_children():
		child.queue_free()
	for id: int in NetworkManager.players:
		var data: Dictionary = NetworkManager.players[id]
		var lbl := Label.new()
		var remaining: int = lives.get(id, 0)
		var hearts: String = "♥ ".repeat(remaining).strip_edges() + " ♡".repeat(maxi(0, max_lives - remaining))
		lbl.text = "• " + data.get("name", "Capivara") + "  " + hearts
		lbl.add_theme_font_size_override("font_size", 14)
		player_list.add_child(lbl)


# ── Scoreboard (TAB) ──────────────────────────────────────────────────────────

func _build_scoreboard() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	_scoreboard = PanelContainer.new()
	_scoreboard.custom_minimum_size = Vector2(420, 0)
	_scoreboard.visible = false
	overlay.add_child(_scoreboard)
	_scoreboard.set_anchors_preset(Control.PRESET_CENTER)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.10, 0.92)
	bg.set_corner_radius_all(10)
	_scoreboard.add_theme_stylebox_override("panel", bg)

	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left",   24)
	mc.add_theme_constant_override("margin_right",  24)
	mc.add_theme_constant_override("margin_top",    18)
	mc.add_theme_constant_override("margin_bottom", 18)
	_scoreboard.add_child(mc)

	var vbox := VBoxContainer.new()
	mc.add_child(vbox)

	var title := Label.new()
	title.text = "PLACAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(0.95, 0.72, 0.15)
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	vbox.add_child(sep)

	_score_vbox = VBoxContainer.new()
	_score_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_score_vbox)

	_rebuild_rows()


func update_scoreboard(deaths: Dictionary, kills: Dictionary) -> void:
	_last_deaths = deaths
	_last_kills  = kills
	_rebuild_rows()


func _rebuild_rows() -> void:
	if not is_instance_valid(_score_vbox):
		return
	for child in _score_vbox.get_children():
		child.queue_free()

	# Header row
	var header := _make_row("Jogador", "Mortes", "Abates", true)
	_score_vbox.add_child(header)

	var ids: Array = NetworkManager.players.keys()
	if ids.is_empty():
		ids = [1]

	for id: int in ids:
		var data: Dictionary = NetworkManager.players.get(id, {})
		var name_str: String = data.get("name", "Capivara")
		var deaths_str: String = str(_last_deaths.get(id, 0))
		var kills_str: String  = str(_last_kills.get(id, 0))
		_score_vbox.add_child(_make_row(name_str, deaths_str, kills_str, false))


func _make_row(col1: String, col2: String, col3: String, is_header: bool) -> HBoxContainer:
	var row := HBoxContainer.new()

	var name_lbl := Label.new()
	name_lbl.text = col1
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	if is_header:
		name_lbl.modulate = Color(0.70, 0.70, 0.70)
	row.add_child(name_lbl)

	for col_text: String in [col2, col3]:
		var lbl := Label.new()
		lbl.text = col_text
		lbl.custom_minimum_size = Vector2(80, 0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 15)
		if is_header:
			lbl.modulate = Color(0.70, 0.70, 0.70)
		row.add_child(lbl)

	return row


# ── Winner overlay ────────────────────────────────────────────────────────────

func show_winner(winner_id: int) -> void:
	var winner_name: String = "?"
	if winner_id == -1:
		winner_name = "EMPATE!"
	else:
		var wd: Dictionary = NetworkManager.players.get(winner_id, {})
		winner_name = wd.get("name", "?")

	var panel := PanelContainer.new()
	var vp_size: Vector2i = get_viewport().size
	panel.position = (Vector2(vp_size) - Vector2(360, 140)) * 0.5
	panel.custom_minimum_size = Vector2(360, 140)
	add_child(panel)

	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left",   32)
	mc.add_theme_constant_override("margin_right",  32)
	mc.add_theme_constant_override("margin_top",    24)
	mc.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(mc)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mc.add_child(vbox)

	var title := Label.new()
	title.text = "FIM DE JOGO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = Color(0.95, 0.72, 0.15)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = ("Vencedor: " + winner_name) if winner_id != -1 else "EMPATE!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	vbox.add_child(sub)


# ── Anúncio de evento (topo central) ─────────────────────────────────────────

func show_event_announcement(message: String, duration: float) -> void:
	if not is_instance_valid(_announce_panel):
		_build_announce_panel()
	_announce_lbl.text = message
	_announce_panel.visible = true
	_announce_panel.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_property(_announce_panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: _announce_panel.visible = false)


func _build_announce_panel() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Faixa horizontal próxima ao topo da tela
	cc.offset_top    = 60.0
	cc.offset_bottom = 210.0
	overlay.add_child(cc)

	_announce_panel = PanelContainer.new()
	_announce_panel.visible = false
	_announce_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(_announce_panel)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.06, 0.04, 0.85)
	bg.set_corner_radius_all(10)
	bg.content_margin_left   = 26
	bg.content_margin_right  = 26
	bg.content_margin_top    = 12
	bg.content_margin_bottom = 12
	_announce_panel.add_theme_stylebox_override("panel", bg)

	var mc := MarginContainer.new()
	_announce_panel.add_child(mc)

	_announce_lbl = Label.new()
	_announce_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_lbl.add_theme_font_size_override("font_size", 18)
	_announce_lbl.modulate = Color(1.0, 0.80, 0.35)
	mc.add_child(_announce_lbl)


# ── Dica de modo (rodapé) ────────────────────────────────────────────────────

func show_mode_hint(text: String) -> void:
	if not is_instance_valid(_hint_lbl):
		_hint_lbl = Label.new()
		_hint_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hint_lbl.offset_left   = 24.0
		_hint_lbl.offset_right  = -24.0
		_hint_lbl.offset_top    = -60.0
		_hint_lbl.offset_bottom = -18.0
		_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
		_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_lbl.add_theme_font_size_override("font_size", 14)
		_hint_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 0.85))
		_hint_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
		_hint_lbl.add_theme_constant_override("outline_size", 6)
		add_child(_hint_lbl)
	_hint_lbl.text = text

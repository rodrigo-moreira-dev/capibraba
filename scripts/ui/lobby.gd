extends Control

const PALETTE := [
	Color(0.72, 0.56, 0.28),
	Color(0.40, 0.24, 0.12),
	Color(0.75, 0.30, 0.15),
	Color(0.60, 0.60, 0.60),
	Color(0.90, 0.55, 0.08),
	Color(0.50, 0.25, 0.78),
]

const ARENA_SCENES := {
	"lava_flat":      "res://scenes/levels/lava_flat.tscn",
	"lava_islands":   "res://scenes/levels/lava_islands.tscn",
	"lava_shrinking": "res://scenes/levels/lava_shrinking.tscn",
}

const MODE_NAMES := {
	"last_standing": "Last Capivara Standing",
	"capivara_bomb": "Capivara Bomb",
	"king_of_hill":  "King of the Hill",
	"race":          "Corrida de Obstáculos",
	"food_theft":    "Roubo de Comida",
}

const ARENA_NAMES := {
	"lava_flat":      "Plataforma Central",
	"lava_islands":   "Ilhas de Lava",
	"lava_shrinking": "Plataforma Maldita",
}

@onready var back_btn:    Button        = $CC/PC/MC/VBox/BackBtn
@onready var mode_label:  Label         = $CC/PC/MC/VBox/ModeLabel
@onready var name_input:  LineEdit      = $CC/PC/MC/VBox/NameInput
@onready var color_row:   HBoxContainer = $CC/PC/MC/VBox/ColorRow
@onready var host_btn:    Button        = $CC/PC/MC/VBox/HostBtn
@onready var ip_input:    LineEdit      = $CC/PC/MC/VBox/JoinRow/IPInput
@onready var join_btn:    Button        = $CC/PC/MC/VBox/JoinRow/JoinBtn
@onready var status_label: Label        = $CC/PC/MC/VBox/StatusLabel
@onready var player_list:  VBoxContainer = $CC/PC/MC/VBox/PlayerList
@onready var start_btn:   Button        = $CC/PC/MC/VBox/StartBtn

var _color_btns: Array = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var mode_str: String = MODE_NAMES.get(GameSettings.selected_mode, "—")
	if GameSettings.selected_mode == "last_standing":
		mode_str += " · " + ARENA_NAMES.get(GameSettings.selected_arena, "")
	mode_label.text = "Modo: " + mode_str

	back_btn.pressed.connect(func() -> void:
		NetworkManager.disconnect_game()
		var back_scene := "res://scenes/ui/arena_select.tscn" \
			if GameSettings.selected_mode == "last_standing" \
			else "res://scenes/ui/mode_select.tscn"
		get_tree().change_scene_to_file(back_scene)
	)

	_build_color_row()
	NetworkManager.players_updated.connect(_refresh)
	NetworkManager.connection_failed.connect(func(): _set_status("Falha na conexão.", true))
	NetworkManager.server_disconnected.connect(
		func(): get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")
	)
	NetworkManager.connected_to_server.connect(
		func(): _set_status("Conectado! Aguardando o host iniciar...")
	)
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	start_btn.pressed.connect(_on_start)


func _on_host() -> void:
	_apply_name()
	NetworkManager.host()
	_set_status("Hospedando na porta %d." % NetworkManager.DEFAULT_PORT)
	start_btn.visible = true
	_refresh()


func _on_join() -> void:
	_apply_name()
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	NetworkManager.join(ip)
	_set_status("Conectando em %s..." % ip)
	_set_buttons_enabled(false)


func _on_start() -> void:
	_start_game.rpc()


func _refresh() -> void:
	for child in player_list.get_children():
		child.queue_free()
	for id: int in NetworkManager.players:
		var data: Dictionary = NetworkManager.players[id]
		var lbl := Label.new()
		var suffix := " (você)" if id == multiplayer.get_unique_id() else ""
		lbl.text = "• " + data.get("name", "Capivara") + suffix
		player_list.add_child(lbl)


func _set_status(msg: String, re_enable: bool = false) -> void:
	status_label.text = msg
	if re_enable:
		_set_buttons_enabled(true)


func _set_buttons_enabled(on: bool) -> void:
	host_btn.disabled = not on
	join_btn.disabled = not on


func _apply_name() -> void:
	var n := name_input.text.strip_edges()
	NetworkManager.my_data["name"] = n if not n.is_empty() else "Capivara"


# ── Color picker ──────────────────────────────────────────────────────────────

func _build_color_row() -> void:
	for i in PALETTE.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(36, 36)
		btn.text = ""
		_apply_swatch(btn, i, i == 0)
		var idx := i
		btn.pressed.connect(func(): _select_color(idx))
		color_row.add_child(btn)
		_color_btns.append(btn)


func _select_color(idx: int) -> void:
	NetworkManager.my_data["color_index"] = idx
	for i in _color_btns.size():
		_apply_swatch(_color_btns[i], i, i == idx)


func _apply_swatch(btn: Button, idx: int, selected: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = PALETTE[idx]
	s.set_corner_radius_all(5)
	if selected:
		s.border_width_left   = 3
		s.border_width_right  = 3
		s.border_width_top    = 3
		s.border_width_bottom = 3
		s.border_color        = Color.WHITE
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus",   s)


# ── Scene transition ──────────────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	var scene: String = ARENA_SCENES.get(
		GameSettings.selected_arena,
		"res://scenes/levels/test_arena.tscn"
	)
	get_tree().change_scene_to_file(scene)

extends CanvasLayer

const MODE_NAMES := {
	"last_standing": "Last Capivara Standing",
	"capivara_bomb": "Capivara Bomb",
	"king_of_hill":  "King of the Hill",
	"race":          "Corrida de Obstáculos",
	"food_theft":    "Roubo de Comida",
}

const MAX_LIVES := 3

@onready var mode_lbl:   Label         = $VBox/ModeLbl
@onready var player_list: VBoxContainer = $VBox/PlayerList


func _ready() -> void:
	add_to_group("hud")
	mode_lbl.text = MODE_NAMES.get(GameSettings.selected_mode, "Modo Livre")
	NetworkManager.players_updated.connect(_refresh)
	_refresh()


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
	for child in player_list.get_children():
		child.queue_free()
	for id: int in NetworkManager.players:
		var data: Dictionary = NetworkManager.players[id]
		var lbl := Label.new()
		var remaining: int = lives.get(id, 0)
		var hearts: String = "♥ ".repeat(remaining).strip_edges() + " ♡".repeat(MAX_LIVES - remaining)
		lbl.text = "• " + data.get("name", "Capivara") + "  " + hearts
		lbl.add_theme_font_size_override("font_size", 14)
		player_list.add_child(lbl)


func show_winner(winner_id: int) -> void:
	var winner_name: String = "?"
	if winner_id == -1:
		winner_name = "EMPATE!"
	else:
		winner_name = NetworkManager.players.get(winner_id, {}).get("name", "?")

	var panel := PanelContainer.new()
	var vp_size := get_viewport().size
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

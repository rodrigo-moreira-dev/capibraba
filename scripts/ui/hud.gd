extends CanvasLayer

@onready var player_list: VBoxContainer = $VBox/PlayerList


func _ready() -> void:
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

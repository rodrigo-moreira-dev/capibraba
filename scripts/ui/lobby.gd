extends Control

@onready var name_input:   LineEdit      = $CC/PC/MC/VBox/NameInput
@onready var host_btn:     Button        = $CC/PC/MC/VBox/HostBtn
@onready var ip_input:     LineEdit      = $CC/PC/MC/VBox/JoinRow/IPInput
@onready var join_btn:     Button        = $CC/PC/MC/VBox/JoinRow/JoinBtn
@onready var status_label: Label         = $CC/PC/MC/VBox/StatusLabel
@onready var player_list:  VBoxContainer = $CC/PC/MC/VBox/PlayerList
@onready var start_btn:    Button        = $CC/PC/MC/VBox/StartBtn


func _ready() -> void:
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


@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/test_arena.tscn")

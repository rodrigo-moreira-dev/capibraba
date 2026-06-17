extends Control

@onready var back_btn: Button = $CC/PC/MC/VBox/BackBtn


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_btn.pressed.connect(
		func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)

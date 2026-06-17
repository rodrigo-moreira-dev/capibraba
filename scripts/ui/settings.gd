extends Control

@onready var volume_slider:    HSlider     = $CC/PC/MC/VBox/VolumeRow/VolumeSlider
@onready var fullscreen_check: CheckButton = $CC/PC/MC/VBox/FullscreenRow/FullscreenCheck
@onready var back_btn:         Button      = $CC/PC/MC/VBox/BackBtn


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	volume_slider.value            = GameSettings.master_volume
	fullscreen_check.button_pressed = GameSettings.fullscreen

	volume_slider.value_changed.connect(func(v: float) -> void:
		GameSettings.apply_volume(v)
		GameSettings.save()
	)
	fullscreen_check.toggled.connect(func(on: bool) -> void:
		GameSettings.apply_fullscreen(on)
		GameSettings.save()
	)
	back_btn.pressed.connect(
		func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)

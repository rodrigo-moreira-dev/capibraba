extends Node2D

## NameLabel2D - Rótulo de nome 2D desenhado via _draw().
## Evita usar a classe Label2D, que não está disponível em todos os builds
## do Godot (verificado ausente no build 4.7.1 usado neste projeto).

var text: String = ""
var font_size: int = 24
var outline_size: int = 6
var text_color: Color = Color.WHITE
var outline_color: Color = Color(0, 0, 0, 0.8)


func _draw() -> void:
	if text.is_empty():
		return
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(-w * 0.5, 0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, outline_size, outline_color)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func set_name_text(t: String) -> void:
	text = t
	queue_redraw()

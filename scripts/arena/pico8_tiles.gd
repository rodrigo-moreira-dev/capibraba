extends RefCounted
class_name Pico8Tiles

## Pico8Tiles - Tiles placeholder 2D estilo PICO-8 (16px) para as arenas.
## Gera texturas de CHÃO/PLATAFORMA e LAVA como ImageTexture procedural e um
## helper que preenche retângulos com sprites de tile repetidos (Sprite2D com
## `region_enabled`). É placeholder — troque `ground_tile_texture()` /
## `lava_tile_texture()` por assets importados depois, mantendo o helper.

const TILE := 16  # tamanho do tile em px

const C_DARK   := Color(0.20, 0.16, 0.13)  # contorno escuro
const C_GROUND := Color(0.42, 0.33, 0.26)  # chão/plataforma
const C_GROUND_HI := Color(0.55, 0.44, 0.34)
const C_LAVA   := Color(0.95, 0.38, 0.02)  # lava
const C_LAVA_HI := Color(1.0, 0.72, 0.20)


## Tile de chão/plataforma (16x16): bloco com topo claro e sombra na base.
static func ground_tile_texture() -> ImageTexture:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in TILE:
		for x in TILE:
			if x == 0 or x == TILE - 1 or y == 0:
				img.set_pixel(x, y, C_DARK)
			elif y < 4:
				img.set_pixel(x, y, C_GROUND_HI)
			elif y == TILE - 2 or y == TILE - 3:
				img.set_pixel(x, y, C_DARK.darkened(0.3))
			else:
				img.set_pixel(x, y, C_GROUND)
	return ImageTexture.create_from_image(img)


## Tile de lava (16x16): base laranja com "ondas" mais claras na superfície.
static func lava_tile_texture() -> ImageTexture:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(C_LAVA)
	for y in TILE:
		for x in TILE:
			var wave := (x + y * 3) % 7
			if y < 3 and wave < 3:
				img.set_pixel(x, y, C_LAVA_HI)
			elif y >= 13:
				img.set_pixel(x, y, C_LAVA.darkened(0.35))
	return ImageTexture.create_from_image(img)


## Preenche um retângulo (centrado em `center`, com `size` px) com tiles repetidos
## de `texture`, adicionando sprites ao pai `parent`. Retorna os sprites criados.
static func fill_rect(parent: Node2D, center: Vector2, size: Vector2, texture: Texture2D) -> Array:
	var created: Array = []
	if size.x <= 0.0 or size.y <= 0.0:
		return created
	var cols := int(ceil(size.x / TILE))
	var rows := int(ceil(size.y / TILE))
	var start := center - size / 2.0
	for ry in rows:
		for cx in cols:
			var s := Sprite2D.new()
			s.texture = texture
			# Mostra só a parte visível do tile nas bordas (region).
			s.region_enabled = true
			var region := Rect2(0, 0, TILE, TILE)
			var px := start.x + cx * TILE
			var py := start.y + ry * TILE
			if px + TILE > center.x + size.x / 2.0:
				region.size.x = (center.x + size.x / 2.0) - px
			if py + TILE > center.y + size.y / 2.0:
				region.size.y = (center.y + size.y / 2.0) - py
			s.region_rect = region
			s.centered = false
			s.position = Vector2(px, py)
			parent.add_child(s)
			created.append(s)
	return created


## Conveniência: preenche o retângulo de um StaticBody2D/Area2D (usa a extensão do
## primeiro CollisionShape2D filho, se for RectangleShape2D).
static func fill_node(parent: Node2D, texture: Texture2D) -> Array:
	var shape := _first_rect_shape(parent)
	if shape == null:
		return []
	var size := Vector2(shape.size.x, shape.size.y)
	return fill_rect(parent, Vector2.ZERO, size, texture)


static func _first_rect_shape(node: Node) -> RectangleShape2D:
	for child in node.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			return child.shape as RectangleShape2D
	return null

extends Node2D

const PICO8_TILES := preload("res://scripts/arena/pico8_tiles.gd")

## ArenaTileRenderer - Estrutura as arenas 2D com tiles placeholder (PICO-8).
## Coloque como filho da arena (antes do HUD, depois do Background). No _ready():
##   - Para cada StaticBody2D da cena que tenha um nó "Visual" (Polygon2D antigo),
##     preenche o retângulo do colisor com tiles de chão e esconde o Visual.
##   - Para cada Area2D no grupo "lava_area", preenche com tiles de lava e
##     esconde o Visual antigo.
## Usa `Pico8Tiles.fill_node` (robusto, sem depender da API frágil de TileSet).
## É placeholder — remova este nó (ou os sprites) quando houver assets reais.

@export var use_ground_tiles: bool = true
@export var use_lava_tiles: bool = true

# Sprites criados, para possível limpeza.
var _sprites: Array = []


func _ready() -> void:
	# Ordena: fundo -> plataformas -> lava (lava por cima é ok, é emissiva).
	_render_grounds()
	_render_lava()


func _render_grounds() -> void:
	if not use_ground_tiles:
		return
	for node in get_tree().get_nodes_in_group("tiled_ground"):
		if not node is StaticBody2D:
			continue
		var tex := PICO8_TILES.ground_tile_texture()
		_sprites.append_array(PICO8_TILES.fill_node(node, tex))
		_hide_visual(node)


func _render_lava() -> void:
	if not use_lava_tiles:
		return
	for node in get_tree().get_nodes_in_group("lava_area"):
		if not node is Area2D:
			continue
		var tex := PICO8_TILES.lava_tile_texture()
		_sprites.append_array(PICO8_TILES.fill_node(node, tex))
		_hide_visual(node)


## Esconde o Polygon2D "Visual" antigo (o tile agora é o visual).
func _hide_visual(node: Node) -> void:
	var v := node.get_node_or_null("Visual")
	if v is Polygon2D:
		v.visible = false

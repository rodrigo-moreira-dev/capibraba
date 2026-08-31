extends RefCounted
class_name Pico8Capybara

## Pico8Capybara - Sprite pixel art estilo PICO-8 do personagem (capivara).
## Gera uma ImageTexture a partir de um mapa de chars (paleta PICO-8 de 16 cores).
## Usado como placeholder reconhecível; pode ser substituído por um asset real
## depois (basta desenhar o PNG e trocar `make_texture()`).

# Paleta PICO-8 (32 cores; usamos as 16 base).
const PALETTE := [
	Color(0.0, 0.0, 0.0),        # 0 preto
	Color(0.11, 0.17, 0.33),     # 1 azul escuro
	Color(0.49, 0.18, 0.33),     # 2 roxo
	Color(0.0, 0.53, 0.32),      # 3 verde
	Color(0.67, 0.32, 0.21),     # 4 marrom (corpo da capivara)
	Color(0.37, 0.34, 0.31),     # 5 cinza (sombra do corpo)
	Color(0.76, 0.76, 0.78),     # 6 cinza claro
	Color(1.0, 0.95, 0.91),      # 7 branco
	Color(1.0, 0.0, 0.30),       # 8 vermelho
	Color(1.0, 0.64, 0.0),       # 9 laranja (destaque)
	Color(1.0, 0.93, 0.15),      # 10 amarelo
	Color(0.0, 0.89, 0.22),      # 11 verde claro
	Color(0.16, 0.68, 1.0),      # 12 azul
	Color(0.51, 0.46, 0.61),     # 13 lavanda
	Color(1.0, 0.47, 0.66),      # 14 rosa (focinho)
	Color(1.0, 0.80, 0.67),      # 15 pêssego (barriga)
]

# Mapa do sprite: 16x16. Cada char -> indice da paleta acima.
# '.' = transparente.
# M=marrom(4) corpo, S=cinza(5) sombra, B=pêssego(15) barriga, W=branco(7) olho,
# K=preto(0) pupila, P=rosa(14) focinho, N=marrom-escuro via 5 (sombra).
const SPRITE: Array[String] = [
	"......SSSSSS......",
	".....SMMMMMMS.....",
	"....SMMMMMMMMS....",
	"....SMKSMMSKMS....",
	"....SMMWWMMWWMS...",
	"....SMMBBMMBBMS...",
	"....SMMMMMMMMMS...",
	"....SMMMMMMPMMS...",
	"....SMMMMMMPMMS...",
	"....SMMMMMMPMMS...",
	"....SMMBBBBBBMS...",
	"....SMMBBBBBBMS...",
	".....SMMBBBBMS....",
	"......SSMMMMSS....",
	"........SSSS......",
	".................",
]


static func make_texture() -> ImageTexture:
	var w := SPRITE[0].length()
	var h := SPRITE.size()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = SPRITE[y]
		for x in w:
			var c: String = row.substr(x, 1)
			if c == "." or c == " ":
				continue
			var idx := index_of(c)
			if idx < 0:
				continue
			img.set_pixel(x, y, PALETTE[idx])
	return ImageTexture.create_from_image(img)


static func index_of(c: String) -> int:
	match c:
		"M": return 4
		"S": return 5
		"B": return 15
		"W": return 7
		"K": return 0
		"P": return 14
		_: return -1


## Largura/altura do sprite em pixels (para dimensionar).
static func pixel_size() -> Vector2i:
	return Vector2i(SPRITE[0].length(), SPRITE.size())

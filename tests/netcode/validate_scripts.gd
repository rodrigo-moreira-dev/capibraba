extends SceneTree

## validate_scripts.gd - Runner de validação (headless).
## Carrega (compila) cada script da Fase 0 POR CAMINHO, sem depender do registro
## de classes globais (que falha no executável do Steam em headless). Se um
## script tiver erro de parse/falta de dependência, `load()` retorna null e
## imprime o erro no console.
## Uso:  godot --headless --path <projeto> --script res://tests/netcode/validate_scripts.gd

const TARGETS := [
	"res://scripts/items/item_catalog.gd",
	"res://scripts/game/arena_rules_base.gd",
	"res://scripts/game/arena_manager_2d_base.gd",
	"res://scripts/game/hellball_manager_2d.gd",
	"res://scripts/game/hellball_manager.gd",
	"res://scripts/player/hellball_player_2d_base.gd",
	"res://scripts/player/arena_topdown_player_base.gd",
	"res://scripts/player/magnet_topdown_player.gd",
	"res://scripts/player/sword_topdown_player.gd",
	"res://scripts/player/hellball_platform_player.gd",
	"res://scripts/player/hellball_topdown_player.gd",
	"res://scripts/player/hellball_player.gd",
]


func _initialize() -> void:
	var failures: Array[String] = []
	for path in TARGETS:
		var res := load(path)
		if res == null:
			failures.append(path)
			# o erro de parse já foi impresso pelo Godot no console
		else:
			print("OK   " + path)

	if failures.is_empty():
		print("=== ALL SCRIPTS LOADED OK ===")
		quit(0)
	else:
		print("=== FAILURES: " + str(failures.size()) + " ===")
		for f in failures:
			print("FAIL " + f)
		quit(1)

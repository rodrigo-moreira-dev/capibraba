extends RefCounted
class_name ItemCatalog

## ItemCatalog - Catálogo genérico de itens do Capibraba.
## Mapeia um id de item -> configuração declarativa (uso primário/secundário,
## cooldowns, cena do projétil/orbe, cor). O consumidor (o jogador) usa
## `get_item(id)` e o `MatchSettings.item_slots`/`items_pool` para decidir quais
## itens equipar. Novos itens entram aqui, não colados nos scripts de jogador.
##
## Regra de ouro: o item NÃO decide se existe; o `items_pool` do minigame decide
## quais ids entram. Este catálogo só descreve o comportamento de cada id.

const CHARGE_ORB_2D := preload("res://scenes/player/charge_orb_2d.tscn")
const TELEPORT_ORB_2D := preload("res://scenes/player/teleport_orb_2d.tscn")
const CHARGE_PROJECTILE_3D := preload("res://scenes/player/charge_projectile.tscn")
const TELEPORT_ORB_3D := preload("res://scenes/player/teleport_orb.tscn")

## Categorias de uso primário/secundário que um jogador pode tratar.
## Um id de item pode ter `primary_use` e/ou `secondary_use`.
## - `shoot_charge`: dispara projétil carregável que empurra (Charge Gun).
## - `teleport_orb`: lança orbe; 2ª pressão teleporta; acertar rival troca.


static func _data() -> Dictionary:
	return {
		"charge_gun": {
			"display": "Charge Gun",
			"primary_use": "shoot_charge",
			"primary_btn": "shoot",
			"secondary_use": "",
			"secondary_btn": "",
			"primary_cooldown": 0.5,
			"secondary_cooldown": 0.0,
			"color": Color(1.0, 0.6, 0.1),
			"scene_2d": CHARGE_ORB_2D,
			"scene_3d": CHARGE_PROJECTILE_3D,
		},
		"teleport_gun": {
			"display": "Teleport Gun",
			"primary_use": "",
			"primary_btn": "",
			"secondary_use": "teleport_orb",
			"secondary_btn": "teleport_gun",
			"primary_cooldown": 0.0,
			"secondary_cooldown": 0.4,
			"color": Color(0.3, 0.8, 1.0),
			"scene_2d": TELEPORT_ORB_2D,
			"scene_3d": TELEPORT_ORB_3D,
		},
	}


static func has_item(id: String) -> bool:
	return _data().has(id)


static func get_item(id: String) -> Dictionary:
	## Devolve uma cópia (Dictionary) da configuração do item.
	return _data().get(id, {}).duplicate()


static func all_ids() -> PackedStringArray:
	return PackedStringArray(_data().keys())


static func is_item_in_pool(id: String) -> bool:
	## Checa se um id está no pool e dentro dos slots configurados do minigame.
	if not MatchSettings.items_pool.has(id):
		return false
	return MatchSettings.get_enabled_items().has(id)

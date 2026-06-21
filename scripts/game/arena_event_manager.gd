extends Node

## ArenaEventManager - Gerencia eventos aleatórios na arena

# Cenas criadas na Fase 3. Carregamento lazy (com guarda) para o projeto
# importar mesmo antes das cenas existirem — preload quebraria o parse.
const METEOR_SCENE_PATH := "res://scenes/arena/meteor.tscn"
const FIRE_PILLAR_SCENE_PATH := "res://scenes/arena/fire_pillar.tscn"

var _event_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _active_wind: Vector3 = Vector3.ZERO
var _wind_timer: float = 0.0


func _ready() -> void:
	_rng.randomize()
	add_to_group("arena_event_manager")


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if not MatchSettings.arena_events_enabled:
		return
	
	_event_timer += delta
	
	# Atualizar vento
	if _wind_timer > 0:
		_wind_timer -= delta
		if _wind_timer <= 0:
			_active_wind = Vector3.ZERO
	
	if _event_timer >= MatchSettings.arena_event_interval:
		_event_timer = 0.0
		_trigger_random_event()


func _trigger_random_event() -> void:
	var available_events := MatchSettings.get_enabled_events()
	if available_events.is_empty():
		return
	
	var event: String = available_events[_rng.randi() % available_events.size()]
	
	match event:
		"meteor_rain":
			_trigger_meteor_rain()
		"earthquake":
			_trigger_earthquake()
		"strong_wind":
			_trigger_strong_wind()
		"fire_pillars":
			_trigger_fire_pillars()


# ── Meteor Rain ───────────────────────────────────────────────────────────────

func _trigger_meteor_rain() -> void:
	var count := _rng.randi_range(3, 6)
	var positions: Array[Vector3] = []
	
	for i in count:
		var pos := Vector3(
			_rng.randf_range(-12, 12),
			15.0,  # Altura de spawn
			_rng.randf_range(-12, 12)
		)
		positions.append(pos)
	
	_announce_event.rpc("CHUVA DE METEOROS!", 2.0)
	await get_tree().create_timer(1.0).timeout
	
	for pos in positions:
		_spawn_meteor.rpc(pos)


@rpc("authority", "call_local", "reliable")
func _spawn_meteor(pos: Vector3) -> void:
	if not ResourceLoader.exists(METEOR_SCENE_PATH):
		return
	var meteor: Node = load(METEOR_SCENE_PATH).instantiate()
	meteor.global_position = pos
	get_tree().current_scene.add_child(meteor, true)


# ── Earthquake ────────────────────────────────────────────────────────────────

func _trigger_earthquake() -> void:
	_announce_event.rpc("TERREMOTO!", 1.5)
	
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p.is_multiplayer_authority():
			p.apply_external_impulse.rpc(
				Vector3(_rng.randf_range(-10, 10), 8, _rng.randf_range(-10, 10))
			)


# ── Strong Wind ───────────────────────────────────────────────────────────────

func _trigger_strong_wind() -> void:
	var wind_dir := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	var wind_strength := _rng.randf_range(8, 15)
	
	_active_wind = wind_dir * wind_strength
	_wind_timer = 6.0
	
	var dir_name := "LESTE" if wind_dir.x > 0.5 else "OESTE" if wind_dir.x < -0.5 else \
					"NORTE" if wind_dir.z > 0.5 else "SUL"
	
	_announce_event.rpc("VENTO FORTE - %s!" % dir_name, 2.0)
	_apply_wind_to_players.rpc(_active_wind, _wind_timer)


@rpc("authority", "call_local", "reliable")
func _apply_wind_to_players(wind: Vector3, duration: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p.has_method("apply_wind"):
			p.apply_wind(wind, duration)


# ── Fire Pillars ──────────────────────────────────────────────────────────────

func _trigger_fire_pillars() -> void:
	_announce_event.rpc("PILARES DE FOGO!", 2.0)
	await get_tree().create_timer(0.5).timeout
	
	var count := _rng.randi_range(2, 4)
	var positions: Array[Vector3] = []
	
	for i in count:
		var pos := Vector3(
			_rng.randf_range(-8, 8),
			0.0,
			_rng.randf_range(-8, 8)
		)
		positions.append(pos)
	
	for pos in positions:
		_spawn_fire_pillar.rpc(pos)


@rpc("authority", "call_local", "reliable")
func _spawn_fire_pillar(pos: Vector3) -> void:
	if not ResourceLoader.exists(FIRE_PILLAR_SCENE_PATH):
		return
	var pillar: Node = load(FIRE_PILLAR_SCENE_PATH).instantiate()
	pillar.global_position = pos
	get_tree().current_scene.add_child(pillar, true)


# ── UI ────────────────────────────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _announce_event(message: String, duration: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_event_announcement"):
		hud.show_event_announcement(message, duration)

extends Control

## MatchSettingsMenu - Menu para configurar todas as funcionalidades do jogo

const CATEGORIES := [
	{
		"name": "Geral",
		"icon": "⚙️",
		"settings": [
			{"key": "lives_per_player", "name": "Vidas por Jogador", "type": "option", "options": [1, 3, 5, 10]},
			{"key": "match_time_limit", "name": "Tempo Limite (min)", "type": "option", "options": [0, 2, 5, 10]},
			{"key": "rounds_to_win", "name": "Rounds para Vencer", "type": "option", "options": [0, 1, 3, 5]},
			{"key": "sudden_death_time", "name": "Sudden Death (min)", "type": "option", "options": [0, 1, 2, 3]},
			{"key": "kill_streak_enabled", "name": "Kill Streak (bônus)", "type": "toggle"},
		]
	},
	{
		"name": "Power-ups",
		"icon": "⭐",
		"settings": [
			{"key": "powerups_enabled", "name": "Ativar Power-ups", "type": "toggle", "main": true},
			{"key": "powerup_spawn_interval", "name": "Intervalo de Spawn (s)", "type": "slider", "min": 5, "max": 30},
			{"key": "powerup_shield_enabled", "name": "🛡️ Escudo", "type": "toggle"},
			{"key": "powerup_superspeed_enabled", "name": "⚡ Super Velocidade", "type": "toggle"},
			{"key": "powerup_triple_jump_enabled", "name": "🦘 Pulo Extra", "type": "toggle"},
			{"key": "powerup_homing_projectile_enabled", "name": "🎯 Míssil Guiado", "type": "toggle"},
			{"key": "powerup_mine_enabled", "name": "💣 Mina", "type": "toggle"},
			{"key": "powerup_magnet_enabled", "name": "🧲 Imã", "type": "toggle"},
			{"key": "powerup_zero_gravity_enabled", "name": "🌀 Gravidade Zero", "type": "toggle"},
		]
	},
	{
		"name": "Eventos de Arena",
		"icon": "🌋",
		"settings": [
			{"key": "arena_events_enabled", "name": "Ativar Eventos", "type": "toggle", "main": true},
			{"key": "arena_event_interval", "name": "Intervalo de Eventos (s)", "type": "slider", "min": 10, "max": 60},
			{"key": "event_meteor_rain_enabled", "name": "☄️ Chuva de Meteoros", "type": "toggle"},
			{"key": "event_earthquake_enabled", "name": "🌍 Terremoto", "type": "toggle"},
			{"key": "event_strong_wind_enabled", "name": "💨 Vento Forte", "type": "toggle"},
			{"key": "event_fire_pillars_enabled", "name": "🔥 Pilares de Fogo", "type": "toggle"},
			{"key": "moving_platforms_enabled", "name": "Plataformas Móveis", "type": "toggle"},
			{"key": "trampolines_enabled", "name": "Trampolins", "type": "toggle"},
			{"key": "danger_zones_enabled", "name": "Zonas de Perigo", "type": "toggle"},
			{"key": "breaking_platforms_enabled", "name": "Plataformas Frágeis", "type": "toggle"},
			{"key": "auto_cannons_enabled", "name": "Canhões Automáticos", "type": "toggle"},
		]
	},
	{
		"name": "Habilidades",
		"icon": "🎮",
		"settings": [
			{"key": "ability_grappling_hook_enabled", "name": "🪝 Gancho", "type": "toggle"},
			{"key": "ability_teleport_enabled", "name": "✨ Teleporte", "type": "toggle"},
			{"key": "ability_freeze_enabled", "name": "❄️ Congelar", "type": "toggle"},
			{"key": "ability_body_push_enabled", "name": "👊 Empurrão Corporal", "type": "toggle"},
			{"key": "ability_air_dash_enabled", "name": "💨 Dash Aéreo", "type": "toggle"},
			{"key": "ability_ground_pound_enabled", "name": "💥 Ground Pound", "type": "toggle"},
		]
	},
	{
		"name": "Visual",
		"icon": "🎨",
		"settings": [
			{"key": "particle_hit_effects_enabled", "name": "Partículas de Impacto", "type": "toggle"},
			{"key": "sound_impact_enhanced", "name": "Sons Melhorados", "type": "toggle"},
			{"key": "kill_cam_enabled", "name": "Kill Cam", "type": "toggle"},
		]
	},
	{
		"name": "Social",
		"icon": "💬",
		"settings": [
			{"key": "quick_chat_enabled", "name": "Chat Rápido", "type": "toggle"},
			{"key": "post_match_stats_enabled", "name": "Estatísticas Pós-Partida", "type": "toggle"},
		]
	},
]

@onready var tab_container: TabContainer = $CC/TabContainer
@onready var back_btn: Button = $CC/BackBtn
@onready var reset_btn: Button = $CC/ResetBtn
@onready var save_btn: Button = $CC/SaveBtn

var _setting_controls: Dictionary = {}


func _ready() -> void:
	MatchSettings.load()
	_build_tabs()
	
	back_btn.pressed.connect(_on_back)
	reset_btn.pressed.connect(_on_reset)
	save_btn.pressed.connect(_on_save)


func _build_tabs() -> void:
	for category in CATEGORIES:
		var scroll := ScrollContainer.new()
		scroll.name = category.icon + " " + category.name
		
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(vbox)
		
		for setting in category.settings:
			_add_setting_row(vbox, setting)
		
		tab_container.add_child(scroll)


func _add_setting_row(container: VBoxContainer, setting: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	
	# Label
	var label := Label.new()
	label.text = setting.name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(label)
	
	# Control baseado no tipo
	var control: Control
	
	match setting.type:
		"toggle":
			control = CheckButton.new()
			control.button_pressed = MatchSettings.get(setting.key)
			control.toggled.connect(func(pressed: bool) -> void:
				MatchSettings.set(setting.key, pressed)
				_on_setting_changed(setting.key, pressed)
			)
		
		"option":
			control = OptionButton.new()
			for i in setting.options.size():
				var opt = setting.options[i]
				var text := str(opt) if opt != 0 else "Desativado"
				control.add_item(text)
				if MatchSettings.get(setting.key) == opt:
					control.selected = i
			control.item_selected.connect(func(idx: int) -> void:
				MatchSettings.set(setting.key, setting.options[idx])
			)
		
		"slider":
			control = HSlider.new()
			control.min_value = setting.min
			control.max_value = setting.max
			control.step = 1.0
			control.value = MatchSettings.get(setting.key)
			control.custom_minimum_size = Vector2(100, 0)
			control.value_changed.connect(func(val: float) -> void:
				MatchSettings.set(setting.key, val)
			)
	
	hbox.add_child(control)
	_setting_controls[setting.key] = control
	
	container.add_child(hbox)
	
	# Separador
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	container.add_child(sep)


func _on_setting_changed(key: String, value: Variant) -> void:
	# Desativar controles dependentes quando main toggle é desativado
	match key:
		"powerups_enabled":
			_set_category_enabled("powerup", value)
		"arena_events_enabled":
			_set_category_enabled("event", value)


func _set_category_enabled(prefix: String, enabled: bool) -> void:
	for key in _setting_controls:
		if key.begins_with(prefix) and key != prefix + "s_enabled" and key != prefix + "_enabled":
			var control = _setting_controls[key]
			if control is CheckButton:
				control.disabled = not enabled


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")


func _on_reset() -> void:
	MatchSettings.reset_to_defaults()
	# Atualizar UI
	for key in _setting_controls:
		var control = _setting_controls[key]
		var value = MatchSettings.get(key)
		if control is CheckButton:
			control.button_pressed = value
		elif control is OptionButton:
			# Encontrar índice correspondente
			pass
		elif control is HSlider:
			control.value = value


func _on_save() -> void:
	MatchSettings.save()
	# Feedback visual
	save_btn.text = "✓ Salvo!"
	await get_tree().create_timer(1.0).timeout
	save_btn.text = "Salvar"

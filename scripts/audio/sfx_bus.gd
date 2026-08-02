extends Node

## SfxBus - Biblioteca procedural de efeitos sonoros (sem assets).
## Gera ondas (seno/quente/quadrada) via AudioStreamWAV e toca num pool de
## AudioStreamPlayer. Todo toque varia o pitch para soar orgânico.
## Quando houver assets reais, basta trocar o interior de `play()`.

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}  # nome -> AudioStreamWAV
var _rng := RandomNumberGenerator.new()

## Tabela de sons (freq = início, freq_end = fim, wave: 0 seno / 1 quente / 2 quadrada)
const SOUNDS := {
	"punch":        {"wave": 1, "freq": 260.0, "freq_end": 140.0, "dur": 0.10, "vol": 0.45},
	"punch_hit":    {"wave": 2, "freq": 190.0, "freq_end": 60.0,  "dur": 0.10, "vol": 0.55},
	"guard":        {"wave": 0, "freq": 520.0, "freq_end": 340.0, "dur": 0.12, "vol": 0.30},
	"guard_block":  {"wave": 2, "freq": 950.0, "freq_end": 480.0, "dur": 0.08, "vol": 0.45},
	"dash":         {"wave": 1, "freq": 300.0, "freq_end": 720.0, "dur": 0.12, "vol": 0.28},
	"charge_shoot": {"wave": 1, "freq": 520.0, "freq_end": 210.0, "dur": 0.14, "vol": 0.40},
	"explosion":    {"wave": 2, "freq": 150.0, "freq_end": 42.0,  "dur": 0.35, "vol": 0.65},
	"teleport":     {"wave": 0, "freq": 780.0, "freq_end": 1650.0,"dur": 0.18, "vol": 0.40},
	"swap":         {"wave": 0, "freq": 480.0, "freq_end": 1250.0,"dur": 0.25, "vol": 0.50},
	"lava":         {"wave": 2, "freq": 95.0,  "freq_end": 55.0,  "dur": 0.28, "vol": 0.50},
	"hurt":         {"wave": 2, "freq": 320.0, "freq_end": 120.0, "dur": 0.14, "vol": 0.50},
}


func _ready() -> void:
	_rng.randomize()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


## Toca um som da tabela. `pitch` permite variação extra por chamada.
func play(sound_name: String, pitch: float = 1.0) -> void:
	var cfg: Dictionary = SOUNDS.get(sound_name, {})
	if cfg.is_empty():
		return
	var stream: AudioStreamWAV = _cache.get(sound_name)
	if stream == null:
		stream = _make_tone(cfg)
		_cache[sound_name] = stream
	var p := _get_free_player()
	if p == null:
		return
	p.stream = stream
	p.pitch_scale = pitch * _rng.randf_range(0.92, 1.08)
	p.volume_db = linear_to_db(float(cfg.get("vol", 0.5)))
	p.play()


func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]  # todos ocupados → rouba o primeiro


func _make_tone(cfg: Dictionary) -> AudioStreamWAV:
	var rate := 22050
	var dur := float(cfg.get("dur", 0.2))
	var freq := float(cfg.get("freq", 440.0))
	var freq_end := float(cfg.get("freq_end", freq))
	var wave := int(cfg.get("wave", 0))
	var vol := float(cfg.get("vol", 0.5))
	var n := maxi(1, int(rate * dur))
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / rate
		var f := lerpf(freq, freq_end, t / maxf(dur, 0.001))
		phase += TAU * f / rate
		var s := 0.0
		match wave:
			0: s = sin(phase)
			1: s = sin(phase) * 0.7 + sin(phase * 2.0) * 0.3
			2: s = 1.0 if fmod(phase, TAU) < PI else -1.0
		var env := minf(t / 0.012, 1.0) * clampf((dur - t) / 0.06, 0.0, 1.0)
		var v := s * env * vol * 0.6
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

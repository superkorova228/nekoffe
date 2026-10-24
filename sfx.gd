class_name Sfx
extends Node
## Звуки: генерируются кодом при запуске (файлы не нужны).
## Учитывает настройки звука и вибрации из SaveData.
## Позже можно заменить на mp3/wav: достаточно подменить stream у плееров.

var _players: Dictionary = {}


func _ready() -> void:
	var defs: Dictionary = {
		"catch": tone_wav([660.0], 0.12, 0.5, 300.0, 0.0),
		"wrong": tone_wav([170.0], 0.28, 0.6, -120.0, 0.5),
		"done": tone_wav([523.0, 659.0, 784.0, 1047.0], 0.09, 0.5, 0.0, 0.0),
		"heal": tone_wav([660.0, 880.0], 0.1, 0.5, 0.0, 0.0),
		"jump": tone_wav([280.0], 0.15, 0.35, 900.0, 0.0),
		"hit": tone_wav([130.0], 0.35, 0.7, -90.0, 0.65),
		"warn": tone_wav([880.0], 0.13, 0.3, 0.0, 0.0),
		"start": tone_wav([523.0, 659.0, 784.0], 0.1, 0.5, 0.0, 0.0),
		"over": tone_wav([440.0, 370.0, 311.0, 247.0], 0.2, 0.55, -30.0, 0.0),
		"click": tone_wav([520.0], 0.05, 0.35, 0.0, 0.0),
	}
	for key in defs:
		var p := AudioStreamPlayer.new()
		p.stream = defs[key]
		p.volume_db = -6.0
		add_child(p)
		_players[key] = p


func play(key: String, pitch: float = 1.0) -> void:
	if not SaveData.sound_on:
		return
	var p: AudioStreamPlayer = _players.get(key)
	if p == null:
		return
	p.pitch_scale = pitch
	p.play()


func buzz(ms: int) -> void:
	if SaveData.vibration_on:
		Input.vibrate_handheld(ms)   # на ПК ничего не делает


## Генерирует короткий тон: список частот (играют по очереди), громкость, "глиссандо", шум
static func tone_wav(freqs: Array, dur: float, vol: float, sweep: float, noise: float) -> AudioStreamWAV:
	var rate: int = 22050
	var data := PackedByteArray()
	var n: int = int(rate * dur)
	for f in freqs:
		var chunk := PackedByteArray()
		chunk.resize(n * 2)
		var phase: float = 0.0
		for i in n:
			var t: float = float(i) / rate
			var x: float = float(i) / n
			var env: float = minf(1.0, float(i) / (rate * 0.004)) * pow(1.0 - x, 1.5)
			phase += TAU * (float(f) + sweep * t) / rate
			var s: float = sin(phase)
			if noise > 0.0:
				s = lerpf(s, randf() * 2.0 - 1.0, noise)
			var v: int = int(clampf(s * env * vol, -1.0, 1.0) * 32767.0)
			chunk.encode_s16(i * 2, v)
		data.append_array(chunk)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w

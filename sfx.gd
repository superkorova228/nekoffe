class_name Sfx
extends Node
## Звуки и музыка. По умолчанию все эффекты генерируются кодом.
## Свои файлы: положи в res://audio/ файл с нужным именем (.ogg, .mp3 или .wav), и он заменит звук.
##   catch, wrong, done, heal, jump, hit, warn, start, over, click  - короткие эффекты (лучше .wav)
##   music_game  - музыка геймплея (зацикливается; лучше .ogg или .mp3)
##   menu_sleep  - звук спящего кота в меню (зацикливается; лучше .ogg или .mp3)
## Если файла нет: эффекты генерируются кодом, музыка и сон просто молчат.

static var instance: Sfx = null

const AUDIO_DIR := "res://audio/"
const KEYS: Array = ["catch", "wrong", "done", "heal", "jump", "hit", "warn", "start", "over", "click"]
const SFX_VOLUME_DB := -8.0
const MUSIC_VOLUME_DB := -8.0     # громкость музыки геймплея
const AMBIENT_VOLUME_DB := -4.0   # громкость сна в меню
const MUSIC_FADE_IN := 0.1        # плавное появление музыки, сек
const MUSIC_FADE_OUT := 0.9       # затухание музыки при конце игры, сек
const MUSIC_END_PITCH := 0.2      # во сколько раз замедляется музыка при затухании (эффект "пластинки"); 1.0 = без эффекта
const AMBIENT_FADE := 0.4         # затухание/появление сна в меню, сек
const CLICK_GAP_MS := 120         # защита от двойного "клика" при быстрых повторах

var _players: Dictionary = {}
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _music_tween: Tween
var _ambient_tween: Tween
var _last_click_ms: int = -1000


func _ready() -> void:
	instance = self
	for key in KEYS:
		var stream: AudioStream = load_audio(key)
		if stream == null:
			stream = _generated(key)
		_players[key] = _make_player(stream, SFX_VOLUME_DB)
	_music = _make_player(load_audio("music_game"), MUSIC_VOLUME_DB)
	_ambient = _make_player(load_audio("menu_sleep"), AMBIENT_VOLUME_DB)
	_set_loop(_music.stream)
	_set_loop(_ambient.stream)
	apply_settings()


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _make_player(stream: AudioStream, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol
	add_child(p)
	return p


## Ищет res://audio/<имя>.ogg / .mp3 / .wav
static func load_audio(base: String) -> AudioStream:
	for ext in ["ogg", "mp3", "wav"]:
		var path: String = "%s%s.%s" % [AUDIO_DIR, base, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


static func _set_loop(s: AudioStream) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true


## Включает или выключает весь звук (общая шина Master)
static func apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not SaveData.sound_on)


## Звук нажатия кнопки (один для всех кнопок)
static func click() -> void:
	if instance != null:
		instance.play("click")


func play(key: String, pitch: float = 1.0) -> void:
	if not SaveData.sound_on:
		return
	if key == "click":
		var now: int = Time.get_ticks_msec()
		if now - _last_click_ms < CLICK_GAP_MS:
			return
		_last_click_ms = now
	var p: AudioStreamPlayer = _players.get(key)
	if p == null or p.stream == null:
		return
	p.pitch_scale = pitch
	p.play()


func buzz(ms: int) -> void:
	if SaveData.vibration_on:
		Input.vibrate_handheld(ms)   # на ПК ничего не делает


# ---------- музыка и сон кота ----------
## Меню: музыка геймплея останавливается, плавно включается сон кота
func menu_audio_start() -> void:
	_stop_music()
	if _ambient.stream == null:
		return
	_kill(_ambient_tween)
	_ambient.volume_db = -50.0
	_ambient.pitch_scale = 1.0
	_ambient.play()
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(_ambient, "volume_db", AMBIENT_VOLUME_DB, AMBIENT_FADE)


## Старт смены: сон затихает, музыка плавно включается с начала
func game_audio_start() -> void:
	if _ambient.playing:
		_kill(_ambient_tween)
		_ambient_tween = create_tween()
		_ambient_tween.tween_property(_ambient, "volume_db", -50.0, AMBIENT_FADE)
		_ambient_tween.tween_callback(_ambient.stop)
	if _music.stream == null:
		return
	_kill(_music_tween)
	_music.pitch_scale = 1.0
	_music.volume_db = -50.0
	_music.stream_paused = false
	_music.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE_IN)


func music_pause(paused: bool) -> void:
	_music.stream_paused = paused


## Конец игры: музыка быстро затихает и замедляется, как остановившаяся пластинка
func music_fade_out() -> void:
	if not _music.playing:
		return
	_kill(_music_tween)
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(_music, "volume_db", -50.0, MUSIC_FADE_OUT).set_ease(Tween.EASE_IN)
	_music_tween.tween_property(_music, "pitch_scale", MUSIC_END_PITCH, MUSIC_FADE_OUT)
	_music_tween.chain().tween_callback(_music.stop)


func _stop_music() -> void:
	_kill(_music_tween)
	_music.stream_paused = false
	_music.stop()


func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()


# ---------- генерируемые звуки ----------
static func _generated(key: String) -> AudioStream:
	match key:
		"catch":
			return tone_wav([660.0], 0.12, 0.5, 300.0, 0.0)
		"wrong":
			return tone_wav([170.0], 0.28, 0.6, -120.0, 0.5)
		"done":
			return tone_wav([523.0, 659.0, 784.0, 1047.0], 0.09, 0.5, 0.0, 0.0)
		"heal":
			return tone_wav([660.0, 880.0], 0.1, 0.5, 0.0, 0.0)
		"jump":
			return tone_wav([280.0], 0.15, 0.35, 900.0, 0.0)
		"hit":
			return tone_wav([130.0], 0.35, 0.7, -90.0, 0.65)
		"warn":
			return tone_wav([880.0], 0.13, 0.3, 0.0, 0.0)
		"start":
			return tone_wav([523.0, 659.0, 784.0], 0.1, 0.5, 0.0, 0.0)
		"over":
			return tone_wav([440.0, 370.0, 311.0, 247.0], 0.2, 0.55, -30.0, 0.0)
		_:
			return tone_wav([520.0], 0.05, 0.35, 0.0, 0.0)   # "click"


## Короткий тон: список частот (играют по очереди), громкость, "глиссандо", шум
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

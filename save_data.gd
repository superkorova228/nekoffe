extends Node
## Autoload "SaveData": прогресс и настройки. Файл: user://save.json

signal coins_changed(total: int)

const PATH := "user://save.json"

var coins: int = 0
var best_score: int = 0
var tutorial_seen: bool = false
var sound_on: bool = true
var vibration_on: bool = true
var selected_skin: String = "default"
var owned_skins: Array = ["default"]


func _ready() -> void:
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	coins = int(d.get("coins", 0))
	best_score = int(d.get("best_score", 0))
	tutorial_seen = bool(d.get("tutorial_seen", false))
	sound_on = bool(d.get("sound_on", true))
	vibration_on = bool(d.get("vibration_on", true))
	selected_skin = str(d.get("selected_skin", "default"))
	owned_skins = d.get("owned_skins", ["default"])


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"coins": coins,
		"best_score": best_score,
		"tutorial_seen": tutorial_seen,
		"sound_on": sound_on,
		"vibration_on": vibration_on,
		"selected_skin": selected_skin,
		"owned_skins": owned_skins,
	}))


func add_coins(n: int) -> void:
	coins += n
	coins_changed.emit(coins)
	save()


func try_spend(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	coins_changed.emit(coins)
	save()
	return true


## Возвращает true, если это новый рекорд
func submit_score(score: int) -> bool:
	if score > best_score:
		best_score = score
		save()
		return true
	return false

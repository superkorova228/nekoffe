class_name Fonts
extends RefCounted
## Шрифты игры. Файлы кладём в res://fonts/ и называем font_main и font_title
## (расширение .ttf, .otf или .woff2). Если файла нет, берётся стандартный шрифт Godot.

static var _main: Font = null
static var _title: Font = null
static var _loaded: bool = false


static func _load_one(base: String) -> Font:
	for ext in ["ttf", "otf", "woff2"]:
		var path: String = "res://fonts/%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			return load(path) as Font
	return null


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_main = _load_one("font_main")
	_title = _load_one("font_title")


## Основной шрифт: все надписи в игре и меню
static func main() -> Font:
	_ensure()
	return _main if _main != null else ThemeDB.fallback_font


## Шрифт названия игры в меню
static func title() -> Font:
	_ensure()
	return _title if _title != null else main()

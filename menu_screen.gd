class_name MenuScreen
extends Control
## Главное меню: тап в любом месте = играть. Кнопки по углам: настройки, "?" (обучение).
## Кот и камера живут в игровой сцене (main.gd), здесь только интерфейс поверх.

signal play_pressed
signal settings_pressed
signal help_pressed

var top_inset: float = 0.0   # отступ сверху под вырез камеры (ставит main.gd)
var coins: int = 0

var _hint: Label
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", int(top_inset) + 30)
	margin.add_theme_constant_override("margin_bottom", 150)   # у самого низа жест "Домой"
	add_child(UIKit.pass_through(margin))

	var col := VBoxContainer.new()
	margin.add_child(UIKit.pass_through(col))

	var top := HBoxContainer.new()
	col.add_child(UIKit.pass_through(top))
	var coin_label := UIKit.label("COINS  %d" % coins, 54, UIKit.GOLD)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	coin_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coin_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(coin_label)
	var settings := UIKit.button("Settings", Vector2(290, 100), 44)
	settings.pressed.connect(func() -> void: settings_pressed.emit())
	top.add_child(settings)

	col.add_child(UIKit.spacer(50))
	var title := UIKit.label("Nek0kofe", 150, Color(), false)
	title.add_theme_font_override("font", Fonts.title())   # отдельный шрифт для названия
	col.add_child(title)
	col.add_child(UIKit.spacer(30))
	_hint = UIKit.label("Tap to play", 72)
	col.add_child(_hint)

	var middle := Control.new()   # здесь, в нижней части экрана, виден спящий кот
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(middle)

	var bottom := HBoxContainer.new()
	col.add_child(UIKit.pass_through(bottom))
	var help := UIKit.button("?", Vector2(120, 120), 72)
	help.pressed.connect(func() -> void: help_pressed.emit())
	bottom.add_child(help)


func _process(delta: float) -> void:
	_t += delta
	if _hint != null:
		_hint.modulate.a = 0.55 + 0.45 * sin(_t * 4.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		play_pressed.emit()

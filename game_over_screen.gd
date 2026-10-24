class_name GameOverScreen
extends Control
## Экран конца смены. Рамка "выпрыгивает" из точки, строки появляются по очереди,
## кнопки появляются последними (обе сразу). Тап во время анимации показывает всё сразу.
## Данные кладёт main.gd в словарь data до добавления на сцену.

signal restarted
signal to_menu

const POP_TIME := 0.35      # рамка растёт из точки, сек
const ROW_DELAY := 0.13     # пауза между строками, сек
const ROW_TIME := 0.18      # появление одной строки, сек
const DIM_ALPHA := 0.6      # затемнение фона

var data: Dictionary = {}

var _card: PanelContainer
var _rows: Array[Control] = []
var _again: Button
var _menu: Button
var _dim: float = 0.0
var _tween: Tween
var _buttons_ready: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UIKit.box(UIKit.CREAM, UIKit.DARK, 40, 8))
	_card.modulate.a = 0.0   # до первой раскладки не показываем, чтобы не мигало
	center.add_child(_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	_card.add_child(col)

	# заголовок появляется вместе с рамкой
	col.add_child(UIKit.label("YOU'RE FIRED!", 96, UIKit.RED, false))

	# дальше строки появляются по очереди
	_add_row(col, UIKit.label("Score  %d" % int(data.get("score", 0)), 72, UIKit.DARK, false))
	if bool(data.get("new_record", false)):
		_add_row(col, _rainbow_label("NEW RECORD!", 60))
	else:
		_add_row(col, UIKit.label("Best  %d" % int(data.get("best", 0)), 52, UIKit.DARK, false))
	_add_row(col, UIKit.label("Orders  %d" % int(data.get("orders", 0)), 52, UIKit.DARK, false))
	_add_row(col, UIKit.label("Best combo  x%d" % int(data.get("combo", 0)), 52, UIKit.DARK, false))

	var coin_row := HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_theme_constant_override("separation", 14)
	coin_row.add_child(UIKit.coin_icon(72.0))
	coin_row.add_child(UIKit.label("Coins  +%d" % int(data.get("coins", 0)), 52, Color("a87400"), false))
	_add_row(col, coin_row)

	col.add_child(UIKit.spacer(14))

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	_again = UIKit.button("New shift", Vector2(700, 130), 58, UIKit.GREEN)
	_again.pressed.connect(func() -> void: restarted.emit())
	_again.disabled = true
	buttons.add_child(_again)
	_menu = UIKit.button("Menu", Vector2(700, 130), 58)
	_menu.pressed.connect(func() -> void: to_menu.emit())
	_menu.disabled = true
	buttons.add_child(_menu)
	_add_row(col, buttons)

	_start_animation.call_deferred()


func _add_row(parent: Control, row: Control) -> void:
	parent.add_child(row)
	row.modulate.a = 0.0
	_rows.append(row)


## NEW RECORD: буквы переливаются радугой (встроенный BBCode-эффект [rainbow])
func _rainbow_label(text: String, font_size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size = Vector2(620, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", Fonts.main())
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_color_override("font_outline_color", UIKit.DARK)
	r.add_theme_constant_override("outline_size", int(font_size * 0.14))
	r.text = "[center][rainbow freq=0.35 sat=0.85 val=1.0]%s[/rainbow][/center]" % text
	return r


func _start_animation() -> void:
	await get_tree().process_frame   # ждём раскладку, чтобы знать размеры
	if not is_inside_tree():
		return
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.02, 0.02)
	_card.modulate.a = 1.0

	_tween = create_tween()
	_tween.tween_property(self, "_dim", DIM_ALPHA, POP_TIME)
	_tween.parallel().tween_property(_card, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var t: float = POP_TIME * 0.7
	for r in _rows:
		r.pivot_offset = r.size * 0.5
		r.scale = Vector2(0.8, 0.8)
		_tween.parallel().tween_property(r, "modulate:a", 1.0, ROW_TIME).set_delay(t)
		_tween.parallel().tween_property(r, "scale", Vector2.ONE, ROW_TIME).set_delay(t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t += ROW_DELAY
	_tween.parallel().tween_callback(_enable_buttons).set_delay(t)


func _enable_buttons() -> void:
	_buttons_ready = true
	_again.disabled = false
	_menu.disabled = false


## Тап во время анимации: показать всё сразу
func _finish_now() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_dim = DIM_ALPHA
	_card.modulate.a = 1.0
	_card.scale = Vector2.ONE
	for r in _rows:
		r.modulate.a = 1.0
		r.scale = Vector2.ONE
	_enable_buttons()


func _gui_input(event: InputEvent) -> void:
	if not _buttons_ready and event is InputEventMouseButton and event.pressed:
		accept_event()
		_finish_now()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, _dim))

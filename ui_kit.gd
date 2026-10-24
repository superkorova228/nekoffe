class_name UIKit
extends RefCounted
## Общие стили и "кирпичики" для экранов меню: кнопки, надписи, рамки, иконки.

const DARK := Color("2b1d14")
const CREAM := Color("fffaf0")
const ORANGE := Color("e9a14a")
const GREEN := Color("7fd1a3")
const RED := Color("e5484d")
const GOLD := Color("f2b705")

const ICON_BTN := 110.0   # размер квадратных кнопок-иконок (настройки, помощь, пауза)
const ICON_MARGIN := 16.0 # отступ иконки от рамки кнопки

static var _tex_cache: Dictionary = {}


## Картинка из res://art/<имя>.png или null, если файла нет
static func art_texture(base: String) -> Texture2D:
	if _tex_cache.has(base):
		return _tex_cache[base]
	var tex: Texture2D = null
	var path: String = "res://art/%s.png" % base
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tex_cache[base] = tex
	return tex


static func box(bg: Color, border: Color = DARK, radius: int = 28, border_w: int = 6, margin_h: float = 40.0, margin_v: float = 30.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s


static func button(text: String, min_size: Vector2, font_size: int = 52, bg: Color = ORANGE) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Fonts.main())
	b.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, DARK)
	b.add_theme_stylebox_override("normal", box(bg))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.15)))
	b.pressed.connect(func() -> void: Sfx.click())   # один звук нажатия для всех кнопок
	return b


## Квадратная кнопка с иконкой res://art/icon_<имя>.png (рамка остаётся, вместо текста картинка).
## Если файла нет, показывается fallback_text.
static func icon_button(icon_name: String, fallback_text: String) -> Button:
	var b := button("", Vector2(ICON_BTN, ICON_BTN), 60)
	b.add_theme_stylebox_override("normal", box(ORANGE, DARK, 28, 6, ICON_MARGIN, ICON_MARGIN))
	b.add_theme_stylebox_override("hover", box(ORANGE.lightened(0.1), DARK, 28, 6, ICON_MARGIN, ICON_MARGIN))
	b.add_theme_stylebox_override("pressed", box(ORANGE.darkened(0.15), DARK, 28, 6, ICON_MARGIN, ICON_MARGIN))
	var tex: Texture2D = art_texture("icon_" + icon_name)
	if tex != null:
		b.icon = tex
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		b.text = fallback_text
	return b


## Иконка монеты: res://art/coin.png, а пока файла нет, рисуется жёлтый кружок-заглушка
static func coin_icon(px: float) -> Control:
	var tex: Texture2D = art_texture("coin")
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = Vector2(px, px)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return r
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var r: float = px * 0.5
		c.draw_circle(Vector2(r, r), r, Color("a87400"))
		c.draw_circle(Vector2(r, r), r * 0.82, GOLD)
		c.draw_arc(Vector2(r, r), r * 0.52, 0.0, TAU, 24, Color("a87400"), px * 0.07))
	return c


static func label(text: String, font_size: int, color: Color = Color.WHITE, outline: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Fonts.main())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", int(font_size * 0.12))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Контейнер, который не перехватывает касания (они "проваливаются" к родителю)
static func pass_through(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c


static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

class_name UIKit
extends RefCounted
## Общие стили и "кирпичики" для экранов меню: кнопки, надписи, рамки.

const DARK := Color("2b1d14")
const CREAM := Color("fffaf0")
const ORANGE := Color("e9a14a")
const GREEN := Color("7fd1a3")
const RED := Color("e5484d")
const GOLD := Color("f2b705")


static func box(bg: Color, border: Color = DARK, radius: int = 28, border_w: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 40.0
	s.content_margin_right = 40.0
	s.content_margin_top = 30.0
	s.content_margin_bottom = 30.0
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
	return b


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

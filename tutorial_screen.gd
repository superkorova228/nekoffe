class_name TutorialScreen
extends Control
## Туториал: 4 карточки, тап = дальше. Картинки рисуются кодом
## (если в res://art есть спрайты ингредиентов и кота, используются они).

signal finished

const PAGES: Array = [
	["Move", "Swipe left or right to change lanes."],
	["Catch in order", "Catch the ingredients the client asks for, in the same order as in the bubble. A wrong one costs patience."],
	["Jump", "Barrels roll across the floor after a warning sign. Swipe up to jump over them. You can't catch while in the air."],
	["Keep clients happy", "If the patience bar runs out or a barrel hits you, you lose a heart. Lose all three and you're fired! Perfect orders earn coins."],
]

var first_run: bool = false
var top_inset: float = 0.0

var _page: int = 0
var _t: float = 0.0
var _title: Label
var _body: Label
var _hint: Label
var _art: Control
var _tex: Dictionary = {}
var _cat_tex: Texture2D = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var names: Dictionary = {0: "coffee", 1: "milk", 2: "strawberry"}
	for k in names:
		var path: String = "res://art/%s.png" % names[k]
		if ResourceLoader.exists(path):
			_tex[k] = load(path)
	if ResourceLoader.exists("res://art/cat.png"):
		_cat_tex = load("res://art/cat.png") as Texture2D

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_right", 70)
	margin.add_theme_constant_override("margin_top", int(top_inset) + 170)
	margin.add_theme_constant_override("margin_bottom", 170)
	add_child(UIKit.pass_through(margin))

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 30)
	margin.add_child(UIKit.pass_through(col))

	_title = UIKit.label("", 88)
	col.add_child(_title)
	_art = Control.new()
	_art.custom_minimum_size = Vector2(0, 620)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_art)
	_body = UIKit.label("", 48, Color("f2e6d0"), false)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(0, 270)   # одинаковая высота, чтобы заголовок не прыгал между карточками
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	col.add_child(_body)
	_hint = UIKit.label("", 54)
	col.add_child(_hint)

	var skip := UIKit.button("Skip", Vector2(240, 100), 44, UIKit.CREAM)
	add_child(skip)
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.anchor_top = 0.0
	skip.anchor_bottom = 0.0
	skip.offset_left = -280.0
	skip.offset_right = -40.0
	skip.offset_top = 40.0 + top_inset
	skip.offset_bottom = 140.0 + top_inset
	skip.pressed.connect(func() -> void: finished.emit())

	_apply_page()


func _apply_page() -> void:
	_title.text = PAGES[_page][0]
	_body.text = PAGES[_page][1]
	if _page < PAGES.size() - 1:
		_hint.text = "Tap to continue"
	else:
		_hint.text = "Tap to play" if first_run else "Tap to close"


func _process(delta: float) -> void:
	_t += delta
	if _hint != null:
		_hint.modulate.a = 0.55 + 0.45 * sin(_t * 4.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _page < PAGES.size() - 1:
			_page += 1
			_apply_page()
		else:
			finished.emit()


# ---------- рисование ----------
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.05, 0.04, 1.0))
	for i in PAGES.size():
		var a: float = 0.95 if i == _page else 0.25
		draw_circle(Vector2(size.x * 0.5 + (i - (PAGES.size() - 1) * 0.5) * 50.0, top_inset + 90.0), 11.0, Color(1, 1, 1, a))
	if _art == null:
		return
	var c: Vector2 = _art.global_position - global_position + _art.size * 0.5
	match _page:
		0:
			_art_move(c)
		1:
			_art_order(c)
		2:
			_art_jump(c)
		3:
			_art_patience(c)


func _art_move(c: Vector2) -> void:
	for i in 3:
		var lx: float = c.x + (i - 1) * 230.0
		draw_rect(Rect2(lx - 100.0, c.y - 270.0, 200.0, 540.0), Color(1, 1, 1, 0.07 if i % 2 == 0 else 0.13))
	var k: float = sin(_t * 1.8)
	var cat_x: float = c.x + 230.0 * k
	_cat(Vector2(cat_x, c.y + 230.0), 0.0)
	draw_line(Vector2(c.x - 230.0, c.y + 270.0), Vector2(c.x + 230.0, c.y + 270.0), Color(1, 1, 1, 0.35), 6.0)
	draw_circle(Vector2(cat_x, c.y + 270.0), 30.0, Color(1, 1, 1, 0.8))


func _art_order(c: Vector2) -> void:
	var bubble := Rect2(c.x - 380.0, c.y - 280.0, 760.0, 190.0)
	draw_rect(bubble, Color.WHITE)
	draw_rect(bubble, UIKit.DARK, false, 6.0)
	var kinds: Array = [0, 1, 2]
	for i in kinds.size():
		var p := Vector2(c.x + (i - 1) * 220.0, c.y - 185.0)
		if i == 0:
			var a: float = 0.5 + 0.4 * sin(_t * 5.0)
			draw_arc(p, 78.0, 0.0, TAU, 32, Color(0.94, 0.63, 0.12, a), 8.0)
		_item(kinds[i], p, 54.0)
	var ph: float = fposmod(_t * 0.7, 1.0)
	_item(0, Vector2(c.x, lerpf(c.y - 60.0, c.y + 150.0, ph)), 54.0)
	_cat(Vector2(c.x, c.y + 270.0), 0.0)


func _art_jump(c: Vector2) -> void:
	var floor_y: float = c.y + 230.0
	draw_line(Vector2(c.x - 400.0, floor_y), Vector2(c.x + 400.0, floor_y), Color(1, 1, 1, 0.4), 8.0)
	var ph: float = fposmod(_t * 0.45, 1.0)
	var lift: float = 150.0 * sin(PI * clampf((ph - 0.3) / 0.4, 0.0, 1.0))
	_cat(Vector2(c.x, floor_y), lift)
	if ph < 0.25:
		var warn := PackedVector2Array([Vector2(c.x - 360.0, floor_y - 130.0), Vector2(c.x - 306.0, floor_y - 34.0), Vector2(c.x - 414.0, floor_y - 34.0), Vector2(c.x - 360.0, floor_y - 130.0)])
		draw_colored_polygon(warn, Color(0.94, 0.63, 0.12, 0.5 + 0.5 * sin(_t * 12.0)))
		draw_polyline(warn, UIKit.DARK, 6.0)
	var bx: float = lerpf(c.x - 440.0, c.x + 440.0, ph)
	var bp := Vector2(bx, floor_y - 46.0)
	var barrel: Texture2D = UIKit.art_texture("barrel")
	if barrel != null:
		draw_set_transform(bp, bx / 46.0, Vector2.ONE)
		var bts: Vector2 = barrel.get_size()
		var bsz: Vector2 = bts * (92.0 / maxf(bts.x, bts.y))
		draw_texture_rect(barrel, Rect2(-bsz * 0.5, bsz), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(bp, 46.0, Color(0.23, 0.14, 0.09))
		draw_arc(bp, 43.0, 0.0, TAU, 40, Color(0.9, 0.28, 0.3), 6.0)
	var a: float = 0.5 + 0.5 * sin(_t * 6.0)
	var ay: float = c.y - 90.0 - lift * 0.3
	draw_polyline(PackedVector2Array([Vector2(c.x - 50.0, ay + 30.0), Vector2(c.x, ay - 10.0), Vector2(c.x + 50.0, ay + 30.0)]), Color(1, 1, 1, a), 10.0)


func _art_patience(c: Vector2) -> void:
	var ratio: float = 1.0 - fposmod(_t * 0.25, 1.0)
	var client_col: Color = Color("b8b8b8").lerp(Color("e5484d"), clampf(inverse_lerp(0.5, 0.1, ratio), 0.0, 1.0))
	var client: Texture2D = UIKit.art_texture("client2")   # лицо клиента из спрайта (res://art/client2.png)
	if client != null:
		var tint: Color = Color.WHITE.lerp(Color(1.0, 0.45, 0.45), clampf(inverse_lerp(0.5, 0.1, ratio), 0.0, 1.0))
		var cts: Vector2 = client.get_size()
		var csz: Vector2 = cts * (190.0 / maxf(cts.x, cts.y))
		draw_texture_rect(client, Rect2(Vector2(c.x, c.y - 170.0) - csz * 0.5, csz), false, tint)
	else:
		draw_circle(Vector2(c.x, c.y - 170.0), 80.0, client_col)
		draw_circle(Vector2(c.x - 26.0, c.y - 184.0), 9.0, UIKit.DARK)
		draw_circle(Vector2(c.x + 26.0, c.y - 184.0), 9.0, UIKit.DARK)
	var bar := Rect2(c.x - 300.0, c.y - 40.0, 600.0, 40.0)
	draw_rect(bar, Color(1, 1, 1, 0.2))
	var pc: Color = Color("5bb98c").lerp(Color("e5484d"), clampf(inverse_lerp(0.6, 0.15, ratio), 0.0, 1.0))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), pc)
	var heart: Texture2D = UIKit.art_texture("heart")
	for h in 3:
		var alive: bool = h < 2 or ratio > 0.2
		var hp := Vector2(c.x + (h - 1) * 110.0, c.y + 150.0)
		if heart != null:
			var ts: Vector2 = heart.get_size()
			var sz: Vector2 = ts * (90.0 / maxf(ts.x, ts.y))
			draw_texture_rect(heart, Rect2(hp - sz * 0.5, sz), false, Color.WHITE if alive else Color(0.3, 0.3, 0.3, 0.6))
		else:
			draw_circle(hp, 40.0, Color("e5484d") if alive else Color(1, 1, 1, 0.2))


func _cat(feet: Vector2, lift: float) -> void:
	var f := Vector2(feet.x, feet.y - lift)
	if _cat_tex != null:
		var h: float = 210.0
		var ts: Vector2 = _cat_tex.get_size()
		var sz: Vector2 = ts * (h / ts.y)
		draw_texture_rect(_cat_tex, Rect2(f - Vector2(sz.x * 0.5, sz.y), sz), false)
		return
	var col: Color = UIKit.ORANGE
	draw_rect(Rect2(f.x - 65.0, f.y - 150.0, 130.0, 150.0), col)
	draw_colored_polygon(PackedVector2Array([Vector2(f.x - 57.0, f.y - 150.0), Vector2(f.x - 57.0, f.y - 186.0), Vector2(f.x - 17.0, f.y - 150.0)]), col)
	draw_colored_polygon(PackedVector2Array([Vector2(f.x + 57.0, f.y - 150.0), Vector2(f.x + 57.0, f.y - 186.0), Vector2(f.x + 17.0, f.y - 150.0)]), col)
	draw_circle(Vector2(f.x - 28.0, f.y - 92.0), 9.0, UIKit.DARK)
	draw_circle(Vector2(f.x + 28.0, f.y - 92.0), 9.0, UIKit.DARK)


func _item(kind: int, pos: Vector2, r: float) -> void:
	if _tex.has(kind):
		var tex: Texture2D = _tex[kind]
		var ts: Vector2 = tex.get_size()
		var sz: Vector2 = ts * (r * 2.3 / maxf(ts.x, ts.y))
		draw_texture_rect(tex, Rect2(pos - sz * 0.5, sz), false)
		return
	match kind:
		0:
			draw_set_transform(pos, 0.0, Vector2(0.72, 1.0))
			draw_circle(Vector2.ZERO, r, Color("6b3f1d"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		1:
			draw_rect(Rect2(pos.x - r * 0.7, pos.y - r * 0.8, r * 1.4, r * 1.6), Color.WHITE)
			draw_rect(Rect2(pos.x - r * 0.7, pos.y - r * 0.1, r * 1.4, r * 0.4), Color("3d7fd6"))
		_:
			draw_circle(pos, r * 0.85, Color("d62839"))

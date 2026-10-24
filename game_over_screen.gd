class_name GameOverScreen
extends Control
## Экран конца смены: счёт, рекорд, монеты, кнопки "новая смена" и "меню".
## Данные кладёт main.gd в словарь data до добавления на сцену.

signal restarted
signal to_menu

var data: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.box(UIKit.CREAM, UIKit.DARK, 40, 8))
	center.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)

	col.add_child(UIKit.label("YOU'RE FIRED!", 96, UIKit.RED, false))
	col.add_child(UIKit.label("Score  %d" % int(data.get("score", 0)), 72, UIKit.DARK, false))
	if bool(data.get("new_record", false)):
		col.add_child(UIKit.label("NEW RECORD!", 56, Color("d9480f"), false))
	else:
		col.add_child(UIKit.label("Best  %d" % int(data.get("best", 0)), 52, UIKit.DARK, false))
	col.add_child(UIKit.label("Orders  %d" % int(data.get("orders", 0)), 52, UIKit.DARK, false))
	col.add_child(UIKit.label("Best combo  x%d" % int(data.get("combo", 0)), 52, UIKit.DARK, false))
	col.add_child(UIKit.label("Coins  +%d   (total %d)" % [int(data.get("coins", 0)), int(data.get("total", 0))], 52, Color("a87400"), false))
	col.add_child(UIKit.spacer(14))

	var again := UIKit.button("New shift", Vector2(700, 130), 58, UIKit.GREEN)
	again.pressed.connect(func() -> void: restarted.emit())
	col.add_child(again)
	var menu := UIKit.button("Menu", Vector2(700, 130), 58)
	menu.pressed.connect(func() -> void: to_menu.emit())
	col.add_child(menu)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))

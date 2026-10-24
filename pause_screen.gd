class_name PauseScreen
extends Control
## Пауза: продолжить, начать заново, выйти в меню.

signal resumed
signal restarted
signal to_menu


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 34)
	center.add_child(col)

	col.add_child(UIKit.label("PAUSED", 140))
	col.add_child(UIKit.spacer(20))
	var resume := UIKit.button("Resume", Vector2(680, 140), 62, UIKit.GREEN)
	resume.pressed.connect(func() -> void: resumed.emit())
	col.add_child(resume)
	var restart := UIKit.button("Restart", Vector2(680, 140), 62)
	restart.pressed.connect(func() -> void: restarted.emit())
	col.add_child(restart)
	var menu := UIKit.button("Menu", Vector2(680, 140), 62, UIKit.CREAM)
	menu.pressed.connect(func() -> void: to_menu.emit())
	col.add_child(menu)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.65))

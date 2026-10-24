class_name SettingsScreen
extends Control
## Настройки: звук и вибрация (сохраняются в SaveData).

signal closed

var _sound: Button
var _vib: Button


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
	col.add_theme_constant_override("separation", 30)
	card.add_child(col)

	col.add_child(UIKit.label("Settings", 90, UIKit.DARK, false))
	_sound = UIKit.button("", Vector2(700, 130), 56)
	_sound.pressed.connect(_toggle_sound)
	col.add_child(_sound)
	_vib = UIKit.button("", Vector2(700, 130), 56)
	_vib.pressed.connect(_toggle_vibration)
	col.add_child(_vib)
	var close := UIKit.button("Close", Vector2(700, 130), 56, UIKit.GREEN)
	close.pressed.connect(func() -> void: closed.emit())
	col.add_child(close)
	_refresh()


func _refresh() -> void:
	_sound.text = "Sound:  %s" % ("ON" if SaveData.sound_on else "OFF")
	_vib.text = "Vibration:  %s" % ("ON" if SaveData.vibration_on else "OFF")


func _toggle_sound() -> void:
	SaveData.sound_on = not SaveData.sound_on
	SaveData.save()
	_refresh()


func _toggle_vibration() -> void:
	SaveData.vibration_on = not SaveData.vibration_on
	SaveData.save()
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7))

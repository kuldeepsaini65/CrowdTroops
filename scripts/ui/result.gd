class_name ResultScreen
extends CanvasLayer
## Win / lose overlay with level stats (minimal for M1; themed in M2).

signal continue_pressed

const INPUT_DELAY := 0.7

var _box: VBoxContainer
var _continue: Button


func _ready() -> void:
	layer = 15
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 30)
	center.add_child(_box)


func show_result(won: bool, stats: Dictionary) -> void:
	for child in _box.get_children():
		child.queue_free()
	_box.add_child(UiStyle.label("VICTORY!" if won else "DEFEAT", 130, 28))
	var lines := "Units sent  %d\nPeak crowd  %d\nRaiders crushed  %d\nCoins  +%d" % [
		int(stats.get("units_sent", 0)),
		int(stats.get("peak_crowd", 0)),
		int(stats.get("raiders_crushed", 0)),
		int(stats.get("coins_earned", 0)),
	]
	_box.add_child(UiStyle.label(lines, 54, 14))
	_continue = UiStyle.button("CONTINUE" if won else "RETRY", 64, Vector2(560, 160))
	_continue.disabled = true
	_continue.pressed.connect(func() -> void: continue_pressed.emit())
	_box.add_child(_continue)
	visible = true
	# Ignore the finger that was still firing when the level ended.
	get_tree().create_timer(INPUT_DELAY).timeout.connect(func() -> void: _continue.disabled = false)


func _unhandled_input(event: InputEvent) -> void:
	if visible and _continue != null and not _continue.disabled and event.is_action_pressed(&"ui_accept"):
		continue_pressed.emit()

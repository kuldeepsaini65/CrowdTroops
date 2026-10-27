class_name PauseMenu
extends CanvasLayer
## Pause overlay (minimal for M1). Runs while the tree is paused.
## P / Esc / Android back toggles it; the app pauses itself when backgrounded.

signal restart_requested

var enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 40)
	center.add_child(box)

	box.add_child(UiStyle.label("PAUSED", 110, 24))
	var resume := UiStyle.button("RESUME", 60, Vector2(520, 150))
	resume.pressed.connect(set_paused.bind(false))
	box.add_child(resume)
	var restart := UiStyle.button("RESTART", 60, Vector2(520, 150))
	restart.pressed.connect(_on_restart)
	box.add_child(restart)


func toggle() -> void:
	set_paused(not get_tree().paused)


func set_paused(paused: bool) -> void:
	if paused and not enabled:
		return
	get_tree().paused = paused
	visible = paused
	GameEvents.game_paused.emit(paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		set_paused(true)


func _on_restart() -> void:
	set_paused(false)
	restart_requested.emit()

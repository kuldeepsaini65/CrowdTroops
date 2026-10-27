class_name Hud
extends CanvasLayer
## In-game HUD. Milestone 1 keeps it functional (level, wall HP, fort HP,
## crowd, pause button, debug stats); Milestone 2 gives it the real theme.

signal pause_pressed

const DEBUG_REFRESH := 0.25

var _level: int = 1
var _wall_hp: int = 0
var _wall_max: int = 0
var _base_hp: int = 0
var _base_max: int = 0
var _sim: CrowdSim

var _status: Label
var _crowd: Label
var _debug: Label
var _debug_timer: float = 0.0


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_status = UiStyle.label("", 50)
	_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status.offset_top = 90.0
	_status.offset_bottom = 230.0
	root.add_child(_status)

	_crowd = UiStyle.label("", 46)
	_crowd.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_crowd.offset_top = -170.0
	_crowd.offset_bottom = -90.0
	root.add_child(_crowd)

	var pause_button := UiStyle.button("II", 56, Vector2(130, 130))
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -170.0
	pause_button.offset_right = -40.0
	pause_button.offset_top = 260.0
	pause_button.offset_bottom = 390.0
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	root.add_child(pause_button)

	if OS.is_debug_build():
		_debug = UiStyle.label("", 30, 8)
		_debug.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_debug.offset_top = 30.0
		_debug.offset_bottom = 80.0
		root.add_child(_debug)

	GameEvents.wall_hp_changed.connect(_on_wall_hp_changed)
	GameEvents.base_hp_changed.connect(_on_base_hp_changed)


func setup(level: int, sim: CrowdSim) -> void:
	_level = level
	_sim = sim
	_refresh_status()


func set_crowd(count: int) -> void:
	_crowd.text = "Crowd %d" % count


func _process(delta: float) -> void:
	if _debug == null or _sim == null:
		return
	_debug_timer -= delta
	if _debug_timer > 0.0:
		return
	_debug_timer = DEBUG_REFRESH
	_debug.text = "FPS %d  |  blue %d  red %d  |  draws %d" % [
		Engine.get_frames_per_second(),
		_sim.f_count,
		_sim.e_count,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	]


func _on_wall_hp_changed(hp: int, max_hp: int) -> void:
	_wall_hp = hp
	_wall_max = max_hp
	_refresh_status()


func _on_base_hp_changed(hp: int, max_hp: int) -> void:
	_base_hp = hp
	_base_max = max_hp
	_refresh_status()


func _refresh_status() -> void:
	_status.text = "LEVEL %d\nWall %d/%d    Fort %d" % [_level, _wall_hp, _wall_max, _base_hp]

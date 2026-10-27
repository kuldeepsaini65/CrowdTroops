extends Node3D
## Root of game.tscn. Builds the level from code and runs the fixed 60 Hz
## loop: cannon -> gates -> fort spawns -> CrowdSim.step -> apply results
## -> render. Win when fort HP hits 0, lose when wall HP hits 0.

enum State { PLAYING, WON, LOST }

const SHAKE_BASE_HIT := 0.12
const SHAKE_WALL_HIT := 0.45
const SHAKE_WIN := 0.8
const HAPTIC_WALL_MS := 40
const CROWD_REFRESH := 0.1

@onready var _camera_rig: CameraRig = $CameraRig
@onready var _sun: DirectionalLight3D = $Sun

var _state: State = State.PLAYING
var _level: int = 1
var _level_def: LevelDef
var _sim: CrowdSim
var _renderer: UnitRenderer
var _fx: FxPool
var _cannon: Cannon
var _base: EnemyBase
var _gates: Array[Gate] = []
var _hud: Hud
var _pause: PauseMenu
var _result: ResultScreen

var _wall_hp: int = 0
var _wall_max: int = 0
var _time: float = 0.0
var _crowd_timer: float = 0.0


func _ready() -> void:
	InputSetup.ensure_actions()
	_sun.rotation = Vector3(deg_to_rad(Tuning.SUN_PITCH_DEG), deg_to_rad(Tuning.SUN_YAW_DEG), 0.0)

	_level = SaveManager.level
	_level_def = LevelBuilder.load_level(_level)
	LevelBuilder.build_graybox_world(self)

	_sim = CrowdSim.new(Tuning.MAX_FRIENDLIES, Tuning.MAX_ENEMIES)
	_sim.rng.seed = hash(_level)
	_sim.configure_gates(_level_def.gates)

	_renderer = UnitRenderer.new()
	add_child(_renderer)
	_renderer.setup(_sim, {
		CrowdSim.Kind.SOLDIER: UnitVisuals.make_placeholder(CrowdSim.Kind.SOLDIER),
		CrowdSim.Kind.CHAMPION: UnitVisuals.make_placeholder(CrowdSim.Kind.CHAMPION),
		CrowdSim.Kind.GRUNT: UnitVisuals.make_placeholder(CrowdSim.Kind.GRUNT),
		CrowdSim.Kind.BRUTE: UnitVisuals.make_placeholder(CrowdSim.Kind.BRUTE),
	})

	_fx = FxPool.new()
	add_child(_fx)
	_fx.setup(Color(0.3, 0.6, 1.0), Color(1.0, 0.3, 0.25))

	for gate_def in _level_def.gates:
		var gate := Gate.new()
		add_child(gate)
		gate.setup(gate_def, _level_def.gate_speed)
		_gates.append(gate)

	var level_rng := RandomNumberGenerator.new()
	level_rng.seed = hash(_level * 31 + 7)
	_base = EnemyBase.new()
	add_child(_base)
	_base.setup(_level_def, _sim, level_rng)

	_cannon = Cannon.new()
	add_child(_cannon)
	_cannon.setup(_sim,
			Tuning.fire_interval(SaveManager.get_upgrade(SaveManager.UPGRADE_FIRE_RATE)),
			Tuning.champion_value(SaveManager.get_upgrade(SaveManager.UPGRADE_CHAMPION)))
	_camera_rig.follow_target = _cannon

	_wall_max = Tuning.wall_hp(SaveManager.get_upgrade(SaveManager.UPGRADE_WALL))
	_wall_hp = _wall_max

	_hud = Hud.new()
	add_child(_hud)
	_hud.setup(_level, _sim)
	_pause = PauseMenu.new()
	add_child(_pause)
	_result = ResultScreen.new()
	add_child(_result)
	_hud.pause_pressed.connect(_pause.toggle)
	_pause.restart_requested.connect(_restart)
	_result.continue_pressed.connect(_restart)

	GameEvents.wall_hp_changed.emit(_wall_hp, _wall_max)
	GameEvents.base_hp_changed.emit(_base.hp, _base.max_hp)
	GameEvents.level_started.emit(_level)


func _physics_process(delta: float) -> void:
	if _state != State.PLAYING:
		return
	var dt := minf(delta, Tuning.MAX_FRAME_DT)
	_time += dt

	_cannon.tick(dt)
	for i in _gates.size():
		var gate := _gates[i]
		gate.tick(dt)
		_sim.set_gate_span(i, gate.span_x0(), gate.span_x1())
	_base.tick(dt)

	_sim.step(dt, _time)
	_apply_step_results()
	_renderer.update_from_sim()

	_crowd_timer -= dt
	if _crowd_timer <= 0.0:
		_crowd_timer = CROWD_REFRESH
		_hud.set_crowd(_sim.f_count)

	if _base.hp <= 0:
		_finish(true)
	elif _wall_hp <= 0:
		_finish(false)


func _apply_step_results() -> void:
	for g in _sim.g_count:
		var hits: int = _sim.g_hits[g]
		if hits > 0:
			_gates[g].flash()
			GameEvents.gate_triggered.emit(g, hits)

	for b in _sim.burst_count:
		_fx.burst(_sim.burst_x[b], _sim.burst_z[b], _sim.burst_team[b])

	if _sim.base_damage > 0:
		_base.apply_damage(_sim.base_damage)
		GameEvents.base_hit.emit(_sim.base_damage)
		GameEvents.base_hp_changed.emit(_base.hp, _base.max_hp)
		GameEvents.screen_shake_requested.emit(SHAKE_BASE_HIT)

	if _sim.wall_damage > 0:
		_wall_hp = maxi(0, _wall_hp - _sim.wall_damage)
		GameEvents.wall_hit.emit(_sim.wall_damage)
		GameEvents.wall_hp_changed.emit(_wall_hp, _wall_max)
		GameEvents.screen_shake_requested.emit(SHAKE_WALL_HIT)
		Haptics.pulse(HAPTIC_WALL_MS)


func _finish(won: bool) -> void:
	_state = State.WON if won else State.LOST
	_cannon.enabled = false
	_pause.enabled = false
	var coins := Tuning.coins_for_win(_level, _wall_hp) if won \
			else Tuning.coins_for_loss(_level, _base.damage_fraction())
	SaveManager.add_coins(coins)
	if won:
		SaveManager.level = _level + 1
		GameEvents.screen_shake_requested.emit(SHAKE_WIN)
	SaveManager.save_game()

	var stats := {
		"level": _level,
		"units_sent": _cannon.shots,
		"peak_crowd": _sim.peak_friendlies,
		"raiders_crushed": _sim.kills,
		"coins_earned": coins,
	}
	GameEvents.level_finished.emit(won, stats)
	_result.show_result(won, stats)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

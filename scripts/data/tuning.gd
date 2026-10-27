class_name Tuning
extends RefCounted
## Every gameplay number lives here (CLAUDE.md §3, §9). Formulas from the spec
## are static functions so tests and the level generator share one source.

# --- World layout (metres; the road runs along -Z away from the camera) ---
const ROAD_WIDTH: float = 8.0
const ROAD_HALF_WIDTH: float = ROAD_WIDTH * 0.5
const ROAD_NEAR_Z: float = 3.5
const ROAD_FAR_Z: float = -60.5
const CANNON_Z: float = 0.0
const MUZZLE_Z: float = -1.6
const WALL_Z: float = -0.9
const BASE_Z: float = -55.0
const BASE_FRONT_Z: float = -52.5
const ENEMY_SPAWN_Z: float = -52.0
const ENEMY_SPAWN_HALF_WIDTH: float = 2.6

# --- Camera ---
const CAMERA_PITCH_DEG: float = 56.0
const CAMERA_VFOV_DEG: float = 50.0          ## vertical FOV at the 9:16 reference aspect
const CAMERA_REF_ASPECT: float = 9.0 / 16.0
const CAMERA_VIEW_NEAR_Z: float = 3.8        ## ground z at the bottom screen edge
const CAMERA_VIEW_FAR_Z: float = -63.0       ## ground z at the top screen edge
const CAMERA_FOLLOW_LERP: float = 0.1        ## per 60 Hz frame
const CAMERA_FOLLOW_AMOUNT: float = 0.6      ## fraction of cannon X the camera tracks
const SHAKE_DECAY: float = 1.8
const SHAKE_MAX_OFFSET: float = 0.35

# --- Lighting ---
const SUN_PITCH_DEG: float = -50.0
const SUN_YAW_DEG: float = -135.0            ## light comes from the upper-left of the screen

# --- Simulation ---
const MAX_FRAME_DT: float = 1.0 / 30.0
const MAX_FRIENDLIES: int = 1500
const MAX_ENEMIES: int = 700
const MAX_CHAMPIONS_DRAWN: int = 64
const MAX_BRUTES_DRAWN: int = 256

# --- Cannon & controls ---
const DRAG_SENSITIVITY: float = 1.15         ## road widths moved per screen width dragged
const CANNON_KEY_SPEED: float = 10.0
const CANNON_FOLLOW_RATE: float = 18.0
const CANNON_MAX_X: float = ROAD_HALF_WIDTH - 0.6
const MUZZLE_JITTER_X: float = 0.12

# --- Friendly units ---
const SOLDIER_SPEED: float = 7.0
const SOLDIER_RADIUS: float = 0.24
const SOLDIER_SPREAD: float = 0.9            ## max initial lateral speed
const LATERAL_DAMP: float = 2.5
const STEER_GAIN: float = 1.2
const STEER_MAX_SPEED: float = 3.0
const STEER_RATE: float = 4.0
const STEER_AFTER_GATES_MARGIN: float = 1.5
const STEER_START_Z_NO_GATES: float = -12.0

const CHAMPION_EVERY: int = 26
const CHAMPION_BASE_VALUE: int = 6
const CHAMPION_VALUE_PER_UPGRADE: int = 3
const CHAMPION_SPEED: float = 6.0
const CHAMPION_RADIUS: float = 0.42
const CHAMPION_MAX_RADIUS: float = 1.4

# --- Enemy units ---
const GRUNT_RADIUS: float = 0.26
const GRUNT_SPEED_BASE: float = 2.0
const GRUNT_SPEED_PER_LEVEL: float = 0.08
const GRUNT_SPEED_MAX: float = 3.6
const BRUTE_VALUE: int = 5
const BRUTE_RADIUS: float = 0.42
const BRUTE_SPEED_MUL: float = 0.7
const BRUTE_MIN_LEVEL: int = 3
const BRUTE_CHANCE_MIN: float = 0.06
const BRUTE_CHANCE_MAX: float = 0.22
const ENEMY_SWAY_AMP: float = 0.6
const ENEMY_SWAY_FREQ: float = 1.7

# --- Gates ---
const GATE_SPEED_BASE: float = 28.0
const GATE_SPEED_PER_LEVEL: float = 6.0
const GATE_SPEED_MAX: float = 115.0
const GATE_SPEED_TO_WORLD: float = 0.02      ## spec speeds are "lane pixels"; 400 px = 8 m
const GATE_WIDTH_SINGLE: float = 3.2
const GATE_WIDTH_DOUBLE: float = 2.2
const GATE_ROW_Z_NEAR: float = -14.0
const GATE_ROW_Z_FAR: float = -36.0
const GATE_ROW_Z_SINGLE: float = -22.0
const CLONE_SCATTER_X: float = 0.7
const CLONE_SCATTER_Z: float = 0.6
const MAX_GATES: int = 31                    ## one bit each in the per-unit mask

# --- Enemy fort ---
const FORT_SPAWN_JITTER: float = 0.3
const FORT_GROUP_MIN: int = 2
const FORT_GROUP_MAX: int = 7
const FORT_FIRST_SPAWN_DELAY: float = 1.0
const BOSS_HP_MULT: float = 1.6

# --- Upgrades ---
const MAX_UPGRADE_LEVEL: int = 12


static func fort_hp(level: int) -> int:
	return roundi(70.0 + 38.0 * level + 3.0 * level * level)


static func fort_spawn_interval(level: int) -> float:
	return maxf(0.5, 1.5 - 0.07 * level)


static func enemy_speed(level: int) -> float:
	return minf(GRUNT_SPEED_MAX, GRUNT_SPEED_BASE + GRUNT_SPEED_PER_LEVEL * (level - 1))


static func brute_chance(level: int) -> float:
	if level < BRUTE_MIN_LEVEL:
		return 0.0
	return clampf(BRUTE_CHANCE_MIN + 0.02 * (level - BRUTE_MIN_LEVEL), BRUTE_CHANCE_MIN, BRUTE_CHANCE_MAX)


static func gate_rows(level: int) -> int:
	if level <= 2:
		return 1
	if level <= 6:
		return 2
	return 3


static func gate_speed(level: int) -> float:
	return minf(GATE_SPEED_MAX, GATE_SPEED_BASE + GATE_SPEED_PER_LEVEL * level) * GATE_SPEED_TO_WORLD


static func wall_hp(wall_upgrade: int) -> int:
	return 12 + 4 * wall_upgrade


static func fire_interval(fire_upgrade: int) -> float:
	return maxf(0.045, 0.112 - 0.0058 * fire_upgrade)


static func champion_value(champion_upgrade: int) -> int:
	return CHAMPION_BASE_VALUE + CHAMPION_VALUE_PER_UPGRADE * champion_upgrade


static func upgrade_cost(upgrade_level: int) -> int:
	return roundi(25.0 * pow(1.5, upgrade_level))


static func coins_for_win(level: int, wall_hp_remaining: int) -> int:
	return 25 + 8 * level + 2 * wall_hp_remaining


static func coins_for_loss(level: int, damage_fraction: float) -> int:
	return roundi(clampf(damage_fraction, 0.0, 1.0) * (12.0 + 4.0 * level))

class_name LevelDef
extends Resource
## Everything needed to build one level. Hand-tuned levels (M4) are saved as
## levels/level_NNN.tres; beyond those, LevelBuilder generates them.

@export var level: int = 1
@export var is_boss: bool = false
@export var base_hp: int = 100
@export var spawn_interval: float = 1.5
@export var enemy_speed: float = 2.0
@export var brute_chance: float = 0.0
@export var gate_speed: float = 0.7
@export var gates: Array[GateDef] = []

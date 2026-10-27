class_name GateDef
extends Resource
## One moving gate in a level (CLAUDE.md §3.4).

enum Op { MULTIPLY, ADD }

@export var op: Op = Op.MULTIPLY
@export var amount: int = 2
@export var z: float = -20.0
@export var width: float = Tuning.GATE_WIDTH_SINGLE
## The gate's whole panel stays inside [min_x, max_x] and bounces at the edges.
@export var min_x: float = -Tuning.ROAD_HALF_WIDTH
@export var max_x: float = Tuning.ROAD_HALF_WIDTH
@export var start_x: float = 0.0
@export var direction: float = 1.0
@export var speed_mult: float = 1.0


func label_text() -> String:
	if op == Op.MULTIPLY:
		return "×%d" % amount
	return "+%d" % amount

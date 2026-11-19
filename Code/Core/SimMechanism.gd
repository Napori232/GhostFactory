class_name SimMechanism
extends RefCounted
## 鬼能机关：独立装置，不吃阈值、不发脉冲。
## 它做且只做一件事：把鬼晶里的鬼能变成「作用」。
## 有一个插槽；插着有电的鬼晶时持续工作，每 push_period 秒扣 energy_per_push 单位鬼能。
##
## effect 决定它把鬼能变成什么（数据驱动，见 Data/mechanisms/*.json）：
##   push  —— 顶：把力矩打在鬼的脚（压回立正）或身体（推倒）。默认。
##   crank —— 长撬：沿朝向的一条线段同时顶住多只鬼的脚（一根顶杆撑两只）。
##   tune  —— 节拍：把半径内鬼的固有周期改写成 target_period（让不同鬼能相干叠加）。
##   amp   —— 共鸣腔：放大半径内鬼的脉冲振幅。
##   reach —— 传声筒：放大半径内鬼的脉冲射程。
##
## 「改鬼」的三类（tune / amp / reach）不移动任何东西，只改参数；
## 它们是「用新机关改之前的鬼」这条设计线的载体。

var id: int = -1
var type_id: String = ""
var def: Dictionary = {}
var cell: Vector2i = Vector2i.ZERO
var facing: int = 0
var base: Vector2 = Vector2.ZERO

var effect: String = "push"
var crystal_id: int = -1
var push_timer: float = 0.0
var pushing: bool = false

var reach: float = 0.62
var min_reach: float = 0.0
var force: float = 8.0
var lever: float = 0.45
var push_period: float = 2.0
var energy_per_push: float = 1.0
var head_radius: float = 0.22
var push_torque: float = 3.6
var effect_radius: float = 3.0
var amplitude_mult: float = 1.0
var range_mult: float = 1.0
var target_period: float = 0.0
var cost: int = 0


func Configure(id_: int, type_id_: String, d: Dictionary, cell_: Vector2i, facing_: int, base_: Vector2) -> SimMechanism:
	id = id_
	type_id = type_id_
	def = d
	cell = cell_
	facing = facing_
	base = base_
	cost = int(d.get("cost", 0))
	effect = String(d.get("effect", "push"))
	reach = float(d.get("reach", 0.62))
	min_reach = float(d.get("min_reach", 0.0))
	force = float(d.get("force", 8.0))
	lever = float(d.get("lever", 0.45))
	push_period = maxf(0.05, float(d.get("push_period", 2.0)))
	energy_per_push = maxf(0.0, float(d.get("energy_per_push", 1.0)))
	head_radius = float(d.get("head_radius", 0.22))
	effect_radius = float(d.get("effect_radius", 3.0))
	amplitude_mult = maxf(1.0, float(d.get("amplitude_mult", 1.0)))
	range_mult = maxf(1.0, float(d.get("range_mult", 1.0)))
	target_period = maxf(0.0, float(d.get("target_period", 0.0)))
	push_torque = force * lever
	crystal_id = -1
	push_timer = 0.0
	pushing = false
	return self


## 作用方向。
func PushDir() -> Vector2:
	match facing:
		0:
			return Vector2(1, 0)
		1:
			return Vector2(0, 1)
		2:
			return Vector2(-1, 0)
	return Vector2(0, -1)


## 顶杆头部（push 的实际施力点）的世界坐标。
func HeadWorld() -> Vector2:
	return base + PushDir() * reach


## 长撬线段的起点（min_reach 默认 0，即从底座算起）。
func SegmentStart() -> Vector2:
	return base + PushDir() * maxf(0.0, min_reach)


## 长撬线段的终点。
func SegmentEnd() -> Vector2:
	return base + PushDir() * maxf(min_reach + 0.05, reach)


## 点到「长撬线段」的距离；用来判定一根撬杆能同时顶到哪几只鬼的脚。
func SegmentDistance(point: Vector2) -> float:
	var a := SegmentStart()
	var b := SegmentEnd()
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)


## 这台机关会不会把鬼「顶回立正」（push / crank 才吃接触判定）。
func AppliesTorque() -> bool:
	return effect == "push" or effect == "crank"


## 是不是「改鬼参数」的机关（tune / amp / reach）。
func ModifiesGhosts() -> bool:
	return effect == "tune" or effect == "amp" or effect == "reach"


func Export() -> Dictionary:
	return {
		"id": id,
		"type": type_id,
		"cell": [cell.x, cell.y],
		"facing": facing,
		"crystal": crystal_id,
		"push_timer": push_timer,
	}


func Import(data: Dictionary) -> void:
	id = int(data.get("id", id))
	type_id = String(data.get("type", type_id))
	var c: Array = data.get("cell", [cell.x, cell.y])
	cell = Vector2i(int(c[0]), int(c[1]))
	facing = int(data.get("facing", facing))
	crystal_id = int(data.get("crystal", -1))
	push_timer = float(data.get("push_timer", 0.0))

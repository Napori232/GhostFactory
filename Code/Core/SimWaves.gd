class_name SimWaves
extends RefCounted
## 波次推进器。只产出「指令数组」，不直接碰 Sim 的实体——
## 这样波次逻辑可以脱离整个模拟单独测试。
##
## 指令（Array[Dictionary]）：
##   {"op":"wave_start", "index":int}
##   {"op":"spawn", "pos":Vector2, "hp":float, "speed":float}
##   {"op":"wave_clear", "index":int}
##   {"op":"all_clear"}

const PREP := 0
const SPAWNING := 1
const ACTIVE := 2
const DONE := 3

var defs: Array = []
var next_index: int = 0
var state: int = PREP
var prep_timer: float = 0.0
var time_to_wave: float = 0.0
var group: int = 0
var spawned: int = 0
var spawn_timer: float = 0.0
var spawn_radius: float = 8.0


func Configure(wave_defs: Array, radius: float) -> void:
	defs = wave_defs
	spawn_radius = maxf(1.0, radius)
	next_index = 0
	state = DONE if defs.is_empty() else PREP
	prep_timer = 0.0
	time_to_wave = 0.0
	if not defs.is_empty():
		Begin(0)


## 回到第 index 波的准备阶段（失败回溯用）。
func Begin(index: int) -> void:
	next_index = maxi(0, index)
	group = 0
	spawned = 0
	spawn_timer = 0.0
	if next_index >= defs.size():
		state = DONE
		prep_timer = 0.0
		time_to_wave = 0.0
		return
	state = PREP
	prep_timer = float(_wave(next_index).get("prep", 10.0))
	time_to_wave = prep_timer


## 推进一个 tick。alive 为当前场上活着的魅数量。
## bonus 为「鬼屋激增」给每个刷怪组加的数量（越界造物越多，bonus 越大）。
func Step(dt: float, alive: int, out: Array, bonus: int = 0) -> void:
	if state == DONE:
		return

	if state == PREP:
		prep_timer -= dt
		time_to_wave = maxf(0.0, prep_timer)
		if prep_timer <= 0.0:
			out.append({"op": "wave_start", "index": next_index})
			state = SPAWNING
			group = 0
			spawned = 0
			spawn_timer = 0.0
		return

	if state == SPAWNING:
		var groups: Array = _wave(next_index).get("groups", [])
		spawn_timer -= dt
		var guard := 0
		while group < groups.size() and guard < 64:
			guard += 1
			var grp: Dictionary = groups[group]
			var count := maxi(1, int(grp.get("count", 1))) + maxi(0, bonus)
			var interval := maxf(0.02, float(grp.get("interval", 1.0)))
			if spawned >= count:
				group += 1
				spawned = 0
				spawn_timer = 0.0
				continue
			if spawn_timer <= 0.0:
				out.append(_make_spawn(grp, spawned, count))
				spawned += 1
				spawn_timer += interval
				continue
			break
		if group >= groups.size():
			state = ACTIVE
		return

	if state == ACTIVE:
		if alive <= 0:
			out.append({"op": "wave_clear", "index": next_index})
			next_index += 1
			if next_index >= defs.size():
				state = DONE
				time_to_wave = 0.0
				out.append({"op": "all_clear"})
			else:
				state = PREP
				prep_timer = float(_wave(next_index).get("prep", 10.0))
				time_to_wave = prep_timer
		return


func _wave(index: int) -> Dictionary:
	if index < 0 or index >= defs.size():
		return {}
	return defs[index]


## 把一个组的第 i 只怪换算成「刷怪位置 + 属性」。
func _make_spawn(grp: Dictionary, i: int, count: int) -> Dictionary:
	var center_deg := float(grp.get("center_deg", 90.0))
	var arc_deg := float(grp.get("arc_deg", 0.0))
	var angle_deg := center_deg
	if count > 1:
		if arc_deg <= 0.0:
			angle_deg = center_deg
		elif arc_deg >= 359.0:
			angle_deg = 360.0 * float(i) / float(count)
		else:
			angle_deg = center_deg - arc_deg * 0.5 + arc_deg * float(i) / float(count - 1)
	var a := deg_to_rad(angle_deg)
	var radius := float(grp.get("radius", spawn_radius))
	return {
		"op": "spawn",
		"pos": Vector2(cos(a), sin(a)) * radius,
		"hp": float(grp.get("hp", 50.0)),
		"speed": float(grp.get("speed", 0.5)),
		"armor": float(grp.get("armor", 1.0)),
		"boss": bool(grp.get("boss", false)),
	}


## 下一波（准备阶段取待来的那波；战斗中取当前波）。
func NextWave() -> Dictionary:
	if next_index >= 0 and next_index < defs.size():
		return defs[next_index]
	return {}

class_name Behemoth
extends RefCounted
## 「庞然大物」参考解：一台跨 15×15 格、靠传送带 + 装卸臂自持运转的机器。
##
## 它不是关卡里的预置内容，而是**内容上限的证明**：
## 用 Data 里那些各自简单的鬼 / 机关 / 带子 / 臂，按正确的位置拼起来，
## 就能得到一台不需要玩家插手、持续发电、持续清场的装置。
##
## 结构（俯视，y 向下）：
##
##   核心（y=9..13）        一个十字：锚鬼 / 翘脚鬼 ×2 / 守夜钟
##     · 每只鬼的脚边一台机关；一台装卸臂同时照看 5 台
##     · 锚鬼要「长撬 + 顶足」两个支撑点才立正
##     · 节拍机关把守夜钟的 3.2 秒改写成 2.0 → 四只鬼同相叠加
##     · 共鸣腔放大振幅、传声筒拉长射程 → 清场线盖住一大片
##     · 接力鬼站在外圈，被脉冲扫到后再响一次，把场往外推
##
##   产线（x=10 / x=12，y=12..16）
##     · 去程快带：把充能的鬼晶从「鬼屋」送到核心
##     · 回程带：把核心用空的晶送回「鬼屋」重新充
##     · 装卸臂有朝向：只吃正前方的带子，只把空晶放到背后的带子
##
##   鬼屋（y=16..18）
##     · 两只低鸣鬼 + 两台顶足机关：鬼能泵
##     · 一台装卸臂：换泵的晶、卸回程带、把充好的晶送上带
##
## Build() 会先把领地扩到 15×15（代表玩家已经守过好几波），
## 然后把整台机器一次建好；测试与 --dev-behemoth 共用。

static func Build(sim: Sim) -> Dictionary:
	var failed: Array = []
	var built: Array = []
	sim.ExpandTerritory(5)
	sim.economy.budget = maxi(sim.economy.budget, 1200)
	for id in ["anchor", "toll", "waver", "hum", "relay"]:
		sim.economy.Unlock(id)
	for id in ["crank", "tuner", "amp", "reach"]:
		sim.economy.Unlock(id)
	for id in ["belt", "express", "arm"]:
		sim.economy.Unlock(id)
	# 把关卡自带的起手装置拆掉（退款），让机器从干净的领地中心长出来。
	_clear_field(sim)

	# ---- 核心：四只鬼围着一台装卸臂 ----
	_ghost(sim, "anchor", Vector2i(9, 11), 0, built, failed)
	_ghost(sim, "waver", Vector2i(13, 11), 2, built, failed)
	_ghost(sim, "waver", Vector2i(11, 9), 1, built, failed)
	_ghost(sim, "toll", Vector2i(11, 13), 3, built, failed)
	_mech(sim, "pusher", Vector2i(10, 11), 2, built, failed)
	_mech(sim, "pusher", Vector2i(12, 11), 0, built, failed)
	_mech(sim, "pusher", Vector2i(11, 10), 3, built, failed)
	_mech(sim, "pusher", Vector2i(11, 12), 1, built, failed)
	# 锚鬼的第二个支撑点：一根从西边伸过来的长撬
	_mech(sim, "crank", Vector2i(8, 11), 0, built, failed)
	# 核心的一只臂：正前方是去程带，背后是回程带
	_swapper(sim, "arm", Vector2i(11, 11), 2, built, failed)

	# ---- 核心外的三台「改鬼」机关 ----
	_mech(sim, "tuner", Vector2i(12, 9), 0, built, failed)
	_mech(sim, "amp", Vector2i(11, 8), 0, built, failed)
	_mech(sim, "reach", Vector2i(13, 9), 0, built, failed)
	_swapper(sim, "arm", Vector2i(12, 8), 1, built, failed)

	# ---- 两条带子：去程（快带，向北）与回程（带，向南） ----
	for y in range(12, 17):
		_belt(sim, "express", Vector2i(10, y), 3, built, failed)
		_belt(sim, "belt", Vector2i(12, y), 1, built, failed)

	# ---- 鬼屋：两台鬼能泵 ----
	_ghost(sim, "hum", Vector2i(9, 17), 0, built, failed)
	_ghost(sim, "hum", Vector2i(13, 17), 2, built, failed)
	_mech(sim, "pusher", Vector2i(10, 17), 2, built, failed)
	_mech(sim, "pusher", Vector2i(12, 17), 0, built, failed)
	_swapper(sim, "arm", Vector2i(11, 17), 3, built, failed)

	# ---- 接力鬼：把清场区往外推 ----
	_ghost(sim, "relay", Vector2i(16, 11), 0, built, failed)

	# ---- 初始存货：相当于玩家攒下的一批充能晶 ----
	# 核心过道（装卸臂伸手可及，也在鬼的脉冲范围里）
	for cell in [Vector2i(10, 10), Vector2i(12, 10), Vector2i(9, 10), Vector2i(13, 10),
			Vector2i(9, 12), Vector2i(13, 12)]:
		_crystal(sim, "crystal", cell, 5.0, built, failed)
	# 改鬼机关的供料池
	for cell in [Vector2i(11, 7), Vector2i(12, 7), Vector2i(13, 7), Vector2i(10, 8), Vector2i(13, 8)]:
		_crystal(sim, "crystal", cell, 5.0, built, failed)
	# 鬼屋的充电池：两只泵各占一颗，剩下的在池子里被反复充放
	for cell in [Vector2i(11, 16), Vector2i(11, 18), Vector2i(12, 18), Vector2i(9, 16), Vector2i(9, 18)]:
		_crystal(sim, "crystal", cell, 5.0, built, failed)
	return {"built": built.size(), "failed": failed}


## 拆掉场上已有的东西（起手装置），退款，回到空地。
static func _clear_field(sim: Sim) -> void:
	var cells: Array = sim.cells.keys()
	for cell in cells:
		if sim.cells.has(cell):
			sim.RemoveAt(cell)


## 机器当前状态的读数。测试与 dev 场景共用。
static func Report(sim: Sim) -> Dictionary:
	var standing := 0
	var pulses := 0
	var relay_pulses := 0
	for id in sim.ghosts:
		var g: SimGhost = sim.ghosts[id]
		if g.standing:
			standing += 1
		pulses += g.pulse_total
		if g.IsRelay():
			relay_pulses += g.pulse_total
	var energy := 0.0
	var full_crystals := 0
	for id in sim.crystals:
		var c: SimCrystal = sim.crystals[id]
		energy += c.charge
		if c.slotted_in < 0 and c.charge >= 1.0:
			full_crystals += 1
	var powered := 0
	var starving := 0
	var hungry: Array = []
	for id in sim.mechanisms:
		var m: SimMechanism = sim.mechanisms[id]
		if m.pushing:
			powered += 1
		else:
			starving += 1
			hungry.append("%s@%d,%d(%.1f)" % [m.type_id, m.cell.x, m.cell.y, _charge_of(sim, m)])
	var hot := 0
	for v in sim.heat:
		if v >= sim.ClearLine():
			hot += 1
	var belt_items := 0
	for bid in sim.belts:
		belt_items += sim.belts[bid].items.size()
	return {
		"time": sim.time,
		"standing": standing,
		"ghosts": sim.ghosts.size(),
		"pulses": pulses,
		"relay_pulses": relay_pulses,
		"energy": energy,
		"full_crystals": full_crystals,
		"powered": powered,
		"starving": starving,
		"hungry": hungry,
		"hot_cells": hot,
		"belt_items": belt_items,
		"mechs": sim.mechanisms.size(),
		"belt_deliveries": int(sim.stats.get("belt_deliveries", 0)),
		"belt_transfers": int(sim.stats.get("belt_transfers", 0)),
		"loader_swaps": int(sim.stats.get("loader_swaps", 0)),
		"field_peak": sim.field_peak,
		"clear_line": sim.ClearLine(),
		"killed": int(sim.stats.get("killed", 0)),
		"cleared_killed": int(sim.stats.get("cleared_killed", 0)),
		"breaches": sim.breaches,
		"wave": sim.waves.next_index,
	}


static func _charge_of(sim: Sim, m: SimMechanism) -> float:
	if m.crystal_id < 0:
		return 0.0
	var c: SimCrystal = sim.crystals.get(m.crystal_id)
	return c.charge if c != null else 0.0


static func _ghost(sim: Sim, type_id: String, cell: Vector2i, facing: int, built: Array, failed: Array) -> void:
	_try(sim, "ghost", type_id, cell, facing, built, failed)


static func _mech(sim: Sim, type_id: String, cell: Vector2i, facing: int, built: Array, failed: Array) -> void:
	_try(sim, "mechanism", type_id, cell, facing, built, failed)


static func _swapper(sim: Sim, type_id: String, cell: Vector2i, facing: int, built: Array, failed: Array) -> void:
	_try(sim, "swapper", type_id, cell, facing, built, failed)


static func _belt(sim: Sim, type_id: String, cell: Vector2i, facing: int, built: Array, failed: Array) -> void:
	_try(sim, "belt", type_id, cell, facing, built, failed)


static func _crystal(sim: Sim, type_id: String, cell: Vector2i, charge: float, built: Array, failed: Array) -> void:
	var r := sim.Build("crystal", type_id, cell)
	if not bool(r.get("ok", false)):
		failed.append("crystal/%s@%s:%s" % [type_id, str(cell), String(r.get("reason", ""))])
		return
	var id := int(r["id"])
	var c: SimCrystal = sim.crystals.get(id)
	if c != null:
		c.charge = clampf(charge, 0.0, c.capacity)
	built.append("crystal")


static func _try(sim: Sim, kind: String, type_id: String, cell: Vector2i, facing: int, built: Array, failed: Array) -> void:
	var r := sim.Build(kind, type_id, cell, facing)
	if bool(r.get("ok", false)):
		built.append("%s/%s" % [kind, type_id])
	else:
		failed.append("%s/%s@%s:%s" % [kind, type_id, str(cell), String(r.get("reason", ""))])

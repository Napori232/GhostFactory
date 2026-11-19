class_name SimEvents
extends RefCounted
## 模拟层对外广播的事件。
## 视图层只订阅这里，模拟层不认识任何节点——这是「逻辑可独立测试」的关键。

## 一只鬼发出一次脉冲。pos 为世界平面坐标，period/amplitude 供可视化使用。
signal GhostPulse(ghost_id: int, pos: Vector2, amplitude: float, period: float)
signal ResonanceBurst(pos: Vector2, amplitude: float, radius: float)
## 鬼达到阈值状态（立正）。
signal GhostStood(ghost_id: int)
## 鬼失去阈值状态（倒下）。
signal GhostFell(ghost_id: int)
## 一只鬼倒下/倾倒时砸中了邻格的鬼。helps=true 表示砸在对方脚上（帮它立正）。
signal GhostStruck(striker_id: int, target_id: int, pos: Vector2, helps: bool)

## 机关完成一次发力（消耗了 1 单位鬼能）。
signal MechanismPushed(mech_id: int, pos: Vector2)
## 机关插槽内鬼能变化。
signal MechanismEnergyChanged(mech_id: int, units: float)

## 某颗鬼晶的存量变化（充能或放电）。
signal CrystalChanged(crystal_id: int, charge: float)
## 鬼晶被拿在手上。
signal CrystalHeld(crystal_id: int, ok: bool)
## 鬼晶插入机关。
signal CrystalInserted(mech_id: int, crystal_id: int)
## 鬼晶从机关取出。
signal CrystalEjected(mech_id: int, crystal_id: int)
## 搬运手 / 装卸臂完成一次搬运（会抽走 drain 单位鬼能）。
signal SwapperWorked(swapper_id: int, mech_id: int, crystal_id: int)
## 带面把一颗晶送出去（进机关、进另一条带子、或落地）。
signal BeltDelivered(belt_id: int, crystal_id: int)

## 魅出现。
signal EnemySpawned(enemy_id: int, pos: Vector2, hp: float)
## 魅被脉冲伤害（每 tick 可能多次，视图自行节流）。
signal EnemyDamaged(enemy_id: int, hp: float)
## 魅死亡。by_clear=true 表示越过了清场线，直接抹掉。
signal EnemyKilled(enemy_id: int, pos: Vector2, by_clear: bool)
## 魅抵达中央区域。total 为累计抵达数。
signal EnemyBreached(enemy_id: int, total: int)

## 新一波开始。
signal WaveStarted(index: int)
## 一波清空。
signal WaveCleared(index: int)
## 全部波次完成。
signal RunCleared
## 失败（抵达中央满额）。
signal RunFailed(reason: String)

## 建造 / 拆除。
signal Built(kind: String, entity_id: int, cell: Vector2i)
signal Removed(kind: String, entity_id: int)
## 整体挪位（鬼 / 机关 / 传送带 / 搬运装置）。插槽里的鬼晶会跟着一起走。
signal Moved(kind: String, entity_id: int, from_cell: Vector2i, to_cell: Vector2i)
## 领地扩张：新的可放置矩形 + 被合法化的越界造物数量。
signal TerritoryExpanded(rect: Rect2i, annexed: int)
## 一处越界造物被魅拆掉。
signal OutlawRazed(cell: Vector2i, kind: String)
## 教程提示变化。
signal HintChanged(text: String)
## 世界被整体重建（失败回溯 / 读档）。视图收到后应重建全部实体节点。
signal WorldRestored

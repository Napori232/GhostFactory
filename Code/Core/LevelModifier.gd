class_name LevelModifier
extends RefCounted
## 夜规：同一张场地换一组约束重打。
##
## 它只改关卡数据（预算 / 准备时间 / 可用图纸），不改任何规则：
## 改完的字典照样交给 Sim.Setup，所以模拟层完全不知道「夜规」存在。

## 返回应用了 mod 的新关卡字典（深拷贝，不改原数据）。
static func Apply(base: Dictionary, mod: Dictionary) -> Dictionary:
	if mod.is_empty():
		return base
	var level := base.duplicate(true)
	level["budget"] = int(round(float(level.get("budget", 80)) * float(mod.get("budget_mult", 1.0))))

	var prep_mult := float(mod.get("prep_mult", 1.0))
	for wave in level.get("waves", []):
		if wave is Dictionary:
			wave["prep"] = float(wave.get("prep", 10.0)) * prep_mult

	var disabled: Array = mod.get("disable", [])
	if not disabled.is_empty():
		var unlocks: Array = level.get("unlocks", [])
		for id in disabled:
			unlocks.erase(String(id))
		level["unlocks"] = unlocks
		# 奖励也不能把它解锁回来
		for reward in level.get("rewards", []):
			if reward is Dictionary and reward.has("unlock") and disabled.has(String(reward["unlock"])):
				reward.erase("unlock")

	level["active_modifier"] = {
		"id": String(mod.get("id", "")),
		"name": String(mod.get("name", "")),
		"desc": String(mod.get("desc", "")),
	}
	return level

class_name BalanceAudit
extends RefCounted
## 数值审计：把每个关卡、每一波的「威胁」与「玩家手上的预算」算成一张表。
##
## 这不是评分，也不进玩法；它只回答两个问题：
##   1. 这一波的敌人要花多少「有效血量」才清得掉？
##   2. 到这一波开始时，玩家一共拿到过多少预算？
##
## 玩家在 HUD 上看到的「有效 HP」「清空奖励」「预算」和这里用的是同一套口径，
## 所以这张表可以直接拿来对账：预算涨得比威胁慢，玩家就会卡住。

static func Rows() -> Array:
	var rows: Array = []
	for level_id in GameData.LevelIds():
		var id := String(level_id)
		var level := GameData.Level(id)
		if level.is_empty():
			continue
		var base_budget := int(level.get("budget", 0))
		var waves: Array = level.get("waves", [])
		var rewards: Array = level.get("rewards", [])
		var extra := 0
		for i in waves.size():
			var wave: Dictionary = waves[i]
			var count := WaveMath.Count(wave)
			var armored := WaveMath.ArmoredCount(wave)
			var eff_hp := WaveMath.Threat(wave)
			var boss := WaveMath.HasBoss(wave)
			var raw_hp := 0.0
			var fastest := 0.0
			for grp in wave.get("groups", []):
				var c := maxi(1, int(grp.get("count", 1)))
				raw_hp += float(c) * float(grp.get("hp", 50.0))
				fastest = maxf(fastest, float(grp.get("speed", 0.5)))
			var reward := 0
			if i < rewards.size() and rewards[i] is Dictionary:
				reward = int(rewards[i].get("budget", 0))
			rows.append({
				"level": id,
				"wave": i,
				"count": count,
				"hp": raw_hp,
				"eff_hp": eff_hp,
				"armored": armored,
				"boss": boss,
				"fastest": fastest,
				"budget_before": base_budget + extra,
				"reward": reward,
			})
			extra += reward
	return rows


## 一张可以直接贴进日志的对账表。
static func Format() -> String:
	var lines: Array = []
	lines.append("level wave  count   hp   eff_hp  armor boss  budget_before  reward")
	for row in Rows():
		lines.append("%-5s %-4d %-6d %-5d %-7d %-5d %-4s  %-13d  %d" % [
			String(row["level"]), int(row["wave"]) + 1, int(row["count"]),
			int(row["hp"]), int(row["eff_hp"]), int(row["armored"]),
			"Y" if bool(row["boss"]) else "-", int(row["budget_before"]), int(row["reward"]),
		])
	return "\n".join(lines)


## 某个关卡的总预算（初始 + 全部清波奖励）。
static func TotalBudget(level_id: String) -> int:
	var level := GameData.Level(level_id)
	if level.is_empty():
		return 0
	var total := int(level.get("budget", 0))
	for r in level.get("rewards", []):
		if r is Dictionary:
			total += int(r.get("budget", 0))
	return total


## 某一波的有效血量（与 HUD 的「有效 HP」同口径）。
static func WaveThreat(wave: Dictionary, pressure_bonus: int = 0) -> float:
	return WaveMath.Threat(wave, pressure_bonus)

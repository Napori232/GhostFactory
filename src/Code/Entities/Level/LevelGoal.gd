class_name LevelGoal
extends RefCounted

## 关卡目标与三轴星级判定。只做计算，不持有状态；数据来自 LevelData 与 Board 的进度。
## 三轴分数为 0~2 的倍率，交由 StarRating.CalculateStars 按既有阈值换算，不改其公共接口。

## 判断是否已达成交付目标。
## @param level 关卡数据。
## @param delivered 已交付件数。
## @return 达标返回 true。
static func IsGoalReached(level: LevelData, delivered: int) -> bool:
	return delivered >= level.goal_amount

## 取目标完成比例，0~1。
## @param level 关卡数据。
## @param delivered 已交付件数。
## @return 已交付 / 目标数，钳制到 1.0。
static func GetProgress(level: LevelData, delivered: int) -> float:
	return clampf(float(delivered) / float(maxi(level.goal_amount, 1)), 0.0, 1.0)

## 计算结算星级：效率 = 2★ 基准 / 实际耗时；手动 = 手动限额 / 实际交付次数；
## 空间 = 可放置预算 / 实际占用。通关至少 1 星。
## @param level 关卡数据。
## @param elapsed 通关耗时，单位：秒。
## @param manual_count 手动交付次数（拾取与放置不计，D5）。
## @param used_cells 可放置区内已占用格数。
## @return 星级 1~3。
static func CalculateStars(level: LevelData, elapsed: float, manual_count: int, used_cells: int) -> int:
	var thresholds := level.GetStarThresholds()
	var efficiency := clampf(thresholds.two_star_time / maxf(elapsed, 1.0), 0.0, 2.0)
	var manual := clampf(float(thresholds.manual_limit) / float(maxi(manual_count, 1)), 0.0, 2.0)
	var space := clampf(float(thresholds.space_budget) / float(maxi(used_cells, 1)), 0.0, 2.0)
	return maxi(1, StarRating.CalculateStars(efficiency, manual, space))

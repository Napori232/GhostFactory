class_name StarThresholds
extends Resource

## 一关的三轴评分阈值。三轴分数均为 0~1，越大越好；
## 星级由 StarRating.CalculateStars(efficiency, manual, space) 计算。
## 2★ 基准时间取自 Docs/GameDesign.md §13 与 Docs/LevelDesign.md。

## 2★ 基准耗时，单位：秒。三关分别 75 / 100 / 105。
@export_range(1.0, 600.0, 1.0) var two_star_time: float = 75.0
## 3★ 耗时目标，单位：秒；比 2★ 更严格。
@export_range(1.0, 600.0, 1.0) var three_star_time: float = 60.0
## 手动次数上限（只统计交付动作，见 D5）；超出后手动轴为 0。
@export_range(1, 500, 1) var manual_limit: int = 40
## 空间预算参考值，单位：格，等于该关可放置区面积。
@export_range(1, 500, 1) var space_budget: int = 18
## 效率轴达标线，0~1。
@export_range(0.0, 1.0, 0.05) var efficiency_threshold: float = 0.5
## 手动轴达标线，0~1。
@export_range(0.0, 1.0, 0.05) var manual_threshold: float = 0.5
## 空间轴达标线，0~1。
@export_range(0.0, 1.0, 0.05) var space_threshold: float = 0.5

class_name LevelData
extends Resource

## 一关的静态配置。地图、目标、时限、预置设施、可用鬼白名单与三轴阈值都在这里。
## 事实来源：Docs/LevelDesign.md 三关表 + Docs/GameDesign.md §13 系统数值；
## 关卡 2 的目标形态按 docs/CodePlan_GhostFactory.md D4 定稿改为 Spirit。

## 关卡序号，从 1 开始。
@export_range(1, 99, 1) var id: int = 1
## 关卡中文名。
@export var display_name: String = ""
## 地台网格尺寸，单位：格。
@export var grid_size: Vector2i = Vector2i(10, 8)
## 关卡时限，单位：秒。
@export_range(1.0, 600.0, 1.0) var time_limit: float = 90.0
## 目标交付形态 id（FormData.id）。
@export var goal_form: String = "Spirit"
## 目标交付数量，单位：件。
@export_range(1, 999, 1) var goal_amount: int = 30
## 开局赠送鬼能，单位：鬼能。
@export_range(0, 999, 1) var start_spirit: int = 30
## 可放置区，显式列出每一格；区外不可放鬼。
@export var placeable_cells: Array[Vector2i] = []
## 障碍格。
@export var obstacle_cells: Array[Vector2i] = []
## 预置鬼。
@export var preplaced_ghosts: Array[GhostPlacement] = []
## 预置设施（交付口 / 仓库口）。
@export var preplaced_facilities: Array[FacilityPlacement] = []
## 本关可用鬼的 id 白名单。
@export var allowed_ghost_ids: Array[StringName] = []
## 生产专属格：三关统一机制，非空时生产鬼只能放在这些格，其他鬼不得占用。
## 空数组表示本关不限制（留给后续新增关卡），当前三关全部划了生产带。
@export var producer_only_cells: Array[Vector2i] = []
## 三轴评分阈值。
@export var star_thresholds: StarThresholds = null
## 初始相机偏航档位，0~7 对应八个方位；只影响观感。
@export_range(0, 7, 1) var camera_yaw: int = 0
## 初始相机缩放档位，0 / 1 / 2 对应 8 / 12 / 16 格视野；只影响观感。
@export_range(0, 2, 1) var camera_zoom: int = 1

## 判断格子是否落在地台内。
## @param cell 待判断的格坐标。
## @return 越界时返回 false。
func InBounds(cell: Vector2i) -> bool:
	return GridUtil.InBounds(cell, grid_size)

## 判断格子是否属于可放置区。
## @param cell 待判断的格坐标。
## @return 属于可放置区时返回 true。
func IsPlaceable(cell: Vector2i) -> bool:
	return placeable_cells.has(cell)

## 判断格子是否为障碍。
## @param cell 待判断的格坐标。
## @return 是障碍时返回 true。
func IsObstacle(cell: Vector2i) -> bool:
	return obstacle_cells.has(cell)

## 判断格子上是否有预置设施。
## @param cell 待判断的格坐标。
## @return 有设施时返回 true。
func HasFacilityAt(cell: Vector2i) -> bool:
	return GetFacilityAt(cell) != null

## 取指定格上的预置设施。
## @param cell 待查询的格坐标。
## @return 设施定义；没有则返回 null。
func GetFacilityAt(cell: Vector2i) -> FacilityPlacement:
	for facility in preplaced_facilities:
		if facility != null and facility.cell == cell:
			return facility
	return null

## 取本关可用鬼白名单的副本。
## @return 鬼 id 数组，修改返回值不影响本资源。
func GetAllowedGhostIds() -> Array[StringName]:
	return allowed_ghost_ids.duplicate()

## 取三轴阈值；资源未配置时返回一份默认阈值，避免调用方处理 null。
## @return 三轴阈值资源。
func GetStarThresholds() -> StarThresholds:
	if star_thresholds != null:
		return star_thresholds
	return StarThresholds.new()

## 取可放置区面积。
## @return 可放置格数量。
func GetPlaceableCount() -> int:
	return placeable_cells.size()

## 判断某只鬼是否允许在本关放置。
## @param ghost_id 鬼的资源 id。
## @return 在白名单内返回 true。
func IsGhostAllowed(ghost_id: StringName) -> bool:
	return allowed_ghost_ids.has(ghost_id)

## 本关是否划了生产专属区。
## @return 专属区非空时返回 true。
func HasProducerZone() -> bool:
	return not producer_only_cells.is_empty()

## 判断格子是否属于生产专属区。
## @param cell 待判断的格坐标。
## @return 属于专属区时返回 true。
func IsProducerOnly(cell: Vector2i) -> bool:
	return producer_only_cells.has(cell)

## 取生产专属区格子的副本。
## @return 专属格数组，修改返回值不影响本资源。
func GetProducerOnlyCells() -> Array[Vector2i]:
	return producer_only_cells.duplicate()

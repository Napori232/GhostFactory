class_name BoardGrid
extends RefCounted

## 棋盘格子占用表。规则层只认 Vector2i 格坐标，不认识任何 2D 像素或 3D 世界坐标。
## 一格同时只能有一只鬼或一个掉落物堆叠；障碍与预置设施永久占位。

var size: Vector2i = Vector2i.ZERO
var obstacles: Array[Vector2i] = []
var facility_cells: Array[Vector2i] = []
var ghost_cells: Dictionary = {}
var item_cells: Dictionary = {}

## 构造格子占用表。
## @param grid_size 地台尺寸（格）。
## @param obstacle_list 障碍格列表。
## @param facilities 预置设施所在格列表。
func _init(grid_size: Vector2i, obstacle_list: Array[Vector2i], facilities: Array[Vector2i]) -> void:
	size = grid_size
	obstacles = obstacle_list.duplicate()
	facility_cells = facilities.duplicate()

## 判断格子是否完全空着（可放置或可掉落）。
## @param cell 待判断的格坐标。
## @return 在界内、非障碍、非设施、无鬼、无掉落物时返回 true。
func IsFree(cell: Vector2i) -> bool:
	if not GridUtil.InBounds(cell, size):
		return false
	if obstacles.has(cell) or facility_cells.has(cell):
		return false
	if ghost_cells.has(cell) or item_cells.has(cell):
		return false
	return true

## 判断格子能否承接一次掉落（与 IsFree 相同，语义分开便于阅读）。
## @param cell 待判断的格坐标。
## @return 可以掉落时返回 true。
func CanDrop(cell: Vector2i) -> bool:
	return IsFree(cell)

## 取某格四邻中所有空格，顺序固定为 上、右、下、左（Docs/GameDesign.md §5.3）。
## @param cell 中心格。
## @return 可掉落的相邻格列表。
func GetEmptyNeighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for neighbor in GridUtil.Neighbors4(cell):
		if CanDrop(neighbor):
			result.append(neighbor)
	return result

## 登记一只鬼的占位。
## @param cell 落点格。
## @param ghost 鬼实例。
func SetGhost(cell: Vector2i, ghost) -> void:
	ghost_cells[cell] = ghost

## 清除一只鬼的占位。
## @param cell 落点格。
func ClearGhost(cell: Vector2i) -> void:
	ghost_cells.erase(cell)

## 登记一个掉落物。
## @param cell 所在格。
## @param item 掉落物实例。
func SetItem(cell: Vector2i, item) -> void:
	item_cells[cell] = item

## 清除一个掉落物。
## @param cell 所在格。
func ClearItem(cell: Vector2i) -> void:
	item_cells.erase(cell)

## 取某格上的鬼。
## @param cell 待查询的格坐标。
## @return 鬼实例；没有则返回 null。
func GetGhostAt(cell: Vector2i):
	return ghost_cells.get(cell, null)

## 取某格上的掉落物。
## @param cell 待查询的格坐标。
## @return 掉落物实例；没有则返回 null。
func GetItemAt(cell: Vector2i):
	return item_cells.get(cell, null)

## 取全部已被鬼占用的格。
## @return 格坐标数组。
func GetAllGhostCells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in ghost_cells.keys():
		result.append(cell)
	return result

## 取全部有掉落物的格。
## @return 格坐标数组。
func GetAllItemCells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in item_cells.keys():
		result.append(cell)
	return result

## 统计可放置区内已被占用的格数，用于空间轴评分。
## @param level 关卡数据，提供可放置区。
## @return 已占用格数。
func UsedPlaceableCount(level: LevelData) -> int:
	var used := 0
	for cell in level.placeable_cells:
		if ghost_cells.has(cell) or item_cells.has(cell):
			used += 1
	return used

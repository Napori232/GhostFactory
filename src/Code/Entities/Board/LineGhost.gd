extends Node2D

## 连线鬼。线本身是一只小鬼，占据连线经过的所有格子，把物品从上游一格一格搬到下游。
## 这让「线」与「鬼」统一为同一种规则载体：线有造价、有占位、有缓冲、能被推挤。

## 组件分组名，加入后由 BoardGrid 统一收集。
const COMPONENT_GROUP: StringName = &"board_component"

## 连线鬼的本体色。
const BODY_COLOR: Color = Color("#7c5cff")
## 连线鬼的描边色。
const EDGE_COLOR: Color = Color("#9b85ff")
## 线上物品的颜色，按形态区分。
const ITEM_COLORS: Dictionary = {
	"Raw": Color("#d9e2f0"),
	"Processed": Color("#f0a44d"),
	"Garbage": Color("#6b6b78"),
}
## 物品默认颜色。
const DEFAULT_ITEM_COLOR: Color = Color("#f2efff")

## 连线经过的格子（网格坐标），从上游到下游。
@export var path: Array[Vector2i] = []:
	set(value):
		path = GridUtil.ToCellArray(value)
		queue_redraw()

## 上游端口所在格（路径起点）。
@export var source_cell: Vector2i = Vector2i.ZERO
## 下游端口所在格（路径终点）。
@export var target_cell: Vector2i = Vector2i.ZERO
## 该线的造价。
@export var cost: int = 0

var _slots: Array = []
var _slot_order: Array = []

func _ready() -> void:
	add_to_group(COMPONENT_GROUP)
	_slots = []
	for i in path.size():
		_slots.append([])
	queue_redraw()

## 设置路径并重置槽位。
## @param cells 路径格列表，从上游到下游。
func SetPath(cells: Array[Vector2i]) -> void:
	path = cells.duplicate()
	_slots = []
	for i in path.size():
		_slots.append([])
	queue_redraw()

## 取得路径格列表。
## @return 路径格列表。
func GetPath() -> Array[Vector2i]:
	return path.duplicate()

## 取得本线鬼占用的格子。
## @return 占用格列表。
func GetOccupiedCells() -> Array[Vector2i]:
	return path.duplicate()

## 取得本线鬼的本体格。
## @return 占用格列表。
func GetBodyCells() -> Array[Vector2i]:
	return path.duplicate()

## 取得本线鬼的附属格。
## @return 空数组，线鬼没有附属。
func GetAppendageCells() -> Array[Vector2i]:
	return []

## 取得本线鬼的 id。
## @return 固定为 "Line"。
func GetGhostId() -> String:
	return "Line"

## 取得本线鬼的 id（snake_case 别名，供运行时脚本调用）。
## @return 固定为 "Line"。
func get_ghost_id() -> String:
	return "Line"

## 取得本线鬼占用的格子（snake_case 别名，供运行时脚本调用）。
## @return 占用格列表。
func get_occupied_cells() -> Array[Vector2i]:
	return GetOccupiedCells()

## 取得本线鬼的本体格（snake_case 别名，供运行时脚本调用）。
## @return 占用格列表。
func get_body_cells() -> Array[Vector2i]:
	return GetBodyCells()

## 取得本线鬼的附属格（snake_case 别名，供运行时脚本调用）。
## @return 空数组。
func get_appendage_cells() -> Array[Vector2i]:
	return []

## 取得本线鬼的本体色（snake_case 别名，供运行时脚本调用）。
## @return 主色。
func get_body_color() -> Color:
	return BODY_COLOR

## 取得本线鬼的本体色。
## @return 主色。
func GetBodyColor() -> Color:
	return BODY_COLOR

## 尝试在入口接收一个物品。
## @param form 形态 id
## @return 接收成功时返回 true；入口被占用或路径为空时返回 false。
func AcceptItem(form: String) -> bool:
	if _slots.is_empty():
		return false
	var first: Array = _slots[0]
	if not first.is_empty():
		return false
	first.append(form)
	return true

## 推进物品一格。
## @return 到达末端、可以交给下游的形态 id；没有则返回空字符串。
func Advance() -> String:
	if _slots.size() < 2:
		return ""
	# 从末端往前推进，末端腾出后上游依次跟进。
	for i in range(_slots.size() - 1, 0, -1):
		var current: Array = _slots[i]
		if not current.is_empty():
			continue
		var upstream: Array = _slots[i - 1]
		if upstream.is_empty():
			continue
		current.append(upstream.pop_front())
		if upstream.is_empty():
			_slots[i - 1] = upstream
		else:
			_slots[i - 1] = upstream
	var last: Array = _slots[_slots.size() - 1]
	if last.is_empty():
		return ""
	return String(last.pop_front())

## 取得路径上所有物品的形态。
## @return 形态 id 列表。
func GetItems() -> Array:
	var result: Array = []
	for slot in _slots:
		for form in slot:
			result.append(form)
	return result

## 取得线上的物品总数。
## @return 物品数量。
func GetItemCount() -> int:
	return GetItems().size()

## 绘制线鬼本体、路径与线上物品。
func _draw() -> void:
	if path.is_empty():
		return
	var half := GridUtil.HALF_CELL
	for i in path.size():
		var center := GridUtil.CellToWorld(path[i])
		var rect := Rect2(center - Vector2.ONE * half, Vector2.ONE * GridUtil.CELL_SIZE)
		draw_rect(rect, BODY_COLOR, true)
		draw_rect(rect, EDGE_COLOR, false, 1.5)
		# 路径方向用一个小箭头提示。
		if i < path.size() - 1:
			var next_center := GridUtil.CellToWorld(path[i + 1])
			var dir := (next_center - center).normalized()
			draw_line(center - dir * 10.0, center + dir * 10.0, EDGE_COLOR, 2.0)
	# 物品。
	for i in _slots.size():
		var slot: Array = _slots[i]
		if slot.is_empty():
			continue
		var center := GridUtil.CellToWorld(path[i])
		var form := String(slot[0])
		draw_circle(center, half * 0.42, ITEM_COLORS.get(form, DEFAULT_ITEM_COLOR))

## 取得某形态的物品颜色。
## @param form 形态 id
## @return 颜色。
static func GetItemColor(form: String) -> Color:
	return ITEM_COLORS.get(form, DEFAULT_ITEM_COLOR)

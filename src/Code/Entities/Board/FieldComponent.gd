@tool
extends Node2D

## 采集区实例。玩家框定一块范围，采集鬼在其中产出掉落物。
## 挂在 BoardGrid 之下，Inspector 改参数后视口立即重绘。

## 组件分组名，加入后由 BoardGrid 统一收集。
const COMPONENT_GROUP: StringName = &"board_component"

## 采集区填充色。本地常量，暂不进 ExportSettings。
const FILL_COLOR: Color = Color(0.239216, 0.862745, 0.592157, 0.35)

## 采集区边框色。
const FRAME_COLOR: Color = Color(0.55, 0.9, 0.62, 0.9)

## 面积收益指数的默认值。ExportSettings.sim_area_exponent 不存在时使用。
const DEFAULT_AREA_EXPONENT: float = 0.5

## 各格上的掉落物堆叠，键为 "x,y"。
var _items: Dictionary = {}

## 采集区覆盖的格（相对 origin_cell 的偏移）。
@export var shape: Array[Vector2i] = []:
	set(value):
		shape = GridUtil.ToCellArray(value)
		queue_redraw()

## 采集区原点格。
@export var origin_cell: Vector2i = Vector2i.ZERO:
	set(value):
		origin_cell = value
		_align_to_cell()

## 掉落的形态 id。
@export var drops: String = "Raw":
	set(value):
		drops = value
		queue_redraw()

## 掉落间隔（秒）。
@export_range(0.1, 10.0, 0.1) var interval: float = 1.0:
	set(value):
		interval = value
		queue_redraw()

## 垃圾率 0~1。
@export_range(0.0, 1.0, 0.01) var garbage_rate: float = 0.4:
	set(value):
		garbage_rate = value
		queue_redraw()

## 采集基率。
@export_range(0.0, 10.0, 0.05) var base_rate: float = 0.6:
	set(value):
		base_rate = value
		queue_redraw()

## 是否被选中。
@export var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

## 选中高亮描边色。
const HIGHLIGHT_COLOR: Color = Color(1.0, 0.9, 0.35, 0.9)

func _ready() -> void:
	add_to_group(COMPONENT_GROUP)
	_align_to_cell()
	queue_redraw()

## 把节点位置对齐到原点格中心。
func _align_to_cell() -> void:
	position = GridUtil.CellToWorld(origin_cell)
	queue_redraw()

## 绘制采集区覆盖范围、面积数字与掉落形态标记。
func _draw() -> void:
	var cells := GetCells()
	for c in cells:
		var rect := _cell_rect(c)
		draw_rect(rect, FILL_COLOR, true)
		draw_rect(rect, FRAME_COLOR, false, 1.5)
	if selected:
		for c in cells:
			draw_rect(_cell_rect(c).grow(-2.0), HIGHLIGHT_COLOR, false, 2.0)
	_draw_label()

## 计算某个占位格相对原点的矩形。
## @param offset 相对 origin_cell 的格偏移。
## @return 以原点格中心为参照的矩形。
func _cell_rect(offset: Vector2i) -> Rect2:
	var center := Vector2(float(offset.x), float(offset.y)) * GridUtil.CELL_SIZE
	return Rect2(center - Vector2.ONE * GridUtil.HALF_CELL, Vector2.ONE * GridUtil.CELL_SIZE)

## 绘制面积数字与掉落形态首字母标记。
func _draw_label() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var mark := drops.substr(0, 1).to_upper() if drops != "" else "*"
	var text := "%d格 %s" % [GetArea(), mark]
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var pos := Vector2(-size.x * 0.5, GridUtil.CELL_SIZE * 0.68)
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.92, 1.0, 0.94, 0.95))

## 取得采集区覆盖的格子（相对 origin_cell 的偏移）。
## shape 为空时退化为单格 (0,0)，保证组件永远有可见占位。
## @return 覆盖格的偏移列表。
func GetShapeCells() -> Array[Vector2i]:
	if shape.is_empty():
		var fallback: Array[Vector2i] = []
		fallback.append(Vector2i.ZERO)
		return fallback
	return shape.duplicate()

## 取得采集区覆盖的全部格子（网格坐标）。
## @return 网格坐标列表。
func GetCells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c in GetShapeCells():
		result.append(c + origin_cell)
	return result

## 取得本组件占用的格子（网格坐标系别名）。
## @return 网格坐标列表。
func GetWorldCells() -> Array[Vector2i]:
	return GetCells()

## 取得采集区面积。
## @return 覆盖的格数。
func GetArea() -> int:
	return GetShapeCells().size()

## 取得采集区的掉落速率。
## 速率 = base_rate × 面积^指数。指数优先读 ExportSettings.sim_area_exponent，缺失时用 0.5。
## @return 每秒产出的掉落物数量。
func GetDropRate() -> float:
	return base_rate * pow(float(GetArea()), GetAreaExponent())

## 取得面积收益的指数。
## 优先读 ExportSettings.sim_area_exponent；该字段可能尚未存在，缺失时用默认值 0.5。
## @return 指数值，默认 0.5。
func GetAreaExponent() -> float:
	var raw: Variant = ExportSettings.get("sim_area_exponent")
	if raw is float or raw is int:
		return float(raw)
	return DEFAULT_AREA_EXPONENT

## 取得产出的形态 id。
## @return 掉落形态 id。
func GetDrops() -> String:
	return drops

## 设置原点格并重新对齐。
## @param new_cell 新的网格坐标。
func SetCell(new_cell: Vector2i) -> void:
	origin_cell = new_cell

## 向指定格子投放一个掉落物。
## @param cell 目标格子，必须在本采集区覆盖范围内。
## @param form 形态 id
## @return 投放成功时返回 true。
func add_item(cell: Vector2i, form: String) -> bool:
	if not GetCells().has(cell):
		return false
	var key := _cell_key(cell)
	var stack: Array = _items.get(key, [])
	stack.append(form)
	_items[key] = stack
	queue_redraw()
	return true

## 从指定格子取出一个掉落物。
## @param cell 目标格子。
## @return 形态 id；该格没有物品时返回空字符串。
func take_item(cell: Vector2i) -> String:
	var key := _cell_key(cell)
	var stack: Array = _items.get(key, [])
	if stack.is_empty():
		return ""
	var form: String = stack.pop_back()
	if stack.is_empty():
		_items.erase(key)
	else:
		_items[key] = stack
	queue_redraw()
	return form

## 取得指定格子的掉落物数量。
## @param cell 目标格子。
## @return 物品数量。
func get_item_count(cell: Vector2i) -> int:
	var stack: Array = _items.get(_cell_key(cell), [])
	return stack.size()

## 生成格子键。
## @param cell 格子坐标。
## @return 字符串键。
func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

## 取得覆盖格子（snake_case 别名，供运行时脚本调用）。
## @return 本组件覆盖的网格坐标列表。
func get_cells() -> Array[Vector2i]:
	return GetCells()

## 取得采集区面积（snake_case 别名，供运行时脚本调用）。
## @return 覆盖的格数。
func get_area() -> int:
	return GetArea()

## 取得掉落速率（snake_case 别名，供运行时脚本调用）。
## @return 每秒产出的掉落物数量。
func get_drop_rate() -> float:
	return GetDropRate()

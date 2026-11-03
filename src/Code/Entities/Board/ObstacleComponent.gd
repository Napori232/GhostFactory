@tool
extends Node2D

## 障碍物。关卡地图上的不可放置地形。
## 挂在 BoardGrid 之下，Inspector 改参数后视口立即重绘。

## 组件分组名，加入后由 BoardGrid 统一收集。
const COMPONENT_GROUP: StringName = &"board_component"

## 障碍物填充色，冷调深灰蓝，与深靛蓝背景协调。
const FILL_COLOR: Color = Color(0.145, 0.169, 0.239, 0.95)

## 障碍物描边色，冷调石板灰。
const FRAME_COLOR: Color = Color(0.353, 0.400, 0.529, 0.95)

## 障碍覆盖的格（相对 origin_cell 的偏移）。
@export var shape: Array[Vector2i] = []:
	set(value):
		shape = GridUtil.ToCellArray(value)
		queue_redraw()

## 障碍原点格。
@export var origin_cell: Vector2i = Vector2i.ZERO:
	set(value):
		origin_cell = value
		_align_to_cell()

## 障碍类型（自由文本，如 "wall"、"machine"）。
@export var kind: String = "wall":
	set(value):
		kind = value
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

## 绘制深灰色不规则块与类型标签。
func _draw() -> void:
	for c in GetShapeCells():
		var rect := _cell_rect(c)
		draw_rect(rect, FILL_COLOR, true)
		draw_rect(rect, FRAME_COLOR, false, 1.5)
		draw_line(rect.position, rect.end, FRAME_COLOR, 1.0)
	if selected:
		for c in GetShapeCells():
			draw_rect(_cell_rect(c).grow(-2.0), HIGHLIGHT_COLOR, false, 2.0)
	_draw_label()

## 计算某个占位格相对原点的矩形。
## @param offset 相对 origin_cell 的格偏移。
## @return 以原点格中心为参照的矩形。
func _cell_rect(offset: Vector2i) -> Rect2:
	var center := Vector2(float(offset.x), float(offset.y)) * GridUtil.CELL_SIZE
	return Rect2(center - Vector2.ONE * GridUtil.HALF_CELL, Vector2.ONE * GridUtil.CELL_SIZE)

## 绘制类型标签。
func _draw_label() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text := kind if kind != "" else "障碍"
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var pos := Vector2(-size.x * 0.5, GridUtil.CELL_SIZE * 0.62)
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.667, 0.706, 0.800, 0.95))

## 取得障碍覆盖的格子（相对 origin_cell 的偏移）。
## shape 为空时退化为单格 (0,0)，保证组件永远有可见占位。
## @return 覆盖格的偏移列表。
func GetShapeCells() -> Array[Vector2i]:
	if shape.is_empty():
		var fallback: Array[Vector2i] = []
		fallback.append(Vector2i.ZERO)
		return fallback
	return shape.duplicate()

## 取得障碍覆盖的全部格子（网格坐标）。
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

## 取得本组件占用的格子（供 BoardGrid 统一收集）。
## @return 网格坐标列表。
func GetOccupiedCells() -> Array[Vector2i]:
	return GetCells()

## 取得障碍类型。
## @return 类型字符串。
func GetKind() -> String:
	return kind

## 设置原点格并重新对齐。
## @param new_cell 新的网格坐标。
func SetCell(new_cell: Vector2i) -> void:
	origin_cell = new_cell

@tool
extends Node2D

## 供品口。关卡预置的接收点，只能接收指定形态的供品，接收方向决定从哪侧收线。
## 挂在 BoardGrid 之下，Inspector 改参数后视口立即重绘。

## 组件分组名，加入后由 BoardGrid 统一收集。
const COMPONENT_GROUP: StringName = &"board_component"

## 供品口本体色。本地常量，暂不进 ExportSettings。
const BODY_COLOR: Color = Color(0.95, 0.78, 0.35)

## 供品口外框色。
const FRAME_COLOR: Color = Color(0.35, 0.28, 0.12)

## 接受的形态 id。
@export var accepts: String = "Raw":
	set(value):
		accepts = value
		queue_redraw()

## 每交付一份计多少分。
@export var score: int = 1:
	set(value):
		score = value
		queue_redraw()

## 网格位置（供品口本体原点格）。
@export var cell: Vector2i = Vector2i.ZERO:
	set(value):
		cell = value
		_align_to_cell()

## 接收方向（线从哪一侧进来）：0=东 1=南 2=西 3=北。
@export_enum("东:0", "南:1", "西:2", "北:3") var facing: int = 0:
	set(value):
		facing = value
		queue_redraw()

## 该供品口的占位形状（相对 cell 的格偏移）。
@export var footprint: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]:
	set(value):
		footprint = GridUtil.ToCellArray(value)
		queue_redraw()

## 是否被选中。
@export var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

## 选中高亮描边色。
const HIGHLIGHT_COLOR: Color = Color(1.0, 0.9, 0.35, 0.9)

## 已交付数量。运行时累加，不参与 Inspector 保存。
var delivered_count: int = 0

func _ready() -> void:
	add_to_group(COMPONENT_GROUP)
	_align_to_cell()
	queue_redraw()

## 把节点位置对齐到本体原点格中心。
func _align_to_cell() -> void:
	position = GridUtil.CellToWorld(cell)
	queue_redraw()

## 绘制供品口梯形、接收方向箭头、形态标签与累计分数。
func _draw() -> void:
	var rect := _body_rect()
	draw_rect(rect, BODY_COLOR, true)
	draw_rect(rect, FRAME_COLOR, false, 2.0)

	var dir := GetFacingVector()
	var arrow_center := Vector2(float(dir.x), float(dir.y)) * GridUtil.CELL_SIZE * 0.2
	var tip := arrow_center + Vector2(float(dir.x), float(dir.y)) * GridUtil.CELL_SIZE * 0.2
	var perp := Vector2(float(-dir.y), float(dir.x)) * GridUtil.CELL_SIZE * 0.11
	draw_colored_polygon(PackedVector2Array([tip, arrow_center + perp, arrow_center - perp]), FRAME_COLOR)

	if selected:
		draw_rect(rect.grow(-2.0), HIGHLIGHT_COLOR, false, 2.5)

	_draw_label()

## 计算供品口本体矩形。
## @return 以本体原点格中心为中心的矩形。
func _body_rect() -> Rect2:
	var extent := GridUtil.HALF_CELL * 0.8
	return Rect2(-Vector2.ONE * extent, Vector2.ONE * extent * 2.0)

## 绘制形态与累计分数标签。
func _draw_label() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text := accepts if accepts != "" else "任意"
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var pos := Vector2(-size.x * 0.5, GridUtil.CELL_SIZE * 0.62)
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 0.16, 0.05, 0.95))

	var count_text := "%d×%d" % [delivered_count, score]
	var count_size := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var count_pos := Vector2(-count_size.x * 0.5, GridUtil.CELL_SIZE * 0.62 + 14.0)
	draw_string(font, count_pos + Vector2(1, 1), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.6))
	draw_string(font, count_pos, count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 0.16, 0.05, 0.95))

## 取得占位形状（相对 cell 的格偏移）。
## footprint 为空时退化为单格 (0,0)，保证组件永远有可见占位。
## @return 覆盖格的偏移列表。
func GetFootprintCells() -> Array[Vector2i]:
	if footprint.is_empty():
		var fallback: Array[Vector2i] = []
		fallback.append(Vector2i.ZERO)
		return fallback
	return footprint.duplicate()

## 取得本组件占用的格子（网格坐标）。
## @return 网格坐标列表。
func GetOccupiedCells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c in GetFootprintCells():
		result.append(c + cell)
	return result

## 取得本组件占用的格子（网格坐标系别名）。
## @return 网格坐标列表。
func GetWorldCells() -> Array[Vector2i]:
	return GetOccupiedCells()

## 取得接受的形态 id。
## @return 接受的形态 id；空字符串表示任意。
func GetAcceptedForm() -> String:
	return accepts

## 取得累计交付数。
## @return 已交付的份数。
func GetDeliveredCount() -> int:
	return delivered_count

## 累加交付数。
## @param n 增加的份数，默认 1。
func AddDelivered(n: int = 1) -> void:
	delivered_count += n
	queue_redraw()

## 取得接收方向。
## @return 0=东 1=南 2=西 3=北。
func GetFacing() -> int:
	return facing % 4

## 取得接收方向对应的网格向量。
## @return 0=东(1,0) 1=南(0,1) 2=西(-1,0) 3=北(0,-1)。
func GetFacingVector() -> Vector2i:
	match facing % 4:
		0:
			return Vector2i(1, 0)
		1:
			return Vector2i(0, 1)
		2:
			return Vector2i(-1, 0)
		_:
			return Vector2i(0, -1)

## 设置所在格子并重新对齐。
## @param new_cell 新的网格坐标。
func SetCell(new_cell: Vector2i) -> void:
	cell = new_cell

## 累加交付数（snake_case 别名，供运行时脚本调用）。
## @param n 增加的份数。
func add_delivered(n: int = 1) -> void:
	AddDelivered(n)

## 取得累计交付数（snake_case 别名，供运行时脚本调用）。
## @return 已交付的份数。
func get_delivered_count() -> int:
	return GetDeliveredCount()

## 取得接受的形态（snake_case 别名，供运行时脚本调用）。
## @return 接受的形态 id。
func get_accepted_form() -> String:
	return GetAcceptedForm()

## 取得占位格子（snake_case 别名，供运行时脚本调用）。
## @return 本组件占用的网格坐标列表。
func get_occupied_cells() -> Array[Vector2i]:
	return GetOccupiedCells()

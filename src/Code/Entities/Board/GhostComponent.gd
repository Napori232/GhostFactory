@tool
extends Node2D

## 一只鬼在地图上的实例。挂在 BoardGrid 之下，用 Inspector 里的参数描述它的占位形状与朝向。
## 鬼数据（GhostData）可能尚未存在，此时退化为「单格 + 默认色 + 占位文字」，不阻塞编辑器使用。

## 组件分组名，加入后由 BoardGrid 统一收集。
const COMPONENT_GROUP: StringName = &"board_component"

## 鬼数据目录。GhostData 资源可能还没建好，缺失时走降级显示。
const GHOST_DATA_DIRECTORY: String = "res://Data/Ghosts"

## 降级时使用的默认本体色。
const DEFAULT_BODY_COLOR: Color = Color(0.6, 0.6, 0.7)

## 附属占位（舌头、吊绳）的默认色。
const APPENDAGE_COLOR: Color = Color(0.95, 0.55, 0.45)

## 选中高亮描边色。
const HIGHLIGHT_COLOR: Color = Color(1.0, 0.9, 0.35, 0.9)

## 手动鬼提示圈的呼吸周期（秒）。
const PULSE_PERIOD: float = 1.2

## 该鬼的占位形状（相对本体原点的格偏移）。留空则用 GhostData.footprint。
@export var footprint: Array[Vector2i] = []:
	set(value):
		footprint = GridUtil.ToCellArray(value)
		queue_redraw()

## 附属占位（舌头、吊绳等）。留空则用 GhostData.appendages。
@export var appendages: Array[Vector2i] = []:
	set(value):
		appendages = GridUtil.ToCellArray(value)
		queue_redraw()

## 本体原点在网格中的位置。
@export var cell: Vector2i = Vector2i.ZERO:
	set(value):
		cell = value
		_align_to_cell()

## 朝向：0=东 1=南 2=西 3=北。
@export_enum("东:0", "南:1", "西:2", "北:3") var facing: int = 0:
	set(value):
		facing = value
		queue_redraw()

## 鬼的数据 id，对应 Data/Ghosts/<id>.tres。
@export var ghost_id: String = "LongTongue":
	set(value):
		ghost_id = value
		_ghost_data = null
		queue_redraw()

## 手动鬼是否已触发（吊死鬼挂绳状态）。
@export var manual_activated: bool = false:
	set(value):
		manual_activated = value
		queue_redraw()

## 该鬼是否被选中。
@export var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _ghost_data: Resource = null
var _pulse_time: float = 0.0

func _ready() -> void:
	add_to_group(COMPONENT_GROUP)
	_align_to_cell()
	queue_redraw()

## 推进呼吸动画。手动鬼未激活时用 modulate 做提示。
func _process(delta: float) -> void:
	if not (IsManual() and not manual_activated):
		if modulate.a < 1.0:
			modulate = Color.WHITE
		return
	_pulse_time += delta
	var wave := 0.5 + 0.5 * sin(TAU * _pulse_time / PULSE_PERIOD)
	modulate = Color(1.0, 1.0, 1.0, lerpf(0.55, 1.0, wave))
	queue_redraw()

## 把节点位置对齐到本体原点的格子中心。
func _align_to_cell() -> void:
	position = GridUtil.CellToWorld(cell)
	queue_redraw()

## 绘制占位方块、中心符号与标签。
func _draw() -> void:
	var body_offsets := GetBodyOffsets()
	var appendage_offsets := GetAppendageOffsets()
	var body_color := GetBodyColor()
	var edge := body_color.lightened(0.35)

	for c in body_offsets:
		_draw_cell(c, body_color, edge)
	for c in appendage_offsets:
		_draw_cell(c, APPENDAGE_COLOR, APPENDAGE_COLOR.lightened(0.3))

	draw_circle(Vector2.ZERO, GridUtil.CELL_SIZE * 0.22, edge)

	if selected:
		for c in body_offsets:
			draw_rect(_cell_rect(c).grow(-2.0), HIGHLIGHT_COLOR, false, 2.5)

	if IsManual() and not manual_activated:
		var wave := 0.5 + 0.5 * sin(TAU * _pulse_time / PULSE_PERIOD)
		draw_arc(Vector2.ZERO, GridUtil.CELL_SIZE * lerpf(0.42, 0.58, wave), 0.0, TAU, 32, HIGHLIGHT_COLOR, 2.0)

	_draw_label()

## 画一个占位格。
## @param offset 相对本体原点的格偏移。
## @param fill 填充色。
## @param edge 描边色。
func _draw_cell(offset: Vector2i, fill: Color, edge: Color) -> void:
	var rect := _cell_rect(offset)
	draw_rect(rect, fill, true)
	draw_rect(rect, edge, false, 1.5)

## 计算某个占位格相对本体的矩形。
## @param offset 相对本体原点的格偏移。
## @return 以本体原点为中心的矩形。
func _cell_rect(offset: Vector2i) -> Rect2:
	var center := Vector2(float(offset.x), float(offset.y)) * GridUtil.CELL_SIZE
	return Rect2(center - Vector2.ONE * GridUtil.HALF_CELL, Vector2.ONE * GridUtil.CELL_SIZE)

## 绘制鬼 id 占位文字，缺美术资源时也能看懂。
func _draw_label() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text := ghost_id if ghost_id != "" else "(未命名)"
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var pos := Vector2(-size.x * 0.5, GridUtil.CELL_SIZE * 0.62)
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.95, 0.98, 0.9))

## 取得本组件占用的全部格子（网格坐标）。
## @return 本体与附属占位平移到 cell 之后的格子列表。
func GetOccupiedCells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c in GetBodyCells():
		result.append(c)
	for c in GetAppendageCells():
		result.append(c)
	return result

## 取得本组件占用的全部格子（网格坐标系）。
## @return 本组件占用的格子列表。
func GetWorldCells() -> Array[Vector2i]:
	return GetOccupiedCells()

## 取得本体占位在网格中的格子。
## @return 本体格偏移平移到 cell 之后的格子列表。
func GetBodyCells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c in GetBodyOffsets():
		result.append(c + cell)
	return result

## 取得附属占位在网格中的格子。
## @return 附属格偏移平移到 cell 之后的格子列表。
func GetAppendageCells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c in GetAppendageOffsets():
		result.append(c + cell)
	return result

## 取得本体占位的相对偏移。
## @return 相对本体原点的格偏移列表；无配置且无鬼数据时返回单格 (0,0)。
func GetBodyOffsets() -> Array[Vector2i]:
	if not footprint.is_empty():
		return footprint.duplicate()
	var data := GetGhostData()
	if data != null:
		var raw: Variant = data.get("footprint")
		if raw is Array:
			var converted: Array[Vector2i] = []
			for item in raw:
				converted.append(_to_cell(item))
			if not converted.is_empty():
				return converted
	return _default_footprint()

## 取得附属占位的相对偏移。
## @return 相对本体原点的格偏移列表；无配置且无鬼数据时返回空数组。
func GetAppendageOffsets() -> Array[Vector2i]:
	if not appendages.is_empty():
		return appendages.duplicate()
	var data := GetGhostData()
	if data != null:
		var raw: Variant = data.get("appendages")
		if raw is Array:
			var converted: Array[Vector2i] = []
			for item in raw:
				converted.append(_to_cell(item))
			if not converted.is_empty():
				return converted
	return []

## 取得鬼数据资源。
## @return 加载到的鬼数据；资源不存在或加载失败时返回 null。
func GetGhostData() -> Resource:
	if _ghost_data != null:
		return _ghost_data
	var path := "%s/%s.tres" % [GHOST_DATA_DIRECTORY, ghost_id]
	if ghost_id == "" or not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	if res == null:
		return null
	_ghost_data = res
	return _ghost_data

## 取得鬼 id。
## @return 当前配置的鬼数据 id。
func GetGhostId() -> String:
	return ghost_id

## 取得本体色。
## @return 鬼数据的 body_color；无鬼数据时返回默认色。
func GetBodyColor() -> Color:
	var data := GetGhostData()
	if data != null:
		var raw: Variant = data.get("body_color")
		if raw is Color:
			return raw
	return DEFAULT_BODY_COLOR

## 取得朝向对应的网格向量。
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

## 取得朝向对应的弧度角。
## @return 以弧度表示的角度，东为 0，顺时针递增。
func GetFacingAngle() -> float:
	return float(facing % 4) * PI * 0.5

## 是否为手动鬼。
## @return 鬼数据标记为手动鬼时返回 true。
func IsManual() -> bool:
	var data := GetGhostData()
	if data != null:
		var raw: Variant = data.get("manual")
		if raw is bool:
			return raw
	return false

## 切换手动鬼的开关状态。
func ToggleManual() -> void:
	manual_activated = not manual_activated
	queue_redraw()

## 设置本体原点在网格中的位置并重新对齐。
## @param new_cell 新的网格坐标。
func SetCell(new_cell: Vector2i) -> void:
	cell = new_cell

## 降级用的默认本体占位。
## @return 只含原点的单格数组。
func _default_footprint() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.append(Vector2i.ZERO)
	return result

## 把任意数据转换成 Vector2i。
## @param value 原始值，通常是 Vector2i。
## @return 转换后的格子坐标；无法转换时返回 (0,0)。
func _to_cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	return Vector2i.ZERO

## 取得鬼 id（snake_case 别名，供运行时脚本调用）。
## @return 当前配置的鬼数据 id。
func get_ghost_id() -> String:
	return GetGhostId()

## 取得本体占位格子（snake_case 别名，供运行时脚本调用）。
## @return 本体占位的网格坐标列表。
func get_body_cells() -> Array[Vector2i]:
	return GetBodyCells()

## 取得占位格子（snake_case 别名，供运行时脚本调用）。
## @return 本组件占用的网格坐标列表。
func get_occupied_cells() -> Array[Vector2i]:
	return GetOccupiedCells()

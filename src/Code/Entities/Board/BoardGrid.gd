@tool
extends Node2D

## 关卡网格容器。关卡场景的根节点，负责绘制网格、提供坐标换算并汇总子组件的占位。
## 组件均为 @tool 脚本，可在编辑器里直接拖入本节点并在 Inspector 调整参数，视口即时刷新。

## 所有关卡组件加入的组名。
const COMPONENT_GROUP: StringName = &"board_component"

## 编辑器内刷新间隔（秒）。运行时每帧重绘。
const EDITOR_REDRAW_INTERVAL: float = 0.25

## 网格宽度（格）。
@export var grid_size: Vector2i = Vector2i(10, 8):
	set(value):
		grid_size = value
		queue_redraw()

## 是否在编辑器内绘制网格线。
@export var draw_grid: bool = true:
	set(value):
		draw_grid = value
		queue_redraw()

## 可放置区域高亮色。
@export var placement_color: Color = Color(0.3, 0.8, 0.4, 0.08):
	set(value):
		placement_color = value
		queue_redraw()

## 网格线颜色。
@export var grid_line_color: Color = Color(1, 1, 1, 0.08):
	set(value):
		grid_line_color = value
		queue_redraw()

## 网格线宽。
@export var grid_line_width: float = 1.0:
	set(value):
		grid_line_width = value
		queue_redraw()

var _editor_timer: float = 0.0

func _ready() -> void:
	queue_redraw()

## 每帧推进重绘。编辑器里按固定间隔刷新以省开销。
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_editor_timer += delta
		if _editor_timer >= EDITOR_REDRAW_INTERVAL:
			_editor_timer = 0.0
			queue_redraw()
		return
	queue_redraw()

## 绘制网格区域、网格线与放置区边框。
func _draw() -> void:
	var rect := GetWorldRect()
	draw_rect(rect, placement_color, true)
	draw_rect(rect, grid_line_color, false, grid_line_width * 2.0)
	if not draw_grid:
		return
	for x in range(1, grid_size.x):
		var px := float(x) * GridUtil.CELL_SIZE
		draw_line(Vector2(px, 0), Vector2(px, rect.size.y), grid_line_color, grid_line_width)
	for y in range(1, grid_size.y):
		var py := float(y) * GridUtil.CELL_SIZE
		draw_line(Vector2(0, py), Vector2(rect.size.x, py), grid_line_color, grid_line_width)

## 取得网格尺寸（格）。
## @return 网格的宽高，单位为格。
func GetCellSize() -> Vector2i:
	return grid_size

## 取得网格在世界坐标下的矩形区域。
## @return 左上角为本网格原点的矩形。
func GetWorldRect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(float(grid_size.x), float(grid_size.y)) * GridUtil.CELL_SIZE)

## 判断格子是否在网格内。
## @param cell 待判断的网格坐标。
## @return 越界时返回 false。
func IsInside(cell: Vector2i) -> bool:
	return GridUtil.InBounds(cell, grid_size)

## 世界坐标转网格坐标。
## @param world 世界坐标。
## @return 对应的网格坐标。
func WorldToCell(world: Vector2) -> Vector2i:
	return GridUtil.WorldToCell(world)

## 网格坐标转世界坐标（格子中心）。
## @param cell 网格坐标。
## @return 该格中心的世界坐标。
func CellToWorld(cell: Vector2i) -> Vector2:
	return GridUtil.CellToWorld(cell)

## 汇总所有子组件占用的格子。
## 子组件提供 GetOccupiedCells 或 GetCells 任一方法即被计入。
## @return 键为格子坐标、值为占用它的组件节点的字典。多个组件占同一格时保留先遍历到的。
func GetOccupiedCells() -> Dictionary:
	var result: Dictionary = {}
	for child in get_children():
		if not (child is Node2D):
			continue
		var comp := child as Node2D
		for c: Vector2i in _collect_cells(comp):
			if not result.has(c):
				result[c] = comp
	return result

## 取得占用指定格子的组件。
## @param cell 网格坐标。
## @return 占用该格的组件节点；没有组件占用时返回 null。
func GetComponentAt(cell: Vector2i) -> Node2D:
	var occupied := GetOccupiedCells()
	if occupied.has(cell):
		return occupied[cell] as Node2D
	return null

## 判断一组格子能否放置。
## @param cells 待放置的格子列表（网格坐标）。
## @param ignore 需要忽略的组件节点，通常是正在被拖动的组件自身；为 null 时不忽略任何组件。
## @return 全部格子都在网格内且不与其它组件重叠时返回 true。
func CanPlace(cells: Array[Vector2i], ignore: Node = null) -> bool:
	var occupied := GetOccupiedCells()
	for c in cells:
		if not IsInside(c):
			return false
		if occupied.has(c):
			var owner_node: Node = occupied[c]
			if ignore != null and owner_node == ignore:
				continue
			return false
	return true

## 取得所有鬼组件。
## @return 子节点中的 GhostComponent 列表。
func GetGhostComponents() -> Array[Node2D]:
	return _collect_by_method("GetGhostId")

## 取得所有供品口组件。
## @return 子节点中的 TerminalComponent 列表。
func GetTerminalComponents() -> Array[Node2D]:
	return _collect_by_method("GetAcceptedForm")

## 取得所有采集区组件。
## @return 子节点中的 FieldComponent 列表。
func GetFieldComponents() -> Array[Node2D]:
	return _collect_by_method("GetDrops")

## 按方法名收集子组件。
## @param method_name 子节点需实现的方法名。
## @return 实现该方法的 Node2D 子节点列表。
func _collect_by_method(method_name: String) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for child in get_children():
		if child is Node2D and child.has_method(method_name):
			result.append(child as Node2D)
	return result

## 取得子组件占用的格子。
## @param comp 子组件节点。
## @return 该组件占用的格子列表；组件不提供占位方法时返回空数组。
func _collect_cells(comp: Node2D) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if comp.has_method("GetOccupiedCells"):
		for c: Vector2i in comp.call("GetOccupiedCells"):
			result.append(c)
	elif comp.has_method("GetCells"):
		for c: Vector2i in comp.call("GetCells"):
			result.append(c)
	return result

## 取得网格尺寸（snake_case 别名，供运行时脚本调用）。
## @return 网格的宽高，单位为格。
func get_cell_size() -> Vector2i:
	return GetCellSize()

## 取得网格矩形（snake_case 别名，供运行时脚本调用）。
## @return 网格的世界矩形。
func get_world_rect() -> Rect2:
	return GetWorldRect()

## 判断格子是否在网格内（snake_case 别名，供运行时脚本调用）。
## @param cell 网格坐标。
## @return 越界时返回 false。
func is_inside(cell: Vector2i) -> bool:
	return IsInside(cell)

## 世界坐标转网格坐标（snake_case 别名，供运行时脚本调用）。
## @param world 世界坐标。
## @return 对应的网格坐标。
func world_to_cell(world: Vector2) -> Vector2i:
	return WorldToCell(world)

## 网格坐标转世界坐标（snake_case 别名，供运行时脚本调用）。
## @param cell 网格坐标。
## @return 该格中心的世界坐标。
func cell_to_world(cell: Vector2i) -> Vector2:
	return CellToWorld(cell)

## 汇总占用格子（snake_case 别名，供运行时脚本调用）。
## @return 格子坐标到组件节点的字典。
func get_occupied_cells() -> Dictionary:
	return GetOccupiedCells()

## 取得占用格子的组件（snake_case 别名，供运行时脚本调用）。
## @param cell 网格坐标。
## @return 占用该格的组件节点；没有时返回 null。
func get_component_at(cell: Vector2i) -> Node2D:
	return GetComponentAt(cell)

## 判断能否放置（snake_case 别名，供运行时脚本调用）。
## @param cells 待放置的格子列表。
## @param ignore 需要忽略的组件节点。
## @return 可以放置时返回 true。
func can_place(cells: Array[Vector2i], ignore: Node = null) -> bool:
	return CanPlace(cells, ignore)

## 取得鬼组件列表（snake_case 别名，供运行时脚本调用）。
## @return GhostComponent 列表。
func get_ghost_components() -> Array[Node2D]:
	return GetGhostComponents()

## 取得供品口组件列表（snake_case 别名，供运行时脚本调用）。
## @return TerminalComponent 列表。
func get_terminal_components() -> Array[Node2D]:
	return GetTerminalComponents()

## 取得采集区组件列表（snake_case 别名，供运行时脚本调用）。
## @return FieldComponent 列表。
func get_field_components() -> Array[Node2D]:
	return GetFieldComponents()

extends Node2D

## 连线绘制层。绘制鬼之间的连线与线上流动的物品，并支持拖拽时的预览线。

## 连线颜色。
@export var line_color: Color = Color(0.95, 0.85, 0.4, 0.9)
## 连线宽度。
@export var line_width: float = 4.0
## 线上物品颜色。
@export var item_color: Color = Color(0.9, 0.95, 1.0, 0.95)
## 拖拽预览线颜色。
@export var preview_color: Color = Color(0.6, 0.9, 1.0, 0.7)
## 端口标记半径。
@export var port_radius: float = 6.0

var _runner: Node = null
var _preview_from: Node = null
var _preview_port: int = -1
var _preview_target: Vector2 = Vector2.ZERO
var _has_preview: bool = false

func _ready() -> void:
	z_index = 5
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

## 设置运行时引用。
## @param runner 运行时节点
func SetRunner(runner: Node) -> void:
	_runner = runner

## 设置拖拽预览线。
## @param from_node 起点节点
## @param port_index 起点端口序号
## @param world_pos 鼠标世界坐标
func SetPreview(from_node: Node, port_index: int, world_pos: Vector2) -> void:
	_preview_from = from_node
	_preview_port = port_index
	_preview_target = world_pos
	_has_preview = true
	queue_redraw()

## 清除预览线。
func ClearPreview() -> void:
	_preview_from = null
	_preview_port = -1
	_has_preview = false
	queue_redraw()

## 绘制连线、端口与预览线。
func _draw() -> void:
	if _runner == null:
		return
	for line in _runner.call("GetLines"):
		var from_node: Node = line.get("from")
		var to_node: Node = line.get("to")
		if from_node == null or to_node == null:
			continue
		if not is_instance_valid(from_node) or not is_instance_valid(to_node):
			continue
		var from_cell := _port_cell(from_node, int(line.get("from_port", 0)))
		var to_cell := _port_cell(to_node, int(line.get("to_port", 0)))
		if from_cell.x < 0 or to_cell.x < 0:
			continue
		var path := GridUtil.PathL(from_cell, to_cell)
		if path.is_empty():
			continue
		var points: PackedVector2Array = PackedVector2Array()
		for cell in path:
			points.append(GridUtil.CellToWorld(cell))
		draw_polyline(points, line_color, line_width)
		_draw_port_marker(from_cell, line_color)
		_draw_port_marker(to_cell, line_color)
		var items: Array = line.get("items", [])
		for i in items.size():
			var t := float(i + 1) / float(maxi(1, items.size()))
			var idx := clampi(int(t * (points.size() - 1)), 0, points.size() - 1)
			draw_circle(points[idx], line_width, item_color)
	if _has_preview and _preview_from != null and is_instance_valid(_preview_from):
		var cell := _port_cell(_preview_from, _preview_port)
		if cell.x >= 0:
			var start := GridUtil.CellToWorld(cell)
			draw_line(start, _preview_target, preview_color, line_width)
			draw_circle(start, port_radius, preview_color)

## 绘制端口标记。
## @param cell 端口所在格
## @param color 标记颜色
func _draw_port_marker(cell: Vector2i, color: Color) -> void:
	draw_circle(GridUtil.CellToWorld(cell), port_radius, color)

## 取得节点端口所在的格。
## @param node 目标节点
## @param port_index 端口序号
## @return 端口格；无效时返回 Vector2i(-1, -1)。
func _port_cell(node: Node, port_index: int) -> Vector2i:
	if node.has_method("GetPortCell"):
		return node.call("GetPortCell", port_index)
	return Vector2i(-1, -1)

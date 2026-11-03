extends Node2D

## 板面交互总控。负责从鬼牌栏拖鬼到棋盘放置、点击端口连线、触发手动鬼与拆除。
## 交互只在建造模式开启时生效；连线本身是一只鬼，由 BoardRunner 生成 LineGhost。

## 板面网格节点。
@export var grid: Node2D = null
## 运行时节点。
@export var runner: Node2D = null
## 鬼牌栏节点。
@export var palette: Control = null
## 连线绘制层节点。
@export var connections: Node2D = null
## 拖拽放置的判定距离（像素）。
@export var drag_threshold: float = 24.0
## 是否允许建造。
@export var build_mode: bool = true
## 拆除时返还的鬼能比例。
@export_range(0.0, 1.0, 0.05) var refund_ratio: float = 0.5

var _dragging: bool = false
var _drag_ghost_id: String = ""
var _drag_preview: Node2D = null
var _pending_port_node: Node = null
var _pending_port_index: int = -1
var _selected_ghost: Node = null

func _ready() -> void:
	set_process_unhandled_input(true)
	if connections != null and connections.has_method("SetRunner"):
		connections.call("SetRunner", runner)
	SignalBus.SpiritChanged.connect(_on_spirit_changed)

## 设置建造模式。
## @param enabled 是否允许建造
func SetBuildMode(enabled: bool) -> void:
	build_mode = enabled
	if not enabled:
		CancelInteraction()

## 取得当前选中的鬼 id。
## @return 鬼 id；没有则返回空字符串。
func GetSelectedGhostId() -> String:
	return _drag_ghost_id

## 取消当前拖拽与连线选择。
func CancelInteraction() -> void:
	_dragging = false
	_drag_ghost_id = ""
	_pending_port_node = null
	_pending_port_index = -1
	_clear_preview()
	if connections != null and connections.has_method("ClearPreview"):
		connections.call("ClearPreview")

## 刷新鬼牌栏。
func RefreshPalette() -> void:
	if palette == null:
		return
	var ghost_ids := PackedStringArray()
	var data := _load_level_data()
	if data != null:
		ghost_ids = ResourceUtil.GetStringArray(data, "available_ghosts")
	if palette.has_method("SetAvailableGhosts"):
		palette.call("SetAvailableGhosts", ghost_ids)
	_sync_palette_spirit()

## 设置当前鬼能并同步到鬼牌栏。
## @param spirit 鬼能数量
func SetSpirit(spirit: int) -> void:
	_sync_palette_spirit()

## 尝试在指定格放置一只鬼。
## @param ghost_id 鬼 id
## @param cell 目标格
## @return 放置成功时返回 true。
func TryPlaceGhost(ghost_id: String, cell: Vector2i) -> bool:
	if not build_mode or runner == null or grid == null:
		return false
	var data := _load_ghost_data(ghost_id)
	if data == null:
		return false
	var cost := ResourceUtil.GetInt(data, "cost")
	var ghost := _instantiate_ghost(ghost_id, data)
	ghost.set("cell", cell)
	if not runner.call("PlaceGhost", ghost):
		ghost.queue_free()
		return false
	if not runner.call("TrySpendSpirit", cost):
		runner.call("AddSpirit", cost)
	UIEffects.PopScale2D(ghost)
	return true

## 尝试连接两个端口。
## @param from_node 起点节点
## @param from_port 起点端口序号
## @param to_node 终点节点
## @param to_port 终点端口序号
## @return 连接成功时返回 true。
func TryConnect(from_node: Node, from_port: int, to_node: Node, to_port: int) -> bool:
	if not build_mode or runner == null:
		return false
	var ok: bool = runner.call("AddLine", from_node, to_node, from_port, to_port)
	if ok:
		_pending_port_node = null
		_pending_port_index = -1
	return ok

## 处理未处理输入。
## @param event 输入事件
func _unhandled_input(event: InputEvent) -> void:
	if not build_mode:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _dragging:
		_handle_drag_motion(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)

## 处理鼠标按键。
## @param event 鼠标事件
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_left_press(event.position)
		else:
			_on_left_release(event.position)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_on_right_press(event.position)

## 左键按下。
## @param screen_pos 屏幕坐标
func _on_left_press(screen_pos: Vector2) -> void:
	# 先看是否点到鬼牌栏上的牌。
	if palette != null:
		var card := _find_card_at(screen_pos)
		if card != null:
			_begin_drag(String(card.get_meta("ghost_id", "")), screen_pos)
			return
	# 再看是否点到端口。
	var hit := _find_port_at(screen_pos)
	if hit.has("node"):
		var node: Node = hit["node"]
		var port_index: int = hit["port"]
		if _pending_port_node == null:
			if runner.has_method("GetOutputPorts") and not runner.call("GetOutputPorts", node).is_empty():
				_pending_port_node = node
				_pending_port_index = port_index
				_highlight_pending(node, port_index)
		else:
			if TryConnect(_pending_port_node, _pending_port_index, node, port_index):
				pass
			else:
				_pending_port_node = node
				_pending_port_index = port_index
		return
	# 点到已有的鬼：手动鬼直接切换。
	var ghost := _find_ghost_at(screen_pos)
	if ghost != null and ghost.has_method("IsManual") and ghost.call("IsManual"):
		ghost.call("ToggleManual")
		return
	_selected_ghost = ghost
	CancelInteraction()

## 左键释放。
## @param screen_pos 屏幕坐标
func _on_left_release(screen_pos: Vector2) -> void:
	if not _dragging:
		return
	var cell := _screen_to_cell(screen_pos)
	if cell.x >= 0 and TryPlaceGhost(_drag_ghost_id, cell):
		pass
	else:
		_clear_preview()
	_dragging = false
	_drag_ghost_id = ""

## 右键按下：拆除鬼。
## @param screen_pos 屏幕坐标
func _on_right_press(screen_pos: Vector2) -> void:
	var ghost := _find_ghost_at(screen_pos)
	if ghost == null or runner == null:
		return
	var data: GhostData = _load_ghost_data(String(ghost.call("GetGhostId")))
	var refund := 0
	if data != null:
		refund = int(round(ResourceUtil.GetInt(data, "cost") * refund_ratio))
	if refund > 0:
		runner.call("AddSpirit", refund)
	runner.call("RemoveGhost", ghost)

## 处理拖拽移动。
## @param event 鼠标事件
func _handle_drag_motion(event: InputEventMouseMotion) -> void:
	if _drag_preview == null:
		return
	_drag_preview.global_position = get_global_mouse_position()
	if connections != null and connections.has_method("SetPreview"):
		var cell := _screen_to_cell(event.position)
		var world_pos := GridUtil.CellToWorld(cell) if cell.x >= 0 else get_global_mouse_position()
		connections.call("SetPreview", null, -1, world_pos)

## 处理快捷键。
## @param event 键盘事件
func _handle_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		CancelInteraction()
		return
	if palette == null:
		return
	var index := event.keycode - KEY_1
	if index < 0 or index > 8:
		return
	var card: Control = palette.call("GetCardAt", index)
	if card != null:
		_begin_drag(String(card.get_meta("ghost_id", "")), get_global_mouse_position())

## 开始拖拽。
## @param ghost_id 鬼 id
## @param screen_pos 起始屏幕坐标
func _begin_drag(ghost_id: String, screen_pos: Vector2) -> void:
	if ghost_id.is_empty():
		return
	_dragging = true
	_drag_ghost_id = ghost_id
	var data := _load_ghost_data(ghost_id)
	if data == null:
		return
	_drag_preview = _instantiate_ghost(ghost_id, data)
	_drag_preview.set("cell", _screen_to_cell(screen_pos))
	if _drag_preview is CanvasItem:
		(_drag_preview as CanvasItem).modulate.a = 0.6
	add_child(_drag_preview)
	_drag_preview.global_position = get_global_mouse_position()

## 清除拖拽预览。
func _clear_preview() -> void:
	if _drag_preview != null and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null

## 实例化一只鬼用于放置或预览。
## @param ghost_id 鬼 id
## @param data 鬼数据资源
## @return 鬼节点。
func _instantiate_ghost(ghost_id: String, data: Resource) -> Node2D:
	var scene: PackedScene = load("res://Code/Entities/Board/GhostComponent.tscn")
	if scene == null:
		return Node2D.new()
	var ghost := scene.instantiate()
	ghost.set("ghost_id", ghost_id)
	var footprint := ResourceUtil.GetArray(data, "footprint")
	var appendages := ResourceUtil.GetArray(data, "appendages")
	ghost.set("footprint", GridUtil.ToCellArray(footprint))
	ghost.set("appendages", GridUtil.ToCellArray(appendages))
	return ghost

## 找到鬼牌栏上被按下的牌。
## @param screen_pos 屏幕坐标
## @return 牌节点；没有返回 null。
func _find_card_at(screen_pos: Vector2) -> Control:
	if palette == null:
		return null
	for card in palette.get_children():
		for child in card.get_children():
			var found := _find_control_at(child, screen_pos)
			if found != null:
				return card as Control
	return null

## 在节点树里递归查找包含屏幕坐标的控件。
## @param node 起始节点
## @param screen_pos 屏幕坐标
## @return 命中的控件；没有返回 null。
func _find_control_at(node: Node, screen_pos: Vector2) -> Control:
	if node is Control:
		var control := node as Control
		if control.get_global_rect().has_point(screen_pos):
			return control
	for child in node.get_children():
		var found := _find_control_at(child, screen_pos)
		if found != null:
			return found
	return null

## 找到屏幕坐标下的鬼。
## @param screen_pos 屏幕坐标
## @return 鬼节点；没有返回 null。
func _find_ghost_at(screen_pos: Vector2) -> Node2D:
	if grid == null:
		return null
	for ghost in grid.get_ghost_components():
		if not is_instance_valid(ghost):
			continue
		if ghost.has_method("GetOccupiedCells"):
			for cell in ghost.call("GetOccupiedCells"):
				var rect := Rect2(GridUtil.CellToWorld(cell) - Vector2.ONE * GridUtil.HALF_CELL, Vector2.ONE * GridUtil.CELL_SIZE)
				if rect.has_point(screen_pos):
					return ghost
	return null

## 找到屏幕坐标下的端口。
## @param screen_pos 屏幕坐标
## @return 含 node 与 port 键的字典；没有返回空字典。
func _find_port_at(screen_pos: Vector2) -> Dictionary:
	if grid == null or runner == null:
		return {}
	var candidates: Array = []
	for ghost in grid.get_ghost_components():
		if not is_instance_valid(ghost):
			continue
		candidates.append(ghost)
	for terminal in grid.get_terminal_components():
		if is_instance_valid(terminal):
			candidates.append(terminal)
	for node in candidates:
		for port_index in range(4):
			var cell: Vector2i = runner.call("GetPortCell", node, port_index)
			if cell.x < 0:
				continue
			var center := GridUtil.CellToWorld(cell)
			if center.distance_to(screen_pos) <= GridUtil.HALF_CELL:
				return {"node": node, "port": port_index}
	return {}

## 把屏幕坐标换算成网格格。
## @param screen_pos 屏幕坐标
## @return 网格格；不在板面上时返回 Vector2i(-1,-1)。
func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	if grid == null:
		return Vector2i(-1, -1)
	return grid.call("WorldToCell", get_global_mouse_position())

## 取得当前关卡数据。
## @return LevelData 资源；无则返回 null。
func _load_level_data() -> LevelData:
	var level_id := int(SaveManager.GetProgress().get("current_level", 1))
	return LevelData.LoadLevel(level_id)

## 加载鬼数据资源。
## @param ghost_id 鬼 id
## @return GhostData 资源；失败返回 null。
func _load_ghost_data(ghost_id: String) -> GhostData:
	var path := "res://Data/Ghosts/%s.tres" % ghost_id
	if not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	if res is GhostData:
		return res
	return null

## 鬼能变化时刷新鬼牌栏。
## @param spirit 当前鬼能
func _on_spirit_changed(spirit: int) -> void:
	_sync_palette_spirit()

## 把当前鬼能同步到鬼牌栏。
func _sync_palette_spirit() -> void:
	if palette == null:
		return
	var spirit := 0
	if runner != null:
		spirit = int(runner.get("spirit"))
	if palette.has_method("SetSpirit"):
		palette.call("SetSpirit", spirit)

## 高亮待连接的端口。
## @param node 端口所在节点
## @param port_index 端口序号
func _highlight_pending(node: Node, port_index: int) -> void:
	if connections == null or not connections.has_method("SetPreview"):
		return
	var world_pos := Vector2.ZERO
	if runner != null:
		world_pos = runner.call("GetPortWorldPos", node, port_index)
	connections.call("SetPreview", node, port_index, world_pos)

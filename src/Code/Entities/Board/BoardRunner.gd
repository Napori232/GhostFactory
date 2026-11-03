extends Node2D

## 运行时板面。承载网格、已放置的鬼、连线与物料推进，负责 20 Hz 逻辑 tick。
## 关卡场景里预置的采集区、供品口与障碍物由本节点读取；玩家放置的鬼与连线在运行时产生。

## 板面网格节点。
@export var grid: Node2D = null
## 玩家当前持有的鬼能。
@export var spirit: int = 0
## 本关已交付的供品数。
@export var delivered: int = 0
## 本关目标交付数。
@export var goal: int = 20
## 是否处于运行状态。
@export var running: bool = true

var _lines: Array = []
var _accumulator: float = 0.0
var _tick_interval: float = 0.05
var _item_step_interval: float = 0.3
var _item_step_accumulator: float = 0.0

func _ready() -> void:
	_tick_interval = 1.0 / maxf(1.0, _get_export("sim_tick_rate", 20.0))
	_item_step_interval = _get_export("sim_item_step_interval", 0.3)

## 安全读取 ExportSettings 的导出项，缺省时回落默认值。
## @param key 导出项名称
## @param default_value 缺省值
## @return 导出项的值。
func _get_export(key: String, default_value: Variant) -> Variant:
	if ExportSettings != null and key in ExportSettings:
		return ExportSettings.get(key)
	return default_value

## 设置网格引用。
## @param value 网格节点
func SetGrid(value: Node2D) -> void:
	grid = value

## 设置目标交付数。
## @param value 目标数量
func SetGoal(value: int) -> void:
	goal = value
	SignalBus.DeliveredChanged.emit(delivered, goal)

## 增加鬼能。
## @param amount 增加量，可为负
func AddSpirit(amount: int) -> void:
	spirit = maxi(0, spirit + amount)
	SignalBus.SpiritChanged.emit(spirit)

## 消耗鬼能建造。
## @param cost 消耗量
## @return 鬼能充足时返回 true。
func TrySpendSpirit(cost: int) -> bool:
	if spirit < cost:
		return false
	AddSpirit(-cost)
	return true

## 推进固定步长逻辑。
func _process(delta: float) -> void:
	if not running:
		return
	_accumulator += delta
	while _accumulator >= _tick_interval:
		_accumulator -= _tick_interval
		_tick()
	_item_step_accumulator += delta
	if _item_step_accumulator >= _item_step_interval:
		_item_step_accumulator = 0.0
		_step_items()

## 执行一次逻辑 tick。
func _tick() -> void:
	_tick_fields()
	_tick_ghosts()

## 推进所有采集区的掉落。
func _tick_fields() -> void:
	if grid == null:
		return
	for field in grid.get_field_components():
		if not is_instance_valid(field):
			continue
		field.set_meta("drop_timer", maxf(0.0, float(field.get_meta("drop_timer", 0.0)) - _tick_interval))
		if float(field.get_meta("drop_timer", 0.0)) > 0.0:
			continue
		var interval: float = maxf(0.1, float(field.get("interval")))
		field.set_meta("drop_timer", interval)
		_drop_item(field)

## 采集区掉出一个物品到随机格。
## @param field 采集区节点
func _drop_item(field: Node2D) -> void:
	var cells: Array[Vector2i] = field.get_cells()
	if cells.is_empty():
		return
	var cell: Vector2i = cells[randi() % cells.size()]
	var form: String = field.get("drops")
	if randf() < float(field.get("garbage_rate")):
		form = "Garbage"
	field.add_item(cell, form)

## 执行所有鬼的动作。
func _tick_ghosts() -> void:
	if grid == null:
		return
	for ghost in grid.get_ghost_components():
		if not is_instance_valid(ghost):
			continue
		_tick_ghost(ghost)

## 执行单只鬼的动作。
## @param ghost 鬼组件节点
func _tick_ghost(ghost: Node2D) -> void:
	match ghost.get_ghost_id():
		"LongTongue":
			_tick_long_tongue(ghost)
		"Stove":
			_tick_stove(ghost)
		"Glutton", "FineChew":
			_tick_collector(ghost)
		"Fork":
			_tick_fork(ghost)
		"Contain":
			_tick_contain(ghost)
		_:
			pass

## 长舌鬼：按 CD 从相邻采集区取料，喂给下游。
## @param ghost 长舌鬼节点
func _tick_long_tongue(ghost: Node2D) -> void:
	var cd: float = _get_export("sim_tongue_cycle", 2.0)
	if not _cd_ready(ghost, cd):
		return
	var field := _find_field_for(ghost)
	if field == null:
		return
	var item := _take_item_from_field(field)
	if item.is_empty():
		return
	_push_to_output(ghost, item)

## 灶鬼：按配方转化形态，带损耗。
## @param ghost 灶鬼节点
func _tick_stove(ghost: Node2D) -> void:
	var cycle: float = _get_export("sim_processing_cycle", 1.2)
	if not _cd_ready(ghost, cycle):
		return
	var buffer: Array = ghost.get_meta("input_buffer", [])
	if buffer.is_empty():
		return
	ghost.set_meta("cd", cycle)
	var raw: String = buffer.pop_front()
	ghost.set_meta("input_buffer", buffer)
	var yield_rate: float = _get_export("sim_processing_yield", 0.8)
	var produced := "Processed"
	if randf() > yield_rate:
		produced = "Garbage"
	_push_to_output(ghost, produced)

## 采集鬼：按基率与面积从采集区取料。
## @param ghost 采集鬼节点
func _tick_collector(ghost: Node2D) -> void:
	var cd: float = _get_export("sim_collector_cycle", 1.0)
	if not _cd_ready(ghost, cd):
		return
	var field := _find_field_for(ghost)
	if field == null:
		return
	var item := _take_item_from_field(field)
	if item.is_empty():
		return
	_push_to_output(ghost, item)

## 岔口鬼：一分为二，固定 1:1。
## @param ghost 岔口鬼节点
func _tick_fork(ghost: Node2D) -> void:
	var cd: float = _get_export("sim_fork_cycle", 0.6)
	if not _cd_ready(ghost, cd):
		return
	var buffer: Array = ghost.get_meta("input_buffer", [])
	if buffer.is_empty():
		return
	ghost.set_meta("cd", cd)
	buffer.pop_front()
	ghost.set_meta("input_buffer", buffer)
	_push_to_output(ghost, "Raw", 0)
	_push_to_output(ghost, "Raw", 1)

## 收容鬼：吃垃圾，返还鬼能。
## @param ghost 收容鬼节点
func _tick_contain(ghost: Node2D) -> void:
	var cd: float = _get_export("sim_contain_interval", 2.0)
	if not _cd_ready(ghost, cd):
		return
	var buffer: Array = ghost.get_meta("input_buffer", [])
	var index := buffer.find("Garbage")
	if index < 0:
		return
	buffer.remove_at(index)
	ghost.set_meta("input_buffer", buffer)
	ghost.set_meta("cd", cd)
	AddSpirit(int(_get_export("sim_contain_refund", 1)))

## 判定冷却是否就绪，就绪则重置计时器。
## @param ghost 鬼节点
## @param cd 冷却时长
## @return 就绪返回 true。
func _cd_ready(ghost: Node2D, cd: float) -> bool:
	ghost.set_meta("cd", maxf(0.0, float(ghost.get_meta("cd", 0.0)) - _tick_interval))
	if float(ghost.get_meta("cd", 0.0)) > 0.0:
		return false
	ghost.set_meta("cd", cd)
	return true

## 查找与该鬼本体相邻的采集区。
## @param ghost 鬼节点
## @return 采集区节点；没有则返回 null。
func _find_field_for(ghost: Node2D) -> Node2D:
	if grid == null:
		return null
	var body: Array[Vector2i] = ghost.get_body_cells()
	for field in grid.get_field_components():
		for cell in field.get_cells():
			if body.has(cell):
				return field
	return null

## 从采集区取出一个物品。
## @param field 采集区节点
## @return 形态 id；没有可取物品时返回空字符串。
func _take_item_from_field(field: Node2D) -> String:
	var cells: Array[Vector2i] = field.get_cells()
	if cells.is_empty():
		return ""
	for i in cells.size():
		var cell: Vector2i = cells[randi() % cells.size()]
		var item: String = field.take_item(cell)
		if not item.is_empty():
			return item
	return ""

## 把物品推给下游。
## @param ghost 鬼节点
## @param form 形态 id
## @param port_index 输出端口序号，-1 表示自动选第一个
func _push_to_output(ghost: Node2D, form: String, port_index: int = -1) -> void:
	var outputs := _get_output_lines(ghost)
	if outputs.is_empty():
		ghost.set_meta("output_buffer", _append_item(ghost.get_meta("output_buffer", []), form))
		return
	var line: Dictionary
	if port_index >= 0 and port_index < outputs.size():
		line = outputs[port_index]
	else:
		line = outputs[0]
	(line["items"] as Array).append(form)

## 取得某鬼所有输出端连线。
## @param ghost 鬼节点
## @return 连线数组。
func _get_output_lines(ghost: Node2D) -> Array:
	var result: Array = []
	for line in _lines:
		if line.get("from") == ghost:
			result.append(line)
	return result

## 向数组追加物品，超过容量则丢弃。
## @param buffer 缓冲数组
## @param form 形态 id
## @return 新的缓冲数组。
func _append_item(buffer: Array, form: String) -> Array:
	var capacity: int = int(_get_export("sim_ghost_buffer", 3))
	if buffer.size() >= capacity:
		return buffer
	buffer.append(form)
	return buffer

## 推进线上物品一步。物品由线鬼一格一格搬运，到达末端后交给下游。
func _step_items() -> void:
	for line in _lines:
		var ghost: Node = line.get("ghost")
		var target: Node = line.get("to")
		if target == null or not is_instance_valid(target):
			continue
		if ghost == null or not is_instance_valid(ghost):
			continue
		# 上游把物品塞进线鬼的入口。
		var pending: Array = line.get("items", [])
		if not pending.is_empty():
			var form: String = pending.pop_front()
			if not ghost.call("AcceptItem", form):
				pending.append(form)
			else:
				(line["items"] as Array).assign(pending)
		# 线鬼把物品推到末端。
		var arrived: String = ghost.call("Advance")
		if arrived.is_empty():
			continue
		if target.has_method("get_accepted_form"):
			var accepted: String = target.get_accepted_form()
			if accepted == arrived:
				target.call("add_delivered", 1)
				delivered += int(target.get("score"))
				SignalBus.ItemDelivered.emit(arrived, target)
				SignalBus.DeliveredChanged.emit(delivered, goal)
			else:
				(line["items"] as Array).append(arrived)
		elif target.has_method("get_meta"):
			var buffer: Array = target.get_meta("input_buffer", [])
			target.set_meta("input_buffer", _append_item(buffer, arrived))

## 建立一条连线。线本身是一只鬼：会生成 LineGhost 节点，占据路径上的格子并搬运物品。
## @param from 起点鬼节点
## @param to 终点鬼节点
## @param from_port 起点端口序号
## @param to_port 终点端口序号
## @return 建立成功时返回 true。
func AddLine(from: Node2D, to: Node2D, from_port: int, to_port: int) -> bool:
	if from == null or to == null:
		return false
	for line in _lines:
		if line.get("from") == from and line.get("to") == to:
			return false
	var from_cell := GetPortCell(from, from_port)
	var to_cell := GetPortCell(to, to_port)
	if from_cell.x < 0 or to_cell.x < 0:
		return false
	var path := GridUtil.PathL(from_cell, to_cell)
	var line_ghost := _spawn_line_ghost(path, from_cell, to_cell)
	_lines.append({
		"from": from,
		"to": to,
		"from_port": from_port,
		"to_port": to_port,
		"items": [],
		"ghost": line_ghost,
	})
	SignalBus.LineCreated.emit(from, to)
	return true

## 生成一只线鬼节点并挂到网格上。
## @param path 路径格列表
## @param source_cell 起点格
## @param target_cell 终点格
## @return 生成的线鬼节点；失败返回 null。
func _spawn_line_ghost(path: Array[Vector2i], source_cell: Vector2i, target_cell: Vector2i) -> Node2D:
	if grid == null:
		return null
	var script: Script = load("res://Code/Entities/Board/LineGhost.gd")
	var ghost := Node2D.new()
	ghost.name = "LineGhost"
	ghost.set_script(script)
	ghost.set("path", path)
	ghost.set("source_cell", source_cell)
	ghost.set("target_cell", target_cell)
	ghost.set("cost", maxi(0, path.size() - 1))
	grid.add_child(ghost)
	return ghost

## 移除所有连到某节点的线。
## @param node 目标节点
func RemoveLinesOf(node: Node2D) -> void:
	_lines = _lines.filter(func(line: Dictionary) -> bool:
		return line.get("from") != node and line.get("to") != node
	)

## 清除全部连线。
func ClearLines() -> void:
	_lines.clear()

## 取得全部连线。
## @return 连线数组。
func GetLines() -> Array:
	return _lines

## 放置一只鬼。
## @param ghost 鬼组件节点
## @return 放置成功时返回 true。
func PlaceGhost(ghost: Node2D) -> bool:
	if grid == null:
		return false
	if not grid.can_place(ghost.get_occupied_cells(), ghost):
		return false
	grid.add_child(ghost)
	ghost.set_meta("cd", 0.0)
	ghost.set_meta("input_buffer", [])
	ghost.set_meta("output_buffer", [])
	SignalBus.GhostPlaced.emit(ghost)
	return true

## 移除一只鬼。
## @param ghost 鬼组件节点
func RemoveGhost(ghost: Node2D) -> void:
	if ghost == null or not is_instance_valid(ghost):
		return
	SignalBus.GhostRemoved.emit(ghost)
	RemoveLinesOf(ghost)
	ghost.queue_free()

## 取得某节点的端口定义列表。
## @param node 目标节点
## @return 端口定义数组；节点无端口时返回空数组。
func GetPorts(node: Node) -> Array:
	if node == null or not is_instance_valid(node):
		return []
	var ghost_id := ""
	if node.has_method("GetGhostId"):
		ghost_id = node.call("GetGhostId")
	elif node.has_method("get_accepted_form"):
		ghost_id = "Terminal"
	return GhostPortDef.GetPorts(ghost_id)

## 取得某节点的输出端口定义列表。
## @param node 目标节点
## @return 端口定义数组。
func GetOutputPorts(node: Node) -> Array:
	var result: Array = []
	for port in GetPorts(node):
		if port.get("kind", "") == GhostPortDef.PORT_OUT:
			result.append(port)
	return result

## 取得某节点的输入端口定义列表。
## @param node 目标节点
## @return 端口定义数组。
func GetInputPorts(node: Node) -> Array:
	var result: Array = []
	for port in GetPorts(node):
		if port.get("kind", "") == GhostPortDef.PORT_IN:
			result.append(port)
	return result

## 取得端口的实际网格格。
## 端口序号在输出端口列表与输入端口列表中各自独立编号：节点若只有输出端口则按输出列表解析，
## 只有输入端口（如供品口）则按输入列表解析。
## @param node 目标节点
## @param port_index 端口序号
## @return 端口所在格；无效时返回 Vector2i(-1, -1)。
func GetPortCell(node: Node, port_index: int) -> Vector2i:
	if node == null or not is_instance_valid(node):
		return Vector2i(-1, -1)
	var origin := _node_origin(node)
	var facing := _node_facing(node)

	var outputs := GetOutputPorts(node)
	var inputs := GetInputPorts(node)
	var port: Dictionary = {}
	if not outputs.is_empty() and not inputs.is_empty():
		# 两种端口都有时，按序号优先落在输出列表（连线起点语义）。
		port = _port_at(outputs, port_index)
	elif not outputs.is_empty():
		port = _port_at(outputs, port_index)
	else:
		port = _port_at(inputs, port_index)
	if port.is_empty():
		return Vector2i(-1, -1)
	var offset: Vector2i = port.get("offset", Vector2i.ZERO)
	return origin + _rotate_offset(offset, facing)

## 取得节点的本体原点格。
## @param node 目标节点
## @return 原点格。
func _node_origin(node: Node) -> Vector2i:
	if node.has_method("get_cell"):
		return node.call("get_cell")
	if "cell" in node:
		return node.get("cell")
	if "origin_cell" in node:
		return node.get("origin_cell")
	return Vector2i.ZERO

## 取得节点的朝向。
## @param node 目标节点
## @return 朝向，0=东 1=南 2=西 3=北。
func _node_facing(node: Node) -> int:
	if node.has_method("get_facing"):
		return node.call("get_facing")
	if "facing" in node:
		return node.get("facing")
	return 0

## 取得端口的世界坐标。
## @param node 目标节点
## @param port_index 端口序号
## @return 世界坐标；无效时返回 Vector2.ZERO。
func GetPortWorldPos(node: Node, port_index: int) -> Vector2:
	var cell := GetPortCell(node, port_index)
	if cell.x < 0:
		return Vector2.ZERO
	return GridUtil.CellToWorld(cell)

## 按朝向旋转格偏移。0=东 1=南 2=西 3=北，顺时针。
## @param offset 原始偏移
## @param facing 朝向
## @return 旋转后的偏移。
func _rotate_offset(offset: Vector2i, facing: int) -> Vector2i:
	var result := offset
	match ((facing % 4) + 4) % 4:
		0:
			result = offset
		1:
			result = Vector2i(-offset.y, offset.x)
		2:
			result = Vector2i(-offset.x, -offset.y)
		3:
			result = Vector2i(offset.y, -offset.x)
	return result

## 在端口定义数组中按序号取值。
## @param ports 端口定义数组
## @param index 序号
## @return 端口定义；越界返回空字典。
func _port_at(ports: Array, index: int) -> Dictionary:
	if index < 0 or index >= ports.size():
		return {}
	return ports[index]

## 移除一条连线。
## @param from 起点节点
## @param to 终点节点
## @return 移除成功时返回 true。
func RemoveLine(from: Node, to: Node) -> bool:
	var before := _lines.size()
	_lines = _lines.filter(func(line: Dictionary) -> bool:
		return not (line.get("from") == from and line.get("to") == to)
	)
	return _lines.size() != before

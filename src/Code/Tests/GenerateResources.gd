extends Node

## 资源生成器：用 ResourceSaver 产出七只鬼与四关的 .tres，避免手写 .tres 格式出错。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/GenerateResources.tscn
## 资源落在 res://Code/Data/ 下（Code/ 目录内），符合 AGENTS.md §一 的权限边界。

const GHOST_DIR: String = "res://Code/Data/Ghosts/"
const LEVEL_DIR: String = "res://Code/Data/Levels/"

var _written: int = 0
var _failed: int = 0

func _ready() -> void:
	_ensure_dirs()
	for ghost in _build_ghosts():
		_save(ghost, GHOST_DIR + _file_name(ghost.id) + ".tres")
	for level in _build_levels():
		_save(level, LEVEL_DIR + "Level%02d.tres" % level.id)
	print("---- 资源生成：%d 个成功，%d 个失败" % [_written, _failed])
	get_tree().quit(1 if _failed > 0 else 0)

## 确保输出目录存在。
func _ensure_dirs() -> void:
	for path in [GHOST_DIR, LEVEL_DIR]:
		var absolute := ProjectSettings.globalize_path(path)
		DirAccess.make_dir_recursive_absolute(absolute)

## 把 StringName id 转成 PascalCase 文件名。
## @param ghost_id 鬼的 id。
## @return 文件名主体，例如 producer -> Producer。
func _file_name(ghost_id: StringName) -> String:
	var raw := String(ghost_id)
	return raw.substr(0, 1).to_upper() + raw.substr(1)

## 保存一个资源并检查结果。
## @param resource 待保存的资源。
## @param path res:// 目标路径。
func _save(resource: Resource, path: String) -> void:
	var err := ResourceSaver.save(resource, path)
	if err == OK:
		_written += 1
		print("PASS: 已生成 %s" % path)
	else:
		_failed += 1
		push_error("生成失败 %s，错误码 %d" % [path, err])

## 构造一个端口定义。
## @param port_id 端口 id。
## @param is_input 是否为输入端口。
## @param accepts 接受的物料标签。
## @param produces 送出的物料标签。
## @param buffer_size 缓冲上限。
## @return 端口定义资源。
func _port(port_id: StringName, is_input: bool, accepts: Array[StringName], produces: Array[StringName], buffer_size: int) -> BoardPortDef:
	var port := BoardPortDef.new()
	port.id = port_id
	port.is_input = is_input
	port.direction = Vector2i.LEFT if is_input else Vector2i.RIGHT
	port.accepts = accepts.duplicate()
	port.produces = produces.duplicate()
	port.buffer_size = buffer_size
	return port

## 构造四只基础鬼。
## 数值取自 Docs/GameDesign.md §13 与 CodePlan §6 阶段 1 的四类基础鬼参数表。
## @return 鬼数据资源数组。
func _build_ghosts() -> Array[GhostData]:
	var result: Array[GhostData] = []

	# 生产鬼：无连线输出端口（D3），产出走四邻掉落。
	var producer := GhostData.new()
	producer.id = &"producer"
	producer.display_name = "生产鬼"
	producer.category = GhostData.CATEGORY_PRODUCTION
	producer.trigger_type = GhostData.TRIGGER_AUTO
	producer.movability = GhostData.MOVABILITY_RIGID
	var producer_ports: Array[BoardPortDef] = []
	producer.ports = producer_ports
	producer.cost = 5
	producer.cycle_time = 2.0
	producer.buffer_capacity = 3
	producer.color = Color(0.36, 0.78, 0.92)
	result.append(producer)

	# 采集鬼：输出端口标签动态（D2），produces 留空，运行时按缓冲内容计算。
	var collector := GhostData.new()
	collector.id = &"collector"
	collector.display_name = "采集鬼"
	collector.category = GhostData.CATEGORY_COLLECTION
	collector.trigger_type = GhostData.TRIGGER_AUTO
	collector.movability = GhostData.MOVABILITY_SOFT
	var empty_in: Array[StringName] = []
	var empty_out: Array[StringName] = []
	var collector_ports: Array[BoardPortDef] = [
		_port(&"out", false, empty_in, empty_out, 3),
	]
	collector.ports = collector_ports
	collector.cost = 5
	collector.cycle_time = 0.5
	collector.buffer_capacity = 3
	collector.color = Color(0.45, 0.86, 0.55)
	result.append(collector)

	# 运输鬼：输入输出各 1，缓冲各 1，移动 0.3 s/格。
	var transporter := GhostData.new()
	transporter.id = &"transporter"
	transporter.display_name = "运输鬼"
	transporter.category = GhostData.CATEGORY_TRANSPORT
	transporter.trigger_type = GhostData.TRIGGER_AUTO
	transporter.movability = GhostData.MOVABILITY_SOFT
	var all_materials: Array[StringName] = [GhostTag.SPIRIT, GhostTag.OFFER, GhostTag.IMPURITY]
	var transporter_ports: Array[BoardPortDef] = [
		_port(&"in", true, all_materials, [], 1),
		_port(&"out", false, [], all_materials, 1),
	]
	transporter.ports = transporter_ports
	transporter.cost = 5
	transporter.cycle_time = 0.3
	transporter.buffer_capacity = 1
	transporter.color = Color(0.96, 0.62, 0.35)
	result.append(transporter)

	# 处理鬼：按 SpiritToOffer 配方加工，杂质可回收为鬼能。
	var processor := GhostData.new()
	processor.id = &"processor"
	processor.display_name = "处理鬼"
	processor.category = GhostData.CATEGORY_PROCESSING
	processor.trigger_type = GhostData.TRIGGER_AUTO
	processor.movability = GhostData.MOVABILITY_SOFT
	var processor_inputs: Array[StringName] = [GhostTag.SPIRIT, GhostTag.IMPURITY]
	var processor_outputs: Array[StringName] = [GhostTag.OFFER, GhostTag.SPIRIT]
	var processor_ports: Array[BoardPortDef] = [
		_port(&"in", true, processor_inputs, [], 2),
		_port(&"out", false, [], processor_outputs, 2),
	]
	processor.ports = processor_ports
	processor.cost = 8
	processor.cycle_time = 1.2
	processor.buffer_capacity = 2
	processor.recipe_id = "SpiritToOffer"
	processor.color = Color(0.94, 0.78, 0.34)
	result.append(processor)

	# ── 推动链三件（Docs/Ghosts.md 推动链四件中的三件，鼓鬼留作长期规划）──
	# 这三只都不走四个大类的默认行为，靠 behavior_id 单独分派。
	# 几何占位形状「待美术定」，先一律按 1 格实装。

	# 推舌鬼：自动触发、刚体，每 2.0 s 出舌把前方柔体推开一格，是推动链的起点。
	var pusher := GhostData.new()
	pusher.id = &"pusher"
	pusher.behavior_id = &"pusher"
	pusher.display_name = "推舌鬼"
	pusher.category = GhostData.CATEGORY_TRANSPORT
	pusher.trigger_type = GhostData.TRIGGER_AUTO
	pusher.movability = GhostData.MOVABILITY_RIGID
	var pusher_materials: Array[StringName] = [GhostTag.SPIRIT, GhostTag.OFFER, GhostTag.IMPURITY]
	var pusher_ports: Array[BoardPortDef] = [
		_port(&"in", true, pusher_materials, [], 1),
		_port(&"out", false, [], pusher_materials, 1),
	]
	pusher.ports = pusher_ports
	pusher.cost = 8
	pusher.cycle_time = 2.0
	pusher.buffer_capacity = 1
	pusher.color = Color(0.62, 0.55, 0.95)
	result.append(pusher)

	# 守财鬼：被动触发、柔体，被推一次掉 1 鬼能——永动机引擎的核心件。
	# 无端口（0/0），只能靠被推产生产出。
	var miser := GhostData.new()
	miser.id = &"miser"
	miser.behavior_id = &"miser"
	miser.display_name = "守财鬼"
	miser.category = GhostData.CATEGORY_TRANSPORT
	miser.trigger_type = GhostData.TRIGGER_PASSIVE
	miser.movability = GhostData.MOVABILITY_SOFT
	var miser_ports: Array[BoardPortDef] = []
	miser.ports = miser_ports
	miser.cost = 4
	miser.cycle_time = 0.0
	miser.buffer_capacity = 0
	miser.color = Color(0.98, 0.82, 0.42)
	result.append(miser)

	# 吊死鬼：被动触发、柔体、需手动摆位；被推动后下一 tick 荡回原位，是推力链的中继。
	var hang := GhostData.new()
	hang.id = &"hang"
	hang.behavior_id = &"hang"
	hang.display_name = "吊死鬼"
	hang.category = GhostData.CATEGORY_TRANSPORT
	hang.trigger_type = GhostData.TRIGGER_PASSIVE
	hang.movability = GhostData.MOVABILITY_SOFT
	var hang_ports: Array[BoardPortDef] = [
		_port(&"in", true, pusher_materials, [], 1),
		_port(&"out", false, [], pusher_materials, 1),
	]
	hang.ports = hang_ports
	hang.cost = 5
	hang.cycle_time = 0.3
	hang.buffer_capacity = 1
	hang.is_manual = true
	hang.color = Color(0.55, 0.72, 0.62)
	result.append(hang)

	return result

## 生成矩形格区域。
## @param x0 起始列（含）。
## @param x1 结束列（不含）。
## @param y0 起始行（含）。
## @param y1 结束行（不含）。
## @return 区域内全部格坐标。
func _rect(x0: int, x1: int, y0: int, y1: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(y0, y1):
		for x in range(x0, x1):
			cells.append(Vector2i(x, y))
	return cells

## 构造四关配置。
## 地图、目标、时限取自 Docs/LevelDesign.md；关卡 2 目标形态按 D4 定稿改为 Spirit；
## 关卡 4 为推动链教学关（Docs/Ghosts.md 推动链四件）。
## @return 关卡数据资源数组。
func _build_levels() -> Array[LevelData]:
	var result: Array[LevelData] = []

	# 关卡 1：10×8，90 s，30 个鬼能，18 格可放置区，唯一交付口 (8,4) 收 Spirit。
	var l1 := LevelData.new()
	l1.id = 1
	l1.display_name = "掉落与交付"
	l1.grid_size = Vector2i(10, 8)
	l1.time_limit = 90.0
	l1.goal_form = "Spirit"
	l1.goal_amount = 30
	l1.start_spirit = 30
	l1.placeable_cells = _rect(2, 8, 3, 6)
	# 生产专属区：可放置区中间一整排 6 格，与交付口 (8,4) 同排。
	# 本关白名单只有生产鬼，上下两排蓝格留作掉落物缓冲带（生产鬼的产出只掉四邻）。
	var l1_producer: Array[Vector2i] = _rect(2, 8, 4, 5)
	l1.producer_only_cells = l1_producer
	l1.obstacle_cells = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
	var l1_facilities: Array[FacilityPlacement] = []
	var l1_delivery := FacilityPlacement.new()
	l1_delivery.kind = FacilityPlacement.KIND_DELIVERY
	l1_delivery.cell = Vector2i(8, 4)
	l1_delivery.accepted_form = "Spirit"
	l1_delivery.facing = Vector2i.LEFT
	l1_facilities.append(l1_delivery)
	l1.preplaced_facilities = l1_facilities
	var l1_allowed: Array[StringName] = [&"producer"]
	l1.allowed_ghost_ids = l1_allowed
	var l1_stars := StarThresholds.new()
	l1_stars.two_star_time = 75.0
	l1_stars.three_star_time = 60.0
	l1_stars.manual_limit = 40
	l1_stars.space_budget = 18
	l1.star_thresholds = l1_stars
	l1.camera_yaw = 0
	l1.camera_zoom = 1
	result.append(l1)

	# 关卡 2：12×9，120 s，72 个（按 D4 改为鬼能），22 格可放置区。
	var l2 := LevelData.new()
	l2.id = 2
	l2.display_name = "采集与输送"
	l2.grid_size = Vector2i(12, 9)
	l2.time_limit = 120.0
	l2.goal_form = "Spirit"
	l2.goal_amount = 72
	l2.start_spirit = 40
	var l2_cells: Array[Vector2i] = []
	l2_cells.append_array(_rect(2, 5, 3, 6))
	l2_cells.append_array(_rect(7, 10, 3, 6))
	l2_cells.append_array(_rect(8, 10, 6, 8))
	l2.placeable_cells = l2_cells
	l2.obstacle_cells = [
		Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5),
		Vector2i(6, 3), Vector2i(6, 4),
	]
	# 生产专属区：左上蓝区第一排 3 格。生产鬼只能放这里，其余鬼不得占用；
	# 空出的蓝区留给采集鬼与中转鬼，逼玩家把「生产 → 采集中转 → 交付」串成一链。
	var l2_producer: Array[Vector2i] = [
		Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
	]
	l2.producer_only_cells = l2_producer
	var l2_facilities: Array[FacilityPlacement] = []
	var l2_storage := FacilityPlacement.new()
	l2_storage.kind = FacilityPlacement.KIND_STORAGE
	l2_storage.cell = Vector2i(1, 7)
	l2_storage.accepted_form = "Spirit"
	l2_storage.facing = Vector2i.RIGHT
	l2_facilities.append(l2_storage)
	var l2_delivery := FacilityPlacement.new()
	l2_delivery.kind = FacilityPlacement.KIND_DELIVERY
	# 交付口按联动教学上移一格：(10,2) -> (10,3)。配合「只许一次 90° 转弯」，
	# 左上区任意格到交付口的两条 L 形走线都会撞上中央墙，必须用中转鬼拆线。
	l2_delivery.cell = Vector2i(10, 3)
	l2_delivery.accepted_form = "Spirit"
	l2_delivery.facing = Vector2i.LEFT
	l2_facilities.append(l2_delivery)
	l2.preplaced_facilities = l2_facilities
	var l2_allowed: Array[StringName] = [&"producer", &"collector", &"transporter"]
	l2.allowed_ghost_ids = l2_allowed
	var l2_stars := StarThresholds.new()
	l2_stars.two_star_time = 100.0
	l2_stars.three_star_time = 85.0
	l2_stars.manual_limit = 100
	l2_stars.space_budget = 22
	l2.star_thresholds = l2_stars
	l2.camera_yaw = 1
	l2.camera_zoom = 1
	result.append(l2)

	# 关卡 3：14×10，120 s，55 个贡品，26 格可放置区。
	var l3 := LevelData.new()
	l3.id = 3
	l3.display_name = "加工与损耗"
	l3.grid_size = Vector2i(14, 10)
	l3.time_limit = 120.0
	l3.goal_form = "Offer"
	l3.goal_amount = 55
	l3.start_spirit = 50
	var l3_cells: Array[Vector2i] = []
	l3_cells.append_array(_rect(2, 6, 2, 6))
	l3_cells.append_array(_rect(8, 10, 2, 4))
	l3_cells.append_array(_rect(9, 11, 6, 9))
	l3.placeable_cells = l3_cells
	# 生产专属区：左上 A 区顶排 4 格，与第 2 关「生产带在最上面」的教学一致；
	# 参考解的四只生产鬼正好摆在这排，采集鬼 / 中转鬼 / 处理鬼全在下方蓝格。
	var l3_producer: Array[Vector2i] = _rect(2, 6, 2, 3)
	l3.producer_only_cells = l3_producer
	l3.obstacle_cells = [
		Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4), Vector2i(7, 2),
		Vector2i(7, 3), Vector2i(7, 4), Vector2i(6, 5), Vector2i(7, 5),
	]
	var l3_facilities: Array[FacilityPlacement] = []
	var l3_storage := FacilityPlacement.new()
	l3_storage.kind = FacilityPlacement.KIND_STORAGE
	l3_storage.cell = Vector2i(1, 8)
	l3_storage.accepted_form = "Spirit"
	l3_storage.facing = Vector2i.RIGHT
	l3_facilities.append(l3_storage)
	var l3_delivery := FacilityPlacement.new()
	l3_delivery.kind = FacilityPlacement.KIND_DELIVERY
	l3_delivery.cell = Vector2i(12, 2)
	l3_delivery.accepted_form = "Offer"
	l3_delivery.facing = Vector2i.LEFT
	l3_facilities.append(l3_delivery)
	l3.preplaced_facilities = l3_facilities
	var l3_allowed: Array[StringName] = [&"producer", &"collector", &"transporter", &"processor"]
	l3.allowed_ghost_ids = l3_allowed
	var l3_stars := StarThresholds.new()
	l3_stars.two_star_time = 105.0
	l3_stars.three_star_time = 90.0
	l3_stars.manual_limit = 100
	l3_stars.space_budget = 26
	l3.star_thresholds = l3_stars
	l3.camera_yaw = 1
	l3.camera_zoom = 2
	result.append(l3)

	# 关卡 4：14×10，150 s，60 个鬼能。推动链教学关：
	# 下方双车道走廊 + 顶墙底墙围出推链场，推舌鬼推守财鬼链产出掉落物，
	# 吊死鬼被推后荡回可当中继；采集鬼负责清走廊里的掉落物，否则推链被「掉落物占格」卡死。
	var l4 := LevelData.new()
	l4.id = 4
	l4.display_name = "推力与联动"
	l4.grid_size = Vector2i(14, 10)
	l4.time_limit = 150.0
	l4.goal_form = "Spirit"
	l4.goal_amount = 60
	l4.start_spirit = 80
	var l4_cells: Array[Vector2i] = []
	l4_cells.append_array(_rect(2, 10, 2, 6))
	l4_cells.append_array(_rect(2, 13, 8, 9))
	l4.placeable_cells = l4_cells
	# 生产专属区：主区顶排 4 格，延续第 2、3 关「生产带在最上面」的教学。
	var l4_producer: Array[Vector2i] = _rect(2, 6, 2, 3)
	l4.producer_only_cells = l4_producer
	# 走廊底墙：把 y=8 车道围成单行推链轨道，守财鬼被推只能沿走廊前进。
	var l4_obstacles: Array[Vector2i] = []
	for x in range(2, 13):
		l4_obstacles.append(Vector2i(x, 9))
	l4.obstacle_cells = l4_obstacles
	var l4_facilities: Array[FacilityPlacement] = []
	var l4_delivery := FacilityPlacement.new()
	l4_delivery.kind = FacilityPlacement.KIND_DELIVERY
	l4_delivery.cell = Vector2i(11, 2)
	l4_delivery.accepted_form = "Spirit"
	l4_delivery.facing = Vector2i.LEFT
	l4_facilities.append(l4_delivery)
	l4.preplaced_facilities = l4_facilities
	var l4_allowed: Array[StringName] = [
		&"producer", &"collector", &"transporter", &"pusher", &"miser", &"hang",
	]
	l4.allowed_ghost_ids = l4_allowed
	var l4_stars := StarThresholds.new()
	l4_stars.two_star_time = 120.0
	l4_stars.three_star_time = 100.0
	l4_stars.manual_limit = 100
	l4_stars.space_budget = 30
	l4.star_thresholds = l4_stars
	l4.camera_yaw = 1
	l4.camera_zoom = 2
	result.append(l4)

	return result

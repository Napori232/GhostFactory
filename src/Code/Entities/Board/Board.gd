class_name Board
extends Node

## 棋盘根：规则层的唯一权威状态。持有网格占用、鬼实例、掉落物、连线、鬼能池与关卡进度。
## 所有判定只认 Vector2i 格坐标；3D 表现层只通过 GetStateSnapshot() 做只读投影。
## 跨实体通知统一走 SignalBus；因 GhostInstance 是 RefCounted 而非 Node，
## 既有信号里的 Node 型实体参数一律传本 Board 节点，真实位置由状态快照提供。

## 关卡资源路径模板。
const LEVEL_PATH: String = "res://Code/Data/Levels/Level%02d.tres"
## 鬼资源目录。新增一只鬼只需往这里丢一份 .tres，核心层不用改
## （Docs/PhysicsLayer.md §5「新增一只鬼 = 一个 .tres + 一个 Behavior 类」）。
const GHOST_DIR: String = "res://Code/Data/Ghosts/"
## 目录列举不可用时的兜底清单（导出包或异常环境下使用）。
const GHOST_PATHS: Array[String] = [
	"res://Code/Data/Ghosts/Producer.tres",
	"res://Code/Data/Ghosts/Collector.tres",
	"res://Code/Data/Ghosts/Transporter.tres",
	"res://Code/Data/Ghosts/Processor.tres",
	"res://Code/Data/Ghosts/Pusher.tres",
	"res://Code/Data/Ghosts/Miser.tres",
	"res://Code/Data/Ghosts/Hang.tres",
]

var level: LevelData = null
var grid: BoardGrid = null
var ghost_library: Dictionary = {}
var ghosts: Array[GhostInstance] = []
var connections: ConnectionLayer = null
var spirit: int = 0
var delivered: int = 0
var manual_count: int = 0
var elapsed: float = 0.0
var completed: bool = false
var failed: bool = false
var stars: int = 0
var revision: int = 0
var rng := RandomNumberGenerator.new()

var _next_uid: int = 1
var _tick_acc: float = 0.0
var _timer_acc: float = 0.0

## 载入全部鬼的静态配置表：优先扫目录，扫不到时退回固定清单。
## @return 以 GhostData.id 为键的字典。
static func LoadGhostLibrary() -> Dictionary:
	var library: Dictionary = {}
	var dir := DirAccess.open(GHOST_DIR)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var scanned := load(GHOST_DIR + file_name) as GhostData
				if scanned != null:
					library[scanned.id] = scanned
			file_name = dir.get_next()
		dir.list_dir_end()
	if library.is_empty():
		for path in GHOST_PATHS:
			var data := load(path) as GhostData
			if data != null:
				library[data.id] = data
	return library

## 载入指定关卡的资源。
## @param level_id 关卡序号，从 1 开始。
## @return 关卡数据；不存在时返回 null。
static func LoadLevelData(level_id: int) -> LevelData:
	return load(LEVEL_PATH % level_id) as LevelData

## 装配一关的初始状态。
## @param level_data 关卡数据。
## @param library 鬼静态配置表，可由 LoadGhostLibrary() 取得。
func Setup(level_data: LevelData, library: Dictionary) -> void:
	level = level_data
	ghost_library = library
	grid = BoardGrid.new(level.grid_size, level.obstacle_cells, _facility_cells())
	connections = ConnectionLayer.new()
	ghosts = []
	spirit = level.start_spirit
	delivered = 0
	manual_count = 0
	elapsed = 0.0
	completed = false
	failed = false
	stars = 0
	revision = 0
	_next_uid = 1
	_tick_acc = 0.0
	_timer_acc = 0.0
	# 固定种子：掉落分布可复现，脚本化通关测试不依赖运气。
	rng.seed = 20261110
	for placement in level.preplaced_ghosts:
		if placement != null and ghost_library.has(placement.ghost_id):
			_place_free(placement.ghost_id, placement.cell, placement.state)
	MarkChanged()

## 取全部预置设施所在格。
## @return 格坐标数组。
func _facility_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for facility in level.preplaced_facilities:
		if facility != null:
			result.append(facility.cell)
	return result

## 状态版本号自增并广播，表现层据此决定是否重建视图。
func MarkChanged() -> void:
	revision += 1
	SignalBus.BoardStateChanged.emit(revision)

## 推进模拟一段真实时间，内部拆成固定 tick 结算。
## @param delta 推进的秒数；测试可一次传入整关时长做脚本化快进。
func Advance(delta: float) -> void:
	if level == null or completed or failed:
		return
	var tick := 1.0 / maxf(ExportSettings.sim_tick_rate, 1.0)
	_tick_acc += maxf(delta, 0.0)
	var guard := 0
	while _tick_acc >= tick and guard < 200000:
		_tick_acc -= tick
		_step(tick)
		guard += 1
		if completed or failed:
			break

## 结算一个 tick：计时 → 鬼行为 → 连线搬运 → 胜负判定。
## @param dt 本 tick 时长，单位：秒。
func _step(dt: float) -> void:
	elapsed += dt
	_timer_acc += dt
	if _timer_acc >= 0.1:
		_timer_acc -= 0.1
		SignalBus.LevelTimerTick.emit(maxf(level.time_limit - elapsed, 0.0))
	BoardRunner.RunTick(self, dt)
	if delivered >= level.goal_amount and not completed:
		_complete()
	elif elapsed >= level.time_limit and not failed:
		_fail()

## 达成目标：按效率 / 手动 / 空间三轴算星级并广播通关。
func _complete() -> void:
	completed = true
	stars = LevelGoal.CalculateStars(level, elapsed, manual_count, grid.UsedPlaceableCount(level))
	SignalBus.LevelCompleted.emit(level.id, stars)
	MarkChanged()

## 倒计时耗尽：广播失败。
func _fail() -> void:
	failed = true
	SignalBus.LevelFailed.emit(level.id)
	MarkChanged()

## 判断一只鬼能否放在指定格。
## @param ghost_id 鬼的资源 id。
## @param cell 本体原点格坐标。
## @return 全部校验通过时返回 true。
func CanPlace(ghost_id: StringName, cell: Vector2i) -> bool:
	if level == null or grid == null or not level.IsGhostAllowed(ghost_id):
		return false
	var data := ghost_library.get(ghost_id) as GhostData
	if data == null or spirit < data.cost:
		return false
	var has_zone := level.HasProducerZone()
	var is_producer := data.category == GhostData.CATEGORY_PRODUCTION
	for occupied in data.GetFootprintAt(cell):
		if not GridUtil.InBounds(occupied, level.grid_size):
			return false
		if not level.IsPlaceable(occupied):
			return false
		if not grid.IsFree(occupied):
			return false
		# 生产专属区：生产鬼只能落在区内，其余鬼一律不得占用。
		if has_zone:
			var in_zone := level.IsProducerOnly(occupied)
			if is_producer and not in_zone:
				return false
			if not is_producer and in_zone:
				return false
	return true

## 放置一只鬼并扣除造价。
## @param ghost_id 鬼的资源 id。
## @param cell 本体原点格坐标。
## @return 新实例；校验失败时返回 null。
func PlaceGhost(ghost_id: StringName, cell: Vector2i) -> GhostInstance:
	if not CanPlace(ghost_id, cell):
		return null
	var data := ghost_library.get(ghost_id) as GhostData
	spirit -= data.cost
	SignalBus.SpiritChanged.emit(spirit)
	var ghost := _place_free(ghost_id, cell, GhostInstance.STATE_IDLE)
	SignalBus.GhostPlaced.emit(self)
	MarkChanged()
	return ghost

## 不扣费地放置一只鬼（预置鬼与存档还原用）。
## @param ghost_id 鬼的资源 id。
## @param cell 本体原点格坐标。
## @param initial_state 初始状态。
## @return 新实例；资源缺失时返回 null。
func _place_free(ghost_id: StringName, cell: Vector2i, initial_state: StringName) -> GhostInstance:
	var data := ghost_library.get(ghost_id) as GhostData
	if data == null:
		return null
	var ghost := GhostInstance.new(data, cell, _next_uid)
	_next_uid += 1
	ghost.state = initial_state
	ghosts.append(ghost)
	for occupied in data.GetFootprintAt(cell):
		grid.SetGhost(occupied, ghost)
	return ghost

## 拆除指定格上的鬼，按设置全额退还造价，并清掉相关连线。
## @param cell 鬼所在格。
## @return 拆除成功返回 true。
func RemoveGhostAt(cell: Vector2i) -> bool:
	var ghost := GetGhostAt(cell)
	if ghost == null:
		return false
	for occupied in ghost.data.GetFootprintAt(ghost.cell):
		grid.ClearGhost(occupied)
	ghosts.erase(ghost)
	connections.RemoveLinksOf(ghost.uid)
	if ExportSettings.build_refund_on_remove:
		AddSpirit(ghost.data.cost)
	SignalBus.GhostRemoved.emit(self)
	MarkChanged()
	return true

## 把一只已放置的柔体鬼沿推动方向挪一格（推动链专用，Docs/GameDesign.md §8.3）。
## 位移后原有连线会错位，按「被推离原设计位就是布局失误的代价」一并拆除。
## @param ghost 待移动的鬼实例。
## @param target 目标原点格坐标。
## @return 移动成功返回 true。
func MoveGhost(ghost, target: Vector2i) -> bool:
	if ghost == null:
		return false
	var next_cells: Array[Vector2i] = ghost.data.GetFootprintAt(target)
	for cell in next_cells:
		if not GridUtil.InBounds(cell, level.grid_size):
			return false
		if grid.obstacles.has(cell) or grid.facility_cells.has(cell):
			return false
		if grid.GetItemAt(cell) != null:
			return false
		var occupant = grid.GetGhostAt(cell)
		if occupant != null and occupant != ghost:
			return false
	for cell in ghost.data.GetFootprintAt(ghost.cell):
		grid.ClearGhost(cell)
	ghost.cell = target
	for cell in next_cells:
		grid.SetGhost(cell, ghost)
	connections.RemoveLinksOf(ghost.uid)
	SignalBus.GhostPushed.emit(self, ghost)
	MarkChanged()
	return true

## 按待机 → 运行 → 暂停 → 待机循环切换鬼的状态；故障点击后恢复待机。
## @param cell 鬼所在格。
## @return 切换后的状态；格子为空时返回空标签。
func CycleGhostStateAt(cell: Vector2i) -> StringName:
	var ghost := GetGhostAt(cell)
	if ghost == null:
		return &""
	var new_state := ghost.CycleState()
	SignalBus.GhostStateChanged.emit(self, new_state)
	MarkChanged()
	return new_state

## 直接设置鬼的状态（脚本化测试与存档还原用）。
## @param cell 鬼所在格。
## @param new_state 目标状态。
## @return 设置成功返回 true。
func SetGhostStateAt(cell: Vector2i, new_state: StringName) -> bool:
	var ghost := GetGhostAt(cell)
	if ghost == null:
		return false
	ghost.state = new_state
	if new_state != GhostInstance.STATE_FAULT:
		ghost.fault_timer = 0.0
	SignalBus.GhostStateChanged.emit(self, new_state)
	MarkChanged()
	return true

## 让一只鬼进入故障并广播。
## @param ghost 待故障的鬼实例。
func SetFault(ghost) -> void:
	if ghost == null or ghost.state == GhostInstance.STATE_FAULT:
		return
	ghost.state = GhostInstance.STATE_FAULT
	SignalBus.GhostFaulted.emit(self)
	SignalBus.GhostStateChanged.emit(self, GhostInstance.STATE_FAULT)
	MarkChanged()

## 手动拾取某格的掉落物，数量进全局鬼能池；不计入手动次数（D5）。
## @param cell 掉落物所在格。
## @return 拾取到的件数；格子为空返回 0。
func PickupItemAt(cell: Vector2i) -> int:
	var item = grid.GetItemAt(cell)
	if item == null:
		return 0
	var amount := int(item.amount)
	grid.ClearItem(cell)
	AddSpirit(amount)
	SignalBus.SpiritPicked.emit(amount)
	MarkChanged()
	return amount

## 从鬼能池向交付口交付 1 件；每次交付计入手动次数（D5）。
## @param facility_cell 交付口所在格。
## @return 交付成功返回 true。
func DeliverFromPool(facility_cell: Vector2i) -> bool:
	var facility := GetFacilityAt(facility_cell)
	if facility == null or facility.kind != FacilityPlacement.KIND_DELIVERY:
		return false
	if spirit < 1:
		return false
	spirit -= 1
	SignalBus.SpiritChanged.emit(spirit)
	return DeliverToFacility("Spirit", facility, true)

## 把地面掉落物直接送进交付口；每次交付计入手动次数（D5）。
## @param item_cell 掉落物所在格。
## @param facility_cell 交付口所在格。
## @return 交付成功返回 true。
func DeliverGroundItem(item_cell: Vector2i, facility_cell: Vector2i) -> bool:
	var item = grid.GetItemAt(item_cell)
	var facility := GetFacilityAt(facility_cell)
	if item == null or facility == null:
		return false
	var form := String(item.form)
	if not ConsumeItem(item_cell, 1):
		return false
	return DeliverToFacility(form, facility, true)

## 向设施送入一件物品（连线自动交付也走这里，但不计手动次数）。
## 仓库口转成建造货币；交付口形态不符则转为杂质落地。
## @param form 形态 id。
## @param facility 设施定义。
## @param is_manual 是否由玩家手动发起，决定是否计入手动轴。
## @return 物品被接收时返回 true。
func DeliverToFacility(form: String, facility, is_manual: bool) -> bool:
	if facility == null:
		return false
	if facility.kind == FacilityPlacement.KIND_STORAGE:
		AddSpirit(1)
		return true
	if form != facility.accepted_form:
		SpawnImpurityNear(facility.cell)
		return true
	delivered += 1
	if is_manual:
		manual_count += 1
	SignalBus.ItemDelivered.emit(form, self)
	SignalBus.OfferScored.emit(delivered, level.goal_amount)
	MarkChanged()
	return true

## 鬼能池增减并广播。
## @param amount 变化量，可为负数。
func AddSpirit(amount: int) -> void:
	spirit = maxi(0, spirit + amount)
	SignalBus.SpiritChanged.emit(spirit)
	MarkChanged()

## 在指定格生成（或堆叠）掉落物。
## @param cell 所在格。
## @param form 形态 id。
## @param amount 件数。
func SpawnItem(cell: Vector2i, form: String, amount: int) -> void:
	if not GridUtil.InBounds(cell, level.grid_size):
		return
	var item = grid.GetItemAt(cell)
	if item != null:
		item.amount += amount
	else:
		grid.SetItem(cell, DroppedItem.new(cell, form, amount))
	MarkChanged()

## 消耗某格掉落物的若干件。
## @param cell 所在格。
## @param amount 消耗件数。
## @return 消耗成功返回 true。
func ConsumeItem(cell: Vector2i, amount: int) -> bool:
	var item = grid.GetItemAt(cell)
	if item == null:
		return false
	item.amount -= amount
	if item.amount <= 0:
		grid.ClearItem(cell)
	MarkChanged()
	return true

## 在指定格附近生成一件杂质；四邻全满时不生成，避免把链路彻底堵死。
## @param near_cell 参考格。
func SpawnImpurityNear(near_cell: Vector2i) -> void:
	var candidates := grid.GetEmptyNeighbors(near_cell)
	if candidates.is_empty():
		return
	var cell: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	SpawnItem(cell, "Impurity", 1)
	SignalBus.ImpurityCreated.emit(cell)

## 取某只鬼当前的有效搜索区（LevelDesign 吞吐核对以 3×3 / 9 格为基准）。
## @param ghost 鬼实例。
## @return 绝对格坐标数组。
func GetSearchCells(ghost) -> Array[Vector2i]:
	if not ghost.search_cells.is_empty():
		return ghost.search_cells
	if not ghost.data.search_area.is_empty():
		var cells: Array[Vector2i] = []
		for cell in GridUtil.Translate(ghost.data.search_area, ghost.cell):
			if GridUtil.InBounds(cell, level.grid_size):
				cells.append(cell)
		return cells
	var result: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell: Vector2i = ghost.cell + Vector2i(dx, dy)
			if GridUtil.InBounds(cell, level.grid_size):
				result.append(cell)
	return result

## 为一只鬼设置框选搜索区。
## @param cell 鬼所在格。
## @param cells 绝对格坐标数组。
## @return 设置成功返回 true。
func SetSearchArea(cell: Vector2i, cells: Array[Vector2i]) -> bool:
	var ghost := GetGhostAt(cell)
	if ghost == null:
		return false
	ghost.search_cells = cells.duplicate()
	MarkChanged()
	return true

## 连接两只鬼的输出端口与输入端口。
## 采集鬼空缓冲时允许按「地面可能物料」预接线，运行时搬运仍以实际缓冲内容为准。
## @param from_cell 上游鬼所在格。
## @param to_cell 下游鬼所在格。
## @return 连线成功返回 true。
func ConnectGhosts(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var from := GetGhostAt(from_cell)
	var to := GetGhostAt(to_cell)
	if from == null or to == null or from == to:
		return false
	var out_port := from.data.GetOutputPort()
	var in_port := to.data.GetInputPort()
	if out_port == null or in_port == null:
		return false
	var tags := _output_tags_for(from, out_port)
	if not GhostTag.CanConnect(tags, in_port.accepts):
		return false
	if connections.HasLink(from.uid, to_cell):
		return false
	var path := _find_link_path(from.cell, to_cell)
	if path.is_empty():
		return false
	connections.AddLink(from.uid, to.uid, from.cell, to_cell, path)
	SignalBus.LineCreated.emit(self, self)
	MarkChanged()
	return true

## 把一只鬼的输出端口连到关卡预置设施（交付口 / 仓库口）。
## @param from_cell 上游鬼所在格。
## @param facility_cell 设施所在格。
## @return 连线成功返回 true。
func ConnectToFacility(from_cell: Vector2i, facility_cell: Vector2i) -> bool:
	var from := GetGhostAt(from_cell)
	var facility := GetFacilityAt(facility_cell)
	if from == null or facility == null:
		return false
	var out_port := from.data.GetOutputPort()
	if out_port == null:
		return false
	var accepted := ConnectionLayer.FormToInputTags(facility.accepted_form)
	if not GhostTag.CanConnect(_output_tags_for(from, out_port), accepted):
		return false
	if connections.HasLink(from.uid, facility_cell):
		return false
	var path := _find_link_path(from.cell, facility_cell)
	if path.is_empty():
		return false
	connections.AddLink(from.uid, ConnectionLayer.NO_GHOST, from.cell, facility_cell, path)
	SignalBus.LineCreated.emit(self, self)
	MarkChanged()
	return true

## 判断某对起点 → 终点是否已经连好，用于「再点一下就拆线」的切换判定。
## @param from_cell 上游鬼所在格。
## @param to_cell 下游鬼或设施所在格。
## @return 已存在连线返回 true。
func HasLink(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if connections == null:
		return false
	var from := GetGhostAt(from_cell)
	return from != null and connections.HasLink(from.uid, to_cell)

## 拆除一条指定起点 → 终点的连线；不改动任何鬼或设施。
## @param from_cell 上游鬼所在格。
## @param to_cell 下游鬼或设施所在格。
## @return 拆除成功返回 true。
func RemoveLink(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if connections == null:
		return false
	var from := GetGhostAt(from_cell)
	if from == null or not connections.RemoveLink(from.uid, to_cell):
		return false
	SignalBus.LineRemoved.emit(self)
	MarkChanged()
	return true

## 拆除一条线身经过指定格的连线（点击线身拆线）。
## @param cell 被点击的格坐标。
## @return 拆除成功返回 true。
func RemoveLinkAtCell(cell: Vector2i) -> bool:
	if connections == null or not connections.RemoveLinkPassing(cell):
		return false
	SignalBus.LineRemoved.emit(self)
	MarkChanged()
	return true

## 判断某格是否可被当作「线身」点击拆除：有线经过且该格不是鬼 / 设施端点。
## @param cell 待判断的格坐标。
## @return 可拆返回 true。
func IsLinkBodyAt(cell: Vector2i) -> bool:
	if connections == null or GetGhostAt(cell) != null or GetFacilityAt(cell) != null:
		return false
	return connections.HasLinkPassing(cell)

## 计算一条连线路径：最多允许一次 90° 转弯的 L 形路径，且绕开障碍格（墙）。
## 两种 L 走向都撞墙时返回空数组，玩家必须放中转鬼把线路拆成两段。
## @param from_cell 起点格。
## @param to_cell 终点格。
## @return 路径格列表；无合法 L 形路径时返回空数组。
func _find_link_path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	if level == null:
		return []
	var blocked := func(cell: Vector2i) -> bool: return level.IsObstacle(cell)
	return GridUtil.PathOneTurn(from_cell, to_cell, blocked, level.grid_size)

## 计算一只鬼可用于连线判定的输出标签集合。
## @param ghost 鬼实例。
## @param out_port 输出端口定义。
## @return 物料标签数组。
func _output_tags_for(ghost, out_port: BoardPortDef) -> Array[StringName]:
	var tags := ConnectionLayer.DynamicOutputTags(ghost, out_port)
	if tags.is_empty() and ghost.data.category == GhostData.CATEGORY_COLLECTION:
		# 采集鬼尚未采到东西时，按地面可能出现的物料允许预接线（D2 的可玩性落地）。
		var possible: Array[StringName] = [GhostTag.SPIRIT, GhostTag.IMPURITY]
		return possible
	return tags

## 取某格上的鬼实例。
## @param cell 待查询的格坐标。
## @return 鬼实例；没有返回 null。
func GetGhostAt(cell: Vector2i) -> GhostInstance:
	if grid == null:
		return null
	return grid.GetGhostAt(cell) as GhostInstance

## 取某格上的掉落物。
## @param cell 待查询的格坐标。
## @return 掉落物实例；没有返回 null。
func GetItemAt(cell: Vector2i) -> DroppedItem:
	if grid == null:
		return null
	return grid.GetItemAt(cell) as DroppedItem

## 取某格上的预置设施。
## @param cell 待查询的格坐标。
## @return 设施定义；没有返回 null。
func GetFacilityAt(cell: Vector2i) -> FacilityPlacement:
	return level.GetFacilityAt(cell) if level != null else null

## 按实例编号找鬼。
## @param uid 实例编号。
## @return 鬼实例；没有返回 null。
func FindGhostByUid(uid: int) -> GhostInstance:
	for ghost in ghosts:
		if ghost.uid == uid:
			return ghost
	return null

## 产出表现层用的只读状态快照。3D 视图只消费这份数据，不改任何规则状态。
## @return 含关卡、鬼、掉落物、设施、连线与计分的字典。
func GetStateSnapshot() -> Dictionary:
	var ghost_list: Array[Dictionary] = []
	for ghost in ghosts:
		ghost_list.append({
			"uid": ghost.uid,
			"id": String(ghost.data.id),
			"name": ghost.data.display_name,
			"category": String(ghost.data.category),
			"cell": ghost.cell,
			"state": String(ghost.state),
			"color": ghost.data.color,
			"input_count": ghost.input_buffer.size(),
			"output_count": ghost.output_buffer.size(),
			"cost": ghost.data.cost,
		})
	var item_list: Array[Dictionary] = []
	for cell in grid.GetAllItemCells():
		var item = grid.GetItemAt(cell)
		if item != null:
			item_list.append({"cell": cell, "form": String(item.form), "amount": int(item.amount)})
	var facility_list: Array[Dictionary] = []
	for facility in level.preplaced_facilities:
		if facility != null:
			facility_list.append({
				"cell": facility.cell,
				"kind": String(facility.kind),
				"accepted_form": facility.accepted_form,
			})
	var link_list: Array[Dictionary] = []
	for link in connections.links:
		link_list.append({"from_cell": link["from_cell"], "to_cell": link["to_cell"], "path": link["path"]})
	return {
		"revision": revision,
		"level_id": level.id,
		"level_name": level.display_name,
		"grid_size": level.grid_size,
		"placeable": level.placeable_cells.duplicate(),
		"producer_only": level.GetProducerOnlyCells(),
		"obstacles": level.obstacle_cells.duplicate(),
		"facilities": facility_list,
		"allowed": level.GetAllowedGhostIds(),
		"goal_form": level.goal_form,
		"goal_amount": level.goal_amount,
		"time_limit": level.time_limit,
		"time_left": maxf(level.time_limit - elapsed, 0.0),
		"elapsed": elapsed,
		"spirit": spirit,
		"delivered": delivered,
		"manual_count": manual_count,
		"ghosts": ghost_list,
		"items": item_list,
		"links": link_list,
		"completed": completed,
		"failed": failed,
		"stars": stars,
	}

## 导出棋盘存档。
## @return 含关卡号、进度与全部实体的字典。
func ExportSaveData() -> Dictionary:
	var ghost_data: Array[Dictionary] = []
	for ghost in ghosts:
		ghost_data.append(ghost.ExportSaveData())
	var item_data: Array[Dictionary] = []
	for cell in grid.GetAllItemCells():
		item_data.append(grid.GetItemAt(cell).ExportSaveData())
	return {
		"level_id": level.id,
		"spirit": spirit,
		"delivered": delivered,
		"manual_count": manual_count,
		"elapsed": elapsed,
		"next_uid": _next_uid,
		"ghosts": ghost_data,
		"items": item_data,
		"links": connections.ExportSaveData(),
	}

## 从存档还原棋盘；鬼静态配置按存档里的 ghost_id 从配置表重建。
## @param saved 由 ExportSaveData 产出的字典。
## @return 还原成功返回 true。
func LoadSaveData(saved: Dictionary) -> bool:
	if level == null:
		return false
	grid = BoardGrid.new(level.grid_size, level.obstacle_cells, _facility_cells())
	connections = ConnectionLayer.new()
	ghosts = []
	spirit = int(saved.get("spirit", 0))
	delivered = int(saved.get("delivered", 0))
	manual_count = int(saved.get("manual_count", 0))
	elapsed = float(saved.get("elapsed", 0.0))
	completed = false
	failed = false
	stars = 0
	for entry in saved.get("ghosts", []):
		var ghost_id := StringName(String(entry.get("ghost_id", "")))
		if not ghost_library.has(ghost_id):
			continue
		var pos: Array = entry.get("cell", [0, 0])
		var ghost := _place_free(ghost_id, Vector2i(int(pos[0]), int(pos[1])), GhostInstance.STATE_IDLE)
		if ghost != null:
			ghost.LoadSaveData(entry)
	for entry in saved.get("items", []):
		var item := DroppedItem.new(Vector2i.ZERO, "Spirit", 1)
		item.LoadSaveData(entry)
		grid.SetItem(item.cell, item)
	connections.LoadSaveData(saved.get("links", []))
	_next_uid = int(saved.get("next_uid", ghosts.size() + 1))
	MarkChanged()
	return true

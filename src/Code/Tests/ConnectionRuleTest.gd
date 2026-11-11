extends Node

## 连线规则测试：物料标签判定、动作标签不参与、设施接收形态、重复连线拒绝、
## 以及「一条线最多一次 90° 转弯」与「墙逼出中转鬼」的新规则。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/ConnectionRuleTest.tscn

var _checks: int = 0
var _failures: int = 0

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("---- 结果：%d 项断言，%d 项失败" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## 记录一条断言。
## @param condition 断言条件。
## @param label 断言说明。
func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		_failures += 1
		print("FAIL: %s" % label)
		push_error("FAIL: %s" % label)

## 构造一个已装配的棋盘。
## @param level_id 关卡序号。
## @return 棋盘实例。
func _make_board(level_id: int) -> Board:
	var board := Board.new()
	board.Setup(Board.LoadLevelData(level_id), Board.LoadGhostLibrary())
	return board

## 中央墙的通行判定回调。
## @param cell 待判断格。
## @return 是障碍时返回 true。
func _wall(cell: Vector2i) -> bool:
	return Board.LoadLevelData(2).IsObstacle(cell)

## 依次验证连线规则。
func _run() -> void:
	var spirit_out: Array[StringName] = [GhostTag.SPIRIT]
	var offer_in: Array[StringName] = [GhostTag.OFFER]
	var action_only: Array[StringName] = [GhostTag.HAUL, GhostTag.GROUND]
	_check(GhostTag.CanConnect(spirit_out, [GhostTag.SPIRIT]), "SPIRIT 输出 → SPIRIT 输入可连")
	_check(not GhostTag.CanConnect(spirit_out, offer_in), "SPIRIT 输出 → 仅收 OFFER 的输入不可连")
	_check(not GhostTag.CanConnect(action_only, [GhostTag.SPIRIT]), "动作标签不参与连线判定（D1）")

	# 关卡 2：生产专属格 + 交付口上移到 (10,3) + 只许一次转弯。
	var l2 := _make_board(2)
	_check(not l2.CanPlace(&"collector", Vector2i(2, 3)), "生产专属格不允许放采集鬼")
	_check(l2.PlaceGhost(&"collector", Vector2i(2, 4)) != null, "关卡 2 在蓝格放下采集鬼")
	_check(l2.PlaceGhost(&"transporter", Vector2i(8, 6)) != null, "关卡 2 在右下 C 区放下中转运输鬼")
	_check(l2.ConnectGhosts(Vector2i(2, 4), Vector2i(8, 6)), "采集鬼 → 中转鬼可连（绕过中央墙的一次转弯）")
	_check(not l2.ConnectGhosts(Vector2i(2, 4), Vector2i(8, 6)), "重复连线被拒绝")
	_check(not l2.ConnectGhosts(Vector2i(8, 6), Vector2i(2, 4)), "采集鬼没有输入端口，反向不可连")
	_check(not l2.ConnectToFacility(Vector2i(2, 4), Vector2i(10, 3)), "采集鬼 → 交付口直连被墙挡住（必须中转）")
	_check(l2.ConnectToFacility(Vector2i(8, 6), Vector2i(10, 3)), "中转鬼 → 交付口可连")
	_check(l2.ConnectToFacility(Vector2i(8, 6), Vector2i(1, 7)), "中转鬼 → 仓库口（Spirit）可连")
	_check(not l2.ConnectToFacility(Vector2i(2, 4), Vector2i(5, 5)), "非设施格不可连线")
	_check(l2.GetStateSnapshot()["links"].size() == 3, "状态快照含 3 条连线")
	for link in l2.connections.links:
		_check(GridUtil.CountTurns(link["path"]) <= 1, "连线 %s → %s 转弯不超过 1 次" % [link["from_cell"], link["to_cell"]])

	# 关卡 3：中央 8 格大墙同样逼出中转鬼。
	var l3 := _make_board(3)
	_check(not l3.CanPlace(&"collector", Vector2i(2, 2)), "关卡 3 生产带不允许放采集鬼")
	_check(l3.PlaceGhost(&"collector", Vector2i(2, 3)) != null, "关卡 3 蓝格放下采集鬼")
	_check(l3.PlaceGhost(&"transporter", Vector2i(9, 6)) != null, "关卡 3 放下中转运输鬼")
	_check(l3.PlaceGhost(&"processor", Vector2i(8, 2)) != null, "关卡 3 放下处理鬼")
	_check(not l3.ConnectGhosts(Vector2i(2, 3), Vector2i(8, 2)), "采集鬼 → 处理鬼直连被中央大墙阻断")
	_check(l3.ConnectGhosts(Vector2i(2, 3), Vector2i(9, 6)), "采集鬼 → 中转鬼可连")
	_check(l3.ConnectGhosts(Vector2i(9, 6), Vector2i(8, 2)), "中转鬼 → 处理鬼可连")
	_check(l3.ConnectToFacility(Vector2i(8, 2), Vector2i(12, 2)), "处理鬼 → 贡品交付口可连")
	_check(l3.PlaceGhost(&"collector", Vector2i(9, 2)) != null, "关卡 3 右侧放下采集鬼做标签用例")
	_check(not l3.ConnectToFacility(Vector2i(9, 2), Vector2i(12, 2)), "采集鬼物料标签与贡品交付口不匹配，拒绝接线")
	_check(l3.PlaceGhost(&"transporter", Vector2i(9, 3)) != null, "关卡 3 右侧放下运输鬼")
	_check(l3.ConnectToFacility(Vector2i(9, 3), Vector2i(12, 2)), "运输鬼可连贡品交付口")

	# 一次转弯规则：两条 L 走向都撞墙就拒绝，绝不折返绕行。
	var blocked := func(cell: Vector2i) -> bool: return _wall(cell)
	var bounds := Vector2i(12, 9)
	var direct := GridUtil.PathOneTurn(Vector2i(2, 4), Vector2i(10, 3), blocked, bounds)
	_check(direct.is_empty(), "左上区 → 交付口 (10,3) 两条 L 形都穿墙，直连被拒")
	_check(
		not GridUtil.PathAvoiding(Vector2i(2, 4), Vector2i(10, 3), blocked, bounds).is_empty(),
		"旧 BFS 寻路仍能找到折返绕行路径（说明新规则不是无解）"
	)
	_check(
		GridUtil.CountTurns(GridUtil.PathAvoiding(Vector2i(2, 4), Vector2i(10, 3), blocked, bounds)) > 1,
		"旧绕行路径转弯超过 1 次，正是被新规则禁止的走法"
	)
	var hop1 := GridUtil.PathOneTurn(Vector2i(2, 4), Vector2i(8, 6), blocked, bounds)
	var hop2 := GridUtil.PathOneTurn(Vector2i(8, 6), Vector2i(10, 3), blocked, bounds)
	_check(not hop1.is_empty() and not hop2.is_empty(), "拆成两段后每段都有合法 L 形路径")
	_check(GridUtil.CountTurns(hop1) == 1 and GridUtil.CountTurns(hop2) == 1, "两段各转一次 90°")
	var clean := true
	for cell in hop1:
		if _wall(cell):
			clean = false
	for cell in hop2:
		if _wall(cell):
			clean = false
	_check(clean, "两段路径都不穿墙")
	_check(GridUtil.CountTurns(GridUtil.PathL(Vector2i(2, 2), Vector2i(6, 2))) == 0, "直线 0 次转弯")
	_check(GridUtil.CountTurns(GridUtil.PathL(Vector2i(2, 2), Vector2i(6, 5))) == 1, "L 形 1 次转弯")

	var barrier := func(cell: Vector2i) -> bool: return cell.y == 4
	_check(
		GridUtil.PathOneTurn(Vector2i(2, 2), Vector2i(2, 6), barrier, bounds).is_empty(),
		"横贯全图的墙：一次转弯无法绕过"
	)
	_check(
		GridUtil.PathAvoiding(Vector2i(2, 2), Vector2i(2, 6), barrier, bounds).is_empty(),
		"横贯全图的墙把两点完全隔断时找不到路径"
	)
	_check(
		GridUtil.PathAvoiding(Vector2i(2, 2), Vector2i(6, 2), barrier, bounds).size() > 0,
		"不跨墙的两点仍可正常寻路"
	)
	_check(
		GridUtil.PathOneTurn(Vector2i(2, 2), Vector2i(6, 2), barrier, bounds).size() > 0,
		"不跨墙的直线仍可一次转弯建线"
	)

	await _test_remove_links(l2)

## 拆线：同一对起点终点再点一次即拆，点线身也可拆，拆完能重连。
## @param l2 已布好线的关卡 2 棋盘。
func _test_remove_links(l2: Board) -> void:
	var before := l2.connections.links.size()
	_check(l2.HasLink(Vector2i(8, 6), Vector2i(10, 3)), "拆线前能查到中转鬼 → 交付口的连线")
	_check(l2.RemoveLink(Vector2i(8, 6), Vector2i(10, 3)), "拆除指定起点终点的连线成功")
	_check(l2.connections.links.size() == before - 1, "拆线后连线数减 1")
	_check(not l2.HasLink(Vector2i(8, 6), Vector2i(10, 3)), "拆除后该对起终点不再有线")
	_check(not l2.RemoveLink(Vector2i(8, 6), Vector2i(10, 3)), "重复拆同一条线返回 false")
	_check(l2.ConnectToFacility(Vector2i(8, 6), Vector2i(10, 3)), "拆掉后可以重新接上同一条线")
	_check(not l2.HasLink(Vector2i(2, 4), Vector2i(99, 99)), "不存在的连线不会被误判")

	var body_cell := Vector2i(-1, -1)
	for link in l2.connections.links:
		for c in link["path"]:
			if l2.IsLinkBodyAt(c):
				body_cell = c
				break
		if body_cell.x >= 0:
			break
	_check(body_cell.x >= 0, "至少能找到一个可点击的线身格")
	if body_cell.x >= 0:
		var before_body := l2.connections.links.size()
		_check(l2.RemoveLinkAtCell(body_cell), "点击线身拆除经过它的连线")
		_check(l2.connections.links.size() == before_body - 1, "点线身拆线后连线数减 1")
	_check(not l2.RemoveLinkAtCell(Vector2i(-1, -1)), "空格上拆线返回 false")

	# 真实 Level 场景的点击链路：点两下建线，再点两下拆线。
	GlobalValue.SetPendingLevelId(2)
	var level_scene: PackedScene = load("res://Code/Entities/Level/Level.tscn")
	_check(level_scene != null, "关卡场景可加载")
	if level_scene == null:
		return
	var level = level_scene.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	var board: Board = level.board
	_check(board.PlaceGhost(&"collector", Vector2i(2, 4)) != null, "交互用例：放下采集鬼")
	_check(board.PlaceGhost(&"transporter", Vector2i(8, 6)) != null, "交互用例：放下中转鬼")
	level._on_connect_toggled(true)
	level._handle_connect_click(Vector2i(2, 4))
	level._handle_connect_click(Vector2i(8, 6))
	_check(board.connections.links.size() == 1, "交互用例：点起点 → 终点建出一条线")
	level._handle_connect_click(Vector2i(2, 4))
	level._handle_connect_click(Vector2i(8, 6))
	_check(board.connections.links.size() == 0, "交互用例：同一对起终点再点一次即拆线")
	level._handle_connect_click(Vector2i(2, 4))
	level._handle_connect_click(Vector2i(8, 6))
	var body: Vector2i = board.connections.links[0]["path"][1]
	level._handle_connect_click(body)
	_check(board.connections.links.size() == 0, "交互用例：接线模式下点线身也能拆线")
	level._handle_connect_click(Vector2i(2, 4))
	level._handle_connect_click(Vector2i(8, 6))
	_check(board.connections.links.size() == 1, "交互用例：再次建线用于普通模式拆线")
	level._on_connect_toggled(false)
	var body2: Vector2i = board.connections.links[0]["path"][1]
	level._handle_normal_click(body2)
	_check(board.connections.links.size() == 0, "交互用例：普通模式下点线身也能拆线")
	level.queue_free()

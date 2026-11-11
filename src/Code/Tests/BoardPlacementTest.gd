extends Node

## 棋盘骨架 headless 测试：放置校验、占格、掉落物、手动拾取、状态循环与拆除退还。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/BoardPlacementTest.tscn

var _checks: int = 0
var _failures: int = 0
var board: Board = null

func _ready() -> void:
	await get_tree().process_frame
	board = Board.new()
	board.Setup(Board.LoadLevelData(1), Board.LoadGhostLibrary())
	_run()
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

## 依次执行全部检查。
func _run() -> void:
	_check(board.CanPlace(&"producer", Vector2i(3, 4)), "可放置区内合法位可放")
	_check(not board.CanPlace(&"producer", Vector2i(4, 1)), "障碍格不可放")
	_check(not board.CanPlace(&"producer", Vector2i(0, 0)), "可放置区外不可放")
	_check(not board.CanPlace(&"collector", Vector2i(3, 4)), "关卡 1 白名单拒绝采集鬼")

	var ghost := board.PlaceGhost(&"producer", Vector2i(3, 4))
	_check(ghost != null, "生产鬼放置成功")
	_check(board.spirit == 25, "放置扣除造价 5 鬼能")
	_check(not board.CanPlace(&"producer", Vector2i(3, 4)), "已占用格不可重复放置")
	_check(board.GetGhostAt(Vector2i(3, 4)) == ghost, "占用表可反查鬼实例")
	_check(GridUtil.Overlap(ghost.data.GetFootprintAt(Vector2i(3, 4)), [Vector2i(3, 5)]).is_empty(), "相邻占位无交叠")

	board.SpawnItem(Vector2i(4, 4), "Spirit", 1)
	_check(board.GetItemAt(Vector2i(4, 4)) != null, "掉落物占一格")
	_check(not board.CanPlace(&"producer", Vector2i(4, 4)), "掉落物占格不可放鬼")
	_check(board.PickupItemAt(Vector2i(4, 4)) == 1, "手动拾取取走 1 件")
	_check(board.spirit == 26, "拾取后鬼能池 +1")

	_check(board.CycleGhostStateAt(Vector2i(3, 4)) == GhostInstance.STATE_RUNNING, "待机 → 运行")
	_check(board.CycleGhostStateAt(Vector2i(3, 4)) == GhostInstance.STATE_PAUSED, "运行 → 暂停")
	_check(board.CycleGhostStateAt(Vector2i(3, 4)) == GhostInstance.STATE_IDLE, "暂停 → 待机")

	_check(board.RemoveGhostAt(Vector2i(3, 4)), "拆除成功")
	_check(board.GetGhostAt(Vector2i(3, 4)) == null, "拆除后占用释放")
	_check(board.spirit == 31, "拆除全额退还 5 鬼能")
	_check(board.CanPlace(&"producer", Vector2i(3, 4)), "拆除后该格恢复可放")
	var snapshot := board.GetStateSnapshot()
	_check(snapshot["grid_size"] == Vector2i(10, 8), "状态快照含网格尺寸")
	_check(snapshot["goal_amount"] == 30, "状态快照含目标数")
	_check(snapshot.has("producer_only"), "状态快照含生产专属区")

	# 生产专属区：三关统一，生产鬼只能放专属格，其他鬼不得占用。
	_check(board.level.HasProducerZone(), "关卡 1 已划出生产专属区")
	_check(board.GetStateSnapshot()["producer_only"].size() == 6, "关卡 1 快照把 6 格生产带传给表现层")
	_check(board.CanPlace(&"producer", Vector2i(3, 4)), "关卡 1 中间排绿格可放生产鬼")
	_check(not board.CanPlace(&"producer", Vector2i(3, 3)), "关卡 1 蓝格不可放生产鬼")
	var l3 := Board.new()
	l3.Setup(Board.LoadLevelData(3), Board.LoadGhostLibrary())
	_check(l3.level.HasProducerZone(), "关卡 3 已划出生产专属区")
	_check(not l3.CanPlace(&"collector", Vector2i(2, 2)), "关卡 3 采集鬼不能占生产带")
	_check(l3.CanPlace(&"collector", Vector2i(2, 3)), "关卡 3 蓝格可放采集鬼")
	var l2 := Board.new()
	l2.Setup(Board.LoadLevelData(2), Board.LoadGhostLibrary())
	_check(l2.level.HasProducerZone(), "关卡 2 划出生产专属区")
	_check(l2.CanPlace(&"producer", Vector2i(2, 3)), "专属格可放生产鬼")
	_check(not l2.CanPlace(&"producer", Vector2i(2, 4)), "生产鬼不能放普通蓝格")
	_check(not l2.CanPlace(&"collector", Vector2i(2, 3)), "采集鬼不能占生产专属格")
	_check(l2.CanPlace(&"collector", Vector2i(2, 4)), "采集鬼可放普通蓝格")
	_check(l2.CanPlace(&"transporter", Vector2i(8, 6)), "中转鬼可放右下 C 区")
	_check(l2.PlaceGhost(&"producer", Vector2i(2, 4)) == null, "违规放置返回 null")
	_check(l2.GetStateSnapshot()["producer_only"].size() == 3, "状态快照把 3 格专属区传给表现层")

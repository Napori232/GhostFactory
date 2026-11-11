extends Node

## 关卡 3 脚本化通关测试：生产 → 采集 → 中转 → 处理 → 交付口，验证加工、损耗与贡品交付。
## 全局「只许一次 90° 转弯」后，中央 8 格大墙使采集鬼无法直连处理鬼，必须各挂一只中转鬼。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/Level03PlaythroughTest.tscn

var _checks: int = 0
var _failures: int = 0
var board: Board = null

func _ready() -> void:
	await get_tree().process_frame
	board = Board.new()
	board.Setup(Board.LoadLevelData(3), Board.LoadGhostLibrary())
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

## 生成矩形搜索区。
## @param x0 起始列（含）。
## @param x1 结束列（不含）。
## @param y0 起始行（含）。
## @param y1 结束行（不含）。
## @return 格坐标数组。
func _rect(x0: int, x1: int, y0: int, y1: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(y0, y1):
		for x in range(x0, x1):
			cells.append(Vector2i(x, y))
	return cells

## 玩家维护：把故障或停摆的鬼恢复到运行态。
func _maintain_ghosts() -> void:
	for ghost in board.ghosts:
		if ghost.state != GhostInstance.STATE_RUNNING:
			board.SetGhostStateAt(ghost.cell, GhostInstance.STATE_RUNNING)

## 搭建并跑通双线产线。
func _run() -> void:
	_check(board.level.HasProducerZone(), "关卡 3 已划出生产带")
	_check(not board.CanPlace(&"collector", Vector2i(2, 2)), "关卡 3 采集鬼不能占生产带")
	for cell in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]:
		_check(board.PlaceGhost(&"producer", cell) != null, "放下生产鬼 %s" % cell)
	_check(board.PlaceGhost(&"collector", Vector2i(2, 3)) != null, "放下采集鬼 A")
	_check(board.PlaceGhost(&"collector", Vector2i(3, 3)) != null, "放下采集鬼 B")
	_check(board.PlaceGhost(&"processor", Vector2i(8, 2)) != null, "放下处理鬼")
	_check(board.PlaceGhost(&"transporter", Vector2i(9, 6)) != null, "放下中转鬼 A")
	_check(board.PlaceGhost(&"transporter", Vector2i(10, 6)) != null, "放下中转鬼 B")
	_check(board.SetSearchArea(Vector2i(2, 3), _rect(1, 6, 1, 4)), "采集鬼 A 框选搜索区")
	_check(board.SetSearchArea(Vector2i(3, 3), _rect(1, 6, 1, 4)), "采集鬼 B 框选搜索区")
	_check(
		not board.ConnectGhosts(Vector2i(2, 3), Vector2i(8, 2)),
		"采集鬼 A 直连处理鬼被中央大墙阻断（一次转弯绕不过去）"
	)
	_check(board.ConnectGhosts(Vector2i(2, 3), Vector2i(9, 6)), "采集鬼 A → 中转鬼 A 连线")
	_check(board.ConnectGhosts(Vector2i(9, 6), Vector2i(8, 2)), "中转鬼 A → 处理鬼连线")
	_check(board.ConnectGhosts(Vector2i(3, 3), Vector2i(10, 6)), "采集鬼 B → 中转鬼 B 连线")
	_check(board.ConnectGhosts(Vector2i(10, 6), Vector2i(8, 2)), "中转鬼 B → 处理鬼连线")
	_check(board.ConnectToFacility(Vector2i(8, 2), Vector2i(12, 2)), "处理鬼 → 贡品交付口连线")
	_check(board.connections.links.size() == 5, "参考解共 5 段连线")
	for link in board.connections.links:
		_check(GridUtil.CountTurns(link["path"]) <= 1, "连线 %s → %s 只转一次 90°" % [link["from_cell"], link["to_cell"]])
	_maintain_ghosts()

	var rounds := 0
	while not board.completed and not board.failed and rounds < 120:
		board.Advance(2.0)
		_maintain_ghosts()
		rounds += 1

	_check(board.completed, "关卡 3 可通关")
	_check(board.delivered >= 55, "自动交付达 55 个贡品，实际 %d" % board.delivered)
	_check(board.elapsed < 120.0, "耗时 %.1f s < 120 s 时限" % board.elapsed)
	_check(not board.failed, "未触发超时失败")
	_check(board.manual_count == 0, "加工链路不产生手动交付次数")

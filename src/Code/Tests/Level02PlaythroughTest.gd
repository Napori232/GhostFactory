extends Node

## 关卡 2 脚本化通关测试（交付口上移 (10,3) + 只许一次 90° 转弯 + 生产专属格）：
## 参考解必须靠右下 C 区的一只中转运输鬼把线路拆成两段，否则两条 L 形都撞中央墙。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/Level02PlaythroughTest.tscn

var _checks: int = 0
var _failures: int = 0
var board: Board = null

func _ready() -> void:
	await get_tree().process_frame
	board = Board.new()
	board.Setup(Board.LoadLevelData(2), Board.LoadGhostLibrary())
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

## 玩家维护：把故障或停摆的鬼恢复到运行态（文档规定故障由玩家手动恢复）。
func _maintain_ghosts() -> void:
	for ghost in board.ghosts:
		if ghost.state != GhostInstance.STATE_RUNNING:
			board.SetGhostStateAt(ghost.cell, GhostInstance.STATE_RUNNING)

## 搭建并跑通「生产 → 采集 → 中转 → 交付」两段式产线。
func _run() -> void:
	_check(board.level.HasProducerZone(), "关卡 2 已划出生产专属区")
	_check(not board.CanPlace(&"producer", Vector2i(2, 4)), "生产鬼不能放普通蓝格")
	_check(not board.CanPlace(&"collector", Vector2i(2, 3)), "采集鬼不能占生产专属格")

	var producers := [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)]
	for cell in producers:
		_check(board.PlaceGhost(&"producer", cell) != null, "放下生产鬼 %s" % cell)
	_check(board.PlaceGhost(&"collector", Vector2i(2, 4)) != null, "放下采集鬼")
	_check(board.PlaceGhost(&"transporter", Vector2i(8, 6)) != null, "在右下 C 区放下中转运输鬼")
	_check(board.SetSearchArea(Vector2i(2, 4), _rect(1, 5, 2, 5)), "采集鬼框选 12 格搜索区")
	_check(
		not board.ConnectToFacility(Vector2i(2, 4), Vector2i(10, 3)),
		"采集鬼直连交付口失败：一次转弯绕不过中央墙"
	)
	_check(board.ConnectGhosts(Vector2i(2, 4), Vector2i(8, 6)), "采集鬼 → 中转鬼连线成功")
	_check(board.ConnectToFacility(Vector2i(8, 6), Vector2i(10, 3)), "中转鬼 → 交付口连线成功")
	_check(board.connections.links.size() == 2, "参考解共 2 段连线")
	for link in board.connections.links:
		_check(GridUtil.CountTurns(link["path"]) <= 1, "连线 %s → %s 只转一次 90°" % [link["from_cell"], link["to_cell"]])
	_maintain_ghosts()

	var rounds := 0
	while not board.completed and not board.failed and rounds < 120:
		board.Advance(2.0)
		_maintain_ghosts()
		rounds += 1

	_check(board.completed, "关卡 2 可通关")
	_check(board.delivered >= 72, "自动交付达 72 个鬼能，实际 %d" % board.delivered)
	_check(board.elapsed < 120.0, "耗时 %.1f s < 120 s 时限" % board.elapsed)
	_check(not board.failed, "未触发超时失败")
	_check(board.manual_count == 0, "全自动链路不产生手动交付次数")

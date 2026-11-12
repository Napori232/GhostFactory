extends Node

## 关卡 4 脚本化通关测试（推动链教学关）：
## 参考解 = 主区「生产 → 采集 → 中转 → 交付」产线 + 走廊「推舌鬼推守财鬼链」引擎，
## 吊死鬼验证被推后荡回原位；走廊掉落物由第二只采集鬼清走，否则推链被「掉落物占格」卡死。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/Level04PlaythroughTest.tscn

var _checks: int = 0
var _failures: int = 0
var _completed_count: int = 0
var _completed_stars: int = 0
var _pushed_count: int = 0
var _corridor_drops: int = 0
var board: Board = null

func _ready() -> void:
	await get_tree().process_frame
	SignalBus.LevelCompleted.connect(_on_level_completed)
	SignalBus.GhostPushed.connect(_on_ghost_pushed)
	SignalBus.SpiritDropped.connect(_on_spirit_dropped)
	board = Board.new()
	board.Setup(Board.LoadLevelData(4), Board.LoadGhostLibrary())
	_run()
	print("---- 结果：%d 项断言，%d 项失败" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## 记录通关信号。
## @param level_id 关卡编号。
## @param stars 结算星级。
func _on_level_completed(level_id: int, stars: int) -> void:
	if level_id == 4:
		_completed_count += 1
		_completed_stars = stars

## 统计被推的鬼数。
## @param _board 广播的棋盘实例。
## @param _ghost 被推的鬼实例。
func _on_ghost_pushed(_board, _ghost) -> void:
	_pushed_count += 1

## 统计落在走廊带（y >= 7）的鬼能掉落。
## @param cell 掉落所在格。
## @param _amount 掉落数量。
func _on_spirit_dropped(cell: Vector2i, _amount: int) -> void:
	if cell.y >= 7:
		_corridor_drops += 1

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

## 生成矩形格坐标数组。
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

## 搭建参考解并跑通。
func _run() -> void:
	# --- 关卡约束核对 ---
	_check(board.level.HasProducerZone(), "关卡 4 已划出生产专属区")
	_check(not board.CanPlace(&"producer", Vector2i(2, 4)), "生产鬼不能放普通蓝格")
	_check(not board.CanPlace(&"collector", Vector2i(2, 2)), "采集鬼不能占生产专属格")
	_check(board.CanPlace(&"pusher", Vector2i(2, 8)), "推舌鬼可放走廊")
	_check(board.CanPlace(&"miser", Vector2i(3, 8)), "守财鬼可放走廊")
	_check(board.CanPlace(&"hang", Vector2i(11, 8)), "吊死鬼可放走廊")
	_check(not board.CanPlace(&"pusher", Vector2i(6, 9)), "走廊底墙不可放鬼")
	_check(not board.CanPlace(&"producer", Vector2i(2, 8)), "生产鬼不能离开生产带")

	# --- 主区产线：生产 → 采集 → 中转 → 交付 ---
	var producers := [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
	for cell in producers:
		_check(board.PlaceGhost(&"producer", cell) != null, "放下生产鬼 %s" % cell)
	_check(board.PlaceGhost(&"collector", Vector2i(2, 4)) != null, "放下主区采集鬼")
	_check(board.SetSearchArea(Vector2i(2, 4), _rect(1, 7, 1, 4)), "主区采集鬼框选 18 格搜索区")
	_check(board.PlaceGhost(&"transporter", Vector2i(9, 5)) != null, "放下中转运输鬼")
	_check(board.ConnectGhosts(Vector2i(2, 4), Vector2i(9, 5)), "采集鬼 → 中转鬼连线成功")
	_check(board.ConnectToFacility(Vector2i(9, 5), Vector2i(11, 2)), "中转鬼 → 交付口连线成功")
	for link in board.connections.links:
		_check(GridUtil.CountTurns(link["path"]) <= 1, "连线 %s → %s 只转一次 90°" % [link["from_cell"], link["to_cell"]])

	# --- 走廊推动链引擎 ---
	_check(board.PlaceGhost(&"pusher", Vector2i(2, 8)) != null, "走廊左端放下推舌鬼")
	_check(board.PlaceGhost(&"miser", Vector2i(3, 8)) != null, "放下守财鬼 1（相邻成链）")
	_check(board.PlaceGhost(&"miser", Vector2i(4, 8)) != null, "放下守财鬼 2")
	_check(board.PlaceGhost(&"collector", Vector2i(9, 4)) != null, "主区右侧放下清道采集鬼")
	_check(board.SetSearchArea(Vector2i(9, 4), _rect(2, 13, 6, 9)), "清道采集鬼框选走廊 22 格搜索区")
	_check(board.PlaceGhost(&"hang", Vector2i(11, 8)) != null, "走廊右端放下吊死鬼")
	_check(board.PlaceGhost(&"pusher", Vector2i(12, 8)) != null, "吊死鬼旁再放一只推舌鬼")
	_maintain_ghosts()

	# --- 推链冒烟：推 2.5 s，链应位移、守财鬼应掉鬼能、吊死鬼应荡回 ---
	board.Advance(2.5)
	_check(_pushed_count >= 3, "2.5 s 内至少推中 3 只（2 守财鬼 + 1 吊死鬼），实际 %d" % _pushed_count)
	_check(board.grid.GetGhostAt(Vector2i(3, 8)) == null, "守财鬼 1 被推离原位")
	_check(board.grid.GetGhostAt(Vector2i(11, 8)) != null, "吊死鬼被推后荡回原位")
	_check(_corridor_drops >= 2, "推链在走廊掉出至少 2 个鬼能，实际 %d" % _corridor_drops)

	# --- 跑到通关 ---
	var rounds := 0
	while not board.completed and not board.failed and rounds < 150:
		board.Advance(2.0)
		_maintain_ghosts()
		rounds += 1

	_check(board.completed, "关卡 4 可通关")
	_check(board.delivered >= 60, "交付数达到 60 个鬼能，实际 %d" % board.delivered)
	_check(_completed_count == 1, "LevelCompleted(4) 恰好触发一次")
	_check(_completed_stars >= 1, "结算星级 >= 1，实际 %d" % _completed_stars)
	_check(board.elapsed < 150.0, "耗时 %.1f s < 150 s 时限" % board.elapsed)
	_check(not board.failed, "未触发超时失败")
	_check(board.manual_count == 0, "全自动链路不产生手动交付次数")
	_check(_pushed_count >= 6, "整局推链持续生效（>= 6 次推动），实际 %d" % _pushed_count)

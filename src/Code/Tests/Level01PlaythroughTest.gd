extends Node

## 关卡 1 脚本化通关测试：放 2 只生产鬼 → 推进到产出 30 个鬼能 → 拾取 → 交付 → 结算星级。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/Level01PlaythroughTest.tscn

var _checks: int = 0
var _failures: int = 0
var _completed_stars: int = 0
var _completed_count: int = 0
var board: Board = null

func _ready() -> void:
	await get_tree().process_frame
	SignalBus.LevelCompleted.connect(_on_level_completed)
	board = Board.new()
	board.Setup(Board.LoadLevelData(1), Board.LoadGhostLibrary())
	_run()
	print("---- 结果：%d 项断言，%d 项失败" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## 记录通关信号。
## @param level_id 关卡编号。
## @param stars 结算星级。
func _on_level_completed(level_id: int, stars: int) -> void:
	_completed_count += 1
	_completed_stars = stars

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

## 跑通关卡 1 的单链。
func _run() -> void:
	_check(board.level.HasProducerZone(), "关卡 1 已划出生产带")
	_check(not board.CanPlace(&"producer", Vector2i(3, 3)), "关卡 1 蓝格不能放生产鬼")
	var a := board.PlaceGhost(&"producer", Vector2i(3, 4))
	var b := board.PlaceGhost(&"producer", Vector2i(5, 4))
	_check(a != null and b != null, "放下 2 只生产鬼")
	board.SetGhostStateAt(Vector2i(3, 4), GhostInstance.STATE_RUNNING)
	board.SetGhostStateAt(Vector2i(5, 4), GhostInstance.STATE_RUNNING)

	var rounds := 0
	while not board.completed and rounds < 100:
		board.Advance(2.0)
		var picked := 0
		for cell in board.grid.GetAllItemCells():
			picked += board.PickupItemAt(cell)
		for i in range(picked):
			if not board.completed:
				board.DeliverFromPool(Vector2i(8, 4))
		rounds += 1

	_check(board.completed, "关卡 1 可通关")
	_check(board.delivered >= 30, "交付数达到 30 个鬼能，实际 %d" % board.delivered)
	_check(_completed_count == 1, "LevelCompleted 恰好触发一次")
	_check(_completed_stars >= 1, "结算星级 >= 1，实际 %d" % _completed_stars)
	_check(board.elapsed < 90.0, "耗时 %.1f s < 90 s 时限" % board.elapsed)
	_check(not board.failed, "未触发超时失败")
	_check(rounds <= 46, "在 46 个产出轮次内完成，实际 %d" % rounds)

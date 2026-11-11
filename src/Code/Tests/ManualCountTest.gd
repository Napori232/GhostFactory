extends Node

## 手动次数口径测试（D5）：只统计向交付口交付的动作，不统计放置、拾取、状态切换。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/ManualCountTest.tscn

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

## 依次验证各类操作是否计入手动次数。
func _run() -> void:
	board.PlaceGhost(&"producer", Vector2i(3, 4))
	board.SetGhostStateAt(Vector2i(3, 4), GhostInstance.STATE_RUNNING)
	board.CycleGhostStateAt(Vector2i(3, 4))
	board.SpawnItem(Vector2i(4, 4), "Spirit", 1)
	board.PickupItemAt(Vector2i(4, 4))
	board.SetSearchArea(Vector2i(3, 4), [Vector2i(3, 4)])
	_check(board.manual_count == 0, "放置 / 切状态 / 拾取 / 框选均不计手动")

	board.AddSpirit(40)
	for i in range(30):
		board.DeliverFromPool(Vector2i(8, 4))
	_check(board.manual_count == 30, "30 次交付 = 30 次手动，实际 %d" % board.manual_count)
	_check(board.delivered == 30, "交付计数达 30")
	_check(LevelGoal.IsGoalReached(board.level, board.delivered), "LevelGoal 判定目标达成")
	_check(LevelGoal.CalculateStars(board.level, 60.0, 30, 4) >= 1, "LevelGoal 可算出星级")

extends Node

## 故障测试：生产鬼四邻无可落空格且自身缓冲已满时进入 FAULT，并广播 GhostFaulted。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/FaultTest.tscn

var _checks: int = 0
var _failures: int = 0
var _fault_count: int = 0
var board: Board = null

func _ready() -> void:
	await get_tree().process_frame
	SignalBus.GhostFaulted.connect(_on_ghost_faulted)
	board = Board.new()
	board.Setup(Board.LoadLevelData(1), Board.LoadGhostLibrary())
	_run()
	print("---- 结果：%d 项断言，%d 项失败" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## 记录故障信号。
## @param source 发出信号的棋盘节点。
func _on_ghost_faulted(source: Node) -> void:
	_fault_count += 1

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

## 构造四邻全满 + 缓冲满的死角。
func _run() -> void:
	# spot 必须落在生产带内（关卡 1 中间排），否则生产区规则会拒绝放置。
	var spot := Vector2i(2, 4)
	var ghost := board.PlaceGhost(&"producer", spot)
	_check(ghost != null, "生产鬼放在生产专属区左端")
	var filled := 0
	for neighbor in GridUtil.Neighbors4(spot):
		if GridUtil.InBounds(neighbor, board.level.grid_size):
			board.SpawnItem(neighbor, "Spirit", 1)
			filled += 1
	_check(filled == 4, "四邻 4 格全部被掉落物占住")
	_check(board.grid.GetEmptyNeighbors(spot).is_empty(), "四邻已无可落空格")

	ghost.output_buffer = ["Spirit", "Spirit", "Spirit"]
	_check(ghost.IsOutputFull(), "自身输出缓冲已满（容量 3）")
	board.SetGhostStateAt(spot, GhostInstance.STATE_RUNNING)
	board.Advance(4.0)

	_check(ghost.state == GhostInstance.STATE_FAULT, "进入 FAULT 状态")
	_check(_fault_count >= 1, "GhostFaulted 已广播")
	_check(board.CycleGhostStateAt(spot) == GhostInstance.STATE_IDLE, "玩家点击后故障恢复为待机")

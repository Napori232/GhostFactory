extends Node

## 推动链 headless 测试（Docs/GameDesign.md §8.3、Docs/PhysicsLayer.md §3）。
## 覆盖：柔体让位一格、刚体止点、障碍与掉落物阻断、出界、守财鬼掉落、吊死鬼回摆、位移断线。
## 运行：Godot --headless --path <src> res://Code/Tests/PushChainTest.tscn

var _checks: int = 0
var _failures: int = 0
var board: Board = null

func _ready() -> void:
	await get_tree().process_frame
	board = Board.new()
	board.Setup(_build_level(), Board.LoadGhostLibrary())
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

## 构造一张干净的 10×6 测试地台，只把 (7,1) 设为障碍。
## @return 测试用关卡数据。
func _build_level() -> LevelData:
	var level := LevelData.new()
	level.id = 90
	level.display_name = "推动链测试"
	level.grid_size = Vector2i(10, 6)
	level.time_limit = 300.0
	level.goal_form = "Spirit"
	level.goal_amount = 1
	level.start_spirit = 200
	var cells: Array[Vector2i] = []
	for y in range(0, 6):
		for x in range(0, 10):
			cells.append(Vector2i(x, y))
	level.placeable_cells = cells
	var obstacles: Array[Vector2i] = [Vector2i(7, 1)]
	level.obstacle_cells = obstacles
	var allowed: Array[StringName] = [
		&"pusher", &"miser", &"hang", &"collector", &"producer", &"transporter",
	]
	level.allowed_ghost_ids = allowed
	return level

## 依次执行全部检查。
func _run() -> void:
	_test_soft_chain()
	_test_rigid_stop()
	_test_obstacle_block()
	_test_item_block()
	_test_out_of_bounds()
	_test_miser_drop()
	_test_hang_sway()
	_test_link_cut_on_push()

## 柔体让位：推舌鬼把采集鬼推开一格。
func _test_soft_chain() -> void:
	var pusher := board.PlaceGhost(&"pusher", Vector2i(2, 2))
	var collector := board.PlaceGhost(&"collector", Vector2i(3, 2))
	_check(pusher != null and collector != null, "推舌鬼与采集鬼放置成功")
	board.SetGhostStateAt(Vector2i(2, 2), GhostInstance.STATE_RUNNING)
	BoardRunner.RunTick(board, ExportSettings.sim_pusher_cycle)
	_check(board.GetGhostAt(Vector2i(3, 2)) == null, "原格已空出")
	_check(board.GetGhostAt(Vector2i(4, 2)) == collector, "采集鬼被推开一格")
	_check(collector.cell == Vector2i(4, 2), "鬼实例的格坐标同步更新")

## 刚体止点：链尾是刚体时整条链都不动。
func _test_rigid_stop() -> void:
	var pusher := board.PlaceGhost(&"pusher", Vector2i(2, 4))
	var mover := board.PlaceGhost(&"collector", Vector2i(3, 4))
	var anchor := board.PlaceGhost(&"producer", Vector2i(4, 4))
	_check(pusher != null and mover != null and anchor != null, "刚体止点组放置成功")
	var result := PushResolver.TryPush(board, Vector2i(2, 4), Vector2i(1, 0))
	_check(not bool(result["ok"]), "撞到刚体时推动失败")
	_check(String(result["reason"]) == "刚体止点", "失败原因标为刚体止点")
	_check(mover.cell == Vector2i(3, 4), "链中柔体一格未动")
	_check(anchor.cell == Vector2i(4, 4), "刚体保持原位")

## 障碍阻断：推力路径遇到障碍整条链不动。
func _test_obstacle_block() -> void:
	var pusher := board.PlaceGhost(&"pusher", Vector2i(5, 1))
	var mover := board.PlaceGhost(&"collector", Vector2i(6, 1))
	_check(pusher != null and mover != null, "障碍阻断组放置成功")
	var result := PushResolver.TryPush(board, Vector2i(5, 1), Vector2i(1, 0))
	_check(not bool(result["ok"]), "障碍阻断推动")
	_check(String(result["reason"]) == "障碍", "失败原因标为障碍")
	_check(mover.cell == Vector2i(6, 1), "被障碍挡住时柔体不动")

## 掉落物占格：地面有货时推不动。
func _test_item_block() -> void:
	var pusher := board.PlaceGhost(&"pusher", Vector2i(2, 0))
	var mover := board.PlaceGhost(&"collector", Vector2i(3, 0))
	board.SpawnItem(Vector2i(4, 0), "Spirit", 1)
	_check(pusher != null and mover != null, "掉落物阻断组放置成功")
	var result := PushResolver.TryPush(board, Vector2i(2, 0), Vector2i(1, 0))
	_check(not bool(result["ok"]), "掉落物阻断推动")
	_check(String(result["reason"]) == "掉落物占格", "失败原因标为掉落物占格")
	_check(mover.cell == Vector2i(3, 0), "被掉落物挡住时柔体不动")

## 出界：推力指向网格外。
func _test_out_of_bounds() -> void:
	var result := PushResolver.TryPush(board, Vector2i(0, 0), Vector2i(-1, 0))
	_check(not bool(result["ok"]), "向界外推动失败")
	_check(String(result["reason"]) == "出界", "失败原因标为出界")

## 守财鬼：被推后掉落 1 鬼能。
func _test_miser_drop() -> void:
	var before := board.grid.GetAllItemCells().size()
	var miser := board.PlaceGhost(&"miser", Vector2i(6, 4))
	_check(miser != null, "守财鬼放置成功")
	var result := PushResolver.TryPush(board, Vector2i(5, 4), Vector2i(1, 0))
	_check(bool(result["ok"]), "守财鬼可被推动")
	_check(miser.cell == Vector2i(7, 4), "守财鬼被推开一格")
	_check(board.grid.GetAllItemCells().size() == before + 1, "被推一次掉 1 鬼能")
	_check(board.grid.GetAllItemCells().has(miser.cell + Vector2i(0, -1)) or
		board.grid.GetAllItemCells().has(miser.cell + Vector2i(0, 1)) or
		board.grid.GetAllItemCells().has(miser.cell + Vector2i(1, 0)) or
		board.grid.GetAllItemCells().has(miser.cell + Vector2i(-1, 0)), "掉落落在四邻格")

## 吊死鬼：被推后下一 tick 荡回原位。
func _test_hang_sway() -> void:
	var hang := board.PlaceGhost(&"hang", Vector2i(3, 5))
	_check(hang != null, "吊死鬼放置成功")
	board.SetGhostStateAt(Vector2i(3, 5), GhostInstance.STATE_RUNNING)
	var pushed := PushResolver.TryPush(board, Vector2i(2, 5), Vector2i(1, 0))
	_check(bool(pushed["ok"]), "吊死鬼可被推动")
	_check(hang.cell == Vector2i(4, 5), "吊死鬼被推开一格")
	_check(hang.sway_dir == Vector2i(1, 0), "记下推力方向待回摆")
	BoardRunner.RunTick(board, 0.1)
	_check(hang.cell == Vector2i(3, 5), "下一 tick 荡回原位")
	_check(hang.sway_dir == Vector2i.ZERO, "回摆后清空方向")

## 位移断线：被推离原位后原有连线一并拆除。
func _test_link_cut_on_push() -> void:
	var source := board.PlaceGhost(&"collector", Vector2i(7, 2))
	var sink := board.PlaceGhost(&"transporter", Vector2i(8, 2))
	_check(source != null and sink != null, "连线组放置成功")
	_check(board.ConnectGhosts(Vector2i(7, 2), Vector2i(8, 2)), "采集鬼 → 运输鬼连线成功")
	_check(board.HasLink(Vector2i(7, 2), Vector2i(8, 2)), "连线存在")
	var result := PushResolver.TryPush(board, Vector2i(6, 2), Vector2i(1, 0))
	_check(bool(result["ok"]), "连线组被推动")
	_check(not board.HasLink(Vector2i(7, 2), Vector2i(8, 2)), "被推离原位后连线拆除")

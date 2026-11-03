extends Node

## 板面交互的 headless 测试：拖放放置、端口连线、线鬼搬运与拆除。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/BoardInteractionTest.tscn

var _failures: int = 0
var _checks: int = 0

func _ready() -> void:
	_test_palette()
	await _test_placement()
	await _test_connection()
	_test_line_ghost()
	print("---- 结果：%d 项断言，%d 项失败" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## 构造一套板面：网格 + 运行时 + 鬼牌栏 + 控制器。
## @return 包含 grid / runner / controller / palette 的字典。
func _make_board() -> Dictionary:
	var root := Node2D.new()
	root.name = "TestBoard"
	add_child(root)

	var grid_scene: PackedScene = load("res://Code/Entities/Board/BoardGrid.tscn")
	var grid := grid_scene.instantiate()
	grid.set("grid_size", Vector2i(10, 8))
	root.add_child(grid)

	var runner_script: Script = load("res://Code/Entities/Board/BoardRunner.gd")
	var runner := Node2D.new()
	runner.set_script(runner_script)
	root.add_child(runner)
	runner.set("grid", grid)
	runner.call("AddSpirit", 50)

	var palette_scene: PackedScene = load("res://Code/Entities/Board/GhostPalette.tscn")
	var palette := palette_scene.instantiate()
	root.add_child(palette)

	var controller_script: Script = load("res://Code/Entities/Board/BoardController.gd")
	var controller := Node2D.new()
	controller.set_script(controller_script)
	root.add_child(controller)
	controller.set("grid", grid)
	controller.set("runner", runner)
	controller.set("palette", palette)
	return {"root": root, "grid": grid, "runner": runner, "palette": palette, "controller": controller}

## 测试鬼牌栏：生成牌面、造价显示与鬼能调暗。
func _test_palette() -> void:
	var palette_scene: PackedScene = load("res://Code/Entities/Board/GhostPalette.tscn")
	var palette := palette_scene.instantiate()
	add_child(palette)
	await get_tree().process_frame
	palette.call("SetAvailableGhosts", PackedStringArray(["LongTongue", "Stove"]))
	await get_tree().process_frame
	_check(palette.call("GetAvailableGhosts").size() == 2, "鬼牌栏可用鬼数量为 2")
	var card: Control = palette.call("GetCardAt", 0)
	_check(card != null, "第一张鬼牌存在")
	if card != null:
		_check(String(card.get_meta("ghost_id", "")) == "LongTongue", "第一张牌是长舌鬼")
		_check(palette.call("GetCardForGhost", "Stove") != null, "能按 id 找到灶鬼牌")
	palette.call("SetSpirit", 0)
	await get_tree().process_frame
	var dimmed: Control = palette.call("GetCardAt", 0)
	_check(dimmed.modulate.a < 0.99, "鬼能不足时鬼牌调暗，实际透明度 %f" % dimmed.modulate.a)
	palette.call("SetSpirit", 50)
	await get_tree().process_frame
	_check(dimmed.modulate.a > 0.99, "鬼能充足时鬼牌恢复亮度")
	palette.queue_free()

## 测试放置：合法格成功、越界与重叠失败。
func _test_placement() -> void:
	var board := _make_board()
	var grid: Node2D = board["grid"]
	var runner: Node2D = board["runner"]
	var controller: Node2D = board["controller"]
	await get_tree().process_frame

	var ok: bool = controller.call("TryPlaceGhost", "LongTongue", Vector2i(4, 4))
	_check(ok, "在空格放置长舌鬼成功")
	_check(grid.get_ghost_components().size() == 1, "网格上有 1 只鬼，实际 %d" % grid.get_ghost_components().size())

	var overlap: bool = controller.call("TryPlaceGhost", "LongTongue", Vector2i(4, 4))
	_check(not overlap, "重叠放置被拒绝")

	var out_of_bounds: bool = controller.call("TryPlaceGhost", "LongTongue", Vector2i(20, 20))
	_check(not out_of_bounds, "越界放置被拒绝")

	_check(int(runner.get("spirit")) == 44, "放置消耗 6 鬼能，实际剩余 %d" % int(runner.get("spirit")))
	board["root"].queue_free()
	await get_tree().process_frame

## 测试连线：建立成功、重复被拒、拆除后清空。
func _test_connection() -> void:
	var board := _make_board()
	var grid: Node2D = board["grid"]
	var runner: Node2D = board["runner"]
	var controller: Node2D = board["controller"]
	await get_tree().process_frame

	controller.call("TryPlaceGhost", "LongTongue", Vector2i(3, 3))
	var terminal_scene: PackedScene = load("res://Code/Entities/Board/TerminalComponent.tscn")
	var terminal := terminal_scene.instantiate()
	terminal.set("cell", Vector2i(8, 3))
	terminal.set("accepts", "Raw")
	grid.add_child(terminal)
	await get_tree().process_frame

	var ghosts: Array = grid.get_ghost_components()
	var ghost: Node2D = ghosts[0]
	var port_cell: Vector2i = runner.call("GetPortCell", ghost, 0)
	_check(port_cell == Vector2i(3, 3), "长舌鬼输出端口在本体格，实际 %s" % str(port_cell))

	var ok: bool = controller.call("TryConnect", ghost, 0, terminal, 0)
	_check(ok, "长舌鬼连到供品口成功")
	_check(runner.call("GetLines").size() == 1, "连线条数为 1，实际 %d" % runner.call("GetLines").size())

	var duplicate: bool = controller.call("TryConnect", ghost, 0, terminal, 0)
	_check(not duplicate, "重复连线被拒绝")
	_check(runner.call("GetLines").size() == 1, "重复连线后仍为 1 条")

	runner.call("RemoveGhost", ghost)
	await get_tree().process_frame
	_check(runner.call("GetLines").size() == 0, "拆除鬼后连线被清除，实际 %d" % runner.call("GetLines").size())
	board["root"].queue_free()
	await get_tree().process_frame

## 测试线鬼：路径占位、接收与推进。
func _test_line_ghost() -> void:
	var script: Script = load("res://Code/Entities/Board/LineGhost.gd")
	var ghost := Node2D.new()
	ghost.set_script(script)
	add_child(ghost)
	await get_tree().process_frame
	ghost.call("SetPath", GridUtil.ToCellArray([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]))
	_check(ghost.call("GetOccupiedCells").size() == 3, "线鬼占用 3 格，实际 %d" % ghost.call("GetOccupiedCells").size())
	_check(String(ghost.call("GetGhostId")) == "Line", "线鬼的 id 是 Line")
	var accepted: bool = ghost.call("AcceptItem", "Raw")
	_check(accepted, "线鬼接收物品成功")
	_check(ghost.call("GetItemCount") == 1, "线鬼上有 1 个物品")
	# 物品需要两格才能到达末端。
	ghost.call("Advance")
	_check(ghost.call("GetItemCount") == 1, "推进后物品仍在线上")
	ghost.call("Advance")
	_check(ghost.call("GetItemCount") == 0, "物品到达末端并离开线鬼")
	ghost.queue_free()

## 执行一条断言。
## @param condition 断言条件
## @param label 失败时的说明文字
func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		_failures += 1
		printerr("FAIL: %s" % label)

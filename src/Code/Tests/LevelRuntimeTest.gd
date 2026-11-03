extends Node

## 关卡布局与运行时的 headless 测试：三个关卡场景能加载、预置内容正确、放置与交付链路跑通。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/LevelRuntimeTest.tscn

const ORIGINAL_SAVE_PATH: String = "user://savegame.cfg"

var _failures: int = 0
var _checks: int = 0

func _ready() -> void:
	_test_level_scenes()
	_test_level_data()
	await _test_delivery_chain()
	print("---- 结果：%d 项断言，%d 项失败" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## 测试三个关卡场景能加载且预置内容正确。
func _test_level_scenes() -> void:
	var expected := {
		1: {"grid": Vector2i(10, 8), "fields": 1, "terminals": 1},
		2: {"grid": Vector2i(12, 9), "fields": 1, "terminals": 1},
		3: {"grid": Vector2i(14, 10), "fields": 1, "terminals": 2},
	}
	for level_id: int in expected:
		var scene := LevelData.LoadLevelScene(level_id)
		_check(scene != null, "Level%02d.tscn 场景可加载" % level_id)
		if scene == null:
			continue
		var root := scene.instantiate()
		add_child(root)
		await get_tree().process_frame
		var grid := _find_grid(root)
		_check(grid != null, "Level%02d 含 BoardGrid" % level_id)
		if grid == null:
			root.queue_free()
			continue
		var exp: Dictionary = expected[level_id]
		_check(grid.grid_size == exp["grid"], "Level%02d 网格尺寸正确，实际 %s" % [level_id, str(grid.grid_size)])
		_check(grid.get_field_components().size() == exp["fields"], "Level%02d 采集区数量为 %d" % [level_id, exp["fields"]])
		_check(grid.get_terminal_components().size() == exp["terminals"], "Level%02d 供品口数量为 %d" % [level_id, exp["terminals"]])
		var field: Node2D = grid.get_field_components()[0]
		_check(field.get_cells().size() == 6, "Level%02d 采集区面积 6 格，实际 %d" % [level_id, field.get_cells().size()])
		_check(field.get("drops") == "Raw", "Level%02d 采集区掉落 Raw" % level_id)
		root.queue_free()
		await get_tree().process_frame

## 测试关卡数据的时长、目标与可用鬼配置。
func _test_level_data() -> void:
	var expected := {
		1: {"time": 80, "goal": 20, "space": 12},
		2: {"time": 100, "goal": 28, "space": 18},
		3: {"time": 90, "goal": 30, "space": 24},
	}
	var total_time := 0
	for level_id: int in expected:
		var data := LevelData.LoadLevel(level_id)
		_check(data != null, "Level%02d.tres 数据可加载" % level_id)
		if data == null:
			continue
		var exp: Dictionary = expected[level_id]
		_check(data.time_limit == exp["time"], "Level%02d 时长 %d 秒，实际 %d" % [level_id, exp["time"], data.time_limit])
		_check(data.goal_score == exp["goal"], "Level%02d 目标 %d，实际 %d" % [level_id, exp["goal"], data.goal_score])
		_check(data.space_budget == exp["space"], "Level%02d 空间预算 %d，实际 %d" % [level_id, exp["space"], data.space_budget])
		_check(data.level_scene != "", "Level%02d 配置了关卡场景路径" % level_id)
		_check(data.available_ghosts.size() > 0, "Level%02d 配置了可用鬼" % level_id)
		total_time += data.time_limit
	_check(total_time == 270, "三关总时长 270 秒，实际 %d" % total_time)

## 测试「采集区 → 长舌鬼 → 线 → 供品口」的交付链路。
func _test_delivery_chain() -> void:
	var scene := LevelData.LoadLevelScene(1)
	if scene == null:
		_check(false, "第 1 关场景可用于交付链路测试")
		return
	var root := scene.instantiate()
	add_child(root)
	await get_tree().process_frame
	var grid := _find_grid(root)
	if grid == null:
		_check(false, "交付链路测试找不到网格")
		root.queue_free()
		return

	var runner_script: Script = load("res://Code/Entities/Board/BoardRunner.gd")
	var runner := Node2D.new()
	runner.set_script(runner_script)
	add_child(runner)
	runner.set("grid", grid)
	runner.call("SetGoal", 20)

	# 在采集区右侧放一只长舌鬼，让它吃到采集区掉落的 Raw。
	var ghost_scene: PackedScene = load("res://Code/Entities/Board/GhostComponent.tscn")
	var ghost := ghost_scene.instantiate()
	ghost.set("ghost_id", "LongTongue")
	ghost.set("cell", Vector2i(3, 3))
	ghost.set("footprint", GridUtil.ToCellArray([Vector2i(0, 0)]))
	ghost.set("appendages", GridUtil.ToCellArray([Vector2i(1, 0)]))
	grid.add_child(ghost)
	await get_tree().process_frame
	_check(grid.get_ghost_components().size() == 1, "长舌鬼已放置到网格")

	# 连线到供品口。
	var terminal: Node2D = grid.get_terminal_components()[0]
	var ok: bool = runner.call("AddLine", ghost, terminal, 0, 0)
	_check(ok, "长舌鬼到供品口的连线建立成功")
	_check(runner.call("GetLines").size() == 1, "连线条数为 1")

	# 直接给长舌鬼塞一个 Raw，验证它能推给下游。
	runner.call("_push_to_output", ghost, "Raw")
	await get_tree().process_frame
	# 物品沿路径一格一格搬运，需要足够步数才能到达末端。
	for i in 20:
		runner.call("_step_items")
		await get_tree().process_frame
		if terminal.get_delivered_count() > 0:
			break
	_check(terminal.get_delivered_count() == 1, "供品口收到 1 份，实际 %d" % terminal.get_delivered_count())
	_check(runner.get("delivered") == 1, "交付计数为 1，实际 %d" % runner.get("delivered"))

	root.queue_free()
	runner.queue_free()

## 在节点树里递归查找板面网格。
## @param node 起始节点
## @return 找到的网格节点；没有则返回 null。
func _find_grid(node: Node) -> Node2D:
	if node is Node2D and node.has_method("get_ghost_components"):
		return node
	for child in node.get_children():
		var found := _find_grid(child)
		if found != null:
			return found
	return null

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

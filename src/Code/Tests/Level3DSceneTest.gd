extends Node

## 3D 表现层 headless 测试（CodePlan §5.9.9）：
## 场景可实例化、节点结构齐全、正交相机 -45°、八向吸附、坐标往返、关卡能开局。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/Level3DSceneTest.tscn

var _checks: int = 0
var _failures: int = 0

func _ready() -> void:
	await get_tree().process_frame
	await _run()
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

## 依次验证场景结构与相机参数。
func _run() -> void:
	var packed := load("res://Code/Entities/Level/Level3D.tscn") as PackedScene
	_check(packed != null, "Level3D.tscn 可加载")
	if packed == null:
		return
	var instance := packed.instantiate()
	_check(instance != null, "Level3D.tscn 可实例化")
	if instance == null:
		return
	add_child(instance)
	await get_tree().process_frame

	var level_node := instance.get_node_or_null("Level3D")
	_check(level_node != null, "内含 Level3D 关卡根")
	_check(instance.get_node_or_null("Level3D/Board") != null, "内含 Board 规则层节点")
	_check(instance.get_node_or_null("Level3D/World/GridFloor") != null, "内含 GridFloor 地台")
	_check(instance.get_node_or_null("Level3D/World/CellMarkers") != null, "内含 CellMarkers 格标记")
	_check(instance.get_node_or_null("Level3D/World/Ghosts") != null, "内含 Ghosts 容器")
	_check(instance.get_node_or_null("Level3D/World/Items") != null, "内含 Items 容器")
	_check(instance.get_node_or_null("Level3D/World/Facilities") != null, "内含 Facilities 容器")
	_check(instance.get_node_or_null("Level3D/UILayer/HUD") != null, "内含 UILayer/HUD")

	var camera := instance.get_node_or_null("Level3D/CameraRig/Camera3D") as Camera3D
	_check(camera != null, "Camera3D 存在")
	if camera != null:
		_check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "相机为正交投影")
		_check(absf(camera.rotation_degrees.x - ExportSettings.view_pitch_degrees) < 0.01, "相机俯仰 -45°")
		_check(camera.size > 0.0, "正交视野尺寸已设置")

	var rig := instance.get_node_or_null("Level3D/CameraRig") as CameraRig
	_check(rig != null, "CameraRig 脚本已挂载")
	if rig != null:
		_check(fmod(rig.rotation_degrees.y, Grid3D.YAW_STEP) == 0.0, "初始偏航为 45° 整数倍")
		_check(rig.GetCompassText().contains("北"), "八向罗盘文字可读")
		rig.RotateStep(1)
		_check(rig.yaw_step == 1, "Q/E 旋转一档后档位正确")

	var hud := instance.get_node_or_null("Level3D/UILayer/HUD") as LevelHud
	_check(hud != null, "LevelHud 脚本已挂载")
	if hud != null:
		_check(hud.GetGhostButtonCount() >= 1, "鬼牌栏已按关卡白名单生成按钮")

	var board := instance.get_node_or_null("Level3D/Board") as Board
	_check(board != null, "Board 脚本已挂载")
	if board != null and board.level != null:
		var snapshot := board.GetStateSnapshot()
		_check(int(snapshot["level_id"]) == 1, "关卡已开局，默认第 1 关")
		_check((snapshot["placeable"] as Array).size() == 18, "可放置区 18 格已装配")
		_check((snapshot["facilities"] as Array).size() == 1, "关卡 1 只有 1 个交付口")

	# 坐标换算与八向吸附的独立断言（不依赖相机视口）。
	var round_trip := true
	for y in range(8):
		for x in range(10):
			var cell := Vector2i(x, y)
			if Grid3D.World3DToCell(Grid3D.CellToWorld3D(cell)) != cell:
				round_trip = false
	_check(round_trip, "Grid3D 全格往返互逆")
	_check(Grid3D.SnapYawDegrees(52.0) == 45.0, "偏航 52° 吸附到 45°")
	_check(Grid3D.SnapYawDegrees(200.0) == 180.0, "偏航 200° 吸附到 180°")
	_check(Grid3D.ZoomLevelToSize(0) == 8.0 and Grid3D.ZoomLevelToSize(1) == 12.0, "三档缩放数值正确")

	# 程序化美术：环境光、地台边框、鬼的分件造型、设施光环、圆管连线、HUD 色板。
	var floor_node := instance.get_node_or_null("Level3D/World/GridFloor")
	_check(floor_node != null, "GridFloor 存在")
	if floor_node != null:
		var env_node := floor_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
		_check(env_node != null and env_node.environment != null, "地台挂了 WorldEnvironment 环境光")
		if env_node != null and env_node.environment != null:
			_check(env_node.environment.background_mode == Environment.BG_COLOR, "环境背景为纯冷色")
		var bars := 0
		for child in floor_node.get_children():
			if child is MeshInstance3D:
				bars += 1
		_check(bars == 4, "地台四边各有一条发光边框，实际 %d" % bars)

	var view := instance.get_node_or_null("Level3D/World") as BoardView3D
	_check(view != null, "World 挂了 BoardView3D 脚本")
	if view != null and board != null:
		board.PlaceGhost(&"producer", Vector2i(3, 4))
		view.Refresh(board.GetStateSnapshot())
		var ghost_root := instance.get_node_or_null("Level3D/World/Ghosts")
		var has_cylinder := false
		var has_sphere := false
		var has_torus := false
		var ghost_parts := 0
		for child in ghost_root.get_children():
			var part := child as MeshInstance3D
			if part == null:
				continue
			ghost_parts += 1
			has_cylinder = has_cylinder or part.mesh is CylinderMesh
			has_sphere = has_sphere or part.mesh is SphereMesh
			has_torus = has_torus or part.mesh is TorusMesh
		_check(ghost_parts >= 4, "生产鬼由底座 / 状态环 / 炉体 / 鬼能球四件组成，实际 %d" % ghost_parts)
		_check(has_cylinder and has_torus and has_sphere, "生产鬼含炉体 / 状态环 / 顶部鬼能球")

	var facility_root := instance.get_node_or_null("Level3D/World/Facilities")
	var facility_has_torus := false
	for child in facility_root.get_children():
		var part := child as MeshInstance3D
		if part != null and part.mesh is TorusMesh:
			facility_has_torus = true
	_check(facility_has_torus, "设施有立体台座与接收光环")

	if view != null:
		var fake_snapshot := {
			"revision": 987654,
			"ghosts": [],
			"items": [],
			"links": [{
				"from_cell": Vector2i(2, 3),
				"to_cell": Vector2i(5, 3),
				"path": [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)],
			}],
		}
		view.Refresh(fake_snapshot)
		var lines_node := instance.get_node_or_null("Level3D/World/Lines")
		var pipes := 0
		for child in lines_node.get_children():
			var part := child as MeshInstance3D
			if part != null and part.mesh is CylinderMesh:
				pipes += 1
		_check(pipes == 3, "三段连线各用一根圆管，实际 %d" % pipes)

	if hud != null:
		_check(hud.theme != null and hud.theme.has_stylebox("normal", "Button"), "HUD 已套用 UIPalette 按钮样式")

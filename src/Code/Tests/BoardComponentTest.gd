extends Node

## 关卡组件层的 headless 测试：GridUtil 几何计算、组件占位、BoardGrid 占用校验。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/BoardComponentTest.tscn

var _failures: int = 0
var _checks: int = 0

func _ready() -> void:
	await _test_grid_util()
	await _test_components()
	await _test_board_grid()
	print("---- 结果：%d 项断言，%d 项失败" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## 记录一条断言结果。
## @param condition 断言条件，成立为 true。
## @param label 断言描述。
func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS  %s" % label)
	else:
		_failures += 1
		print("FAIL  %s" % label)

## 比较两个浮点数，误差在 epsilon 内视为相等。
## @param a 左值。
## @param b 右值。
## @param epsilon 允许误差。
## @return 近似相等时返回 true。
func _nearly_equal(a: float, b: float, epsilon: float = 0.01) -> bool:
	return absf(a - b) <= epsilon

## 测试 GridUtil 的各静态方法。
func _test_grid_util() -> void:
	print("== GridUtil ==")
	_check(GridUtil.CELL_SIZE == 64.0, "CELL_SIZE 为 64")

	_check(GridUtil.CellToWorld(Vector2i(0, 0)) == Vector2(32, 32), "CellToWorld((0,0)) 为 (32,32)")
	_check(GridUtil.CellToWorldCorner(Vector2i(0, 0)) == Vector2(0, 0), "CellToWorldCorner((0,0)) 为 (0,0)")
	_check(GridUtil.CellToWorld(Vector2i(2, 3)) == Vector2(160, 224), "CellToWorld((2,3)) 为 (160,224)")
	_check(GridUtil.CellToWorldCorner(Vector2i(2, 3)) == Vector2(128, 192), "CellToWorldCorner((2,3)) 为 (128,192)")

	var round_trip_ok := true
	for x in range(0, 10):
		for y in range(0, 8):
			if GridUtil.WorldToCell(GridUtil.CellToWorld(Vector2i(x, y))) != Vector2i(x, y):
				round_trip_ok = false
	_check(round_trip_ok, "CellToWorld 与 WorldToCell 往返一致")

	_check(GridUtil.InBounds(Vector2i(0, 0), Vector2i(10, 8)), "InBounds 接受 (0,0)")
	_check(GridUtil.InBounds(Vector2i(9, 7), Vector2i(10, 8)), "InBounds 接受 (9,7)")
	_check(not GridUtil.InBounds(Vector2i(10, 0), Vector2i(10, 8)), "InBounds 拒绝 (10,0)")
	_check(not GridUtil.InBounds(Vector2i(-1, 0), Vector2i(10, 8)), "InBounds 拒绝 (-1,0)")
	_check(not GridUtil.InBounds(Vector2i(0, 8), Vector2i(10, 8)), "InBounds 拒绝 (0,8)")

	_check(GridUtil.Neighbors4(Vector2i(3, 3)).size() == 4, "Neighbors4 数量为 4")
	var n4 := GridUtil.Neighbors4(Vector2i(3, 3))
	_check(n4.has(Vector2i(3, 2)) and n4.has(Vector2i(4, 3)) and n4.has(Vector2i(3, 4)) and n4.has(Vector2i(2, 3)),
		"Neighbors4 含上右下左")

	_check(GridUtil.Manhattan(Vector2i(0, 0), Vector2i(3, 4)) == 7, "Manhattan((0,0),(3,4)) 为 7")
	_check(GridUtil.Manhattan(Vector2i(2, 2), Vector2i(2, 2)) == 0, "Manhattan 自身为 0")

	var norm := GridUtil.NormalizeFootprint([Vector2i(-1, 0), Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, 1)])
	_check(norm.size() == 3, "NormalizeFootprint 去重后为 3 格")
	_check(norm.has(Vector2i(0, 0)) and norm.has(Vector2i(1, 0)) and norm.has(Vector2i(1, 1)),
		"NormalizeFootprint 平移到最小 (0,0)")
	_check(GridUtil.NormalizeFootprint([]).is_empty(), "NormalizeFootprint 空输入返回空数组")

	var bounds := GridUtil.FootprintBounds([Vector2i(1, 1), Vector2i(3, 2), Vector2i(2, 4)])
	_check(bounds.position == Vector2i(1, 1), "FootprintBounds 起点为 (1,1)")
	_check(bounds.size == Vector2i(3, 4), "FootprintBounds 尺寸为 (3,4)")
	_check(GridUtil.FootprintBounds([]).size == Vector2i.ZERO, "FootprintBounds 空输入返回零矩形")

	var moved := GridUtil.Translate([Vector2i(0, 0), Vector2i(1, 0)], Vector2i(5, 2))
	_check(moved.size() == 2 and moved[0] == Vector2i(5, 2) and moved[1] == Vector2i(6, 2), "Translate 平移正确")

	var overlap := GridUtil.Overlap([Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(1, 0), Vector2i(2, 0)])
	_check(overlap.size() == 1 and overlap[0] == Vector2i(1, 0), "Overlap 返回公共格")
	_check(GridUtil.Overlap([Vector2i(0, 0)], [Vector2i(5, 5)]).is_empty(), "Overlap 无公共格时返回空数组")

	var path := GridUtil.PathL(Vector2i(0, 0), Vector2i(3, 2))
	_check(path.size() == 6, "PathL 长度为首尾加 4 步共 6 格，实际 %d" % path.size())
	_check(path[0] == Vector2i(0, 0), "PathL 起点正确")
	_check(path[path.size() - 1] == Vector2i(3, 2), "PathL 终点正确")
	var orthogonal := true
	for i in range(1, path.size()):
		var d := path[i] - path[i - 1]
		if absi(d.x) + absi(d.y) != 1:
			orthogonal = false
	_check(orthogonal, "PathL 每步都是正交移动")
	var path_y_first := GridUtil.PathL(Vector2i(0, 0), Vector2i(3, 2), false)
	_check(path_y_first[1] == Vector2i(0, 1), "PathL prefer_x_first=false 时先走 Y 轴")
	_check(GridUtil.PathL(Vector2i(2, 2), Vector2i(2, 2)).size() == 1, "PathL 起终点相同返回单格")

## 测试四个组件的占位与参数。
func _test_components() -> void:
	print("== 组件 ==")
	var ghost_scene: PackedScene = load("res://Code/Entities/Board/GhostComponent.tscn")
	var ghost := ghost_scene.instantiate() as Node2D
	var ghost_footprint: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var ghost_appendages: Array[Vector2i] = [Vector2i(0, 1)]
	ghost.set("footprint", ghost_footprint)
	ghost.set("appendages", ghost_appendages)
	ghost.set("cell", Vector2i(2, 3))
	add_child(ghost)
	await get_tree().process_frame

	_check(ghost.get("cell") == Vector2i(2, 3), "GhostComponent 记录 cell")
	_check(ghost.call("GetOccupiedCells").size() == 3, "GhostComponent 占位数为 footprint + appendages")
	_check(ghost.call("GetBodyCells").size() == 2, "GhostComponent 本体占位 2 格")
	_check(ghost.call("GetAppendageCells").size() == 1, "GhostComponent 附属占位 1 格")
	_check(ghost.position.distance_to(GridUtil.CellToWorld(Vector2i(2, 3))) < 0.01,
		"GhostComponent 位置与 CellToWorld 一致")
	_check(ghost.call("GetGhostId") == "LongTongue", "GhostComponent 返回 ghost_id")
	_check(ghost.call("GetFacingVector") == Vector2i(1, 0), "GhostComponent 朝向 0 对应东")
	_check(_nearly_equal(ghost.call("GetFacingAngle"), 0.0), "GhostComponent 朝向角为 0")

	# GhostData 资源存在时读取数据，不存在时安全降级为 null。
	var data = ghost.call("GetGhostData")
	if data == null:
		print("PASS  GhostComponent 在 GhostData 缺失时安全降级为 null")
		_check(ghost.call("GetBodyCells").size() >= 1, "降级时本体占位仍为至少 1 格")
	else:
		print("PASS  GhostComponent 成功读取 GhostData 资源")
		_check(ghost.call("GetBodyColor") is Color, "降级或正常时都能取到本体色")

	ghost.call("SetCell", Vector2i(4, 4))
	await get_tree().process_frame
	_check(ghost.position.distance_to(GridUtil.CellToWorld(Vector2i(4, 4))) < 0.01,
		"SetCell 后位置重新对齐")

	var term_scene: PackedScene = load("res://Code/Entities/Board/TerminalComponent.tscn")
	var term := term_scene.instantiate() as Node2D
	var term_footprint: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	term.set("cell", Vector2i(8, 2))
	term.set("footprint", term_footprint)
	add_child(term)
	await get_tree().process_frame
	var term_cells: Array = term.call("GetWorldCells")
	_check(term_cells.size() == 2, "TerminalComponent 占位 2 格")
	_check(term_cells.has(Vector2i(8, 2)) and term_cells.has(Vector2i(9, 2)), "TerminalComponent 占位坐标正确")
	_check(term.call("GetAcceptedForm") == "Raw", "TerminalComponent 返回 accepts")
	term.call("AddDelivered", 3)
	_check(term.call("GetDeliveredCount") == 3, "TerminalComponent 累加交付数")

	var field_scene: PackedScene = load("res://Code/Entities/Board/FieldComponent.tscn")
	var field := field_scene.instantiate() as Node2D
	var field_shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	field.set("origin_cell", Vector2i(1, 1))
	field.set("shape", field_shape)
	field.set("base_rate", 0.6)
	add_child(field)
	await get_tree().process_frame
	_check(field.call("GetArea") == 4, "FieldComponent 面积为 4")
	_check(field.call("GetCells").size() == 4, "FieldComponent 覆盖 4 格")
	_check(_nearly_equal(field.call("GetDropRate"), 1.2), "FieldComponent 掉落速率为 1.2，实际 %f" % field.call("GetDropRate"))

	var obst_scene: PackedScene = load("res://Code/Entities/Board/ObstacleComponent.tscn")
	var obst := obst_scene.instantiate() as Node2D
	var obst_shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	obst.set("origin_cell", Vector2i(6, 6))
	obst.set("shape", obst_shape)
	obst.set("kind", "machine")
	add_child(obst)
	await get_tree().process_frame
	_check(obst.call("GetKind") == "machine", "ObstacleComponent 返回 kind")
	_check(obst.call("GetCells").size() == 2, "ObstacleComponent 覆盖 2 格")

## 测试 BoardGrid 的占用汇总与放置校验。
func _test_board_grid() -> void:
	print("== BoardGrid ==")
	var grid_scene: PackedScene = load("res://Code/Entities/Board/BoardGrid.tscn")
	var grid := grid_scene.instantiate() as Node2D
	add_child(grid)
	await get_tree().process_frame
	grid.set("grid_size", Vector2i(10, 8))
	_check(grid.call("GetCellSize") == Vector2i(10, 8), "BoardGrid 尺寸为 10×8")
	_check(grid.call("GetWorldRect").size == Vector2(640, 512), "BoardGrid 世界矩形为 640×512")
	_check(grid.call("IsInside", Vector2i(9, 7)), "BoardGrid 判定 (9,7) 在界内")
	_check(not grid.call("IsInside", Vector2i(10, 7)), "BoardGrid 判定 (10,7) 越界")

	var ghost_scene: PackedScene = load("res://Code/Entities/Board/GhostComponent.tscn")
	var ghost := ghost_scene.instantiate() as Node2D
	var grid_footprint: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var grid_appendages: Array[Vector2i] = [Vector2i(0, 1)]
	ghost.set("footprint", grid_footprint)
	ghost.set("appendages", grid_appendages)
	ghost.set("cell", Vector2i(2, 2))
	grid.add_child(ghost)
	await get_tree().process_frame

	var world_cells: Array = ghost.call("GetWorldCells")
	_check(world_cells.size() == 3, "GetWorldCells 与占位数一致")
	var world_consistent := true
	for c: Vector2i in world_cells:
		if grid.call("WorldToCell", GridUtil.CellToWorld(c)) != c:
			world_consistent = false
	_check(world_consistent, "GetWorldCells 与 BoardGrid.WorldToCell 换算一致")

	var occupied: Dictionary = grid.call("GetOccupiedCells")
	_check(occupied.size() == 3, "BoardGrid 汇总出 3 个被占格")
	_check(occupied.has(Vector2i(2, 2)) and occupied.has(Vector2i(3, 2)) and occupied.has(Vector2i(2, 3)),
		"被占格坐标正确")
	_check(grid.call("GetComponentAt", Vector2i(2, 2)) == ghost, "GetComponentAt 返回对应组件")
	_check(grid.call("GetComponentAt", Vector2i(9, 9)) == null, "空格的 GetComponentAt 返回 null")
	_check(grid.call("GetGhostComponents").size() == 1, "BoardGrid 收集到 1 个鬼组件")

	# 重叠放置应失败。
	var overlap_cells: Array[Vector2i] = [Vector2i(3, 2)]
	_check(not grid.call("CanPlace", overlap_cells, null), "与已有鬼重叠时 CanPlace 为 false")
	# 越界应失败。
	var oob_cells: Array[Vector2i] = [Vector2i(10, 0)]
	_check(not grid.call("CanPlace", oob_cells, null), "越界时 CanPlace 为 false")
	var oob_cells2: Array[Vector2i] = [Vector2i(0, 8)]
	_check(not grid.call("CanPlace", oob_cells2, null), "下边界外 CanPlace 为 false")
	# 不重叠应成功。
	var free_cells: Array[Vector2i] = [Vector2i(7, 5)]
	_check(grid.call("CanPlace", free_cells, null), "不重叠时 CanPlace 为 true")
	# 忽略自身时应成功。
	var self_cells: Array[Vector2i] = [Vector2i(2, 2)]
	_check(grid.call("CanPlace", self_cells, ghost), "忽略自身时 CanPlace 为 true")
	# 忽略自身也仍然受边界约束。
	var self_oob: Array[Vector2i] = [Vector2i(2, 2), Vector2i(10, 2)]
	_check(not grid.call("CanPlace", self_oob, ghost), "忽略自身时越界仍为 false")

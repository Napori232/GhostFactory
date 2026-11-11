extends Node

## 数据层 headless 测试：四只基础鬼与三关资源可加载、字段与规格一致，
## 并覆盖端口标签判定规则（D1）与 3D 坐标换算互逆性。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/LevelDataLoadTest.tscn

const GHOST_DIR: String = "res://Code/Data/Ghosts/"
const LEVEL_DIR: String = "res://Code/Data/Levels/"

var _checks: int = 0
var _failures: int = 0

func _ready() -> void:
	await get_tree().process_frame
	_test_ghosts()
	_test_levels()
	_test_port_rules()
	_test_grid3d()
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

## 加载一个资源并断言加载成功。
## @param path res:// 路径。
## @return 加载到的 Resource；失败返回 null。
func _load(path: String) -> Resource:
	var res := load(path)
	_check(res != null, "资源可加载 %s" % path)
	return res

## 四只基础鬼的配置核对。
func _test_ghosts() -> void:
	var producer := _load(GHOST_DIR + "Producer.tres") as GhostData
	var collector := _load(GHOST_DIR + "Collector.tres") as GhostData
	var transporter := _load(GHOST_DIR + "Transporter.tres") as GhostData
	var processor := _load(GHOST_DIR + "Processor.tres") as GhostData
	if producer == null or collector == null or transporter == null or processor == null:
		return

	_check(producer.id == &"producer", "生产鬼 id 正确")
	_check(producer.category == GhostData.CATEGORY_PRODUCTION, "生产鬼大类正确")
	_check(producer.movability == GhostData.MOVABILITY_RIGID, "生产鬼为刚体")
	_check(producer.cycle_time == 2.0, "生产鬼周期 2.0 s")
	_check(producer.buffer_capacity == 3, "生产鬼缓冲 3")
	_check(producer.ports.is_empty(), "生产鬼无连线输出端口（D3）")
	_check(producer.GetFootprintAt(Vector2i(3, 4)) == [Vector2i(3, 4)], "生产鬼占位换算正确")

	_check(collector.category == GhostData.CATEGORY_COLLECTION, "采集鬼大类正确")
	_check(collector.movability == GhostData.MOVABILITY_SOFT, "采集鬼为柔体")
	_check(collector.cycle_time == 0.5, "采集鬼拾取间隔 0.5 s")
	_check(collector.GetOutputPort() != null, "采集鬼有输出端口")
	_check(collector.GetOutputPort().produces.is_empty(), "采集鬼输出标签动态留空（D2）")

	_check(transporter.category == GhostData.CATEGORY_TRANSPORT, "运输鬼大类正确")
	_check(transporter.cycle_time == 0.3, "运输鬼 0.3 s/格")
	_check(transporter.GetInputPort() != null and transporter.GetOutputPort() != null, "运输鬼输入输出端口齐全")
	_check(transporter.GetInputPort().buffer_size == 1, "运输鬼输入缓冲 1")

	_check(processor.category == GhostData.CATEGORY_PROCESSING, "处理鬼大类正确")
	_check(processor.cycle_time == 1.2, "处理鬼周期 1.2 s")
	_check(processor.recipe_id == "SpiritToOffer", "处理鬼关联配方正确")
	_check(processor.GetInputPort().accepts.has(GhostTag.IMPURITY), "处理鬼可接受杂质回收")

## 三关配置核对。
func _test_levels() -> void:
	var l1 := _load(LEVEL_DIR + "Level01.tres") as LevelData
	var l2 := _load(LEVEL_DIR + "Level02.tres") as LevelData
	var l3 := _load(LEVEL_DIR + "Level03.tres") as LevelData
	if l1 == null or l2 == null or l3 == null:
		return

	_check(l1.id == 1 and l1.grid_size == Vector2i(10, 8), "关卡 1 网格 10×8")
	_check(l1.time_limit == 90.0, "关卡 1 时限 90 s")
	_check(l1.goal_form == "Spirit" and l1.goal_amount == 30, "关卡 1 目标 30 个鬼能")
	_check(l1.start_spirit == 30, "关卡 1 开局鬼能 30")
	_check(l1.GetPlaceableCount() == 18, "关卡 1 可放置区 18 格")
	_check(l1.obstacle_cells.size() == 3, "关卡 1 障碍 3 格")
	_check(l1.allowed_ghost_ids == [&"producer"], "关卡 1 仅生产鬼")
	_check(l1.HasFacilityAt(Vector2i(8, 4)), "关卡 1 交付口位于 (8,4)")
	_check(l1.GetFacilityAt(Vector2i(8, 4)).accepted_form == "Spirit", "关卡 1 交付口接收鬼能")
	_check(l1.GetStarThresholds().two_star_time == 75.0, "关卡 1 2★ 基准 75 s")
	_check(l1.GetStarThresholds().manual_limit == 40, "关卡 1 手动次数上限 40（D5）")
	_check(l1.HasProducerZone(), "关卡 1 也划出生产专属区")
	_check(l1.GetProducerOnlyCells().size() == 6, "关卡 1 生产带 6 格")
	_check(
		l1.GetProducerOnlyCells() == [
			Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
			Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4),
		],
		"关卡 1 生产带为可放置区中间一整排"
	)
	_check(l1.IsProducerOnly(Vector2i(3, 4)) and not l1.IsProducerOnly(Vector2i(3, 3)), "关卡 1 蓝格不是生产区")
	for cell in l1.GetProducerOnlyCells():
		_check(l1.IsPlaceable(cell), "关卡 1 生产格 %s 落在可放置区内" % cell)

	_check(l2.id == 2 and l2.grid_size == Vector2i(12, 9), "关卡 2 网格 12×9")
	_check(l2.time_limit == 120.0, "关卡 2 时限 120 s")
	_check(l2.goal_form == "Spirit" and l2.goal_amount == 72, "关卡 2 目标按 D4 改为 72 个鬼能")
	_check(l2.GetPlaceableCount() == 22, "关卡 2 可放置区 22 格")
	_check(l2.allowed_ghost_ids == [&"producer", &"collector", &"transporter"], "关卡 2 无处理鬼，配置自洽")
	_check(l2.HasFacilityAt(Vector2i(10, 3)), "关卡 2 交付口上移一格到 (10,3)")
	_check(l2.GetFacilityAt(Vector2i(10, 3)).accepted_form == "Spirit", "关卡 2 交付口随 D4 改收鬼能")
	_check(not l2.HasFacilityAt(Vector2i(10, 2)), "关卡 2 旧交付口 (10,2) 已撤销")
	_check(l2.HasProducerZone(), "关卡 2 划出生产专属区")
	_check(
		l2.GetProducerOnlyCells() == [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3)],
		"关卡 2 生产专属区为左上蓝区第一排 3 格"
	)
	_check(l2.IsProducerOnly(Vector2i(2, 3)), "(2,3) 属于生产专属区")
	_check(not l2.IsProducerOnly(Vector2i(2, 4)), "(2,4) 是普通蓝格")
	_check(l1.HasProducerZone() and l2.HasProducerZone() and l3.HasProducerZone(), "三关统一启用生产专属区")

	_check(l3.id == 3 and l3.grid_size == Vector2i(14, 10), "关卡 3 网格 14×10")
	_check(l3.time_limit == 120.0, "关卡 3 时限 120 s")
	_check(l3.goal_form == "Offer" and l3.goal_amount == 55, "关卡 3 目标 55 个贡品")
	_check(l3.GetPlaceableCount() == 26, "关卡 3 可放置区 26 格")
	_check(l3.allowed_ghost_ids.has(&"processor"), "关卡 3 含处理鬼")
	_check(l3.GetFacilityAt(Vector2i(12, 2)).accepted_form == "Offer", "关卡 3 交付口接收贡品")
	_check(l3.obstacle_cells.size() == 8, "关卡 3 中央墙 8 格")
	_check(l3.HasProducerZone(), "关卡 3 也划出生产专属区")
	_check(
		l3.GetProducerOnlyCells() == [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)],
		"关卡 3 生产带为左上 A 区顶排 4 格"
	)
	_check(l3.IsProducerOnly(Vector2i(2, 2)) and not l3.IsProducerOnly(Vector2i(2, 3)), "关卡 3 采集鬼所在格不是生产区")
	for cell in l3.GetProducerOnlyCells():
		_check(l3.IsPlaceable(cell), "关卡 3 生产格 %s 落在可放置区内" % cell)

## 端口标签判定：只认物料标签（D1）。
func _test_port_rules() -> void:
	var spirit_out: Array[StringName] = [GhostTag.SPIRIT]
	var spirit_in: Array[StringName] = [GhostTag.SPIRIT]
	var offer_in: Array[StringName] = [GhostTag.OFFER]
	_check(GhostTag.CanConnect(spirit_out, spirit_in), "SPIRIT 输出 → SPIRIT 输入可连")
	_check(not GhostTag.CanConnect(spirit_out, offer_in), "SPIRIT 输出 → 仅收 OFFER 的输入不可连")
	var action_out: Array[StringName] = [GhostTag.HAUL, GhostTag.GROUND]
	_check(not GhostTag.CanConnect(action_out, spirit_in), "动作标签不参与连线判定（D1）")
	_check(GhostTag.CanConnect([GhostTag.IMPURITY], [GhostTag.IMPURITY]), "杂质标签可连")

## 3D 坐标换算：全格往返一致 + 八向吸附。
func _test_grid3d() -> void:
	var all_ok := true
	for y in range(10):
		for x in range(8):
			var cell := Vector2i(x, y)
			if Grid3D.World3DToCell(Grid3D.CellToWorld3D(cell)) != cell:
				all_ok = false
	_check(all_ok, "Grid3D 全格往返互逆")
	_check(Grid3D.SnapYawDegrees(37.0) == 45.0, "偏航 37° 吸附到 45°")
	_check(Grid3D.SnapYawDegrees(-37.0) == 315.0, "偏航 -37° 吸附到 315°")
	_check(Grid3D.SnapYawDegrees(370.0) == 0.0, "偏航 370° 归一化到 0°")
	for step in range(8):
		var deg := Grid3D.YawStepToDegrees(step)
		_check(fmod(deg, Grid3D.YAW_STEP) == 0.0, "偏航档 %d 为 45° 整数倍" % step)
	_check(Grid3D.ZoomLevelToSize(0) == 8.0 and Grid3D.ZoomLevelToSize(2) == 16.0, "三档缩放 8 / 16 格")

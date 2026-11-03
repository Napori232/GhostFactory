extends Node

## 教程系统自测。覆盖步骤数据、遮罩层、总控与信号总线。
##
## 运行方式：godot --headless --path <项目> res://Code/Tests/TutorialTest.tscn

const STEPS_PATH: String = "res://Data/Tutorial/tutorial_steps.tres"
const OVERLAY_SCENE_PATH: String = "res://Code/Entities/Tutorial/TutorialOverlay.tscn"
const CONTROLLER_SCENE_PATH: String = "res://Code/Entities/Tutorial/TutorialController.tscn"
const LEVEL_SCENE_PATH: String = "res://Code/Entities/Level/Level.tscn"

var _failures: int = 0
var _checks: int = 0

func _ready() -> void:
	_test_steps_data()
	_test_overlay()
	await _test_controller()
	_test_signal_bus()
	await _test_scene_open()
	_report()

## 断言条件成立。
## @param condition 条件结果。
## @param label 断言描述。
func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		_failures += 1
		printerr("FAIL: %s" % label)

## 步骤数据：能加载、6 步、字段非空。
func _test_steps_data() -> void:
	var resource := ResourceLoader.load(STEPS_PATH)
	_check(resource is TutorialScript, "步骤数据可加载且类型为 TutorialScript")
	if not (resource is TutorialScript):
		return
	var steps: Array[TutorialStep] = (resource as TutorialScript).steps
	_check(steps.size() == 6, "步骤数量为 6（实际 %d）" % steps.size())
	for step in steps:
		_check(not step.step_id.is_empty(), "步骤 %s 的 step_id 非空" % step.step_id)
		_check(not step.title.is_empty(), "步骤 %s 的 title 非空" % step.step_id)
		_check(not step.target_anchor.is_empty(), "步骤 %s 的 target_anchor 非空" % step.step_id)
		_check(not step.description.is_empty(), "步骤 %s 的 description 非空" % step.step_id)
	var ids: Array[String] = []
	for step in steps:
		ids.append(step.step_id)
	_check(ids == ["welcome", "place", "connect", "deliver", "spirit", "finish"], "步骤 id 顺序正确")

## 遮罩层：显示步骤后四块遮罩可见、气泡文字非空、下标正确。
func _test_overlay() -> void:
	var scene := ResourceLoader.load(OVERLAY_SCENE_PATH) as PackedScene
	_check(scene != null, "TutorialOverlay 场景可加载")
	if scene == null:
		return
	var overlay := scene.instantiate() as TutorialOverlay
	add_child(overlay)
	await get_tree().process_frame
	var step := TutorialStep.new()
	step.step_id = "test"
	step.title = "测试标题"
	step.description = "测试正文"
	step.target_anchor = "board"
	step.wait_for = TutorialStep.WAIT_AUTO
	overlay.ShowStep(step, Rect2(120.0, 120.0, 200.0, 160.0), 2, 6)
	_check(overlay.visible, "遮罩层显示后可见")
	_check(overlay.GetCurrentIndex() == 2, "GetCurrentIndex 返回 2")
	var masks := _find_masks(overlay)
	_check(masks.size() == 4, "遮罩层含 4 块遮罩（实际 %d）" % masks.size())
	for mask in masks:
		_check(mask.visible, "遮罩 %s 可见" % mask.name)
	_check(not _label_text(overlay, "TitleLabel").is_empty(), "气泡标题非空")
	_check(not _label_text(overlay, "BodyLabel").is_empty(), "气泡正文非空")
	_check(not _label_text(overlay, "ProgressLabel").is_empty(), "气泡进度文字非空")
	overlay.Hide()
	_check(not overlay.visible, "Hide 后遮罩层不可见")
	overlay.queue_free()

## 取得四块遮罩。
func _find_masks(overlay: TutorialOverlay) -> Array[ColorRect]:
	var result: Array[ColorRect] = []
	for child in overlay.get_children():
		if child is ColorRect:
			result.append(child as ColorRect)
	return result

## 取得气泡里某个 Label 的文字。
func _label_text(overlay: TutorialOverlay, label_name: String) -> String:
	var label := overlay.find_child(label_name, true, false) as Label
	if label == null:
		return ""
	return label.text

## 总控：Start 后运行中；Skip 后停止并写入 skip_tutorial。
func _test_controller() -> void:
	var original_skip := bool(SaveManager.GetSetting(&"skip_tutorial", false))
	var scene := ResourceLoader.load(CONTROLLER_SCENE_PATH) as PackedScene
	_check(scene != null, "TutorialController 场景可加载")
	if scene == null:
		return
	var controller := scene.instantiate() as TutorialController
	add_child(controller)
	await get_tree().process_frame
	controller.Start()
	await get_tree().process_frame
	_check(controller.IsRunning(), "Start 后 IsRunning 为 true")
	_check(controller.GetStepCount() == 6, "总控读到 6 个步骤")
	_check(controller.GetCurrentStep() != null, "总控能取得当前步骤")
	controller.Skip()
	await get_tree().process_frame
	_check(not controller.IsRunning(), "Skip 后 IsRunning 为 false")
	_check(bool(SaveManager.GetSetting(&"skip_tutorial", false)), "Skip 后 skip_tutorial 变为 true")
	# 测试结束恢复原设置，避免污染玩家存档。
	SaveManager.SetSetting(&"skip_tutorial", original_skip)
	_check(bool(SaveManager.GetSetting(&"skip_tutorial", false)) == original_skip, "skip_tutorial 已恢复原值")
	controller.queue_free()

## 信号总线：存在教程用到的信号。
func _test_signal_bus() -> void:
	_check("LineCreated" in SignalBus, "SignalBus 存在 LineCreated 信号")
	_check("TutorialCompleted" in SignalBus, "SignalBus 存在 TutorialCompleted 信号")
	_check("GhostPlaced" in SignalBus, "SignalBus 存在 GhostPlaced 信号")
	_check("ItemDelivered" in SignalBus, "SignalBus 存在 ItemDelivered 信号")

## 三个相关场景能实例化且不报错。
func _test_scene_open() -> void:
	for path in [OVERLAY_SCENE_PATH, CONTROLLER_SCENE_PATH, LEVEL_SCENE_PATH]:
		var scene := ResourceLoader.load(path) as PackedScene
		_check(scene != null, "场景可加载：%s" % path)
		if scene == null:
			continue
		var node := scene.instantiate()
		add_child(node)
		await get_tree().process_frame
		_check(is_instance_valid(node), "场景实例化成功：%s" % path)
		node.queue_free()
		await get_tree().process_frame

## 输出汇总并退出。
func _report() -> void:
	print("---- 教程系统自测结束：%d 项断言，%d 项失败 ----" % [_checks, _failures])
	if _failures > 0:
		printerr("TutorialTest FAILED")
		get_tree().quit(1)
	else:
		print("TutorialTest PASSED")
		get_tree().quit(0)

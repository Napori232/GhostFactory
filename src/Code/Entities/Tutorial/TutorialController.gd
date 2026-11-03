class_name TutorialController
extends Node

## 教程总控。加载步骤数据，按顺序驱动遮罩层推进教程。
##
## 步骤的推进条件由 TutorialStep.wait_for 决定：等待任意点击、等待放置鬼、
## 等待连线、等待交付，或定时自动继续。

## 步骤切换时发出。
signal StepChanged(index: int)
## 教程全部完成时发出。
signal TutorialFinished()
## 玩家中途跳过教程时发出。
signal TutorialSkipped()

## 步骤数据资源路径。
@export var steps_path: String = "res://Data/Tutorial/tutorial_steps.tres"
## 覆盖层节点。
@export var overlay: TutorialOverlay = null
## 目标锚点名到实际节点的解析器：由外部注入。
@export var anchor_resolver: Callable = Callable()

const ANCHOR_PALETTE: String = "palette"
const ANCHOR_BOARD: String = "board"
const ANCHOR_TERMINAL: String = "terminal"
const OVERLAY_NODE_NAME: String = "Overlay"
const SETTING_TUTORIAL_COMPLETED: StringName = &"tutorial_completed"

var _steps: Array[TutorialStep] = []
var _index: int = -1
var _running: bool = false
var _auto_token: int = 0

func _ready() -> void:
	if overlay == null:
		overlay = get_node_or_null(OVERLAY_NODE_NAME) as TutorialOverlay
	_steps = _load_steps()
	if _steps.is_empty():
		return
	SignalBus.GhostPlaced.connect(_on_ghost_placed)
	SignalBus.LineCreated.connect(_on_line_created)
	SignalBus.ItemDelivered.connect(_on_item_delivered)
	if overlay != null:
		overlay.StepCompleted.connect(_on_overlay_step_completed)
		overlay.StepReverted.connect(_on_overlay_step_reverted)
		overlay.TutorialSkipped.connect(_on_overlay_skipped)
	if _should_auto_start():
		Start.call_deferred()

## 判断是否应当在进入关卡时自动弹出教程。
## @return 需要自动开始时返回 true。
func _should_auto_start() -> bool:
	if not ExportSettings.tutorial_enabled:
		return false
	if bool(SaveManager.GetSetting(&"skip_tutorial", false)):
		return false
	if bool(SaveManager.GetSetting(SETTING_TUTORIAL_COMPLETED, false)):
		return false
	return _get_host_level_id() == 1

## 取得宿主关卡的编号。
## @return 关卡编号；取不到时返回 0。
func _get_host_level_id() -> int:
	var host := get_parent()
	if host != null:
		var value: Variant = host.get("_level_id")
		if value is int:
			return value
	return 0

## 加载步骤数据资源。
## @return 步骤列表；资源缺失或类型不符时返回空数组。
func _load_steps() -> Array[TutorialStep]:
	if not ResourceLoader.exists(steps_path):
		push_warning("教程步骤数据不存在：%s" % steps_path)
		return []
	var resource := ResourceLoader.load(steps_path)
	if resource is TutorialScript:
		return (resource as TutorialScript).steps
	if resource is TutorialStep:
		return [resource as TutorialStep]
	push_warning("教程步骤数据类型不符：%s" % steps_path)
	return []

## 开始教程。
func Start() -> void:
	if _running or _steps.is_empty():
		return
	_index = 0
	_running = true
	_show_step()

## 结束教程并隐藏覆盖层。
func Stop() -> void:
	_running = false
	_auto_token += 1
	if overlay != null:
		overlay.Hide()

## 跳过教程，并写入 skip_tutorial 设置。
func Skip() -> void:
	if not _running:
		return
	SaveManager.SetSetting(&"skip_tutorial", true)
	Stop()
	TutorialSkipped.emit()

## 前进到下一步。
func Next() -> void:
	if not _running:
		return
	if _index + 1 >= _steps.size():
		_finish()
		return
	_index += 1
	_show_step()

## 回到上一步。
func Previous() -> void:
	if not _running or _index <= 0:
		return
	_index -= 1
	_show_step()

## 取得当前步骤。
## @return 当前步骤；没有运行教程时返回 null。
func GetCurrentStep() -> TutorialStep:
	if _index < 0 or _index >= _steps.size():
		return null
	return _steps[_index]

## 教程是否正在运行。
## @return 正在运行时返回 true。
func IsRunning() -> bool:
	return _running

## 取得步骤总数。
## @return 步骤数。
func GetStepCount() -> int:
	return _steps.size()

## 显示当前步骤。
func _show_step() -> void:
	var step := GetCurrentStep()
	if step == null:
		return
	var rect := _resolve_anchor_rect(step.target_anchor)
	if overlay != null:
		overlay.ShowStep(step, rect, _index, _steps.size())
		# 「等待任意点击」的步骤由点击热区推进，「下一步」按钮已隐藏；其余步骤允许手动推进。
		overlay.SetNextEnabled(true)
	StepChanged.emit(_index)
	if step.wait_for == TutorialStep.WAIT_AUTO:
		_start_auto_timer(step.auto_duration)

## 定时自动继续。
func _start_auto_timer(duration: float) -> void:
	_auto_token += 1
	var token := _auto_token
	await get_tree().create_timer(maxf(duration, 0.1)).timeout
	if not _running or token != _auto_token:
		return
	Next()

## 教程走完。
func _finish() -> void:
	_running = false
	_auto_token += 1
	if overlay != null:
		overlay.Hide()
	SaveManager.SetSetting(&"tutorial_completed", true)
	TutorialFinished.emit()
	SignalBus.TutorialCompleted.emit()

## 解析锚点到画布矩形。
## @param anchor_name 锚点名，例如 palette / board / terminal。
## @return 目标矩形；找不到目标时返回空矩形。
func _resolve_anchor_rect(anchor_name: String) -> Rect2:
	if anchor_resolver.is_valid():
		var result: Variant = anchor_resolver.call(anchor_name)
		var rect := _to_canvas_rect(result)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			return rect
	return _resolve_default_anchor(anchor_name)

## 未注入解析器时的默认查找：先按唯一名，再按语义别名。
func _resolve_default_anchor(anchor_name: String) -> Rect2:
	var host := _find_host_scene()
	if host == null:
		return Rect2()
	var unique := host.get_node_or_null("%" + anchor_name)
	if unique != null:
		var unique_rect := _to_canvas_rect(unique)
		if unique_rect.size.x > 0.0 and unique_rect.size.y > 0.0:
			return unique_rect
	match anchor_name:
		ANCHOR_PALETTE:
			return _to_canvas_rect(host.get_node_or_null("%GhostBar"))
		ANCHOR_BOARD:
			return _to_canvas_rect(host.get_node_or_null("%BoardHost"))
		ANCHOR_TERMINAL:
			return _to_canvas_rect(_find_terminal(host))
	return Rect2()

## 找到承载关卡内容的场景根节点。
func _find_host_scene() -> Node:
	var node: Node = self
	while node != null:
		if node.get_node_or_null("%BoardHost") != null:
			return node
		node = node.get_parent()
	return get_tree().current_scene

## 在板面里找第一个供品口组件。
func _find_terminal(host: Node) -> Node:
	for child in host.find_children("*", "Node2D", true, false):
		if child.has_method("get_accepted_form"):
			return child
	return null

## 把节点或矩形换算成画布矩形。
func _to_canvas_rect(target: Variant) -> Rect2:
	if target is Rect2:
		return target
	if target is Control:
		return (target as Control).get_global_rect()
	if target is Node2D:
		var half := GridUtil.HALF_CELL
		var origin := (target as Node2D).global_position
		return Rect2(origin - Vector2(half, half), Vector2(half * 2.0, half * 2.0))
	return Rect2()

func _on_overlay_step_completed(_index: int) -> void:
	Next()

func _on_overlay_step_reverted(_index: int) -> void:
	Previous()

func _on_overlay_skipped() -> void:
	Skip()

func _on_ghost_placed(_ghost: Node) -> void:
	var step := GetCurrentStep()
	if _running and step != null and step.wait_for == TutorialStep.WAIT_PLACE_GHOST:
		Next()

func _on_line_created(_from: Node, _to: Node) -> void:
	var step := GetCurrentStep()
	if _running and step != null and step.wait_for == TutorialStep.WAIT_CONNECT_LINE:
		Next()

func _on_item_delivered(_form: String, _terminal: Node) -> void:
	var step := GetCurrentStep()
	if _running and step != null and step.wait_for == TutorialStep.WAIT_DELIVER:
		Next()

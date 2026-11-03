class_name TutorialOverlay
extends Control

## 教程遮罩层。整屏压暗，挖出一块聚光灯区域，并在目标旁弹出说明气泡。
##
## 遮罩由四块 ColorRect（上/下/左/右）拼成，中间留出目标矩形作为亮区。
## 亮区外的地方一律 MOUSE_FILTER_IGNORE，保证玩家仍能操作底下的板面。

## 步骤切换时发出，参数为新步骤下标。
signal StepChanged(index: int)
## 玩家完成当前步骤（「下一步」按钮或等待条件达成）时发出，参数为完成的下标。
signal StepCompleted(index: int)
## 玩家点击「上一步」时发出，参数为回退到的下标。
signal StepReverted(index: int)
## 玩家点击「跳过教程」时发出。
signal TutorialSkipped()
## 教程全部步骤走完时发出。
signal TutorialFinished()

const BUBBLE_MIN_WIDTH: float = 320.0
const EDGE_MARGIN: float = 12.0

@onready var _mask_top: ColorRect = $MaskTop
@onready var _mask_bottom: ColorRect = $MaskBottom
@onready var _mask_left: ColorRect = $MaskLeft
@onready var _mask_right: ColorRect = $MaskRight
@onready var _highlight: TutorialHighlight = $Highlight
@onready var _bubble: PanelContainer = $Bubble
@onready var _title_label: Label = $Bubble/BubbleRows/TitleLabel
@onready var _body_label: Label = $Bubble/BubbleRows/BodyLabel
@onready var _progress_label: Label = $Bubble/BubbleRows/ProgressLabel
@onready var _prev_button: Button = $Bubble/BubbleRows/ButtonRow/PrevButton
@onready var _next_button: Button = $Bubble/BubbleRows/ButtonRow/NextButton
@onready var _skip_button: Button = $Bubble/BubbleRows/ButtonRow/SkipButton
@onready var _click_catcher: Control = $ClickCatcher

var _current_index: int = -1
var _anchor_rect: Rect2 = Rect2()

func _ready() -> void:
	visible = false
	_prev_button.pressed.connect(_on_prev_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	_click_catcher.gui_input.connect(_on_click_catcher_input)

## 显示某一步教程。
## @param step 步骤数据。
## @param anchor_rect 目标区域矩形（屏幕坐标）。
## @param index 当前步骤下标，从 0 开始。
## @param total 步骤总数。
func ShowStep(step: TutorialStep, anchor_rect: Rect2, index: int, total: int) -> void:
	if step == null:
		return
	_current_index = index
	_anchor_rect = anchor_rect
	visible = true
	_title_label.text = step.title
	_body_label.text = step.description
	_progress_label.text = "第 %d / %d 步" % [index + 1, maxi(total, 1)]
	_prev_button.disabled = index <= 0
	# 等待任意点击的步骤由点击热区推进，隐藏「下一步」避免两条路径同时生效。
	_next_button.visible = step.wait_for != TutorialStep.WAIT_ANY_CLICK
	_click_catcher.visible = step.wait_for == TutorialStep.WAIT_ANY_CLICK
	_apply_mask()
	_place_bubble()
	StepChanged.emit(index)

## 隐藏遮罩与气泡。
func Hide() -> void:
	visible = false
	_current_index = -1
	_anchor_rect = Rect2()
	_highlight.Clear()

## 取得当前显示的步骤下标。
## @return 步骤下标；没有显示步骤时返回 -1。
func GetCurrentIndex() -> int:
	return _current_index

## 取得当前目标矩形。
## @return 目标区域矩形（画布坐标）。
func GetAnchorRect() -> Rect2:
	return _anchor_rect

## 设置「下一步」按钮是否可用。
## @param enabled 可用时为 true。
func SetNextEnabled(enabled: bool) -> void:
	_next_button.disabled = not enabled

## 取得遮罩覆盖的整屏尺寸（遮罩层局部坐标）。
## @return 整屏尺寸。
func GetAreaSize() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	return get_viewport_rect().size

## 把画布坐标的矩形换算成本遮罩层的局部坐标。
func _to_local_rect(rect: Rect2) -> Rect2:
	var inv := get_global_transform().affine_inverse()
	var origin := inv * rect.position
	var corner := inv * rect.end
	return Rect2(origin, corner - origin)

## 四块遮罩围出聚光灯亮区。
func _apply_mask() -> void:
	var area := GetAreaSize()
	var hole := _to_local_rect(_anchor_rect)
	if hole.size.x <= 0.0 or hole.size.y <= 0.0:
		hole = Rect2(Vector2.ZERO, area)
	hole = hole.intersection(Rect2(Vector2.ZERO, area))
	if hole.size.x <= 0.0 or hole.size.y <= 0.0:
		hole = Rect2(Vector2.ZERO, area)
	var color := Color(0.0, 0.0, 0.0, clampf(ExportSettings.tutorial_mask_alpha, 0.0, 1.0))
	for mask in [_mask_top, _mask_bottom, _mask_left, _mask_right]:
		mask.color = color
	_mask_top.position = Vector2.ZERO
	_mask_top.size = Vector2(area.x, hole.position.y)
	_mask_bottom.position = Vector2(0.0, hole.end.y)
	_mask_bottom.size = Vector2(area.x, maxf(area.y - hole.end.y, 0.0))
	_mask_left.position = Vector2(0.0, hole.position.y)
	_mask_left.size = Vector2(hole.position.x, hole.size.y)
	_mask_right.position = Vector2(hole.end.x, hole.position.y)
	_mask_right.size = Vector2(maxf(area.x - hole.end.x, 0.0), hole.size.y)
	_highlight.position = hole.position
	_highlight.size = hole.size
	_highlight.SetTargetRect(Rect2(Vector2.ZERO, hole.size))

## 气泡避让：默认在目标下方，越界时改到上方或侧边。
func _place_bubble() -> void:
	var area := GetAreaSize()
	var bubble_size := _bubble.get_combined_minimum_size()
	bubble_size.x = maxf(bubble_size.x, BUBBLE_MIN_WIDTH)
	var gap := ExportSettings.tutorial_bubble_gap
	var hole := _to_local_rect(_anchor_rect)
	if hole.size.x <= 0.0 or hole.size.y <= 0.0:
		hole = Rect2(Vector2(area.x * 0.5, area.y * 0.5), Vector2.ZERO)
	var x := hole.position.x + hole.size.x * 0.5 - bubble_size.x * 0.5
	x = clampf(x, EDGE_MARGIN, maxf(area.x - bubble_size.x - EDGE_MARGIN, EDGE_MARGIN))
	var y := hole.end.y + gap
	if y + bubble_size.y > area.y - EDGE_MARGIN:
		y = hole.position.y - gap - bubble_size.y
	if y < EDGE_MARGIN:
		y = clampf(hole.position.y, EDGE_MARGIN, maxf(area.y - bubble_size.y - EDGE_MARGIN, EDGE_MARGIN))
	_bubble.position = Vector2(x, y)
	_bubble.size = bubble_size

func _on_next_pressed() -> void:
	StepCompleted.emit(_current_index)

func _on_prev_pressed() -> void:
	StepReverted.emit(_current_index)

func _on_skip_pressed() -> void:
	TutorialSkipped.emit()

func _on_click_catcher_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		StepCompleted.emit(_current_index)

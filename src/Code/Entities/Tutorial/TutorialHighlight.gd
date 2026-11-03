class_name TutorialHighlight
extends Control

## 教程高亮框。在目标区域描一圈主色圆角边框，并做呼吸脉动。
##
## 目标矩形用本地坐标表示，由 TutorialOverlay 计算好再交给本组件。

## 描边色。
@export var border_color: Color = UIPalette.PRIMARY
## 描边宽度（像素）。
@export var border_width: float = 3.0
## 圆角半径（像素）。
@export var corner_radius: float = 10.0
## 呼吸速度（秒/次）。
@export var pulse_speed: float = 1.4
## 呼吸时边框的明暗幅度（0~1）。
@export var pulse_amount: float = 0.45

var _target_rect: Rect2 = Rect2()
var _pulse_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## 设置高亮目标矩形（本地坐标）。
## @param rect 目标矩形。
func SetTargetRect(rect: Rect2) -> void:
	_target_rect = rect
	visible = rect.size.x > 0.0 and rect.size.y > 0.0
	pivot_offset = rect.size * 0.5
	queue_redraw()

## 清除高亮。
func Clear() -> void:
	_target_rect = Rect2()
	visible = false
	queue_redraw()

## 取得当前高亮矩形。
## @return 目标矩形；未设置时返回空矩形。
func GetTargetRect() -> Rect2:
	return _target_rect

func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_time += delta
	# 缩放呼吸，幅度由 ExportSettings 统一控制。
	scale = Vector2.ONE * (1.0 + GetPulseWave() * ExportSettings.tutorial_highlight_pulse)
	queue_redraw()

## 取得当前呼吸波值（0~1）。
## @return 波值。
func GetPulseWave() -> float:
	return 0.5 + 0.5 * sin(_pulse_time * TAU / maxf(pulse_speed, 0.05))

func _draw() -> void:
	if _target_rect.size.x <= 0.0 or _target_rect.size.y <= 0.0:
		return
	var color := border_color.lerp(UIPalette.PRIMARY_LIGHT, GetPulseWave() * pulse_amount)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = color
	style.set_border_width_all(int(border_width))
	style.set_corner_radius_all(int(corner_radius))
	style.draw(get_canvas_item(), _target_rect)

class_name UIFeedback
extends Control

## 轻量即时反馈组件。用于「鬼能不足」「已放置」「交付 +1」这类飘字与提示条。
## 全部由代码构建，不依赖美术资源；生成后自动自毁。

## 飘字默认字号。
const FLOAT_FONT_SIZE: int = 24
## 提示条默认字号。
const TOAST_FONT_SIZE: int = 18
## 提示条上下停留时长（秒）。
const TOAST_HOLD: float = 1.2
## 提示条淡出时长（秒）。
const TOAST_FADE: float = 0.35
## 提示条距底部的距离（像素）。
const TOAST_BOTTOM_MARGIN: float = 120.0

## 在指定位置生成一段向上飘并淡出的文字，结束后自毁。
## @param parent 飘字的挂载父节点。
## @param world_pos 世界坐标，通常是触发事件的控件中心。
## @param text 飘字内容。
## @param color 文字颜色。
static func Show(parent: Node, world_pos: Vector2, text: String, color: Color = UIPalette.TEXT_PRIMARY) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var label := Label.new()
	label.text = text
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FLOAT_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", UIPalette.BG_DEEP)
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	label.global_position = world_pos - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	var rise := ExportSettings.ui_feedback_rise
	var duration := ExportSettings.ui_feedback_duration
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - rise, duration)
	tween.tween_property(label, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(label.queue_free)

## 在屏幕中下方弹出一条提示，停留后淡出并自毁。
## @param parent 提示条的挂载父节点。
## @param text 提示内容。
## @param color 提示条描边与文字颜色。
static func Toast(parent: Node, text: String, color: Color = UIPalette.WARNING) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var panel := PanelContainer.new()
	panel.z_index = 100
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _toast_style(color))
	parent.add_child(panel)

	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", TOAST_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)

	# 提示条挂载后按父节点尺寸居中，并从下方滑入。
	panel.reset_size()
	var parent_size := Vector2(640, 360)
	if parent is Control:
		parent_size = (parent as Control).size
	panel.position = Vector2((parent_size.x - panel.size.x) * 0.5, parent_size.y - TOAST_BOTTOM_MARGIN)
	var target_position := panel.position
	panel.position = target_position + Vector2(0, 24)
	panel.modulate.a = 0.0

	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(panel, "position", target_position, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(TOAST_HOLD)
	tween.tween_property(panel, "modulate:a", 0.0, TOAST_FADE)
	tween.tween_callback(panel.queue_free)

## 生成提示条样式盒。
## @param color 描边与底色主色。
## @return StyleBoxFlat。
static func _toast_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UIPalette.BG_RAISED.r, UIPalette.BG_RAISED.g, UIPalette.BG_RAISED.b, 0.95)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.shadow_color = Color(color.r, color.g, color.b, 0.25)
	style.shadow_size = 8
	return style

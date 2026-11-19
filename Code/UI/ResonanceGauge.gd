class_name ResonanceGauge
extends Control
## 共振指数竖条。两条线：伤害线（黄）与清场线（红，顶端）。

var value: float = 0.0
var damage_line: float = 0.55
var clear_line: float = 1.75


func _ready() -> void:
	custom_minimum_size = Vector2(22, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func SetValues(v: float, dmg: float, clr: float) -> void:
	if absf(v - value) < 0.001 and absf(dmg - damage_line) < 0.001 and absf(clr - clear_line) < 0.001:
		return
	value = v
	damage_line = dmg
	clear_line = maxf(clr, 0.01)
	queue_redraw()


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	draw_rect(full, Color(0.02, 0.035, 0.05, 0.9), true)
	var ratio := clampf(value / clear_line, 0.0, 1.0)
	var h := size.y * ratio
	if h > 0.5:
		var col := Palette.ACCENT.lerp(Palette.WARN, clampf(ratio * 1.6, 0.0, 1.0))
		col = col.lerp(Palette.DANGER, clampf((ratio - 0.7) / 0.3, 0.0, 1.0))
		draw_rect(Rect2(Vector2(1, size.y - h), Vector2(size.x - 2, h)), col, true)
	# 伤害线
	var dy := size.y * (1.0 - clampf(damage_line / clear_line, 0.0, 1.0))
	draw_line(Vector2(0, dy), Vector2(size.x, dy), Palette.WARN, 1.5)
	# 清场线
	draw_line(Vector2(0, 1), Vector2(size.x, 1), Palette.DANGER, 2.0)
	draw_rect(full, Palette.BORDER, false, 1.0)

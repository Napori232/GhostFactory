class_name HeldSlot
extends HBoxContainer
## 手持鬼晶条：HUD 底部建造栏里的一格。
##
## 为什么要换掉相机上的 3D 图标：
##   1) 3D 图标挂在相机前，投影位置会和底部建造栏重叠；
##   2) 放下之后节点没有隐藏，会留下一个「幽灵图标」。
## 固定成 HUD 里的一条，空手就整条隐藏，不会再打架。

var _icon: CrystalIcon
var _charge_label: Label
var _bar: ProgressBar
var _capacity: float = 5.0


## 内联的水晶图标：一个八面体剪影 + 按存量变大的内芯。
class CrystalIcon extends Control:
	var color: Color = Color(0.31, 0.88, 0.77)
	var ratio: float = 0.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.44
		var pts := PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r * 0.62, 0),
			c + Vector2(0, r), c + Vector2(-r * 0.62, 0),
		])
		draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.16))
		var ratio2 := clampf(ratio, 0.0, 1.0)
		if ratio2 > 0.01:
			var rp := r * ratio2
			var inner := PackedVector2Array([
				c + Vector2(0, -rp), c + Vector2(rp * 0.62, 0),
				c + Vector2(0, rp), c + Vector2(-rp * 0.62, 0),
			])
			draw_colored_polygon(inner, Color(color.r, color.g, color.b, 0.95))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), color.lightened(0.25), 1.4)


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(286, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_icon = CrystalIcon.new()
	_icon.custom_minimum_size = Vector2(24, 24)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	var title := Label.new()
	title.text = "手持"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Palette.MUTED)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	_charge_label = Label.new()
	_charge_label.text = "0 / 5"
	_charge_label.add_theme_font_size_override("font_size", 14)
	_charge_label.add_theme_color_override("font_color", Palette.TEXT)
	_charge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_charge_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value = 0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(96, 5)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.08, 0.10)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.CRYSTAL
	fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	add_child(_bar)
	visible = false


## 更新槽位。c 为 null 时隐藏。
func SetCrystal(c: SimCrystal) -> void:
	if c == null:
		Clear()
		return
	visible = true
	_capacity = maxf(1.0, c.capacity)
	var ratio := clampf(c.charge / _capacity, 0.0, 1.0)
	_icon.ratio = ratio
	_icon.queue_redraw()
	_charge_label.text = "%d / %d" % [int(floor(c.charge)), int(_capacity)]
	_bar.value = ratio * 100.0


func Clear() -> void:
	visible = false
	if _charge_label != null:
		_charge_label.text = "0 / 5"
	if _bar != null:
		_bar.value = 0.0
	if _icon != null:
		_icon.ratio = 0.0
		_icon.queue_redraw()

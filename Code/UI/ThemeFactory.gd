class_name ThemeFactory
extends RefCounted
## 界面主题。字体用 SystemFont 从系统里找中文字体——
## 不打包任何字体文件，跨机器可运行；Windows / macOS / Linux 各给一组候选名。


static func BuildTheme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC",
		"Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Micro Hei",
		"SimHei", "sans-serif",
	])
	font.allow_system_fallback = true
	theme.default_font = font
	theme.default_font_size = 16

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(Palette.PANEL.r, Palette.PANEL.g, Palette.PANEL.b, 0.93)
	panel.border_color = Palette.BORDER
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(14)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 8
	theme.set_stylebox("panel", "PanelContainer", panel)

	var button := _flat(Color(0.09, 0.13, 0.17, 0.95), Palette.BORDER, 1, 8)
	var hover := _flat(Color(0.13, 0.19, 0.24, 0.98), Palette.ACCENT.darkened(0.25), 1, 8)
	var pressed := _flat(Color(0.08, 0.24, 0.22, 0.98), Palette.ACCENT, 2, 8)
	var disabled := _flat(Color(0.06, 0.08, 0.10, 0.85), Color(0.14, 0.18, 0.22), 1, 8)
	theme.set_stylebox("normal", "Button", button)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), Palette.ACCENT, 1, 8))
	theme.set_color("font_color", "Button", Palette.TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Palette.ACCENT)
	theme.set_color("font_disabled_color", "Button", Palette.MUTED.darkened(0.35))
	theme.set_font_size("font_size", "Button", 15)

	theme.set_color("font_color", "Label", Palette.TEXT)
	theme.set_font_size("font_size", "Label", 16)
	theme.set_color("font_color", "RichTextLabel", Palette.TEXT)
	theme.set_font_size("normal_font_size", "RichTextLabel", 16)

	theme.set_stylebox("panel", "PopupPanel", panel)
	theme.set_color("font_color", "TooltipLabel", Palette.TEXT)
	var tip := _flat(Color(0.02, 0.03, 0.045, 0.97), Palette.BORDER, 1, 6)
	theme.set_stylebox("panel", "TooltipPanel", tip)

	return theme


static func _flat(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

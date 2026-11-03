class_name UIPalette
extends RefCounted

## UI 配色系统。以主色 #7c5cff 为核心的 12 色体系，覆盖背景、面板、文字、语义色与鬼牌分类。
## 美术资源到位后，界面里的每个色位都对应这里的一个常量，便于整体换肤。

## 主色（品牌紫）。按钮强调、选中态、进度条与焦点描边。
const PRIMARY: Color = Color("#7c5cff")
## 主色高光，悬停与按下前的提亮。
const PRIMARY_LIGHT: Color = Color("#9b85ff")
## 主色暗压，用于描边与阴影。
const PRIMARY_DARK: Color = Color("#5b3fd6")
## 主色低透明填充，用于选中背景与高亮区域。
const PRIMARY_SOFT: Color = Color("#7c5cff33")

## 最深背景，页面底色。
const BG_DEEP: Color = Color("#0d0b16")
## 次级背景，卡片与面板底。
const BG_PANEL: Color = Color("#16122a")
## 三级背景，抬起卡片与输入框。
const BG_RAISED: Color = Color("#1e1938")
## 分割线与描边。
const BORDER: Color = Color("#2e2752")

## 主文字色。
const TEXT_PRIMARY: Color = Color("#f2efff")
## 次文字，说明与标签。
const TEXT_SECONDARY: Color = Color("#a89fd4")
## 禁用文字。
const TEXT_DISABLED: Color = Color("#5f5890")

## 成功色，交付达成与解锁。
const SUCCESS: Color = Color("#3ddc97")
## 警告色，鬼能不足与时间将尽。
const WARNING: Color = Color("#ffb454")
## 危险色，错误与拆除。
const DANGER: Color = Color("#ff5c7a")
## 信息色，连线与端口。
const INFO: Color = Color("#4cc9f0")

## 全部 12 色的有序列表，供换肤工具遍历。
const ALL: Array[Color] = [
	PRIMARY,
	PRIMARY_LIGHT,
	PRIMARY_DARK,
	PRIMARY_SOFT,
	BG_DEEP,
	BG_PANEL,
	BG_RAISED,
	BORDER,
	TEXT_PRIMARY,
	TEXT_SECONDARY,
	TEXT_DISABLED,
	SUCCESS,
	WARNING,
	DANGER,
	INFO,
]

## 取得全部色位的名称与颜色对照表。
## @return 名称到颜色的字典。
static func GetNamedColors() -> Dictionary:
	return {
		"primary": PRIMARY,
		"primary_light": PRIMARY_LIGHT,
		"primary_dark": PRIMARY_DARK,
		"primary_soft": PRIMARY_SOFT,
		"bg_deep": BG_DEEP,
		"bg_panel": BG_PANEL,
		"bg_raised": BG_RAISED,
		"border": BORDER,
		"text_primary": TEXT_PRIMARY,
		"text_secondary": TEXT_SECONDARY,
		"text_disabled": TEXT_DISABLED,
		"success": SUCCESS,
		"warning": WARNING,
		"danger": DANGER,
		"info": INFO,
	}

## 按名称取色。
## @param name 色位名称
## @return 对应颜色；未知名称返回主色。
static func Get(name: String) -> Color:
	return GetNamedColors().get(name, PRIMARY)

## 生成一份应用级主题，注入到指定节点树。
## 统一按钮、面板、标签的字体与颜色，界面各处无需各自硬编码。
## @param root 主题应用的根节点。
static func ApplyTheme(root: Node) -> void:
	if root == null:
		return
	var theme := Theme.new()
	theme.default_font_size = 16

	theme.set_color("font_color", "Label", TEXT_PRIMARY)
	theme.set_color("font_outline_color", "Label", BG_DEEP)
	theme.set_constant("outline_size", "Label", 0)

	theme.set_stylebox("normal", "Button", _button_style(BG_RAISED, BORDER))
	theme.set_stylebox("hover", "Button", _button_style(PRIMARY_DARK, PRIMARY))
	theme.set_stylebox("pressed", "Button", _button_style(PRIMARY_DARK, PRIMARY_LIGHT))
	theme.set_stylebox("focus", "Button", _button_style(BG_RAISED, PRIMARY))
	theme.set_stylebox("disabled", "Button", _button_style(BG_PANEL, BORDER))
	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", TEXT_DISABLED)

	theme.set_stylebox("panel", "PanelContainer", _panel_style())
	theme.set_stylebox("panel", "Panel", _panel_style())

	theme.set_color("font_color", "CheckButton", TEXT_PRIMARY)
	theme.set_stylebox("normal", "CheckBox", _panel_style())
	theme.set_stylebox("hover", "CheckBox", _panel_style())
	theme.set_stylebox("pressed", "CheckBox", _panel_style())

	theme.set_stylebox("panel", "PopupPanel", _panel_style())
	theme.set_stylebox("normal", "LineEdit", _panel_style())

	if root is Control:
		root.theme = theme
	elif root is Window:
		root.theme = theme

## 生成按钮样式盒。
## @param bg 背景色
## @param border 描边色
## @return StyleBoxFlat。
static func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

## 生成面板样式盒。
## @return StyleBoxFlat。
static func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_PANEL
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

class_name UIPalette
extends RefCounted

## UI 配色系统。深靛蓝底 + 玻璃质感面板 + 霓虹描边 + 暖橙点缀，保留夜间鬼工厂氛围但避免死黑。
## 美术资源到位后，界面里的每个色位都对应这里的一个常量，便于整体换肤。

## 主色（品牌紫）。按钮强调、选中态、进度条与焦点描边。
const PRIMARY: Color = Color("#7c5cff")
## 主色高光，悬停与按下前的提亮。
const PRIMARY_LIGHT: Color = Color("#a08fff")
## 主色暗压，用于描边与阴影。
const PRIMARY_DARK: Color = Color("#5335c4")
## 主色低透明填充，用于选中背景与高亮区域。
const PRIMARY_SOFT: Color = Color("#7c5cff33")

## 点缀色（暖橙）。资源点、造价数字与关键提示靠它从紫色主调里跳出来。
const ACCENT: Color = Color("#ff9f45")
## 点缀色高光。
const ACCENT_LIGHT: Color = Color("#ffbc78")
## 点缀色低透明填充。
const ACCENT_SOFT: Color = Color("#ff9f4526")

## 最深背景，页面底色。深靛蓝而非纯黑，保留一点冷调亮度让面板层次可见。
const BG_DEEP: Color = Color("#0b0f1e")
## 背景渐变顶部色。
const BG_GRADIENT_TOP: Color = Color("#1a2150")
## 背景渐变底部色。
const BG_GRADIENT_BOTTOM: Color = Color("#070a14")
## 次级背景，卡片与面板底。
const BG_PANEL: Color = Color("#151b30")
## 三级背景，抬起卡片与输入框。
const BG_RAISED: Color = Color("#1f2743")
## 分割线与描边。
const BORDER: Color = Color("#33406b")
## 玻璃面板填充，半透明白叠在深底上形成材质感。
const GLASS_BG: Color = Color("#ffffff14")
## 玻璃面板霓虹描边。
const GLASS_BORDER: Color = Color("#7c5cff66")

## 主文字色。
const TEXT_PRIMARY: Color = Color("#eef1ff")
## 次文字，说明与标签。
const TEXT_SECONDARY: Color = Color("#9aa4c8")
## 禁用文字。
const TEXT_DISABLED: Color = Color("#5b6484")

## 成功色，交付达成与解锁。
const SUCCESS: Color = Color("#3ddc97")
## 警告色，鬼能不足与时间将尽。
const WARNING: Color = Color("#ffb454")
## 危险色，错误与拆除。
const DANGER: Color = Color("#ff5c7a")
## 信息色，连线与端口。
const INFO: Color = Color("#4cc9f0")
## 冷调辉光，用于背景光斑与边缘高光。
const GLOW_CYAN: Color = Color("#35e0d8")

## 全部色位的有序列表，供换肤工具遍历。
const ALL: Array[Color] = [
	PRIMARY,
	PRIMARY_LIGHT,
	PRIMARY_DARK,
	PRIMARY_SOFT,
	ACCENT,
	ACCENT_LIGHT,
	ACCENT_SOFT,
	BG_DEEP,
	BG_GRADIENT_TOP,
	BG_GRADIENT_BOTTOM,
	BG_PANEL,
	BG_RAISED,
	BORDER,
	GLASS_BG,
	GLASS_BORDER,
	TEXT_PRIMARY,
	TEXT_SECONDARY,
	TEXT_DISABLED,
	SUCCESS,
	WARNING,
	DANGER,
	INFO,
	GLOW_CYAN,
]

## 取得全部色位的名称与颜色对照表。
## @return 名称到颜色的字典。
static func GetNamedColors() -> Dictionary:
	return {
		"primary": PRIMARY,
		"primary_light": PRIMARY_LIGHT,
		"primary_dark": PRIMARY_DARK,
		"primary_soft": PRIMARY_SOFT,
		"accent": ACCENT,
		"accent_light": ACCENT_LIGHT,
		"accent_soft": ACCENT_SOFT,
		"bg_deep": BG_DEEP,
		"bg_gradient_top": BG_GRADIENT_TOP,
		"bg_gradient_bottom": BG_GRADIENT_BOTTOM,
		"bg_panel": BG_PANEL,
		"bg_raised": BG_RAISED,
		"border": BORDER,
		"glass_bg": GLASS_BG,
		"glass_border": GLASS_BORDER,
		"text_primary": TEXT_PRIMARY,
		"text_secondary": TEXT_SECONDARY,
		"text_disabled": TEXT_DISABLED,
		"success": SUCCESS,
		"warning": WARNING,
		"danger": DANGER,
		"info": INFO,
		"glow_cyan": GLOW_CYAN,
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

	theme.set_stylebox("normal", "Button", _button_style(BG_RAISED, GLASS_BORDER, PRIMARY, false))
	theme.set_stylebox("hover", "Button", _button_style(BG_RAISED, PRIMARY, PRIMARY_LIGHT, true))
	theme.set_stylebox("pressed", "Button", _button_style(PRIMARY_DARK, PRIMARY_LIGHT, PRIMARY_LIGHT, true))
	theme.set_stylebox("focus", "Button", _button_style(BG_RAISED, PRIMARY, PRIMARY_LIGHT, false))
	theme.set_stylebox("disabled", "Button", _button_style(BG_PANEL, BORDER, BORDER, false))
	theme.set_color("font_color", "Button", TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	theme.set_constant("outline_size", "Button", 0)

	theme.set_stylebox("panel", "PanelContainer", _panel_style())
	theme.set_stylebox("panel", "Panel", _panel_style())

	theme.set_color("font_color", "CheckButton", TEXT_PRIMARY)
	theme.set_stylebox("normal", "CheckBox", _panel_style())
	theme.set_stylebox("hover", "CheckBox", _panel_style())
	theme.set_stylebox("pressed", "CheckBox", _panel_style())

	theme.set_stylebox("panel", "PopupPanel", _panel_style())
	theme.set_stylebox("normal", "LineEdit", _panel_style())
	theme.set_stylebox("focus", "LineEdit", _input_style())

	theme.set_color("font_color", "HSlider", TEXT_PRIMARY)
	theme.set_stylebox("slider", "HSlider", _slider_style())
	theme.set_stylebox("grabber_area", "HSlider", _grabber_style())

	if root is Control:
		root.theme = theme
	elif root is Window:
		root.theme = theme

## 生成按钮样式盒。
## @param bg 背景色
## @param border 描边色
## @param glow 霓虹外发光色
## @param elevated 是否带浮起阴影
## @return StyleBoxFlat。
static func _button_style(bg: Color, border: Color, glow: Color, elevated: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(glow.r, glow.g, glow.b, 0.22 if elevated else 0.12)
	style.shadow_size = 10 if elevated else 4
	style.shadow_offset = Vector2(0, 2)
	return style

## 生成玻璃质感面板样式盒。
## @return StyleBoxFlat。
static func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = GLASS_BG
	style.border_color = GLASS_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style

## 生成输入框样式盒。
## @return StyleBoxFlat。
static func _input_style() -> StyleBoxFlat:
	var style := _panel_style()
	style.bg_color = BG_PANEL
	style.border_color = PRIMARY
	style.set_border_width_all(2)
	return style

## 生成滑条轨道样式盒。
## @return StyleBoxFlat。
static func _slider_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_DEEP
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

## 生成滑条已填充段样式盒。
## @return StyleBoxFlat。
static func _grabber_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PRIMARY
	style.set_corner_radius_all(4)
	return style

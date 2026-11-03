extends Control

## 主菜单。左文右图版式：左侧标题与按钮组，右侧主视觉占位，底层为带光斑的背景层。
## 「开始游戏」进入关卡选择界面，「继续游戏」直接回到上次所在关卡。

const GAME_VERSION: String = "0.1.0"
## 主按钮（开始游戏）使用的实心底色。
const PRIMARY_BG: Color = UIPalette.PRIMARY
## 次级按钮使用的描边色。
const SECONDARY_BORDER: Color = UIPalette.PRIMARY_SOFT
## 次级按钮的透明底色。
const SECONDARY_BG: Color = Color(0.086275, 0.066667, 0.101961, 0.62)

@onready var _background: BackgroundLayer = %Background
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _world_label: Label = %WorldLabel
@onready var _version: Label = %Version
@onready var _key_art: ArtPlaceholder = %KeyArt
@onready var _start_button: Button = %StartButton
@onready var _continue_button: Button = %ContinueButton
@onready var _level_select_button: Button = %LevelSelectButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
	UIPalette.ApplyTheme(self)
	_title.text = "鬼工厂"
	_subtitle.text = "在废弃工厂里，用规则造出鬼，让鬼替你干活。"
	_world_label.text = "拼接规则 · 引流 · 交付 —— 每一关都是一道会动的机关题。"
	_version.text = "v%s" % GAME_VERSION
	_setup_background()
	_style_buttons()
	_start_button.pressed.connect(_on_start_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_level_select_button.pressed.connect(_on_level_select_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_refresh_continue_state()
	_start_button.grab_focus()
	SignalBus.ProgressChanged.connect(_refresh_continue_state)
	_play_intro()
	_play_idle_motion()

## 播放持续动效：标题呼吸与摇摆、主按钮呼吸、主视觉占位浮动、按钮悬停反馈。
## 这些动效与入场动画并行，入场结束后接管，让界面始终处于「活着」的状态。
func _play_idle_motion() -> void:
	# 标题：持续呼吸缩放 + 轻微左右摇摆。等入场动画走完再叠加，避免两者互相覆盖 scale。
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(_title):
		return
	_anchor_pivot(_title)
	UIEffects.BreatheLoop(_title, ExportSettings.ui_breathe_amplitude * 1.5, ExportSettings.ui_breathe_period * 1.4)
	UIEffects.Sway(_title, 1.5, ExportSettings.ui_sway_period * 1.2)

	# 主按钮：幅度更小的呼吸，作为视觉焦点。
	_anchor_pivot(_start_button)
	UIEffects.BreatheLoop(_start_button, ExportSettings.ui_breathe_amplitude * 0.6, ExportSettings.ui_breathe_period)

	# 主视觉占位：上下浮动，缓慢漂移。
	if _key_art != null:
		UIEffects.FloatBob(_key_art, ExportSettings.ui_float_distance, 4.2)
		UIEffects.Sway(_key_art, 1.2, 5.0)

	# 所有按钮：悬停放大 + 按下回弹。
	for button in [_start_button, _continue_button, _level_select_button, _settings_button, _quit_button]:
		UIEffects.AttachInteractive(button, ExportSettings.ui_hover_scale, ExportSettings.ui_press_scale, ExportSettings.ui_hover_duration)

## 把控件的旋转轴心设到自身中心，保证摇摆不会绕左上角甩出去。
## @param node 目标控件。
func _anchor_pivot(node: Control) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5
	node.resized.connect(func() -> void:
		if is_instance_valid(node):
			node.pivot_offset = node.size * 0.5
	)

## 配置背景层与主视觉占位，等待美术资源到位后自动替换。
func _setup_background() -> void:
	if _background != null:
		_background.SetGlowIntensity(ExportSettings.ui_glow_intensity)
		var placeholder := _background.GetArtPlaceholder()
		if placeholder != null:
			placeholder.SetLabel(ExportSettings.ui_background_label)
		if ExportSettings.ui_background_art != "":
			_background.SetArt(ExportSettings.ui_background_art)
	if _key_art != null:
		_key_art.SetLabel(ExportSettings.ui_key_art_label)
		if ExportSettings.ui_key_art != "":
			_key_art.SetArt(ExportSettings.ui_key_art)

## 区分主次按钮样式：主按钮实心主色，次按钮描边。
func _style_buttons() -> void:
	_apply_primary_style(_start_button)
	for button in [_continue_button, _level_select_button, _settings_button, _quit_button]:
		_apply_secondary_style(button)

## 应用主按钮样式：主色实底。
## @param button 目标按钮。
func _apply_primary_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(PRIMARY_BG, UIPalette.PRIMARY_LIGHT))
	button.add_theme_stylebox_override("hover", _make_button_style(UIPalette.PRIMARY_LIGHT, Color.WHITE))
	button.add_theme_stylebox_override("pressed", _make_button_style(UIPalette.PRIMARY_DARK, UIPalette.PRIMARY_LIGHT))
	button.add_theme_stylebox_override("focus", _make_button_style(PRIMARY_BG, Color.WHITE))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)

## 应用次按钮样式：透明底 + 主色描边。
## @param button 目标按钮。
func _apply_secondary_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(SECONDARY_BG, SECONDARY_BORDER))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.486274, 0.360784, 1, 0.18), UIPalette.PRIMARY_LIGHT))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.486274, 0.360784, 1, 0.28), UIPalette.PRIMARY_LIGHT))
	button.add_theme_stylebox_override("focus", _make_button_style(SECONDARY_BG, UIPalette.PRIMARY_LIGHT))

## 生成按钮样式盒。
## @param bg 背景色
## @param border 描边色
## @return StyleBoxFlat。
func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
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

## 播放进场动效：标题与副标题依次淡入并轻微放大，按钮组依次淡入。
## 标题类节点位于 VBoxContainer 内，由容器接管位置，因此这里用缩放与透明度而非位移做入场。
func _play_intro() -> void:
	_play_intro_item(_title, 0.0)
	_play_intro_item(_subtitle, 0.08)
	_play_intro_item(_world_label, 0.16)
	UIEffects.PlayStagger([_start_button, _continue_button, _level_select_button, _settings_button, _quit_button], 0.07)
	for button in [_start_button, _continue_button, _level_select_button, _settings_button, _quit_button]:
		if not button.mouse_entered.is_connected(_on_button_hovered.bind(button)):
			button.mouse_entered.connect(_on_button_hovered.bind(button))
		if not button.pressed.is_connected(_on_button_pressed_effect.bind(button)):
			button.pressed.connect(_on_button_pressed_effect.bind(button))

## 单个文本节点的入场动效：淡入并从 96% 放大到 100%。
## @param node 目标控件
## @param delay 延迟秒数
func _play_intro_item(node: Control, delay: float) -> void:
	node.modulate.a = 0.0
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.96, 0.96)
	var tween := node.create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.4)
	tween.tween_property(node, "scale", Vector2.ONE, 0.45)

## 按钮悬停时做一次轻微放大。
## @param button 悬停的按钮。
func _on_button_hovered(button: Button) -> void:
	UIEffects.PopScale(button, 1.0, ExportSettings.ui_pop_scale, 0.16)

## 按钮点击时做一次缩放回弹并迸发粒子。
## @param button 被点击的按钮。
func _on_button_pressed_effect(button: Button) -> void:
	if not button.is_inside_tree():
		return
	UIEffects.PopScale(button, 0.92, ExportSettings.ui_pop_scale, 0.22)
	UIEffects.BurstAtControl(button, UIPalette.PRIMARY, 14)

## 刷新「继续游戏」按钮的可用状态。
func _refresh_continue_state() -> void:
	var current_level := int(SaveManager.GetProgress().get("current_level", 1))
	_continue_button.disabled = current_level <= 0
	if current_level > 0:
		_continue_button.text = "继续游戏（第 %d 关）" % current_level
	else:
		_continue_button.text = "继续游戏"

## 开始游戏：进入关卡选择界面，由玩家挑选要打的关卡。
func _on_start_pressed() -> void:
	SceneRouter.GotoLevelSelect()

## 继续游戏：回到上次所在关卡。
func _on_continue_pressed() -> void:
	SceneRouter.GotoLevel(int(SaveManager.GetProgress().get("current_level", 1)))

## 进入关卡选择界面。
func _on_level_select_pressed() -> void:
	SceneRouter.GotoLevelSelect()

## 进入设置界面。
func _on_settings_pressed() -> void:
	SceneRouter.GotoSettings()

## 退出游戏。
func _on_quit_pressed() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and _start_button.has_focus():
		_on_start_pressed()
		accept_event()

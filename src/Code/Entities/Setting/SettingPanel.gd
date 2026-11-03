extends Control

## 设置面板。提供音量、开关、画质与重置进度入口，可作为独立页面或嵌入面板使用。
## 视觉使用 UIPalette 23 色板：音量滑条主色、开关开启态成功色、画质下拉主色描边、重置按钮危险色描边。

const QUALITY_VALUES: Array[String] = ["low", "medium", "high"]
const QUALITY_LABELS: Array[String] = ["低", "中", "高"]

## 是否以嵌入面板方式使用。为 true 时返回按钮只隐藏自身，不切换场景。
@export var embed_mode: bool = false

@onready var _background: BackgroundLayer = %Background
@onready var _title: Label = %Title
@onready var _master_slider: HSlider = %MasterSlider
@onready var _master_value: Label = %MasterValue
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value: Label = %SfxValue
@onready var _dialogue_slider: HSlider = %DialogueSlider
@onready var _dialogue_value: Label = %DialogueValue
@onready var _ambience_slider: HSlider = %AmbienceSlider
@onready var _ambience_value: Label = %AmbienceValue
@onready var _skip_tutorial_check: CheckButton = %SkipTutorialCheck
@onready var _screen_shake_check: CheckButton = %ScreenShakeCheck
@onready var _quality_option: OptionButton = %QualityOption
@onready var _reset_button: Button = %ResetButton
@onready var _back_button: Button = %BackButton
@onready var _reset_dialog: ConfirmationDialog = %ResetDialog

var _syncing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UIPalette.ApplyTheme(self)
	_setup_quality_option()
	_setup_background()
	_connect_signals()
	_style_widgets()
	SyncFromStorage()
	_refresh_switch_colors()
	_play_intro_item(_title, 0.0)
	_setup_interaction()
	# 标题持续轻微呼吸，避免静态界面显得僵硬。
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(_title):
		UIEffects.BreatheLoop(_title, ExportSettings.ui_breathe_amplitude * 0.8, ExportSettings.ui_breathe_period * 1.5)

## 配置交互反馈：按钮悬停放大与按下回弹，滑条与开关挂上悬停反馈。
func _setup_interaction() -> void:
	for button in [_reset_button, _back_button]:
		UIEffects.AttachInteractive(button, ExportSettings.ui_hover_scale, ExportSettings.ui_press_scale, ExportSettings.ui_hover_duration)
	for slider in [_master_slider, _music_slider, _sfx_slider, _dialogue_slider, _ambience_slider]:
		UIEffects.AttachInteractive(slider, 1.03, 0.97, ExportSettings.ui_hover_duration)
	for check in [_skip_tutorial_check, _screen_shake_check]:
		UIEffects.AttachInteractive(check, 1.03, 0.97, ExportSettings.ui_hover_duration)

## 从存档与音频设置刷新界面显示。
func SyncFromStorage() -> void:
	_syncing = true
	_apply_volume(&"master", _master_slider, _master_value)
	_apply_volume(&"music", _music_slider, _music_value)
	_apply_volume(&"sfx", _sfx_slider, _sfx_value)
	_apply_volume(&"dialogue", _dialogue_slider, _dialogue_value)
	_apply_volume(&"ambience", _ambience_slider, _ambience_value)
	_skip_tutorial_check.button_pressed = bool(SaveManager.GetSetting(&"skip_tutorial", false))
	_screen_shake_check.button_pressed = bool(SaveManager.GetSetting(&"screen_shake", true))
	_select_quality(String(SaveManager.GetSetting(&"quality", "medium")))
	_syncing = false

## 单个文本节点的入场动效：淡入并轻微放大。
## 节点位于容器内，由容器接管位置，因此用缩放与透明度而非位移做入场。
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

## 配置背景层：光斑强度与背景图占位说明文字。
func _setup_background() -> void:
	if _background == null:
		return
	_background.SetGlowIntensity(ExportSettings.ui_glow_intensity)
	var placeholder := _background.GetArtPlaceholder()
	if placeholder != null:
		placeholder.SetLabel(ExportSettings.ui_background_label)
	if ExportSettings.ui_background_art != "":
		_background.SetArt(ExportSettings.ui_background_art)

## 建立画质选项内容。
func _setup_quality_option() -> void:
	_quality_option.clear()
	for i in range(QUALITY_LABELS.size()):
		_quality_option.add_item(QUALITY_LABELS[i], i)

## 连接界面控件与全局信号。
func _connect_signals() -> void:
	_master_slider.value_changed.connect(_on_volume_changed.bind(&"master", &"master_volume"))
	_music_slider.value_changed.connect(_on_volume_changed.bind(&"music", &"music_volume"))
	_sfx_slider.value_changed.connect(_on_volume_changed.bind(&"sfx", &"sfx_volume"))
	_dialogue_slider.value_changed.connect(_on_volume_changed.bind(&"dialogue", &"dialogue_volume"))
	_ambience_slider.value_changed.connect(_on_volume_changed.bind(&"ambience", &"ambience_volume"))
	_skip_tutorial_check.toggled.connect(_on_skip_tutorial_toggled)
	_screen_shake_check.toggled.connect(_on_screen_shake_toggled)
	_quality_option.item_selected.connect(_on_quality_selected)
	_reset_button.pressed.connect(_on_reset_button_pressed)
	_back_button.pressed.connect(_on_back_button_pressed)
	_reset_dialog.confirmed.connect(_on_reset_confirmed)
	SignalBus.SettingChanged.connect(_on_setting_changed)

## 统一各控件的色板样式：滑条主色、画质下拉主色描边、重置按钮危险色描边。
func _style_widgets() -> void:
	for slider in [_master_slider, _music_slider, _sfx_slider, _dialogue_slider, _ambience_slider]:
		_style_slider(slider)
	_style_quality_option()
	_style_reset_button()
	_style_back_button()

## 把音量滑条改成主色轨道与主色滑块。
## @param slider 目标滑条。
func _style_slider(slider: HSlider) -> void:
	slider.add_theme_stylebox_override("slider", _make_flat_style(UIPalette.BG_RAISED, UIPalette.BORDER, 6))
	slider.add_theme_stylebox_override("grabber_area", _make_flat_style(UIPalette.PRIMARY, UIPalette.PRIMARY, 6))
	slider.add_theme_stylebox_override("grabber_area_highlight", _make_flat_style(UIPalette.PRIMARY_LIGHT, UIPalette.PRIMARY_LIGHT, 6))
	var grabber := _make_circle_texture(UIPalette.PRIMARY, 18)
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", _make_circle_texture(UIPalette.PRIMARY_LIGHT, 22))

## 画质下拉使用主色描边。
func _style_quality_option() -> void:
	_quality_option.add_theme_stylebox_override("normal", _make_flat_style(UIPalette.BG_RAISED, UIPalette.PRIMARY, 10))
	_quality_option.add_theme_stylebox_override("hover", _make_flat_style(UIPalette.BG_RAISED, UIPalette.PRIMARY_LIGHT, 10))
	_quality_option.add_theme_stylebox_override("pressed", _make_flat_style(UIPalette.BG_PANEL, UIPalette.PRIMARY_LIGHT, 10))
	_quality_option.add_theme_stylebox_override("focus", _make_flat_style(UIPalette.BG_RAISED, UIPalette.PRIMARY_LIGHT, 10))

## 重置进度按钮使用危险色描边。
func _style_reset_button() -> void:
	_reset_button.add_theme_stylebox_override("normal", _make_flat_style(UIPalette.BG_PANEL, UIPalette.DANGER, 10))
	_reset_button.add_theme_stylebox_override("hover", _make_flat_style(Color(UIPalette.DANGER.r, UIPalette.DANGER.g, UIPalette.DANGER.b, 0.18), UIPalette.DANGER, 10))
	_reset_button.add_theme_stylebox_override("pressed", _make_flat_style(Color(UIPalette.DANGER.r, UIPalette.DANGER.g, UIPalette.DANGER.b, 0.30), UIPalette.DANGER, 10))
	_reset_button.add_theme_stylebox_override("focus", _make_flat_style(UIPalette.BG_PANEL, UIPalette.DANGER, 10))
	_reset_button.add_theme_color_override("font_color", UIPalette.DANGER)
	_reset_button.add_theme_color_override("font_hover_color", Color.WHITE)

## 返回按钮使用次要描边样式。
func _style_back_button() -> void:
	_back_button.add_theme_stylebox_override("normal", _make_flat_style(UIPalette.BG_PANEL, UIPalette.BORDER, 10))
	_back_button.add_theme_stylebox_override("hover", _make_flat_style(UIPalette.BG_RAISED, UIPalette.PRIMARY, 10))
	_back_button.add_theme_stylebox_override("pressed", _make_flat_style(UIPalette.BG_PANEL, UIPalette.PRIMARY_DARK, 10))
	_back_button.add_theme_stylebox_override("focus", _make_flat_style(UIPalette.BG_PANEL, UIPalette.PRIMARY, 10))

## 生成扁平样式盒。
## @param bg 背景色
## @param border 描边色
## @param radius 圆角半径
## @return StyleBoxFlat 样式。
func _make_flat_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

## 生成一个圆形贴图，用作滑块手柄。
## @param color 圆形颜色
## @param diameter 直径（像素）
## @return ImageTexture 贴图。
func _make_circle_texture(color: Color, diameter: int) -> ImageTexture:
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(diameter, diameter) * 0.5
	var radius := float(diameter) * 0.5
	for y in range(diameter):
		for x in range(diameter):
			var pixel := Vector2(x + 0.5, y + 0.5)
			if pixel.distance_to(center) <= radius - 1.0:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

## 刷新两个开关的文字颜色：开启用成功色，关闭用禁用色。
func _refresh_switch_colors() -> void:
	_apply_switch_color(_skip_tutorial_check)
	_apply_switch_color(_screen_shake_check)

## 按开关状态设置文字颜色。
## @param check 目标开关。
func _apply_switch_color(check: CheckButton) -> void:
	var color: Color = UIPalette.SUCCESS if check.button_pressed else UIPalette.TEXT_DISABLED
	check.add_theme_color_override("font_color", color)
	check.add_theme_color_override("font_hover_color", color)
	check.add_theme_color_override("font_pressed_color", color)

## 读取指定音量的当前值并写入滑条与数值标签。
## @param channel 音量类别：master、music、sfx、dialogue 或 ambience
## @param slider 对应的滑条
## @param value_label 对应的数值标签
func _apply_volume(channel: StringName, slider: HSlider, value_label: Label) -> void:
	var volume := Util.GetAudioVolume(channel)
	var previous := _syncing
	_syncing = true
	slider.value = volume
	_syncing = previous
	value_label.text = "%d%%" % roundi(volume * 100.0)

## 按画质值选中对应选项。
## @param quality 画质值：low、medium 或 high
func _select_quality(quality: String) -> void:
	var index := QUALITY_VALUES.find(quality)
	if index < 0:
		index = QUALITY_VALUES.find("medium")
	if index < 0:
		index = 0
	_quality_option.select(index)

## 处理音量滑条变化，实时应用音量并写入存档。
## @param value 新的线性音量，0.0-1.0
## @param channel 音量类别：master、music、sfx、dialogue 或 ambience
## @param setting_key 对应的存档键名
func _on_volume_changed(value: float, channel: StringName, setting_key: StringName) -> void:
	if _syncing:
		return
	Util.SetAudioVolume(channel, value)
	SaveManager.SetSetting(setting_key, value)
	_update_volume_label(channel, value)

## 更新某个音量的数值标签。
## @param channel 音量类别
## @param value 线性音量，0.0-1.0
func _update_volume_label(channel: StringName, value: float) -> void:
	var text := "%d%%" % roundi(value * 100.0)
	match channel:
		&"master":
			_master_value.text = text
		&"music":
			_music_value.text = text
		&"sfx":
			_sfx_value.text = text
		&"dialogue":
			_dialogue_value.text = text
		&"ambience":
			_ambience_value.text = text

## 处理跳过教程开关变化。
## @param pressed 开关是否打开
func _on_skip_tutorial_toggled(pressed: bool) -> void:
	_apply_switch_color(_skip_tutorial_check)
	if _syncing:
		return
	SaveManager.SetSetting(&"skip_tutorial", pressed)

## 处理屏幕震动开关变化。
## @param pressed 开关是否打开
func _on_screen_shake_toggled(pressed: bool) -> void:
	_apply_switch_color(_screen_shake_check)
	if _syncing:
		return
	SaveManager.SetSetting(&"screen_shake", pressed)

## 处理画质选项变化。
## @param index 选中项序号
func _on_quality_selected(index: int) -> void:
	if _syncing:
		return
	if index < 0 or index >= QUALITY_VALUES.size():
		return
	SaveManager.SetSetting(&"quality", QUALITY_VALUES[index])

## 处理重置进度按钮点击，弹出二次确认。
func _on_reset_button_pressed() -> void:
	_reset_dialog.popup_centered()

## 处理重置确认，确有进度重置时执行重置。
func _on_reset_confirmed() -> void:
	SaveManager.ResetProgress()
	SyncFromStorage()

## 处理返回按钮点击：独立页面返回主菜单，嵌入面板则隐藏自身。
func _on_back_button_pressed() -> void:
	if embed_mode:
		visible = false
		return
	SceneRouter.GotoMenu()

## 处理外部设置变更通知，刷新对应控件显示。
## @param key 设置项键名
## @param value 设置项的新值
func _on_setting_changed(key: StringName, value: Variant) -> void:
	if _syncing:
		return
	match key:
		&"skip_tutorial":
			_syncing = true
			_skip_tutorial_check.button_pressed = bool(value)
			_syncing = false
		&"screen_shake":
			_syncing = true
			_screen_shake_check.button_pressed = bool(value)
			_syncing = false
		&"quality":
			_syncing = true
			_select_quality(String(value))
			_syncing = false
		&"master_volume":
			_apply_volume(&"master", _master_slider, _master_value)
		&"music_volume":
			_apply_volume(&"music", _music_slider, _music_value)
		&"sfx_volume":
			_apply_volume(&"sfx", _sfx_slider, _sfx_value)
		&"dialogue_volume":
			_apply_volume(&"dialogue", _dialogue_slider, _dialogue_value)
		&"ambience_volume":
			_apply_volume(&"ambience", _ambience_slider, _ambience_value)

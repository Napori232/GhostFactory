extends Control

## 设置面板。提供音量、开关、画质与重置进度入口，可作为独立页面或嵌入面板使用。

const QUALITY_VALUES: Array[String] = ["low", "medium", "high"]
const QUALITY_LABELS: Array[String] = ["低", "中", "高"]

## 是否以嵌入面板方式使用。为 true 时返回按钮只隐藏自身，不切换场景。
@export var embed_mode: bool = false

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
	_setup_quality_option()
	_connect_signals()
	SyncFromStorage()

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
	if _syncing:
		return
	SaveManager.SetSetting(&"skip_tutorial", pressed)

## 处理屏幕震动开关变化。
## @param pressed 开关是否打开
func _on_screen_shake_toggled(pressed: bool) -> void:
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

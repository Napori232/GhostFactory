extends Control

## 主菜单。提供进入游戏、关卡选择、设置与退出的入口。

const GAME_VERSION: String = "0.1.0"

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _version: Label = %Version
@onready var _start_button: Button = %StartButton
@onready var _continue_button: Button = %ContinueButton
@onready var _level_select_button: Button = %LevelSelectButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton

func _ready() -> void:
	_title.text = "鬼工厂"
	_subtitle.text = "在废弃工厂里，用规则造出鬼，让鬼替你干活。"
	_version.text = "v%s" % GAME_VERSION
	_start_button.pressed.connect(_on_start_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_level_select_button.pressed.connect(_on_level_select_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_refresh_continue_state()
	_start_button.grab_focus()
	SignalBus.ProgressChanged.connect(_refresh_continue_state)

## 刷新「继续游戏」按钮的可用状态。
func _refresh_continue_state() -> void:
	var current_level := int(SaveManager.GetProgress().get("current_level", 1))
	_continue_button.disabled = current_level <= 0
	if current_level > 0:
		_continue_button.text = "继续游戏（第 %d 关）" % current_level
	else:
		_continue_button.text = "继续游戏"

## 开始游戏：进入当前已解锁的最高关卡。
func _on_start_pressed() -> void:
	SceneRouter.GotoLevel(_highest_unlocked_level())

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

## 取得已解锁的最高关卡编号。
## @return 关卡编号，至少为 1。
func _highest_unlocked_level() -> int:
	var levels: PackedStringArray = SaveManager.GetProgress().get("unlocked_levels", PackedStringArray())
	var highest := 1
	for entry in levels:
		var id := int(entry)
		if id > highest:
			highest = id
	return highest

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and _start_button.has_focus():
		_on_start_pressed()
		accept_event()

extends Control

## 关卡场景。当前版本只搭建流程框架：顶部资源条、棋盘占位区、鬼牌栏占位、暂停菜单与结算。
## 棋盘交互、放置、连线、采集与共鸣判定均未实现，相关位置标注为占位。

@onready var _level_name_label: Label = %LevelName
@onready var _spirit_label: Label = %SpiritValue
@onready var _delivered_label: Label = %DeliveredValue
@onready var _timer_label: Label = %TimerValue
@onready var _ghost_bar: HBoxContainer = %GhostBar
@onready var _pause_button: Button = %PauseButton
@onready var _pause_menu: Control = %PauseMenu
@onready var _simulate_button: Button = %SimulateButton
@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _restart_button: Button = %RestartButton
@onready var _quit_button: Button = %QuitButton
@onready var _result_panel: Control = %ResultPanel

var _level_id: int = 1
var _level_data: LevelData = null
var _time_left: float = 0.0
var _elapsed: float = 0.0

func _ready() -> void:
	_level_id = GlobalValue.TakePendingLevelId()
	if _level_id <= 0:
		_level_id = int(SaveManager.GetProgress().get("current_level", 1))
	_level_data = LevelData.LoadLevel(_level_id)
	if _level_data == null:
		_show_load_error()
		return
	_apply_level_data()
	_pause_button.pressed.connect(_on_pause_pressed)
	_resume_button.pressed.connect(_on_resume_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_simulate_button.pressed.connect(_on_simulate_pressed)
	_pause_menu.visible = false
	_result_panel.visible = false
	_simulate_button.visible = ExportSettings.debug_level_simulate_enabled
	SaveManager.SetCurrentLevel(_level_id)
	SignalBus.LevelStarted.emit(_level_id)

## 把关卡数据填入界面。
func _apply_level_data() -> void:
	_level_name_label.text = "%s" % _level_data.display_name
	_time_left = float(_level_data.time_limit)
	_timer_label.text = "%d 秒" % _level_data.time_limit
	_spirit_label.text = "0"
	_delivered_label.text = "0 / %d" % _level_data.goal_score
	_build_ghost_bar()

## 生成鬼牌栏占位条目。
func _build_ghost_bar() -> void:
	for child in _ghost_bar.get_children():
		child.queue_free()
	for ghost_id in _level_data.available_ghosts:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(96, 64)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var name_label := Label.new()
		name_label.text = ghost_id
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		var cost_label := Label.new()
		cost_label.text = "造价 —"
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override("font_size", 12)
		cost_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		box.add_child(name_label)
		box.add_child(cost_label)
		slot.add_child(box)
		_ghost_bar.add_child(slot)

## 每帧推进占位倒计时。
func _process(delta: float) -> void:
	if _level_data == null or _pause_menu.visible:
		return
	_elapsed += delta
	if fmod(_elapsed, 0.1) < delta:
		_time_left = maxf(0.0, _time_left - 0.1)
		_timer_label.text = "%d 秒" % int(ceil(_time_left))

## 打开暂停菜单。
func _on_pause_pressed() -> void:
	_pause_menu.visible = true
	get_tree().paused = true

## 关闭暂停菜单。
func _on_resume_pressed() -> void:
	_pause_menu.visible = false
	get_tree().paused = false

## 打开设置面板。
func _on_settings_pressed() -> void:
	_pause_menu.visible = false
	SceneRouter.GotoSettings()

## 从暂停菜单返回主菜单。
func _on_quit_pressed() -> void:
	get_tree().paused = false
	SceneRouter.GotoMenu()

## 重玩本关。
func _on_restart_pressed() -> void:
	get_tree().paused = false
	SceneRouter.GotoLevel(_level_id)

## 模拟结算，用于在没有玩法逻辑时验证结算流程。
func _on_simulate_pressed() -> void:
	get_tree().paused = false
	_pause_menu.visible = false
	var efficiency := float(ExportSettings.placeholder_score_efficiency)
	var manual := float(ExportSettings.placeholder_score_manual)
	var space := float(ExportSettings.placeholder_score_space)
	var stars := StarRating.CalculateStars(efficiency, manual, space)
	if stars <= 0:
		stars = 1
	_result_panel.ShowResult(_level_id, stars)
	SignalBus.LevelCompleted.emit(_level_id, stars)

## 关卡数据缺失时显示提示并退回主菜单。
func _show_load_error() -> void:
	_level_name_label.text = "关卡数据缺失"
	push_error("关卡 %d 的数据加载失败。" % _level_id)
	SceneRouter.GotoMenu()

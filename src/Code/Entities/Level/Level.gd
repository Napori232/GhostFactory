extends Control

## 关卡场景。加载关卡布局场景，承载板面、鬼牌栏与 HUD，提供进入、暂停与结算流程。
## 玩法核心（放置、连线、采集、交付）由 Code/Entities/Board 下的运行时组件负责。

@onready var _level_name_label: Label = %LevelName
@onready var _spirit_label: Label = %SpiritValue
@onready var _delivered_label: Label = %DeliveredValue
@onready var _timer_label: Label = %TimerValue
@onready var _board_host: Control = %BoardHost
@onready var _ghost_bar: Control = %GhostBar
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
var _runner: Node2D = null
var _controller: Node2D = null

func _ready() -> void:
	_level_id = GlobalValue.TakePendingLevelId()
	if _level_id <= 0:
		_level_id = int(SaveManager.GetProgress().get("current_level", 1))
	_level_data = LevelData.LoadLevel(_level_id)
	if _level_data == null:
		_show_load_error()
		return
	_build_board()
	_apply_level_data()
	_setup_palette()
	_setup_tutorial()
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

## 初始化新手教程。
func _setup_tutorial() -> void:
	if not ExportSettings.tutorial_enabled:
		return
	var scene: PackedScene = load("res://Code/Entities/Tutorial/TutorialController.tscn")
	if scene == null:
		return
	var controller := scene.instantiate()
	controller.name = "TutorialController"
	add_child(controller)
	if controller.has_method("set"):
		controller.set("anchor_resolver", Callable(self, "_resolve_tutorial_anchor"))

## 解析教程锚点到画布矩形。
## @param anchor_name 锚点名，例如 palette / board / terminal。
## @return 目标矩形。
func _resolve_tutorial_anchor(anchor_name: String) -> Rect2:
	match anchor_name:
		"palette":
			return _ghost_bar.get_global_rect()
		"board":
			return _board_host.get_global_rect()
		"terminal":
			var terminal := _find_terminal(_board_host)
			if terminal != null:
				return Rect2(terminal.global_position - Vector2.ONE * GridUtil.HALF_CELL, Vector2.ONE * GridUtil.CELL_SIZE)
	return Rect2()

## 在板面里找第一个供品口组件。
## @param host 起始节点
## @return 供品口节点；没有则返回 null。
func _find_terminal(host: Node) -> Node2D:
	for child in host.find_children("*", "Node2D", true, false):
		if child.has_method("get_accepted_form"):
			return child
	return null

## 初始化鬼牌栏与板面交互。
func _setup_palette() -> void:
	var palette_scene: PackedScene = load("res://Code/Entities/Board/GhostPalette.tscn")
	if palette_scene != null:
		var palette := palette_scene.instantiate()
		_ghost_bar.add_child(palette)
		palette.set("available_ghosts", _level_data.available_ghosts)
		var controller_script: Script = load("res://Code/Entities/Board/BoardController.gd")
		if controller_script != null:
			var controller := Node2D.new()
			controller.name = "BoardController"
			controller.set_script(controller_script)
			# 控制器挂在板面宿主下，保证与网格同坐标系。
			_board_host.add_child(controller)
			controller.set("grid", _find_grid(_board_host))
			controller.set("runner", _runner)
			controller.set("palette", palette)
			_controller = controller
			if _controller.has_method("RefreshPalette"):
				_controller.call("RefreshPalette")
			var connections_script: Script = load("res://Code/Entities/Board/ConnectionLayer.gd")
			if connections_script != null:
				var connections := Node2D.new()
				connections.name = "ConnectionLayer"
				connections.set_script(connections_script)
				_board_host.add_child(connections)
				connections.set("runner", _runner)
				if _controller.has_method("set"):
					_controller.set("connections", connections)

## 实例化关卡布局场景并挂到板面区域。
func _build_board() -> void:
	for child in _board_host.get_children():
		child.queue_free()
	var level_scene := LevelData.LoadLevelScene(_level_id)
	if level_scene == null:
		return
	var instance := level_scene.instantiate()
	_board_host.add_child(instance)
	instance.position = Vector2.ZERO
	_runner = _find_runner(instance)
	_controller = _find_controller(instance)
	var grid := _find_grid(instance)
	if _runner != null and grid != null:
		_runner.set("grid", grid)
		_runner.call("SetGoal", _level_data.goal_score)
		_runner.call("AddSpirit", _start_spirit())
	SignalBus.SpiritChanged.connect(_on_spirit_changed)
	SignalBus.DeliveredChanged.connect(_on_delivered_changed)

## 取得建造起始鬼能。
## @return 鬼能数量。
func _start_spirit() -> int:
	var raw: Variant = ExportSettings.get("build_start_spirit")
	if raw is int or raw is float:
		return int(raw)
	return 20

## 在节点树里递归查找板面网格。
## @param node 起始节点
## @return 找到的网格节点；没有则返回 null。
func _find_grid(node: Node) -> Node2D:
	if node is Node2D and node.has_method("get_ghost_components"):
		return node
	for child in node.get_children():
		var found := _find_grid(child)
		if found != null:
			return found
	return null

## 在节点树里递归查找运行时节点。
## @param node 起始节点
## @return 找到的运行时节点；没有则返回 null。
func _find_runner(node: Node) -> Node2D:
	if node.has_method("GetLines"):
		return node
	for child in node.get_children():
		var found := _find_runner(child)
		if found != null:
			return found
	return null

## 在节点树里递归查找交互总控节点。
## @param node 起始节点
## @return 找到的交互总控节点；没有则返回 null。
func _find_controller(node: Node) -> Node2D:
	if node.has_method("TryPlaceGhost"):
		return node
	for child in node.get_children():
		var found := _find_controller(child)
		if found != null:
			return found
	return null

## 把关卡数据填入界面。
func _apply_level_data() -> void:
	_level_name_label.text = "%s" % _level_data.display_name
	_time_left = float(_level_data.time_limit)
	_timer_label.text = "%d 秒" % _level_data.time_limit
	_spirit_label.text = "0"
	_delivered_label.text = "0 / %d" % _level_data.goal_score

## 刷新鬼能显示。
## @param spirit 当前鬼能
func _on_spirit_changed(spirit: int) -> void:
	_spirit_label.text = str(spirit)

## 刷新交付计数显示。
## @param delivered 已交付数量
## @param goal 目标数量
func _on_delivered_changed(delivered: int, goal: int) -> void:
	_delivered_label.text = "%d / %d" % [delivered, goal]

## 每帧推进占位倒计时。
func _process(delta: float) -> void:
	if _level_data == null or _pause_menu.visible:
		return
	_elapsed += delta
	if fmod(_elapsed, 0.1) < delta:
		_time_left = maxf(0.0, _time_left - 0.1)
		_timer_label.text = "%d 秒" % int(ceil(_time_left))
		SignalBus.LevelTimerTick.emit(_time_left)

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
	_finish_level()

## 结算本关并展示结算面板。
func _finish_level() -> void:
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

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
	_setup_theme()
	_setup_hud_motion()
	_setup_side_panel()
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

## 应用全局主题，让 HUD 与棋盘面板使用统一的玻璃质感样式。
func _setup_theme() -> void:
	UIPalette.ApplyTheme(self)
	var hud_bar := get_node_or_null("Root/Column/HudBar") as PanelContainer
	if hud_bar != null:
		hud_bar.add_theme_stylebox_override("panel", _glass_style())
	var board_frame := get_node_or_null("Root/Column/MiddleRow/BoardFrame") as PanelContainer
	if board_frame != null:
		board_frame.add_theme_stylebox_override("panel", _glass_style())
	var side_panel := get_node_or_null("Root/Column/MiddleRow/SidePanel") as PanelContainer
	if side_panel != null:
		side_panel.add_theme_stylebox_override("panel", _glass_style())
	var ghost_frame := get_node_or_null("Root/Column/GhostBarRow/GhostBarFrame") as PanelContainer
	if ghost_frame != null:
		ghost_frame.add_theme_stylebox_override("panel", _glass_style())
	_style_pause_menu()
	for button in [_pause_button, _resume_button, _settings_button, _restart_button, _quit_button, _simulate_button]:
		if button != null:
			UIEffects.AttachInteractive(button, ExportSettings.ui_hover_scale, ExportSettings.ui_press_scale, ExportSettings.ui_hover_duration)

## 填充右侧情报面板：交付目标、空间预算与已放置鬼数。
func _setup_side_panel() -> void:
	if _level_data == null:
		return
	var goal_label := get_node_or_null("Root/Column/MiddleRow/SidePanel/SideMargin/SideColumn/GoalValue") as Label
	if goal_label != null:
		goal_label.text = str(_level_data.goal_score)
	var space_label := get_node_or_null("Root/Column/MiddleRow/SidePanel/SideMargin/SideColumn/SpaceValue") as Label
	if space_label != null:
		space_label.text = "%d 格" % _level_data.space_budget
	_style_legend()
	_refresh_placed_count()

## 给图例色块按色板上色，让玩家能对应棋盘上的元素。
func _style_legend() -> void:
	var base := "Root/Column/MiddleRow/SidePanel/SideMargin/SideColumn/LegendColumn/"
	var entries := {
		"LegendRaw": UIPalette.ACCENT,
		"LegendTerminal": UIPalette.WARNING,
		"LegendField": UIPalette.SUCCESS,
		"LegendWall": UIPalette.TEXT_SECONDARY,
	}
	for node_name in entries:
		var swatch := get_node_or_null(base + node_name + "/Swatch") as ColorRect
		if swatch == null:
			continue
		var tint: Color = entries[node_name]
		swatch.color = tint

## 刷新已放置鬼数。
func _refresh_placed_count() -> void:
	var placed_label := get_node_or_null("Root/Column/MiddleRow/SidePanel/SideMargin/SideColumn/PlacedValue") as Label
	if placed_label == null:
		return
	var count := 0
	for child in _board_host.get_children():
		if child.has_method("GetGhostId"):
			count += 1
	placed_label.text = "%d 只" % count

## 生成玻璃质感面板样式盒。
## @return StyleBoxFlat。
func _glass_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UIPalette.GLASS_BG
	style.border_color = UIPalette.GLASS_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 3)
	return style

## 给暂停菜单卡片套上玻璃样式。
func _style_pause_menu() -> void:
	var card := get_node_or_null("PauseMenu/Center/PauseCard") as PanelContainer
	if card == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UIPalette.BG_PANEL.r, UIPalette.BG_PANEL.g, UIPalette.BG_PANEL.b, 0.96)
	style.border_color = UIPalette.GLASS_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(UIPalette.PRIMARY.r, UIPalette.PRIMARY.g, UIPalette.PRIMARY.b, 0.3)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	card.add_theme_stylebox_override("panel", style)

## 配置 HUD 动效：数值变化时弹跳，倒计时紧张时转为警告色并脉冲。
func _setup_hud_motion() -> void:
	for label in [_spirit_label, _delivered_label, _timer_label]:
		if label == null:
			continue
		label.pivot_offset = label.size * 0.5
		label.resized.connect(func() -> void:
			if is_instance_valid(label):
				label.pivot_offset = label.size * 0.5
		)

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
	_center_board(instance, grid)

## 把棋盘在板面容器内居中，避免右侧留出大片空白。
## @param instance 关卡布局实例。
## @param grid 棋盘网格节点。
func _center_board(instance: Node2D, grid: Node2D) -> void:
	if grid == null:
		return
	# 等布局完成后按网格实际尺寸重新居中。
	await get_tree().process_frame
	var grid_rect: Rect2 = Rect2()
	if grid.has_method("get_world_rect"):
		grid_rect = grid.get_world_rect()
	if grid_rect.size.x <= 0.0 or grid_rect.size.y <= 0.0:
		return
	var host_rect := _board_host.size
	var offset := Vector2(
		maxf(0.0, (host_rect.x - grid_rect.size.x) * 0.5),
		maxf(0.0, (host_rect.y - grid_rect.size.y) * 0.5)
	)
	instance.position = offset
	# 网格居中后把坐标原点补偿掉，组件仍按原格位渲染。
	grid.position = Vector2.ZERO

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
	_pop_value(_spirit_label)

## 刷新交付计数显示。
## @param delivered 已交付数量
## @param goal 目标数量
func _on_delivered_changed(delivered: int, goal: int) -> void:
	_delivered_label.text = "%d / %d" % [delivered, goal]
	_pop_value(_delivered_label)

## 数值变化时做一次弹跳，让玩家注意到状态更新。
## @param label 目标数值标签。
func _pop_value(label: Label) -> void:
	if label == null or not is_instance_valid(label):
		return
	UIEffects.PopScale(label, 1.0, 1.18, 0.22)

## 每帧推进占位倒计时。
func _process(delta: float) -> void:
	if _level_data == null or _pause_menu.visible:
		return
	_elapsed += delta
	if fmod(_elapsed, 0.1) < delta:
		_time_left = maxf(0.0, _time_left - 0.1)
		_timer_label.text = "%d 秒" % int(ceil(_time_left))
		_update_timer_warning()
		SignalBus.LevelTimerTick.emit(_time_left)

## 时间不足十秒时把倒计时转成警告色并持续脉冲。
func _update_timer_warning() -> void:
	if _timer_label == null or not is_instance_valid(_timer_label):
		return
	var urgent := _time_left <= 10.0
	var target := UIPalette.WARNING if urgent else UIPalette.TEXT_PRIMARY
	if _timer_label.get_meta("timer_urgent", false) == urgent and _timer_label.get_meta("timer_urgent_set", false):
		return
	_timer_label.set_meta("timer_urgent", urgent)
	_timer_label.set_meta("timer_urgent_set", true)
	_timer_label.add_theme_color_override("font_color", target)
	if urgent:
		UIEffects.GlowPulse(_timer_label, 0.3, 1.0)
	else:
		_timer_label.modulate = Color.WHITE

## 打开暂停菜单。
func _on_pause_pressed() -> void:
	_pause_menu.visible = true
	get_tree().paused = true
	# 暂停卡片弹入，避免菜单突然闪现。
	var card := get_node_or_null("PauseMenu/Center/PauseCard") as Control
	if card != null:
		card.pivot_offset = card.size * 0.5
		UIEffects.PopScale(card, 0.85, 1.0, 0.28)
		UIEffects.FadeIn(card, 0.22)

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

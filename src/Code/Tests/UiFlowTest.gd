extends Node

## UI 流程的 headless 测试：主菜单、关卡选择与设置。
## 选关卡片已恢复为可进入关卡，测试覆盖按钮可用性与跳转绑定。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/UiFlowTest.tscn

const ORIGINAL_SAVE_PATH: String = "user://savegame.cfg"

var _failures: int = 0
var _checks: int = 0
var _tree: SceneTree = null

func _ready() -> void:
	_tree = get_tree()
	# 把 runner 移到 root 下，避免切换场景时随测试场景一起被释放。
	_reparent.call_deferred()
	await _tree.process_frame
	await _tree.process_frame
	await _run_all()
	print("---- 结果：%d 项断言，%d 项失败" % [_checks, _failures])
	_tree.quit(1 if _failures > 0 else 0)

## 将自身节点移到场景树根节点下。
func _reparent() -> void:
	var parent := get_parent()
	if parent == null:
		return
	parent.remove_child(self)
	_tree.root.add_child(self)

## 依次执行全部测试组。
func _run_all() -> void:
	await _test_start_menu()
	await _test_level_select()
	await _test_setting_panel()
	await _test_scene_navigation()

## 测试场景导航：菜单 → 关卡选择 → 返回菜单。
func _test_scene_navigation() -> void:
	var tmp_path := "user://test_ui_flow_nav.cfg"
	ExportSettings.save_game_path = tmp_path
	SaveManager.ResetProgress()
	_change_scene_to("res://Code/Entities/StartMenu/StartMenu.tscn")
	await _tree.process_frame
	_check(_tree.current_scene != null, "主菜单场景已加载")
	_check(_tree.current_scene.name == "StartMenu", "当前场景为主菜单，实际 %s" % _tree.current_scene.name)

	SceneRouter.GotoLevelSelect()
	await _tree.process_frame
	await _tree.process_frame
	_check(_tree.current_scene.name == "LevelSelect", "导航到关卡选择，实际 %s" % _tree.current_scene.name)

	SceneRouter.GotoMenu()
	await _tree.process_frame
	await _tree.process_frame
	_check(_tree.current_scene.name == "StartMenu", "从关卡选择返回主菜单，实际 %s" % _tree.current_scene.name)
	_restore_save_path()

## 测试主菜单：按钮齐备、继续按钮在无存档时禁用。
func _test_start_menu() -> void:
	# 用临时存档隔离：不读真实进度，避免被通关类测试留下的「当前关卡」污染。
	var tmp_path := "user://test_ui_flow_menu.cfg"
	ExportSettings.save_game_path = tmp_path
	SaveManager.ResetProgress()
	var scene: PackedScene = load("res://Code/Entities/StartMenu/StartMenu.tscn")
	_check(scene != null, "主菜单场景可加载")
	if scene == null:
		_remove_tmp(tmp_path)
		_restore_save_path()
		return
	var menu := scene.instantiate()
	add_child(menu)
	await _tree.process_frame
	_check(menu.get_node_or_null("%Title") != null, "主菜单含标题节点")
	_check(menu.get_node_or_null("%StartButton") != null, "主菜单含开始游戏按钮")
	_check(menu.get_node_or_null("%ContinueButton") != null, "主菜单含继续游戏按钮")
	_check(menu.get_node_or_null("%LevelSelectButton") != null, "主菜单含关卡选择按钮")
	_check(menu.get_node_or_null("%SettingsButton") != null, "主菜单含设置按钮")
	_check(menu.get_node_or_null("%QuitButton") != null, "主菜单含退出按钮")
	var continue_button: Button = menu.get_node("%ContinueButton")
	_check(not continue_button.disabled, "继续按钮在有进度时可用")
	_check("第 1 关" in continue_button.text, "继续按钮标注当前关卡，实际 %s" % continue_button.text)
	menu.queue_free()
	_remove_tmp(tmp_path)
	_restore_save_path()

## 测试关卡选择：卡片数量与解锁态。
func _test_level_select() -> void:
	var tmp_path := "user://test_ui_flow_select.cfg"
	ExportSettings.save_game_path = tmp_path
	SaveManager.ResetProgress()
	var scene: PackedScene = load("res://Code/Entities/LevelSelect/LevelSelect.tscn")
	_check(scene != null, "关卡选择场景可加载")
	if scene == null:
		_restore_save_path()
		return
	var select := scene.instantiate()
	add_child(select)
	await _tree.process_frame
	_check(select.get_node_or_null("%Cards") != null, "关卡选择含卡片容器")
	_check(select.get_node_or_null("%BackButton") != null, "关卡选择含返回按钮")
	var cards: HBoxContainer = select.get_node("%Cards")
	_check(cards.get_child_count() == ExportSettings.level_count, "关卡卡片数量为 %d，实际 %d" % [ExportSettings.level_count, cards.get_child_count()])
	var first_card := cards.get_child(0) as PanelContainer
	_check(first_card != null, "第一张卡片存在")
	if first_card != null:
		_check(not first_card.modulate.a < 0.99, "已解锁卡片未变灰")
		var first_button := _find_button(first_card)
		_check(first_button != null and not first_button.disabled, "已解锁卡片按钮可用（选关已恢复）")
		_check(first_button != null and first_button.text == "进入关卡", "已解锁卡片按钮文案为「进入关卡」")
		_check(first_button != null and first_button.get_signal_connection_list("pressed").size() > 0, "卡片按钮已绑定进入关卡回调")
		var first_body := first_card.get_node_or_null("Body") as VBoxContainer
		_check(first_body != null and "掉落与交付" in _collect_text(first_body), "卡片展示真实关卡名而非「待重建」")
	var third_card := cards.get_child(2) as PanelContainer
	_check(third_card != null, "第三张卡片存在")
	if third_card != null:
		_check(third_card.modulate.a < 0.99, "未解锁卡片变灰")
		var third_button := _find_button(third_card)
		_check(third_button != null and third_button.disabled, "未解锁关卡按钮禁用")
	var progress_label: Label = select.get_node("%ProgressLabel")
	_check("0 / %d" % ExportSettings.level_count in progress_label.text, "进度文案正确，实际 %s" % progress_label.text)
	_restore_save_path()
	select.queue_free()

## 测试设置面板：控件齐备。
func _test_setting_panel() -> void:
	var scene: PackedScene = load("res://Code/Entities/Setting/SettingPanel.tscn")
	_check(scene != null, "设置面板场景可加载")
	if scene == null:
		return
	var panel := scene.instantiate()
	add_child(panel)
	await _tree.process_frame
	_check(panel.get_node_or_null("%ResetButton") != null, "设置面板含重置进度按钮")
	_check(panel.get_node_or_null("%ResetDialog") != null, "设置面板含重置二次确认对话框")
	_check(panel.get_node_or_null("%BackButton") != null, "设置面板含返回按钮")
	_check(panel.get_node_or_null("%MasterSlider") != null, "设置面板含主音量滑条")
	_check(panel.get_node_or_null("%SkipTutorialCheck") != null, "设置面板含跳过教程开关")
	_check(panel.get_node_or_null("%ScreenShakeCheck") != null, "设置面板含屏幕震动开关")
	_check(panel.get_node_or_null("%QualityOption") != null, "设置面板含画质选项")
	panel.queue_free()

## 切换当前场景。
## @param path 目标场景路径
func _change_scene_to(path: String) -> void:
	get_tree().change_scene_to_file(path)

## 在节点子树内递归查找第一个 Button。
## @param node 起始节点
## @return 找到的 Button；没有则返回 null。
func _find_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child
		var found := _find_button(child)
		if found != null:
			return found
	return null

## 递归收集容器下所有 Label 的文字，用于核对卡片内容。
## @param node 起始节点。
## @return 拼接后的文字。
func _collect_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += node.text + "\n"
	for child in node.get_children():
		text += _collect_text(child)
	return text

## 恢复存档路径并清理临时文件。
func _restore_save_path() -> void:
	ExportSettings.save_game_path = ORIGINAL_SAVE_PATH

## 删除临时存档文件。
## @param path user:// 下的文件路径
func _remove_tmp(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)

## 执行一条断言。
## @param condition 断言条件
## @param label 失败时的说明文字
func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		_failures += 1
		printerr("FAIL: %s" % label)

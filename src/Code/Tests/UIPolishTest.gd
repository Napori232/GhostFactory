extends Node

## UI 美化层自测。覆盖色板、新组件（ArtPlaceholder / BackgroundLayer / UIFeedback）
## 与三个界面（主菜单 / 关卡选择 / 设置）的场景结构与运行时表现。
## 失败时以非 0 退出码结束，方便 CI 判定。

## 期望的色板常量数量。
const EXPECTED_COLOR_COUNT: int = 23
## 主菜单应包含的按钮数量。
const EXPECTED_MENU_BUTTON_COUNT: int = 5

var _passed: int = 0
var _failed: int = 0
var _messages: Array[String] = []

func _ready() -> void:
	await _run()
	var total := _passed + _failed
	print("=== UI 美化层自测结果 ===")
	for message in _messages:
		print(message)
	print("PASS: %d / %d，FAIL: %d" % [_passed, total, _failed])
	if _failed > 0:
		print("RESULT: FAIL")
		get_tree().quit(1)
		return
	print("RESULT: PASS")
	get_tree().quit(0)

## 顺序执行全部测试分组。
func _run() -> void:
	_test_palette()
	_test_art_placeholder()
	_test_background_layer()
	_test_ui_feedback()
	await _test_start_menu()
	await _test_level_select()
	await _test_setting_panel()

## 记录一条检查结果。
## @param ok 检查是否通过
## @param label 检查项名称
## @param detail 失败时的补充说明
func _check(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		_passed += 1
		_messages.append("PASS  %s" % label)
		return
	_failed += 1
	_messages.append("FAIL  %s%s" % [label, "" if detail == "" else "（%s）" % detail])

## 测试色板：常量齐全、ALL 长度正确、按名取色一致。
func _test_palette() -> void:
	var named := UIPalette.GetNamedColors()
	_check(named.size() == EXPECTED_COLOR_COUNT, "色板常量数量为 %d" % EXPECTED_COLOR_COUNT, "实际 %d" % named.size())
	_check(UIPalette.ALL.size() == EXPECTED_COLOR_COUNT, "ALL 数组长度为 %d" % EXPECTED_COLOR_COUNT, "实际 %d" % UIPalette.ALL.size())
	_check(UIPalette.Get("primary") == UIPalette.PRIMARY, "Get(primary) 返回主色")
	_check(UIPalette.Get("warning") == UIPalette.WARNING, "Get(warning) 返回警告色")
	_check(UIPalette.Get("不存在") == UIPalette.PRIMARY, "Get 未知名称回退主色")
	var keys: Array = named.keys()
	keys.sort()
	for key in keys:
		_check(UIPalette.Get(key) == named[key], "Get(%s) 与对照表一致" % key)

## 测试美术占位组件：无资源时 HasArt 为假，设置标签生效。
func _test_art_placeholder() -> void:
	var placeholder := ArtPlaceholder.new()
	add_child(placeholder)
	await get_tree().process_frame
	_check(placeholder != null, "ArtPlaceholder 可实例化")
	_check(not placeholder.HasArt(), "无美术资源时 HasArt() 为 false")
	placeholder.SetLabel("背景图 · 测试")
	_check(placeholder.label_text == "背景图 · 测试", "SetLabel 后文字生效", placeholder.label_text)
	placeholder.SetArt("res://nonexistent_placeholder.png")
	_check(not placeholder.HasArt(), "路径不存在时仍无美术资源")
	placeholder.queue_free()

## 测试背景层：可实例化、可绘制、光斑强度可调。
func _test_background_layer() -> void:
	var layer := BackgroundLayer.new()
	layer.size = Vector2(640, 360)
	add_child(layer)
	await get_tree().process_frame
	_check(layer != null, "BackgroundLayer 可实例化")
	_check(layer.art_placeholder != null, "BackgroundLayer 内嵌 ArtPlaceholder")
	layer.SetGlowIntensity(0.6)
	_check(is_equal_approx(layer.glow_intensity, 0.6), "SetGlowIntensity 生效", str(layer.glow_intensity))
	layer.SetArt("res://nonexistent_background.png")
	_check(layer.background_art_path == "res://nonexistent_background.png", "SetArt 记录背景图路径")
	layer.queue_free()
	await get_tree().process_frame

## 测试飘字与提示条：调用后节点被加入父节点。
func _test_ui_feedback() -> void:
	var host := Control.new()
	host.size = Vector2(640, 360)
	add_child(host)
	await get_tree().process_frame
	var before := host.get_child_count()
	UIFeedback.Show(host, Vector2(100, 100), "鬼能不足", UIPalette.DANGER)
	_check(host.get_child_count() == before + 1, "Show 生成飘字并挂到父节点")
	UIFeedback.Toast(host, "已放置", UIPalette.SUCCESS)
	_check(host.get_child_count() == before + 2, "Toast 生成提示条并挂到父节点")
	host.queue_free()
	await get_tree().process_frame

## 测试主菜单：包含背景层、占位组件与 5 个按钮，开始游戏指向关卡选择。
func _test_start_menu() -> void:
	var scene: PackedScene = load("res://Code/Entities/StartMenu/StartMenu.tscn")
	_check(scene != null, "主菜单场景可加载")
	if scene == null:
		return
	var menu := scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	_check(menu.get_node_or_null("%Background") is BackgroundLayer, "主菜单包含 BackgroundLayer")
	_check(menu.get_node_or_null("%KeyArt") is ArtPlaceholder, "主菜单包含主视觉占位组件")
	for button_name in ["%StartButton", "%ContinueButton", "%LevelSelectButton", "%SettingsButton", "%QuitButton"]:
		_check(menu.get_node_or_null(button_name) is Button, "主菜单包含按钮 %s" % button_name)
	var start_button: Button = menu.get_node("%StartButton")
	_check(start_button.text == "开始游戏", "开始按钮文本为「开始游戏」", start_button.text)
	_check(_menu_button_count(menu) == EXPECTED_MENU_BUTTON_COUNT, "主菜单按钮数量为 %d" % EXPECTED_MENU_BUTTON_COUNT, str(_menu_button_count(menu)))
	_check(start_button.pressed.get_connections().size() > 0, "开始按钮已连接点击信号")
	menu.queue_free()
	await get_tree().process_frame

## 测试关卡选择：包含背景层、卡片容器与返回按钮。
func _test_level_select() -> void:
	var scene: PackedScene = load("res://Code/Entities/LevelSelect/LevelSelect.tscn")
	_check(scene != null, "关卡选择场景可加载")
	if scene == null:
		return
	var panel := scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	_check(panel.get_node_or_null("%Background") is BackgroundLayer, "关卡选择包含 BackgroundLayer")
	_check(panel.get_node_or_null("%Cards") is HBoxContainer, "关卡选择包含卡片容器")
	_check(panel.get_node_or_null("%BackButton") is Button, "关卡选择包含返回按钮")
	_check(panel.get_node_or_null("%ProgressFill") is ColorRect, "关卡选择包含进度条填充节点")
	var cards: HBoxContainer = panel.get_node("%Cards")
	_check(cards.get_child_count() == ExportSettings.level_count, "关卡卡片数量与关卡总数一致", "%d / %d" % [cards.get_child_count(), ExportSettings.level_count])
	panel.queue_free()
	await get_tree().process_frame

## 测试设置界面：包含背景层、音量滑条、开关、画质下拉与重置按钮。
func _test_setting_panel() -> void:
	var scene: PackedScene = load("res://Code/Entities/Setting/SettingPanel.tscn")
	_check(scene != null, "设置场景可加载")
	if scene == null:
		return
	var panel := scene.instantiate()
	add_child(panel)
	await get_tree().process_frame
	_check(panel.get_node_or_null("%Background") is BackgroundLayer, "设置界面包含 BackgroundLayer")
	_check(panel.get_node_or_null("%MasterSlider") is HSlider, "设置界面包含主音量滑条")
	_check(panel.get_node_or_null("%SkipTutorialCheck") is CheckButton, "设置界面包含跳过教程开关")
	_check(panel.get_node_or_null("%ScreenShakeCheck") is CheckButton, "设置界面包含屏幕震动开关")
	_check(panel.get_node_or_null("%QualityOption") is OptionButton, "设置界面包含画质下拉")
	_check(panel.get_node_or_null("%ResetButton") is Button, "设置界面包含重置进度按钮")
	_check(panel.get_node_or_null("%BackButton") is Button, "设置界面包含返回按钮")
	panel.queue_free()
	await get_tree().process_frame

## 统计主菜单里的按钮数量。
## @param menu 主菜单根节点
## @return 按钮数量。
func _menu_button_count(menu: Node) -> int:
	var count := 0
	for node in menu.find_children("*", "Button", true, false):
		count += 1
	return count

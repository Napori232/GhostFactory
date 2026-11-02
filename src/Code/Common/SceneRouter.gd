class_name SceneRouter
extends RefCounted

## 场景路由。集中处理跨场景跳转，避免各场景散落 change_scene_to_file 调用。

## 跳转到主菜单。
static func GotoMenu() -> void:
	_change_scene(ExportSettings.scene_menu, &"menu")

## 跳转到关卡选择。
static func GotoLevelSelect() -> void:
	_change_scene(ExportSettings.scene_level_select, &"level_select")

## 跳转到指定关卡。
## @param level_id 关卡编号，从 1 开始
static func GotoLevel(level_id: int) -> void:
	_change_scene(ExportSettings.scene_level, &"level", level_id)

## 跳转到设置界面。
static func GotoSettings() -> void:
	_change_scene(ExportSettings.scene_settings, &"settings")

## 执行场景切换并广播导航信号。
## @param path 目标场景路径
## @param target 导航目标标识
## @param level_id 关卡编号，非关卡场景传 -1
static func _change_scene(path: String, target: StringName, level_id: int = -1) -> void:
	if not ResourceLoader.exists(path):
		push_error("目标场景不存在：%s" % path)
		return
	SignalBus.NavigateTo.emit(target)
	if level_id >= 0:
		GlobalValue.SetPendingLevelId(level_id)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		push_error("场景树不可用，无法切换到 %s" % path)
		return
	tree.change_scene_to_file(path)

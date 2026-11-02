extends Node2D
class_name State

## 状态基类。子类重写 enter/exit/update/physics_process/handled_input 实现具体行为。

var state_machine: Node = null
var animation_player: AnimationPlayer = null
var state_time: float = 0.0
var obj: CharacterBody2D = null
var gameInputControl: Node = null

## 状态完成并请求切换。
## @param next_state_name 下一个目标状态名称
signal finished(next_state_name: String)

## 当前状态是否允许进入。
var is_use: bool = true

## 进入状态时调用。
func enter() -> void:
	state_time = 0.0

## 退出状态时调用。
func exit() -> void:
	pass

## 每帧逻辑更新。
## @param delta 帧间隔秒数
func update(_delta: float) -> void:
	pass

## 每物理帧更新。
## @param delta 物理帧间隔秒数
func physics_process(_delta: float) -> void:
	pass

## 处理未消费的输入事件。
## @param event 输入事件
func handled_input(_event: InputEvent) -> void:
	pass

## 切换本节点的生命周期处理状态。
## @param value 是否激活 process/physics_process/process_input
func change_process_state(value: bool) -> void:
	set_process(value)
	set_physics_process(value)
	set_process_input(value)

## 在动画播放完成后自动触发状态迁移。
## @param next_state 动画结束后要切换到的目标状态名
func animation_end_finished(next_state: String) -> void:
	if animation_player:
		animation_player.animation_finished.connect(func(_t):
			finished.emit(next_state)
		, CONNECT_ONE_SHOT)

## 批量修改所有子状态是否可进入。
## @param flag 是否可用
## @param temp 遍历根节点，默认为当前状态机
func change_use_all(flag: bool, temp: Node = null) -> void:
	var target_root = temp if temp != null else state_machine
	if not target_root:
		return
	for item in target_root.get_children():
		if item.has_method("enter"):
			item.is_use = flag
		else:
			change_use_all(flag, item)

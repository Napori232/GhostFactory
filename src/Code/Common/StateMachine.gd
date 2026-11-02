extends Node
class_name StateMachine

## 状态机。子节点中实现了 enter() 的节点被登记为状态，按名称切换。

## 状态切换。
## @param prev_state 离开的前一个状态
## @param current_state 进入的当前状态
signal state_changed(prev_state: Node, current_state: Node)

## 初始状态名（对应子节点名称）。
@export var init_state: String
## 是否在切换时打印调试信息。
@export var is_debug: bool = false

var obj: CharacterBody2D
var state_map: Dictionary = {}
var current_state: Node
var prev_state: Node
var cur_state_name: String
var gameInputControl: Node

## 初始化状态机。
## @param p_obj 受控制的 CharacterBody2D 实体
## @param animation_player 关联的动画播放器（可选）
## @param p_game_input_control 关联的输入控制器（可选）
func init(p_obj: CharacterBody2D, animation_player: AnimationPlayer = null, p_game_input_control: Node = null) -> void:
	if is_debug:
		state_changed.connect(func(pre, cur):
			var pre_name = pre.name if pre else "None"
			var cur_name = cur.name if cur else "None"
			print("%s -> %s" % [pre_name, cur_name])
		)
	self.obj = p_obj
	self.gameInputControl = p_game_input_control
	if gameInputControl:
		gameInputControl.obj = obj
	_set_all_children_init(get_children(), p_obj, animation_player, p_game_input_control)
	var start_state = state_map.get(init_state.to_lower())
	if start_state:
		start_state.enter()
		current_state = start_state
		cur_state_name = current_state.name

func _set_all_children_init(children: Array, parent: CharacterBody2D, animation_player: AnimationPlayer, p_game_input_control: Node) -> void:
	for child in children:
		if child.has_method("enter"):
			child.obj = parent
			child.state_machine = self
			child.animation_player = animation_player
			child.gameInputControl = p_game_input_control
			if child.has_signal("finished"):
				child.finished.connect(func(next_state_name):
					change_state(next_state_name)
				)
			state_map[child.name.to_lower()] = child
		elif child.get_child_count() > 0:
			_set_all_children_init(child.get_children(), parent, animation_player, p_game_input_control)

## 切换前插入点，子类可重写。
func insert_with_exit_enter() -> void:
	pass

## 切换前钩子，子类可重写。
## @param _next_state_name 目标状态节点名称
func change_before(_next_state_name: String) -> void:
	pass

## 切换状态机当前状态。
## @param next_state_name 目标状态节点名称
func change_state(next_state_name: String) -> void:
	var next_state = state_map.get(next_state_name.to_lower(), null)
	if next_state_name == cur_state_name:
		return
	if not next_state or not next_state.is_use:
		return
	change_before(next_state_name)
	if current_state:
		current_state.exit()
		prev_state = current_state
	insert_with_exit_enter()
	next_state.enter()
	current_state = next_state
	cur_state_name = current_state.name
	state_changed.emit(prev_state, current_state)

## 每物理帧中间处理，子类可重写。
func phy_middleware() -> void:
	pass

## 每帧中间处理，子类可重写。
func middleware() -> void:
	pass

func _process(delta: float) -> void:
	middleware()
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	phy_middleware()
	if current_state:
		current_state.physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handled_input(event)

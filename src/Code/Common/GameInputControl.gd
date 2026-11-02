extends Node
class_name GameInputControl

## 输入控制组件基类。子类持有具体输入映射与轴值派生逻辑。

var obj: CharacterBody2D = null
var animation_player: AnimationPlayer = null
var state_machine: Node = null

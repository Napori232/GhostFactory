extends Control

## 主菜单。启动主场景，提供进入游戏的入口。

@onready var _title: Label = %Title
@onready var _hint: Label = %Hint

func _ready() -> void:
	_title.text = "鬼工厂"
	_hint.text = "按任意键开始"

func _unhandled_input(_event: InputEvent) -> void:
	pass

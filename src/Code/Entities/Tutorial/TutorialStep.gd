class_name TutorialStep
extends Resource

## 教程步骤数据。描述一步教学：讲什么话、高亮哪里、玩家要做什么才算完成。

## 步骤 id，用于存档记录进度。
@export var step_id: String = ""
## 步骤标题。
@export var title: String = ""
## 步骤说明文字。
@export var description: String = ""
## 高亮目标的锚点名，例如 "palette" / "board" / "terminal"。
@export var target_anchor: String = ""
## 完成该步需要的动作。
@export_enum("等待任意点击", "等待放置鬼", "等待连线", "等待交付", "自动继续") var wait_for: int = 0
## 该步是否可以跳过。
@export var skippable: bool = true
## 自动继续的停留时长（秒），wait_for 为自动继续时生效。
@export var auto_duration: float = 2.5

## 等待玩家点击任意处的推进方式。
const WAIT_ANY_CLICK: int = 0
## 等待玩家放置一只鬼的推进方式。
const WAIT_PLACE_GHOST: int = 1
## 等待玩家连一条线的推进方式。
const WAIT_CONNECT_LINE: int = 2
## 等待玩家交付一份供品的推进方式。
const WAIT_DELIVER: int = 3
## 按固定时长自动继续的推进方式。
const WAIT_AUTO: int = 4

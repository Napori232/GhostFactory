class_name FormData
extends Resource

## 形态资源。形态是物品类别标签，属于全局词表，由关卡引用。
## 参见 Docs/GameDesign.md §6.2。
##
## 当前词表：鬼能（SPIRIT）/ 贡品（OFFER）/ 杂质（IMPURITY）。

## 形态 id，全局唯一，例如 Spirit。
@export var id: String = ""
## 形态显示名，例如 鬼能。
@export var display_name: String = ""
## 单词母标记，美术未定的占位方案，例如 S。
@export var letter: String = ""
## 形态主题色，用于 UI 与粒子配色。
@export var color: Color = Color.WHITE
## 该形态是否可作为关卡交付目标。
@export var deliverable: bool = false

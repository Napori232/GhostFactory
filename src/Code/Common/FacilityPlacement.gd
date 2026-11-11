class_name FacilityPlacement
extends Resource

## 关卡预置的一个交互口。交付口与仓库口是同一类可配置设施，
## 行为差异全部由 kind 与 accepted_form 表达，不为每种口写单独脚本。
## 参见 Docs/GameDesign.md §4.8.2 与 v12 裁决 C1/C2。

## 交付口：检验并计分。
const KIND_DELIVERY: StringName = &"DELIVERY"
## 仓库口：接收鬼能，转为建造货币。
const KIND_STORAGE: StringName = &"STORAGE"

## 设施类型：DELIVERY / STORAGE。
@export var kind: StringName = KIND_DELIVERY
## 所在格坐标。
@export var cell: Vector2i = Vector2i.ZERO
## 接收的形态 id（FormData.id），例如 Spirit / Offer。
@export var accepted_form: String = "Spirit"
## 世界朝向，不随相机旋转改变。
@export var facing: Vector2i = Vector2i.LEFT

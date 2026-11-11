class_name GhostPlacement
extends Resource

## 关卡预置的一只鬼。只描述「在哪、放什么、开局什么状态」，不含运行时状态。

## 鬼的资源 id，对应 GhostData.id。
@export var ghost_id: StringName = &""
## 本体原点格坐标。
@export var cell: Vector2i = Vector2i.ZERO
## 开局状态：IDLE / RUNNING / PAUSED。
@export var state: StringName = &"RUNNING"

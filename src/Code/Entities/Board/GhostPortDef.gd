class_name GhostPortDef
extends RefCounted

## 鬼端口定义。描述每只鬼的输入/输出端口在自身占位中的相对位置与朝向。
## 端口用于连线：输出端口 → 输入端口，中间自动生成 L 形路径。

## 端口定义。offset 为相对本体原点的格偏移，dir 为端口朝向（0=东 1=南 2=西 3=北）。
const PORT_IN: String = "in"
const PORT_OUT: String = "out"

## 各鬼的端口表。键为鬼 id，值为端口数组。
const PORTS: Dictionary = {
	"LongTongue": [
		{"kind": PORT_OUT, "offset": Vector2i(0, 0), "dir": 0, "tag": &"GRAB"},
	],
	"Stove": [
		{"kind": PORT_IN, "offset": Vector2i(0, 0), "dir": 0, "tag": &"SWALLOW"},
		{"kind": PORT_OUT, "offset": Vector2i(1, 0), "dir": 0, "tag": &"FEED"},
	],
	"Fork": [
		{"kind": PORT_IN, "offset": Vector2i(0, 0), "dir": 0, "tag": &"SWALLOW"},
		{"kind": PORT_OUT, "offset": Vector2i(1, 0), "dir": 0, "tag": &"SPLIT"},
		{"kind": PORT_OUT, "offset": Vector2i(0, 1), "dir": 0, "tag": &"SPLIT"},
	],
	"Glutton": [
		{"kind": PORT_OUT, "offset": Vector2i(0, 0), "dir": 0, "tag": &"SPIT"},
	],
	"FineChew": [
		{"kind": PORT_OUT, "offset": Vector2i(0, 0), "dir": 0, "tag": &"SPIT"},
	],
	"Terminal": [
		{"kind": PORT_IN, "offset": Vector2i(0, 0), "dir": 2, "tag": &"OFFER"},
	],
	"Hanged": [],
	"Tumbler": [],
	"Contain": [],
	"Mirror": [],
}

## 取得某只鬼的端口定义。
## @param ghost_id 鬼 id
## @return 端口定义数组的副本；未知鬼返回空数组。
static func GetPorts(ghost_id: String) -> Array:
	return (PORTS.get(ghost_id, []) as Array).duplicate(true)

## 取得某只鬼的端口数量。
## @param ghost_id 鬼 id
## @return 端口数量。
static func GetPortCount(ghost_id: String) -> int:
	return GetPorts(ghost_id).size()

## 判断端口朝向旋转后的方向向量。
## @param base_dir 基准方向（0=东 1=南 2=西 3=北）
## @param facing 鬼的朝向（0=东 1=南 2=西 3=北）
## @return 旋转后的方向向量。
static func RotateDir(base_dir: int, facing: int) -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	return dirs[(base_dir + facing) % 4]

## 判断端口能否接到某鬼的端口上。
## @param out_tag 输出端口标签
## @param in_tag 输入端口标签
## @return 标签匹配时返回 true。
static func CanConnect(out_tag: StringName, in_tag: StringName) -> bool:
	if out_tag == &"GRAB" and in_tag == &"SWALLOW":
		return true
	if out_tag == &"FEED" and in_tag == &"SWALLOW":
		return true
	if out_tag == &"SPLIT" and in_tag == &"SWALLOW":
		return true
	if out_tag == &"SPIT" and in_tag == &"SWALLOW":
		return true
	if out_tag == &"SPIT" and in_tag == &"OFFER":
		return true
	if out_tag == &"FEED" and in_tag == &"OFFER":
		return true
	if out_tag == &"GRAB" and in_tag == &"OFFER":
		return true
	return false

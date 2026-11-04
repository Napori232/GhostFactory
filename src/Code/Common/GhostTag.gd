class_name GhostTag
extends RefCounted

## 端口标签词表。开放词表：新增标签只需在此声明一次，
## 数据层与实体层共用同一套 StringName 值。
##
## 标签只回答一个问题：**这两个端口之间允许建立连接吗？**
## 连接建立之后发生什么由物理层算出，标签不再介入。
## 参见 Docs/GameDesign.md §4.7 与 Docs/PhysicsLayer.md §2。

## 物料标签：物品本身的类别，运输与交付按它区分。
## 鬼能：全局唯一的硬货币与加工原料。
const SPIRIT: StringName = &"SPIRIT"
## 贡品：加工产物，关卡交付目标。
const OFFER: StringName = &"OFFER"
## 杂质：加工损耗的副产物，可再处理。
const IMPURITY: StringName = &"IMPURITY"

## 动作标签：端口本身能做什么。
## 搬运：主动送出一件物品。运输鬼的输出端口。
const HAUL: StringName = &"HAUL"
## 地面：取物范围来自地面掉落物。采集鬼的输出端口。
const GROUND: StringName = &"GROUND"

## 全部物料标签，按词表顺序排列。
const MATERIALS: Array[StringName] = [
	SPIRIT,
	OFFER,
	IMPURITY,
]

## 全部动作标签，按词表顺序排列。
const ACTIONS: Array[StringName] = [
	HAUL,
	GROUND,
]

## 全部标签，按词表顺序排列。
const ALL: Array[StringName] = [
	SPIRIT,
	OFFER,
	IMPURITY,
	HAUL,
	GROUND,
]

## 判断一个标签是否属于本词表。
## @param tag 待检查的标签。
## @return 属于词表时返回 true，否则返回 false。
static func IsValid(tag: StringName) -> bool:
	return ALL.has(tag)

## 判断一个标签是否为物料标签。
## @param tag 待检查的标签。
## @return 是物料标签时返回 true，否则返回 false。
static func IsMaterial(tag: StringName) -> bool:
	return MATERIALS.has(tag)

## 判断一个标签是否为动作标签。
## @param tag 待检查的标签。
## @return 是动作标签时返回 true，否则返回 false。
static func IsAction(tag: StringName) -> bool:
	return ACTIONS.has(tag)

## 判断两个端口能否连线。输出端必须能送出物料，目标端必须接受该物料。
## @param output_tags 输出端口的标签集合。
## @param input_tags 目标端口接受的物料标签集合。
## @return 允许连线时返回 true，否则返回 false。
static func CanConnect(output_tags: Array[StringName], input_tags: Array[StringName]) -> bool:
	for tag in output_tags:
		if not IsMaterial(tag):
			continue
		if input_tags.has(tag):
			return true
	return false

## 返回标签的中文说明。
## @param tag 待描述的标签。
## @return 中文说明；未知标签返回「未知标签」。
static func Describe(tag: StringName) -> String:
	match tag:
		SPIRIT:
			return "鬼能"
		OFFER:
			return "贡品"
		IMPURITY:
			return "杂质"
		HAUL:
			return "搬运"
		GROUND:
			return "地面"
	return "未知标签"

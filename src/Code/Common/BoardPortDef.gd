class_name BoardPortDef
extends Resource

## 端口定义资源。一个端口只描述「能送出什么物料、能接收什么物料」，不承载运行时缓冲。
## 连线合法性一律以物料标签（SPIRIT / OFFER / IMPURITY）为准，动作标签 HAUL / GROUND
## 只用于界面提示，绝不写进 accepts / produces，避免污染 GhostTag.CanConnect 的判定。
## 参见 Docs/PhysicsLayer.md §2 与 docs/CodePlan_GhostFactory.md §5.2、D1。

## 端口 id，在同一只鬼内唯一，例如 &"out"。
@export var id: StringName = &""
## 端口朝向，取 GridUtil.Neighbors4 的四个方向之一；世界方位，不随相机改变。
@export var direction: Vector2i = Vector2i.RIGHT
## 接受的物料标签集合。为空表示该端口不接受任何物料。
@export var accepts: Array[StringName] = []
## 可送出的物料标签集合。为空表示运行时动态计算（采集鬼，见 D2）或不送出（生产鬼，见 D3）。
@export var produces: Array[StringName] = []
## 该端口的线路缓冲上限，单位：件。
@export_range(0, 20, 1) var buffer_size: int = 1
## 是否为输入端口（能接收物料）。
@export var is_input: bool = false

## 判断本端口能否接收给定物料集合送来的东西。
## @param output_tags 上游输出端口能送出的物料标签集合。
## @return 至少有一种物料匹配时返回 true。
func CanAcceptFrom(output_tags: Array[StringName]) -> bool:
	return GhostTag.CanConnect(output_tags, accepts)

## 判断本端口与另一个端口能否建立连线（本端口为输出端，另一个为输入端）。
## @param input_port 待连接的输入端口，可为 null。
## @return 两端物料标签有交集时返回 true。
func CanConnectTo(input_port: BoardPortDef) -> bool:
	if input_port == null or not input_port.is_input:
		return false
	return GhostTag.CanConnect(produces, input_port.accepts)

## 返回端口的中文简述，用于界面与日志。
## @return 形如「输出·鬼能/贡品」的说明文字。
func Describe() -> String:
	var side := "输入" if is_input else "输出"
	var tags := accepts if is_input else produces
	if tags.is_empty():
		return "%s·动态" % side
	var names: Array[String] = []
	for tag in tags:
		names.append(GhostTag.Describe(tag))
	return "%s·%s" % [side, "/".join(names)]

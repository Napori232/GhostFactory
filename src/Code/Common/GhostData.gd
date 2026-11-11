class_name GhostData
extends Resource

## 一只鬼的静态配置。只描述「它是什么、占几格、有什么端口、跑多快」，
## 不含任何运行时状态；运行时状态放在 Entities/Board/GhostInstance.gd。
## 字段取自 Docs/GameDesign.md §4.1/§4.2 与 docs/CodePlan_GhostFactory.md §5.1。
##
## 注意：category 是四个大类之一，只给玩家与关卡设计读，不参与任何判定。

## 生产大类：按周期凭空产出鬼能并直接落地。
const CATEGORY_PRODUCTION: StringName = &"PRODUCTION"
## 采集大类：在搜索区里找地面掉落物，拾进输出区。
const CATEGORY_COLLECTION: StringName = &"COLLECTION"
## 运输大类：沿连线把一件物品搬到下一台机器。
const CATEGORY_TRANSPORT: StringName = &"TRANSPORT"
## 处理大类：按配方加工，差额转杂质。
const CATEGORY_PROCESSING: StringName = &"PROCESSING"

## 自动触发：按自己的周期动。
const TRIGGER_AUTO: StringName = &"AUTO"
## 被动触发：被别的鬼影响时才动。
const TRIGGER_PASSIVE: StringName = &"PASSIVE"

## 刚体：放下后不可被推动。
const MOVABILITY_RIGID: StringName = &"RIGID"
## 柔体：会被推动链带动。
const MOVABILITY_SOFT: StringName = &"SOFT"

## 资源内唯一 id，例如 &"producer"。
@export var id: StringName = &""
## 行为分派键。留空时按 category 走四个大类的基础行为；
## 填了具体键（pusher / miser / hang）则走推动链专用行为。
## 存在的意义是「新增一只鬼 = 一份 .tres + 一个行为分支」，不必给大类加判定分支。
@export var behavior_id: StringName = &""
## 中文显示名，例如「生产鬼」。
@export var display_name: String = ""
## 四个大类之一，仅用于分类与 UI，不参与判定。
@export var category: StringName = CATEGORY_PRODUCTION
## 触发类型：AUTO / PASSIVE。
@export var trigger_type: StringName = TRIGGER_AUTO
## 可动性：RIGID / SOFT。
@export var movability: StringName = MOVABILITY_RIGID
## 占位格集合，相对本体原点；用 GridUtil.NormalizeFootprint 规整。
@export var footprint: Array[Vector2i] = [Vector2i.ZERO]
## 端口定义。生产鬼为空数组（产出走掉落，见 D3）。
@export var ports: Array[BoardPortDef] = []
## 造价，单位：鬼能。
@export_range(0, 100, 1) var cost: int = 5
## 自动行为周期，单位：秒。生产鬼 2.0，处理鬼 1.2。
@export_range(0.05, 20.0, 0.05) var cycle_time: float = 2.0
## 输出缓冲上限，单位：件。
@export_range(0, 20, 1) var buffer_capacity: int = 3
## 搜索区（相对格），采集鬼用；空数组表示全图。
@export var search_area: Array[Vector2i] = []
## 是否需要手动操作。本次四只基础鬼全部为 false。
@export var is_manual: bool = false
## 关联的配方资源 id，处理鬼用；其余鬼留空。
@export var recipe_id: String = ""
## 3D 占位体颜色；美术未就位时用于区分鬼种。
@export var color: Color = Color(0.55, 0.85, 0.95, 1.0)

## 按 id 取端口定义。
## @param port_id 端口 id。
## @return 找到的端口定义；未找到返回 null。
func GetPortDef(port_id: StringName) -> BoardPortDef:
	for port in ports:
		if port != null and port.id == port_id:
			return port
	return null

## 判断是否存在朝向指定方向的端口。
## @param dir 世界四邻方向之一。
## @return 存在时返回 true。
func HasPortInDirection(dir: Vector2i) -> bool:
	for port in ports:
		if port != null and port.direction == dir:
			return true
	return false

## 把占位形状平移到指定落点。
## @param origin 本体原点格坐标。
## @return 绝对格坐标数组。
func GetFootprintAt(origin: Vector2i) -> Array[Vector2i]:
	return GridUtil.Translate(footprint, origin)

## 取第一个输入端口。
## @return 输入端口定义；没有输入端口返回 null。
func GetInputPort() -> BoardPortDef:
	for port in ports:
		if port != null and port.is_input:
			return port
	return null

## 取第一个输出端口。
## @return 输出端口定义；没有输出端口返回 null。
func GetOutputPort() -> BoardPortDef:
	for port in ports:
		if port != null and not port.is_input:
			return port
	return null

## 返回端口配置的中文简述，用于鬼牌栏的悬停提示。
## @return 端口说明文字；无端口时说明产出走地面掉落。
func DescribePorts() -> String:
	if ports.is_empty():
		return "无连线端口，产出掉在四邻空格"
	var parts: Array[String] = []
	for port in ports:
		if port != null:
			parts.append(port.Describe())
	return "；".join(parts)

class_name GhostData
extends Resource

## 鬼的数据模板。描述一只鬼的静态属性：几何占位、端口标签、缓冲与速率。
## 数值型参数优先放到 ExportSettings；此资源只承载「这只鬼本身是什么」。
## 参见 Docs/Ghosts.md。

## 鬼数据目录，存放 %s.tres。
const DATA_DIRECTORY: String = "res://Data/Ghosts"

## 鬼 id，全局唯一，例如 LongTongue。
@export var id: String = ""
## 鬼显示名，例如 长舌鬼。
@export var display_name: String = ""
## 动词：采集 / 加工 / 分流 / 净化 / 复制 / 悬挂 / 位移 / 转化 / 交付。
@export var verb: String = ""
## 独特机制的一句话描述。
@export var mechanism: String = ""
## 造价，单位鬼能。
@export var cost: int = 0
## 本体占位，相对原点的格偏移。
@export var footprint: Array[Vector2i] = []
## 附属占位（舌头 / 吊绳），相对本体原点的格偏移。
@export var appendages: Array[Vector2i] = []
## 输入缓冲格数。
@export var input_buffer: int = 0
## 输出缓冲格数。
@export var output_buffer: int = 0
## 动作周期，单位秒。0 表示不自持。
@export var cd: float = 0.0
## 采集基率，采集鬼使用。
@export var base_rate: float = 0.0
## 垃圾率，采集鬼产出中变成垃圾的比例。
@export var garbage_rate: float = 0.0
## 加工产出率，0.0-1.0。
@export var yield_rate: float = 0.0
## 加工周期，单位秒。
@export var cycle_time: float = 0.0
## 是否手动鬼。手动鬼由玩家点一下开启，不参与推挤链。
@export var manual: bool = false
## ACTION 端口标签：我能作用于什么。
@export var action_tags: Array[StringName] = []
## RECEPTACLE 端口标签：我能被什么作用。
@export var receptacle_tags: Array[StringName] = []
## 鬼体主题色。
@export var body_color: Color = Color(0.6, 0.6, 0.7)
## 玩家是否可放置。供品口为关卡预置，此处为 false。
@export var spawnable: bool = true
## 是否采集区鬼。采集区鬼的占位由玩家框定，最小 2×2。
@export var is_area_ghost: bool = false

## 按 id 加载鬼数据。
## @param id 鬼 id，例如 LongTongue。
## @return 加载到的 GhostData；不存在或类型不符时返回 null 并输出警告。
static func Load(id: String) -> GhostData:
	var path := "%s/%s.tres" % [DATA_DIRECTORY, id]
	if not ResourceLoader.exists(path):
		push_warning("鬼数据不存在：%s" % path)
		return null
	var res := ResourceLoader.load(path)
	if res is GhostData:
		return res
	push_warning("鬼数据类型不符：%s" % path)
	return null

## 列出全部鬼数据的 id。
## 扫描 Data/Ghosts 下的 .tres，逐个加载并读取 id。
## @return 全部可加载鬼数据的 id 列表；无法加载的文件会被跳过。
static func ListIds() -> PackedStringArray:
	var ids := PackedStringArray()
	var dir := DirAccess.open(DATA_DIRECTORY)
	if dir == null:
		push_warning("鬼数据目录不存在：%s" % DATA_DIRECTORY)
		return ids
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res := ResourceLoader.load("%s/%s" % [DATA_DIRECTORY, file_name])
		if res is GhostData:
			ids.append((res as GhostData).id)
		else:
			push_warning("鬼数据类型不符，已跳过：%s" % file_name)
	return ids

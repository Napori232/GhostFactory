class_name LevelData
extends Resource

## 关卡数据资源。描述一关的固定配置：时长、目标、空间预算、可用的形态与鬼池。
## 地图细节（供品口位置、采集区形状、障碍）由关卡设计填入，本资源只承载数据。

## 关卡编号，从 1 开始。
@export var level_id: int = 1
## 关卡显示名，例如「第一关：输送线」。
@export var display_name: String = ""
## 所属章节号，对应策划案 §11.1 的难度递进。
@export var chapter: int = 1
## 关卡简介，显示在关卡选择卡片上。
@export var description: String = ""
## 关卡限时，单位秒。
@export var time_limit: int = 90
## 需要交付的供品数量，达成即算过关。
@export var goal_score: int = 20
## 可用空间格数，摆放鬼与线时受此约束。
@export var space_budget: int = 12
## 本关使用的形态词表 id 列表。
@export var forms_used: PackedStringArray = PackedStringArray()
## 本关使用的配方 id 列表。
@export var recipes_in_use: PackedStringArray = PackedStringArray()
## 本关允许放置的鬼池白名单，防止解锁的鬼带来超纲规则。
@export var available_ghosts: PackedStringArray = PackedStringArray()
## 供品口列表，元素结构 {accepts: String, position: Vector2, score: int}。
@export var terminals: Array = []
## 采集区列表，元素结构 {shape: Array, drops: String, interval: float, garbage_rate: float}。
@export var fields: Array = []
## 障碍物列表，元素结构 {shape: Array, kind: String}。
@export var obstacles: Array = []
## 关卡场景路径，为空表示该关卡尚未搭建（数据先行，场景后补）。
@export var level_scene: String = ""

## 取得本关的关卡数据文件路径。
## @param id 关卡编号，从 1 开始。
## @return res:// 下的 .tres 资源路径。
static func GetLevelPath(id: int) -> String:
	return "%s/%s" % [ExportSettings.levels_directory, ExportSettings.level_file_template % id]

## 按关卡编号加载关卡数据。
## @param id 关卡编号，从 1 开始。
## @return 加载到的 LevelData；加载失败或类型不符时返回 null。
static func LoadLevel(id: int) -> LevelData:
	var path := GetLevelPath(id)
	if not ResourceLoader.exists(path):
		push_warning("关卡数据不存在：%s" % path)
		return null
	var res := ResourceLoader.load(path)
	if res is LevelData:
		return res
	push_warning("关卡数据类型不符：%s" % path)
	return null

## 关卡场景路径模板。
## 关卡数据在 ExportSettings.levels_directory（默认 res://Data/Levels）下，关卡场景按约定放在
## Code/Entities/Level/Levels 目录下的同名文件。此处硬编码该约定路径，不修改 ExportSettings.gd。
const LEVEL_SCENE_TEMPLATE: String = "res://Code/Entities/Level/Levels/Level%02d.tscn"

## 加载关卡场景。
## @param id 关卡编号，从 1 开始，默认为第 1 关。
## @return 加载到的 PackedScene；未配置或加载失败时返回 null。
static func LoadLevelScene(id: int = 1) -> PackedScene:
	var path := LEVEL_SCENE_TEMPLATE % id
	if not ResourceLoader.exists(path):
		push_warning("关卡场景不存在：%s" % path)
		return null
	var res := ResourceLoader.load(path)
	if res is PackedScene:
		return res
	push_warning("关卡场景类型不符：%s" % path)
	return null

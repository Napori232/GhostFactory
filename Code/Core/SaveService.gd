class_name SaveService
extends RefCounted
## 存档：只存「元进度」（解锁、最佳波次、设置、统计），不存波次中途状态。
## 存档带版本号；旧档通过 Migrate 升级，新增字段一律给默认值，
## 保证老存档永远能读——这是「长期维护」的硬要求。

const CURRENT_VERSION := 1
const DEFAULT_PATH := "user://save.json"

var path: String = DEFAULT_PATH


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


## 默认（新档）内容。
static func DefaultMeta() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"unlocks": ["waver", "pusher", "crystal"],
		"best_wave": 0,
		"current_level": "01",
		"tutorial_done": false,
		"settings": {
			"volume": 0.8,
			"shake": true,
			"fx_quality": "high",
			"camera_speed": 1.0,
		},
		"stats": {
			"runs": 0,
			"cleared_waves": 0,
			"pulses": 0,
		},
	}


## 写盘。返回是否成功。
func SaveMeta(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = CURRENT_VERSION
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveService: 无法写入 " + path + "（" + str(FileAccess.get_open_error()) + "）")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


## 读盘。文件不存在或损坏时返回默认档，不抛错。
func LoadMeta() -> Dictionary:
	if not FileAccess.file_exists(path):
		return DefaultMeta()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return DefaultMeta()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveService: 存档损坏，已回退默认档 " + path)
		return DefaultMeta()
	return Migrate(parsed)


## 版本迁移。v0（无版本号）→ v1。
static func Migrate(data: Dictionary) -> Dictionary:
	var out := DefaultMeta()
	var version := int(data.get("version", 0))
	# 逐字段合并：老档有的用老档，没有的保留默认值。
	for key in data.keys():
		out[key] = data[key]
	for key in DefaultMeta().keys():
		if not out.has(key):
			out[key] = DefaultMeta()[key]
	if version < 1:
		# v0 没有 settings/stats 分段，合并默认值即可（上面已做）。
		pass
	out["version"] = CURRENT_VERSION
	return out

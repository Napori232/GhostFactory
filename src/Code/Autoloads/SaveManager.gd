extends Node

## 存档管理器。负责 user://savegame.cfg 的读写，以及进度与设置的内存状态。
## 音量总线的真实应用仍由 Util 负责，本类只保存设置项的持久化副本。

const SAVE_VERSION: int = 1
const DEFAULT_UNLOCKED_LEVEL: String = "1"
const SETTING_KEYS: Array[String] = [
	"skip_tutorial",
	"screen_shake",
	"quality",
	"master_volume",
	"music_volume",
	"sfx_volume",
	"dialogue_volume",
	"ambience_volume",
]

var _progress: Dictionary = {}
var _unlocked: Dictionary = {}
var _settings: Dictionary = {}
var _meta: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_to_defaults()
	if HasSave():
		LoadGame()
	else:
		SaveGame()

## 重置所有内存状态为默认值。
func _reset_to_defaults() -> void:
	_progress = {
		"unlocked_levels": PackedStringArray([DEFAULT_UNLOCKED_LEVEL]),
		"best_stars": {},
		"current_level": 1,
	}
	_unlocked = {
		"ghosts": PackedStringArray(),
	}
	_settings = {
		"skip_tutorial": false,
		"screen_shake": true,
		"quality": "medium",
		"master_volume": ExportSettings.audio_master_volume,
		"music_volume": ExportSettings.audio_music_volume,
		"sfx_volume": ExportSettings.audio_sfx_volume,
		"dialogue_volume": ExportSettings.audio_dialogue_volume,
		"ambience_volume": ExportSettings.audio_ambience_volume,
	}
	_meta = {
		"version": SAVE_VERSION,
		"play_time": 0.0,
		"clear_count": 0,
		"last_played": "",
	}

## 是否存在存档文件。
## @return 存档文件存在时返回 true。
func HasSave() -> bool:
	return FileAccess.file_exists(ExportSettings.save_game_path)

## 读取存档并应用到内存状态。
## @return 读取成功时返回 true；文件不存在或读取失败时返回 false。
func LoadGame() -> bool:
	var config := ConfigFile.new()
	if config.load(ExportSettings.save_game_path) != OK:
		push_warning("存档读取失败：%s" % ExportSettings.save_game_path)
		return false
	var version := int(config.get_value("meta", "version", 0))
	if version != SAVE_VERSION:
		push_warning("存档版本不匹配（%d，期望 %d），已降级为默认状态。" % [version, SAVE_VERSION])
		_reset_to_defaults()
		return false
	_progress = _read_section(config, "progress", _progress)
	_unlocked = _read_section(config, "unlocked", _unlocked)
	_settings = _read_section(config, "settings", _settings)
	_meta = _read_section(config, "meta", _meta)
	_meta["version"] = SAVE_VERSION
	SignalBus.ProgressChanged.emit()
	return true

## 将内存状态写入存档。
## @return 写入成功时返回 true。
func SaveGame() -> bool:
	var config := ConfigFile.new()
	for section in ["progress", "unlocked", "settings", "meta"]:
		var data: Dictionary = _get_section(section)
		for key in data:
			config.set_value(section, String(key), data[key])
	var error := config.save(ExportSettings.save_game_path)
	var success := error == OK
	if not success:
		push_warning("存档写入失败，错误码：%d" % error)
	SignalBus.SaveGameWritten.emit(success)
	return success

## 读取一个存档段，缺失的键回落到默认值。
## @param config 已加载的 ConfigFile
## @param section 段名
## @param defaults 默认值字典
## @return 合并后的字典。
func _read_section(config: ConfigFile, section: String, defaults: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	for key in config.get_section_keys(section):
		result[String(key)] = config.get_value(section, key, result.get(String(key)))
	return result

## 取得某个段的内存状态。
## @param section 段名
## @return 该段的数据字典。
func _get_section(section: String) -> Dictionary:
	match section:
		"progress":
			return _progress
		"unlocked":
			return _unlocked
		"settings":
			return _settings
		"meta":
			return _meta
		_:
			return {}

## 重置进度，保留设置项。
## @return 写入成功时返回 true。
func ResetProgress() -> bool:
	_progress = {
		"unlocked_levels": PackedStringArray([DEFAULT_UNLOCKED_LEVEL]),
		"best_stars": {},
		"current_level": 1,
	}
	_unlocked = {
		"ghosts": PackedStringArray(),
	}
	_meta["clear_count"] = 0
	var success := SaveGame()
	SignalBus.ProgressChanged.emit()
	return success

## 取得进度段的副本。
## @return 含 unlocked_levels、best_stars、current_level 的字典。
func GetProgress() -> Dictionary:
	return _progress.duplicate(true)

## 查询关卡是否已解锁。第 1 关默认解锁。
## @param level_id 关卡编号，从 1 开始
## @return 已解锁时返回 true。
func IsLevelUnlocked(level_id: int) -> bool:
	if level_id <= 1:
		return true
	var levels: PackedStringArray = _progress.get("unlocked_levels", PackedStringArray())
	return levels.has(str(level_id))

## 解锁关卡，幂等。
## @param level_id 关卡编号，从 1 开始
func UnlockLevel(level_id: int) -> void:
	var levels: PackedStringArray = _progress.get("unlocked_levels", PackedStringArray())
	var key := str(level_id)
	if levels.has(key):
		return
	levels.append(key)
	_progress["unlocked_levels"] = levels
	SaveGame()
	SignalBus.ProgressChanged.emit()

## 查询关卡历史最佳星级。
## @param level_id 关卡编号，从 1 开始
## @return 星级 0~3，未通过时返回 0。
func GetBestStars(level_id: int) -> int:
	var stars: Dictionary = _progress.get("best_stars", {})
	return int(stars.get(str(level_id), 0))

## 记录关卡最佳星级，只增不减。
## @param level_id 关卡编号，从 1 开始
## @param stars 本次星级，1~3
func SetBestStars(level_id: int, stars: int) -> void:
	var clamped := clampi(stars, 0, 3)
	var best := GetBestStars(level_id)
	if clamped <= best:
		return
	var star_map: Dictionary = _progress.get("best_stars", {})
	star_map[str(level_id)] = clamped
	_progress["best_stars"] = star_map
	SaveGame()
	SignalBus.ProgressChanged.emit()

## 记录当前所在关卡。
## @param level_id 关卡编号，从 1 开始
func SetCurrentLevel(level_id: int) -> void:
	_progress["current_level"] = level_id
	SaveGame()

## 解锁一只鬼，幂等。
## @param ghost_id 鬼的 id
func UnlockGhost(ghost_id: String) -> void:
	_unlock_id_list("ghosts", ghost_id)
	SignalBus.GhostUnlocked.emit(ghost_id)

## 向指定解锁表追加一个 id 并写盘。
## @param key 解锁表名：ghosts
## @param id 要追加的 id
func _unlock_id_list(key: String, id: String) -> void:
	var list: PackedStringArray = _unlocked.get(key, PackedStringArray())
	if list.has(id):
		return
	list.append(id)
	_unlocked[key] = list
	SaveGame()

## 读取设置项。
## @param key 设置项键名
## @param default_value 键不存在时的返回值
## @return 设置项的值。
func GetSetting(key: StringName, default_value: Variant = null) -> Variant:
	return _settings.get(String(key), default_value)

## 写入设置项并立即落盘。
## @param key 设置项键名
## @param value 设置项的新值
func SetSetting(key: StringName, value: Variant) -> void:
	var key_str := String(key)
	if _settings.get(key_str) == value:
		return
	_settings[key_str] = value
	SaveGame()
	SignalBus.SettingChanged.emit(key, value)

## 取得全部设置项键名。
## @return 设置项键名列表。
func GetSettingKeys() -> PackedStringArray:
	return PackedStringArray(SETTING_KEYS)

## 累加累计游玩时长。
## @param seconds 本次增加的秒数
func AddPlayTime(seconds: float) -> void:
	_meta["play_time"] = float(_meta.get("play_time", 0.0)) + seconds

## 取得累计游玩时长。
## @return 累计秒数。
func GetPlayTime() -> float:
	return float(_meta.get("play_time", 0.0))

## 增加通关次数。
func AddClearCount() -> void:
	_meta["clear_count"] = int(_meta.get("clear_count", 0)) + 1

## 导出完整存档数据。
## @return 含 progress、unlocked、settings、meta 四段的字典。
func ExportSaveData() -> Dictionary:
	return {
		"progress": _progress.duplicate(true),
		"unlocked": _unlocked.duplicate(true),
		"settings": _settings.duplicate(true),
		"meta": _meta.duplicate(true),
	}

## 从字典恢复内存状态，不写盘。
## @param data 由 ExportSaveData 得到的存档字典
func LoadSaveData(data: Dictionary) -> void:
	if data.has("progress"):
		_progress = (data["progress"] as Dictionary).duplicate(true)
	if data.has("unlocked"):
		_unlocked = (data["unlocked"] as Dictionary).duplicate(true)
	if data.has("settings"):
		_settings = (data["settings"] as Dictionary).duplicate(true)
	if data.has("meta"):
		_meta = (data["meta"] as Dictionary).duplicate(true)
	_meta["version"] = SAVE_VERSION
	SignalBus.ProgressChanged.emit()

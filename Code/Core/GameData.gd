class_name GameData
extends RefCounted
## 内容层入口：只做「从 res://Data 读 JSON 并缓存」，不做任何玩法逻辑。
## 新增一只鬼 / 一种机关 / 一条传送带 = 新增一个 JSON + 在 content.json 里登记。
## 数据文件路径固定，导出时请在导出预设的「非资源文件过滤器」里包含 *.json。

const ROOT := "res://Data/"

static var _cache: Dictionary = {}


## 读取并解析一个 JSON 文件；失败返回空字典并 push_error（不崩溃）。
static func LoadJson(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		push_error("GameData: 数据文件不存在 " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("GameData: 数据文件为空 " + path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameData: JSON 根节点必须是对象 " + path)
		return {}
	_cache[path] = parsed
	return parsed


## 全局调参。
static func Game() -> Dictionary:
	return LoadJson(ROOT + "game.json")


## 内容目录：建造栏顺序、关卡列表。见 Data/content.json。
static func Content() -> Dictionary:
	return LoadJson(ROOT + "content.json")


## 建造栏条目：[{"kind": "ghost", "id": "waver"}, ...]。
static func Catalog() -> Array:
	return Content().get("entries", [])


## 关卡 id 列表（按设计顺序）。
static func LevelIds() -> Array:
	return Content().get("levels", [])


## 鬼的定义。
static func Ghost(id: String) -> Dictionary:
	return LoadJson(ROOT + "ghosts/" + id + ".json")


## 鬼能机关的定义。
static func Mechanism(id: String) -> Dictionary:
	return LoadJson(ROOT + "mechanisms/" + id + ".json")


## 鬼晶的定义。
static func Crystal(id: String) -> Dictionary:
	return LoadJson(ROOT + "crystals/" + id + ".json")


## 自动化物流装置（搬运手 / 装卸臂）的定义。
static func Swapper(id: String) -> Dictionary:
	return LoadJson(ROOT + "swappers/" + id + ".json")


## 传送带的定义。
static func Belt(id: String) -> Dictionary:
	return LoadJson(ROOT + "belts/" + id + ".json")


## 全部夜规（modifier）定义。
static func Modifiers() -> Array:
	var d := LoadJson(ROOT + "modifiers.json")
	return d.get("modifiers", [])


## 按 id 取一条夜规；没有返回空字典。
static func Modifier(id: String) -> Dictionary:
	for m in Modifiers():
		if m is Dictionary and String(m.get("id", "")) == id:
			return m
	return {}


## 关卡定义。
static func Level(id: String) -> Dictionary:
	return LoadJson(ROOT + "levels/" + id + ".json")


## 按「建造类别」取定义字典。kind: ghost / mechanism / crystal / swapper / belt。
static func DefinitionFor(kind: String, id: String) -> Dictionary:
	match kind:
		"ghost":
			return Ghost(id)
		"mechanism":
			return Mechanism(id)
		"crystal":
			return Crystal(id)
		"swapper":
			return Swapper(id)
		"belt":
			return Belt(id)
	return {}


## 判断某类定义是否存在（不触发「文件不存在」的报错）。
static func HasDefinition(kind: String, id: String) -> bool:
	var sub := ""
	match kind:
		"ghost":
			sub = "ghosts/"
		"mechanism":
			sub = "mechanisms/"
		"crystal":
			sub = "crystals/"
		"swapper":
			sub = "swappers/"
		"belt":
			sub = "belts/"
		_:
			return false
	return FileAccess.file_exists(ROOT + sub + id + ".json")


## 判断某个 id 是否存在于任意一类内容里。
static func Exists(id: String) -> bool:
	for sub in ["ghosts/", "mechanisms/", "crystals/", "swappers/", "belts/"]:
		if FileAccess.file_exists(ROOT + sub + id + ".json"):
			return true
	return false


## 取任意内容的显示名（鬼 / 机关 / 鬼晶 / 搬运手 / 传送带）。找不到时返回 id 本身。
static func DisplayName(id: String) -> String:
	for sub in ["ghosts/", "mechanisms/", "crystals/", "swappers/", "belts/"]:
		var d := LoadJson(ROOT + sub + id + ".json")
		if not d.is_empty():
			return String(d.get("name", id))
	return id


## 某个定义属于哪一类建造（给 HUD / 测试用）。
static func KindOf(id: String) -> String:
	if FileAccess.file_exists(ROOT + "ghosts/" + id + ".json"):
		return "ghost"
	if FileAccess.file_exists(ROOT + "mechanisms/" + id + ".json"):
		return "mechanism"
	if FileAccess.file_exists(ROOT + "crystals/" + id + ".json"):
		return "crystal"
	if FileAccess.file_exists(ROOT + "swappers/" + id + ".json"):
		return "swapper"
	if FileAccess.file_exists(ROOT + "belts/" + id + ".json"):
		return "belt"
	return ""


## 校验内容数据是否自洽。测试与启动自检共用。
## 返回 {"ok": bool, "errors": Array[String]}。
static func Validate() -> Dictionary:
	var errors: Array = []
	var game := Game()
	if game.is_empty():
		errors.append("game.json 缺失或无法解析")
	for key in ["tick_rate", "damage_line", "clear_line", "dps_scale"]:
		if not game.has(key):
			errors.append("game.json 缺少字段: " + key)

	var content := Content()
	if content.is_empty():
		errors.append("content.json 缺失或无法解析")
	var catalog: Array = content.get("entries", [])
	if catalog.is_empty():
		errors.append("content.json 没有 entries（建造栏会是空的）")
	for entry in catalog:
		if not (entry is Dictionary):
			errors.append("content.json 里有非对象条目")
			continue
		var kind := String(entry.get("kind", ""))
		var cid := String(entry.get("id", ""))
		if kind.is_empty() or cid.is_empty():
			errors.append("content.json 条目缺少 kind / id")
			continue
		if not HasDefinition(kind, cid):
			errors.append("content.json 指向不存在的定义: %s/%s" % [kind, cid])
		var d := DefinitionFor(kind, cid)
		if not d.is_empty():
			for key in ["name", "cost"]:
				if not d.has(key):
					errors.append("%s/%s 缺少字段: %s" % [kind, cid, key])

	# 反向检查：每个定义文件都必须登记进 content.json，否则建造栏里看不到它
	var registered: Dictionary = {}
	for entry in catalog:
		if entry is Dictionary:
			registered[String(entry.get("kind", "")) + "/" + String(entry.get("id", ""))] = true
	for folder in ["ghosts", "mechanisms", "belts", "swappers", "crystals"]:
		var dir := DirAccess.open(ROOT + folder)
		if dir == null:
			continue
		var kind_name: String = String(folder).trim_suffix("s")
		for file in dir.get_files():
			if not file.ends_with(".json"):
				continue
			var file_id := file.get_basename()
			var def := DefinitionFor(kind_name, file_id)
			if String(def.get("id", "")) != file_id:
				errors.append("%s/%s 的 id 与文件名不一致" % [folder, file_id])
			if not registered.has(kind_name + "/" + file_id):
				errors.append("%s/%s 没有登记进 content.json" % [folder, file_id])

	for level_id in LevelIds():
		_validate_level(String(level_id), errors)

	var mods := Modifiers()
	if mods.is_empty():
		errors.append("modifiers.json 缺失或没有夜规")
	for m in mods:
		if not (m is Dictionary):
			errors.append("modifiers.json 里有非对象条目")
			continue
		var mid := String(m.get("id", ""))
		if mid.is_empty():
			errors.append("夜规缺少 id")
		if String(m.get("name", "")).is_empty():
			errors.append("夜规 %s 缺少 name" % mid)
		for key in ["budget_mult", "prep_mult"]:
			if m.has(key) and float(m[key]) <= 0.0:
				errors.append("夜规 %s 的 %s 必须大于 0" % [mid, key])
		for disabled in m.get("disable", []):
			if not Exists(String(disabled)):
				errors.append("夜规 %s 禁用了不存在的定义: %s" % [mid, String(disabled)])
	return {"ok": errors.is_empty(), "errors": errors}


static func _validate_level(level_id: String, errors: Array) -> void:
	var path := "levels/" + level_id + ".json"
	var level := Level(level_id)
	if level.is_empty():
		errors.append(path + " 缺失或无法解析")
		return
	for key in ["grid", "buildable", "waves", "initial", "initial_crystals"]:
		if not level.has(key):
			errors.append(path + " 缺少字段: " + key)

	var grid: Dictionary = level.get("grid", {})
	var build: Dictionary = level.get("buildable", {})
	if not build.is_empty() and not grid.is_empty():
		var gw := int(grid.get("w", 0))
		var gh := int(grid.get("h", 0))
		var bx := int(build.get("x", 0))
		var by := int(build.get("y", 0))
		var bw := int(build.get("w", 0))
		var bh := int(build.get("h", 0))
		if bx < 0 or by < 0 or bw <= 0 or bh <= 0 or bx + bw > gw or by + bh > gh:
			errors.append(path + " 的 buildable 超出 grid")

	var waves: Array = level.get("waves", [])
	if waves.is_empty():
		errors.append(path + " 没有任何波次")
	for i in waves.size():
		var groups: Array = waves[i].get("groups", [])
		if groups.is_empty():
			errors.append(path + " 波次 %d 没有 groups" % i)
		for j in groups.size():
			var grp: Dictionary = groups[j]
			for key in ["count", "interval", "hp", "speed"]:
				if not grp.has(key):
					errors.append(path + " 波次 %d 组 %d 缺少 %s" % [i, j, key])

	var def_cache: Dictionary = {}
	for entry in level.get("initial", []):
		var kind := String(entry.get("kind", ""))
		var type_id := String(entry.get("type", ""))
		var key := kind + ":" + type_id
		if not def_cache.has(key):
			def_cache[key] = DefinitionFor(kind, type_id)
		if def_cache[key].is_empty():
			errors.append(path + " 初始建筑引用了不存在的定义: " + key)
	for unlock in level.get("unlocks", []):
		var uid := String(unlock)
		if not Exists(uid):
			errors.append(path + " 的 unlocks 引用了不存在的定义: " + uid)
	for reward in level.get("rewards", []):
		if reward is Dictionary and reward.has("unlock"):
			var rid := String(reward["unlock"])
			if not Exists(rid):
				errors.append(path + " 奖励引用了不存在的定义: " + rid)

	var next_id := String(level.get("next_level", ""))
	if not next_id.is_empty() and not FileAccess.file_exists(ROOT + "levels/" + next_id + ".json"):
		errors.append(path + " 的 next_level 指向不存在的关卡: " + next_id)


## 清空缓存。热重载与测试之间隔离用。
static func ClearCache() -> void:
	_cache.clear()

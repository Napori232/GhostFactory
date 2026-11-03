extends Node

## 鬼数据层的 headless 测试：校验 10 只鬼、3 个形态、1 个配方资源可加载且字段正确。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/GhostDataTest.tscn

const GHOST_DIR: String = "res://Data/Ghosts"
const FORM_DIR: String = "res://Data/Forms"
const RECIPE_DIR: String = "res://Data/Recipes"

var _failures: int = 0
var _checks: int = 0

func _ready() -> void:
	_run_all()
	print("---- 结果：%d 项断言，%d 项失败" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## 依次执行全部测试组。
func _run_all() -> void:
	_test_ghost_resources()
	_test_form_resources()
	_test_recipe_resources()
	_test_static_helpers()
	_test_tag_helpers()

## 校验 10 只鬼的数据资源。
func _test_ghost_resources() -> void:
	var expected := {
		"LongTongue": {
			"name": "长舌鬼", "cost": 6, "fp": 1, "ap": 1, "cd": 2.0,
			"in": 0, "out": 2, "base": 0.0, "garbage": 0.0, "manual": false,
			"act": [&"GRAB"], "rec": [&"SWALLOW"], "spawnable": true, "area": false,
		},
		"Hanged": {
			"name": "吊死鬼", "cost": 5, "fp": 1, "ap": 1, "cd": 0.0,
			"in": 0, "out": 0, "base": 0.0, "garbage": 0.0, "manual": true,
			"act": [&"HANG"], "rec": [&"GRAB"], "spawnable": true, "area": false,
		},
		"Tumbler": {
			"name": "不倒翁鬼", "cost": 4, "fp": 1, "ap": 0, "cd": 0.0,
			"in": 0, "out": 0, "base": 0.0, "garbage": 0.0, "manual": false,
			"act": [], "rec": [], "spawnable": true, "area": false,
		},
		"Stove": {
			"name": "灶鬼", "cost": 8, "fp": 2, "ap": 0, "cd": 0.0,
			"in": 3, "out": 3, "base": 0.0, "garbage": 0.0, "manual": false,
			"act": [&"FEED"], "rec": [&"SWALLOW"], "spawnable": true, "area": false,
		},
		"Fork": {
			"name": "岔口鬼", "cost": 10, "fp": 4, "ap": 0, "cd": 0.0,
			"in": 3, "out": 3, "base": 0.0, "garbage": 0.0, "manual": false,
			"act": [&"SPLIT"], "rec": [&"SWALLOW"], "spawnable": true, "area": false,
		},
		"Glutton": {
			"name": "贪食鬼", "cost": 12, "fp": 1, "ap": 0, "cd": 0.0,
			"in": 0, "out": 3, "base": 0.6, "garbage": 0.4, "manual": false,
			"act": [&"SPIT"], "rec": [], "spawnable": true, "area": true,
		},
		"FineChew": {
			"name": "细嚼鬼", "cost": 8, "fp": 1, "ap": 0, "cd": 0.0,
			"in": 0, "out": 3, "base": 0.25, "garbage": 0.0, "manual": false,
			"act": [&"SPIT"], "rec": [], "spawnable": true, "area": true,
		},
		"Contain": {
			"name": "收容鬼", "cost": 5, "fp": 4, "ap": 0, "cd": 0.0,
			"in": 0, "out": 0, "base": 0.0, "garbage": 0.0, "manual": false,
			"act": [], "rec": [], "spawnable": true, "area": false,
		},
		"Mirror": {
			"name": "镜鬼", "cost": 14, "fp": 1, "ap": 0, "cd": 0.0,
			"in": 0, "out": 0, "base": 0.0, "garbage": 0.0, "manual": false,
			"act": [&"MIRROR"], "rec": [], "spawnable": true, "area": false,
		},
		"Terminal": {
			"name": "供品口", "cost": 0, "fp": 2, "ap": 0, "cd": 0.0,
			"in": 0, "out": 6, "base": 0.0, "garbage": 0.0, "manual": false,
			"act": [], "rec": [&"OFFER"], "spawnable": false, "area": false,
		},
	}
	_check(expected.size() == 10, "期望表包含 10 只鬼")
	for ghost_id: String in expected:
		var data := GhostData.Load(ghost_id)
		if data == null:
			_check(false, "%s 加载失败" % ghost_id)
			continue
		var exp: Dictionary = expected[ghost_id]
		_check(data.id == ghost_id, "%s 的 id 正确" % ghost_id)
		_check(data.display_name == exp["name"], "%s 的 display_name 正确" % ghost_id)
		_check(data.cost == exp["cost"], "%s 的 cost 正确" % ghost_id)
		_check(data.footprint.size() == exp["fp"], "%s 的 footprint 长度正确" % ghost_id)
		_check(data.appendages.size() == exp["ap"], "%s 的 appendages 长度正确" % ghost_id)
		_check(is_equal_approx(data.cd, exp["cd"]), "%s 的 cd 正确" % ghost_id)
		_check(data.input_buffer == exp["in"], "%s 的 input_buffer 正确" % ghost_id)
		_check(data.output_buffer == exp["out"], "%s 的 output_buffer 正确" % ghost_id)
		_check(is_equal_approx(data.base_rate, exp["base"]), "%s 的 base_rate 正确" % ghost_id)
		_check(is_equal_approx(data.garbage_rate, exp["garbage"]), "%s 的 garbage_rate 正确" % ghost_id)
		_check(data.manual == exp["manual"], "%s 的 manual 正确" % ghost_id)
		_check(_tags_equal(data.action_tags, exp["act"]), "%s 的 action_tags 正确" % ghost_id)
		_check(_tags_equal(data.receptacle_tags, exp["rec"]), "%s 的 receptacle_tags 正确" % ghost_id)
		_check(data.spawnable == exp["spawnable"], "%s 的 spawnable 正确" % ghost_id)
		_check(data.is_area_ghost == exp["area"], "%s 的 is_area_ghost 正确" % ghost_id)

	# 占位形状的具体格偏移断言
	var long_tongue := GhostData.Load("LongTongue")
	_check(long_tongue != null and long_tongue.footprint[0] == Vector2i(0, 0), "LongTongue 本体占位为 (0,0)")
	_check(long_tongue != null and long_tongue.appendages[0] == Vector2i(1, 0), "LongTongue 舌头附属占位为 (1,0)")
	var hung := GhostData.Load("Hanged")
	_check(hung != null and hung.appendages[0] == Vector2i(0, -1), "Hanged 吊绳附属占位为 (0,-1)")
	var fork := GhostData.Load("Fork")
	_check(fork != null and fork.footprint.size() == 4 and fork.footprint[3] == Vector2i(1, 1), "Fork 占位为 2x2 四格")
	var stove := GhostData.Load("Stove")
	_check(stove != null and is_equal_approx(stove.yield_rate, 0.8), "Stove 的 yield_rate 为 0.8")
	_check(stove != null and is_equal_approx(stove.cycle_time, 1.2), "Stove 的 cycle_time 为 1.2")

	# 任务书点名的专项断言
	_check(long_tongue != null and long_tongue.appendages.size() == 1, "LongTongue 的 appendages 长度为 1")
	var terminal := GhostData.Load("Terminal")
	_check(terminal != null and terminal.spawnable == false, "Terminal 的 spawnable 为 false")
	var glutton := GhostData.Load("Glutton")
	_check(glutton != null and glutton.is_area_ghost == true, "Glutton 的 is_area_ghost 为 true")
	_check(GhostData.Load("Terminal") != null and GhostData.Load("Terminal").cost == 0, "Terminal 的 cost 为 0")

## 校验 3 个形态资源。
func _test_form_resources() -> void:
	var expected := {
		"Raw": {"name": "生料", "letter": "R", "color": Color(0.75, 0.8, 0.85)},
		"Processed": {"name": "加工品", "letter": "P", "color": Color(0.95, 0.65, 0.3)},
		"Garbage": {"name": "垃圾", "letter": "G", "color": Color(0.35, 0.35, 0.38)},
	}
	for form_id: String in expected:
		var path := "%s/%s.tres" % [FORM_DIR, form_id]
		var res := ResourceLoader.load(path)
		if res == null:
			_check(false, "%s 加载失败" % form_id)
			continue
		_check(res is FormData, "%s 是 FormData" % form_id)
		var form := res as FormData
		var exp: Dictionary = expected[form_id]
		_check(form.id == form_id, "%s 的 id 正确" % form_id)
		_check(form.display_name == exp["name"], "%s 的 display_name 正确" % form_id)
		_check(form.letter == exp["letter"], "%s 的 letter 正确" % form_id)
		_check(form.color.is_equal_approx(exp["color"]), "%s 的 color 正确" % form_id)

## 校验 1 个配方资源。
func _test_recipe_resources() -> void:
	var res := ResourceLoader.load("%s/RawToProcessed.tres" % RECIPE_DIR)
	_check(res != null, "RawToProcessed 加载成功")
	if res == null:
		return
	_check(res is RecipeData, "RawToProcessed 是 RecipeData")
	var recipe := res as RecipeData
	_check(recipe.id == "RawToProcessed", "RawToProcessed 的 id 正确")
	_check(recipe.from_form == "Raw", "RawToProcessed 的 from_form 为 Raw")
	_check(recipe.to_form == "Processed", "RawToProcessed 的 to_form 为 Processed")
	_check(is_equal_approx(recipe.yield_rate, 0.8), "RawToProcessed 的 yield_rate 为 0.8")
	_check(is_equal_approx(recipe.cycle_time, 1.2), "RawToProcessed 的 cycle_time 为 1.2")

## 校验 GhostData 的静态工具方法。
func _test_static_helpers() -> void:
	_check(GhostData.Load("LongTongue") != null, "GhostData.Load 能加载 LongTongue")
	_check(GhostData.Load("NotExistGhost") == null, "GhostData.Load 对不存在的 id 返回 null")
	var ids := GhostData.ListIds()
	_check(ids.size() == 10, "GhostData.ListIds 返回 10 个 id，实际 %d" % ids.size())
	_check(ids.has("LongTongue"), "ListIds 包含 LongTongue")
	_check(ids.has("Terminal"), "ListIds 包含 Terminal")

## 校验标签词表工具。
func _test_tag_helpers() -> void:
	_check(GhostTag.ALL.size() == 9, "GhostTag.ALL 含 9 个标签，实际 %d" % GhostTag.ALL.size())
	_check(GhostTag.IsValid(GhostTag.GRAB), "GhostTag.IsValid 接受 GRAB")
	_check(not GhostTag.IsValid(&"NOT_A_TAG"), "GhostTag.IsValid 拒绝未知标签")
	_check(GhostTag.Describe(GhostTag.SWALLOW) == "吞噬", "GhostTag.Describe(SWALLOW) 为 吞噬")
	_check(GhostTag.Describe(GhostTag.OFFER) == "交付", "GhostTag.Describe(OFFER) 为 交付")

## 比较两个 StringName 数组是否元素与顺序一致。
## @param a 实际标签数组。
## @param b 期望标签数组。
## @return 一致时返回 true。
func _tags_equal(a: Array[StringName], b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

## 执行一条断言。
## @param condition 断言条件。
## @param label 失败时的说明文字。
func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		_failures += 1
		printerr("FAIL: %s" % label)

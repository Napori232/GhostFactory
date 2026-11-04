extends Node

## 存档与关卡数据的 headless 往返测试。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/SaveManagerRoundTrip.tscn

const ORIGINAL_SAVE_PATH: String = "user://savegame.cfg"

var _failures: int = 0
var _checks: int = 0

func _ready() -> void:
	_run_all()
	print("---- 结果：%d 项断言，%d 项失败" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## 依次执行全部测试组。
func _run_all() -> void:
	_test_save_round_trip()
	_test_reset_progress()
	_test_best_stars_monotonic()
	_test_form_resources()
	_test_recipe_resources()

## 测试存档写入后能读回一致。
func _test_save_round_trip() -> void:
	var tmp_path := "user://test_save_round_trip.cfg"
	ExportSettings.save_game_path = tmp_path
	SaveManager.ResetProgress()
	SaveManager.UnlockLevel(2)
	SaveManager.SetBestStars(1, 2)
	SaveManager.SetSetting(&"quality", "high")
	SaveManager.SetSetting(&"screen_shake", false)

	SaveManager._reset_to_defaults()
	SaveManager.LoadGame()

	_check(SaveManager.IsLevelUnlocked(1), "第 1 关默认解锁")
	_check(SaveManager.IsLevelUnlocked(2), "第 2 关解锁状态保留")
	_check(not SaveManager.IsLevelUnlocked(3), "第 3 关保持锁定")
	_check(SaveManager.GetBestStars(1) == 2, "最佳星级读回为 2，实际 %d" % SaveManager.GetBestStars(1))
	_check(SaveManager.GetSetting(&"quality") == "high", "设置 quality 读回为 high")
	_check(SaveManager.GetSetting(&"screen_shake") == false, "设置 screen_shake 读回为 false")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
	ExportSettings.save_game_path = ORIGINAL_SAVE_PATH

## 测试重置进度保留设置项。
func _test_reset_progress() -> void:
	var tmp_path := "user://test_save_reset.cfg"
	ExportSettings.save_game_path = tmp_path
	SaveManager.ResetProgress()
	SaveManager.UnlockLevel(3)
	SaveManager.SetBestStars(2, 3)
	SaveManager.SetSetting(&"skip_tutorial", true)

	SaveManager.ResetProgress()
	_check(not SaveManager.IsLevelUnlocked(3), "重置后第 3 关回到锁定")
	_check(SaveManager.GetBestStars(2) == 0, "重置后星级清零，实际 %d" % SaveManager.GetBestStars(2))
	_check(SaveManager.GetSetting(&"skip_tutorial") == true, "重置进度保留设置项")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
	ExportSettings.save_game_path = ORIGINAL_SAVE_PATH

## 测试最佳星级只增不减。
func _test_best_stars_monotonic() -> void:
	var tmp_path := "user://test_save_stars.cfg"
	ExportSettings.save_game_path = tmp_path
	SaveManager.ResetProgress()
	SaveManager.SetBestStars(1, 2)
	SaveManager.SetBestStars(1, 1)
	_check(SaveManager.GetBestStars(1) == 2, "更低星级不覆盖，实际 %d" % SaveManager.GetBestStars(1))
	SaveManager.SetBestStars(1, 3)
	_check(SaveManager.GetBestStars(1) == 3, "更高星级覆盖，实际 %d" % SaveManager.GetBestStars(1))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
	ExportSettings.save_game_path = ORIGINAL_SAVE_PATH

## 测试三个形态资源可加载且字段正确。
func _test_form_resources() -> void:
	var expected := {
		"Spirit": {"name": "鬼能", "deliverable": false},
		"Offer": {"name": "贡品", "deliverable": true},
		"Impurity": {"name": "杂质", "deliverable": false},
	}
	for form_id: String in expected:
		var path := "res://Data/Forms/%s.tres" % form_id
		var data := ResourceLoader.load(path) as FormData
		if data == null:
			_check(false, "%s.tres 加载失败" % form_id)
			continue
		var exp: Dictionary = expected[form_id]
		_check(data.id == form_id, "%s id 正确" % form_id)
		_check(data.display_name == exp["name"], "%s display_name 正确" % form_id)
		_check(data.deliverable == exp["deliverable"], "%s deliverable 正确" % form_id)

## 测试两条配方可加载且字段正确。
func _test_recipe_resources() -> void:
	var expected := {
		"SpiritToOffer": {"from": "Spirit", "to": "Offer", "yield": 0.75, "cycle": 1.2},
		"ImpurityToSpirit": {"from": "Impurity", "to": "Spirit", "yield": 1.0, "cycle": 1.6},
	}
	for recipe_id: String in expected:
		var path := "res://Data/Recipes/%s.tres" % recipe_id
		var data := ResourceLoader.load(path) as RecipeData
		if data == null:
			_check(false, "%s.tres 加载失败" % recipe_id)
			continue
		var exp: Dictionary = expected[recipe_id]
		_check(data.id == recipe_id, "%s id 正确" % recipe_id)
		_check(data.from_form == exp["from"], "%s from_form 正确" % recipe_id)
		_check(data.to_form == exp["to"], "%s to_form 正确" % recipe_id)
		_check(is_equal_approx(data.yield_rate, exp["yield"]), "%s yield_rate 正确" % recipe_id)
		_check(is_equal_approx(data.cycle_time, exp["cycle"]), "%s cycle_time 正确" % recipe_id)

## 执行一条断言。
## @param condition 断言条件
## @param label 失败时的说明文字
func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		_failures += 1
		printerr("FAIL: %s" % label)

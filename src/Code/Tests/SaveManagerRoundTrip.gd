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
	_test_level_resources()

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

## 测试三个关卡资源可加载且字段正确。
func _test_level_resources() -> void:
	var expected := {
		1: {"name": "第一关：输送线", "time": 80, "goal": 20, "space": 12},
		2: {"name": "第二关：加工与损耗", "time": 100, "goal": 28, "space": 18},
		3: {"name": "第三关：产能与分流", "time": 90, "goal": 30, "space": 24},
	}
	for level_id: int in expected:
		var data := LevelData.LoadLevel(level_id)
		if data == null:
			_check(false, "Level%02d.tres 加载失败" % level_id)
			continue
		var exp: Dictionary = expected[level_id]
		_check(data.display_name == exp["name"], "Level%02d display_name 正确" % level_id)
		_check(data.time_limit == exp["time"], "Level%02d time_limit 正确" % level_id)
		_check(data.goal_score == exp["goal"], "Level%02d goal_score 正确" % level_id)
		_check(data.space_budget == exp["space"], "Level%02d space_budget 正确" % level_id)
		_check(data.level_id == level_id, "Level%02d level_id 正确" % level_id)
	_check(LevelData.LoadLevel(99) == null, "不存在的关卡返回 null")

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

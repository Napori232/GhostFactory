extends Control

## 结算面板。展示三轴评分、星级、解锁内容，并提供下一关 / 重玩 / 返回主菜单入口。
## 当前三轴分数为占位常量，玩法实装后由真实评分替换。

@onready var _title: Label = %Title
@onready var _efficiency_value: Label = %EfficiencyValue
@onready var _manual_value: Label = %ManualValue
@onready var _space_value: Label = %SpaceValue
@onready var _stars_label: Label = %StarsLabel
@onready var _unlock_label: Label = %UnlockLabel
@onready var _save_hint: Label = %SaveHint
@onready var _next_button: Button = %NextButton
@onready var _retry_button: Button = %RetryButton
@onready var _menu_button: Button = %MenuButton

var _level_id: int = 1

func _ready() -> void:
	_next_button.pressed.connect(_on_next_pressed)
	_retry_button.pressed.connect(_on_retry_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)

## 展示结算结果。
## @param level_id 本次结算的关卡编号，从 1 开始
## @param stars 本次获得的星级，1~3
func ShowResult(level_id: int, stars: int) -> void:
	_level_id = level_id
	_title.text = "第 %d 关完成" % level_id
	_efficiency_value.text = str(ExportSettings.placeholder_score_efficiency)
	_manual_value.text = str(ExportSettings.placeholder_score_manual)
	_space_value.text = str(ExportSettings.placeholder_score_space)
	_stars_label.text = StarRating.ToText(stars)
	_apply_progress(level_id, stars)
	_update_unlock_text()
	_next_button.disabled = level_id >= ExportSettings.level_count
	visible = true

## 写入进度：记录最佳星级，解锁下一关。
## @param level_id 本次结算的关卡编号
## @param stars 本次获得的星级
func _apply_progress(level_id: int, stars: int) -> void:
	var success := true
	if stars > 0:
		SaveManager.SetBestStars(level_id, stars)
		SaveManager.AddClearCount()
		SaveManager.SetCurrentLevel(mini(level_id + 1, ExportSettings.level_count))
		if level_id < ExportSettings.level_count:
			SaveManager.UnlockLevel(level_id + 1)
	else:
		success = false
	if not success:
		_save_hint.text = "结算未写入存档。"
		return
	_save_hint.text = "进度已保存。"

## 刷新解锁内容显示。
func _update_unlock_text() -> void:
	var unlocked: PackedStringArray = SaveManager.GetProgress().get("unlocked_levels", PackedStringArray())
	var highest := 1
	for entry in unlocked:
		highest = maxi(highest, int(entry))
	if highest <= 1:
		_unlock_label.text = "解锁了：—"
	else:
		_unlock_label.text = "解锁了：第 %d 关" % highest

## 前往下一关。
func _on_next_pressed() -> void:
	if _level_id < ExportSettings.level_count:
		SceneRouter.GotoLevel(_level_id + 1)

## 重玩本关。
func _on_retry_pressed() -> void:
	SceneRouter.GotoLevel(_level_id)

## 返回主菜单。
func _on_menu_pressed() -> void:
	SceneRouter.GotoMenu()

extends Control

## 关卡选择界面。列出全部关卡卡片，展示解锁状态、关卡参数与历史星级。

const LOCKED_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.45)
const STAR_FILLED: String = "★"
const STAR_EMPTY: String = "☆"
const MAX_STARS: int = 3

@onready var _cards_container: HBoxContainer = %Cards
@onready var _progress_label: Label = %ProgressLabel
@onready var _back_button: Button = %BackButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_back_button.pressed.connect(_on_back_button_pressed)
	SignalBus.ProgressChanged.connect(_on_progress_changed)
	Refresh()

## 刷新关卡卡片与顶部进度统计。
func Refresh() -> void:
	_clear_cards()
	var total := ExportSettings.level_count
	for level_id in range(1, total + 1):
		_cards_container.add_child(_build_card(level_id))
	_progress_label.text = "已通关 %d / %d" % [_count_cleared_levels(), total]

## 统计已获得至少一星的关卡数量。
## @return 通关关卡数。
func _count_cleared_levels() -> int:
	var cleared := 0
	for level_id in range(1, ExportSettings.level_count + 1):
		if SaveManager.GetBestStars(level_id) >= 1:
			cleared += 1
	return cleared

## 生成一张关卡卡片。
## @param level_id 关卡编号，从 1 开始
## @return 构建完成的 PanelContainer。
func _build_card(level_id: int) -> PanelContainer:
	var data: LevelData = LevelData.LoadLevel(level_id)
	var unlocked := SaveManager.IsLevelUnlocked(level_id)
	var stars := SaveManager.GetBestStars(level_id)

	var panel := PanelContainer.new()
	panel.name = "LevelCard%d" % level_id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_card_style(unlocked))
	if not unlocked:
		panel.modulate = LOCKED_MODULATE

	var box := VBoxContainer.new()
	box.name = "Body"
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	box.add_child(_make_label("关卡 %d" % level_id, 20))
	if data == null:
		box.add_child(_make_label("数据缺失", 18))
		box.add_child(_make_label("关卡配置加载失败，无法开始。", 14))
	else:
		box.add_child(_make_label(data.display_name, 20))
		box.add_child(_make_label(data.description, 14))
		box.add_child(_make_label("时长 %d 秒" % data.time_limit, 14))
		box.add_child(_make_label("目标交付 %d" % data.goal_score, 14))
		box.add_child(_make_label("空间预算 %d 格" % data.space_budget, 14))
		box.add_child(_make_label(_format_stars(stars), 18))
		box.add_child(_make_label("已解锁" if unlocked else "未解锁", 14))

	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "开始关卡" if unlocked else "未解锁"
	button.disabled = not unlocked or data == null
	button.pressed.connect(_on_card_pressed.bind(level_id))
	box.add_child(button)
	return panel

## 生成一个卡片用的 Label。
## @param text 显示文本
## @param font_size 字号
## @return 配置好的 Label。
func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

## 生成卡片外观样式。
## @param unlocked 关卡是否已解锁
## @return StyleBoxFlat 样式。
func _make_card_style(unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.18, 1.0) if unlocked else Color(0.09, 0.09, 0.12, 1.0)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16.0)
	style.set_border_width_all(2)
	style.border_color = Color(0.35, 0.60, 0.85, 0.85) if unlocked else Color(0.30, 0.30, 0.35, 0.60)
	return style

## 把星级转换为文本。
## @param stars 星级 0~3
## @return 形如 ★★☆ 的文本。
func _format_stars(stars: int) -> String:
	var text := ""
	for i in range(MAX_STARS):
		text += STAR_FILLED if i < stars else STAR_EMPTY
	return text

## 清空卡片容器中的旧卡片。
func _clear_cards() -> void:
	for child in _cards_container.get_children():
		_cards_container.remove_child(child)
		child.queue_free()

## 处理卡片按钮点击。
## @param level_id 关卡编号，从 1 开始
func _on_card_pressed(level_id: int) -> void:
	if not SaveManager.IsLevelUnlocked(level_id):
		return
	SceneRouter.GotoLevel(level_id)

## 处理返回按钮点击。
func _on_back_button_pressed() -> void:
	SceneRouter.GotoMenu()

## 处理进度变化通知。
func _on_progress_changed() -> void:
	Refresh()

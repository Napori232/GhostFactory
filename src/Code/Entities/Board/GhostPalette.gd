extends Control

## 鬼牌栏。列出本关可用的鬼，显示名称与造价，供玩家拖到棋盘上放置。

## 本关可用的鬼 id 列表。为空时由 SetAvailableGhosts 填充。
@export var available_ghosts: PackedStringArray = PackedStringArray()
## 是否显示造价。
@export var show_cost: bool = true
## 每张牌的最小宽度。
@export var card_width: float = 92.0

var _cards: Array = []
var _card_row: HBoxContainer = null
var _spirit: int = 0

func _ready() -> void:
	_card_row = get_node_or_null("%CardRow")
	if _card_row == null:
		_card_row = HBoxContainer.new()
		_card_row.name = "CardRow"
		add_child(_card_row)
		_card_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rebuild()

## 设置本关可用鬼并重建牌面。
## @param ids 鬼 id 列表
func SetAvailableGhosts(ids: PackedStringArray) -> void:
	available_ghosts = ids.duplicate()
	_rebuild()

## 取得本关可用鬼列表。
## @return 鬼 id 列表。
func GetAvailableGhosts() -> PackedStringArray:
	return available_ghosts.duplicate()

## 取得指定序号的鬼牌。
## @param index 序号
## @return 鬼牌节点；越界返回 null。
func GetCardAt(index: int) -> Control:
	if index < 0 or index >= _cards.size():
		return null
	return _cards[index]

## 取得指定鬼 id 对应的鬼牌。
## @param ghost_id 鬼 id
## @return 鬼牌节点；没有返回 null。
func GetCardForGhost(ghost_id: String) -> Control:
	for card in _cards:
		if card.get_meta("ghost_id", "") == ghost_id:
			return card
	return null

## 设置当前鬼能，买不起的牌调暗。
## @param spirit 当前鬼能
func SetSpirit(spirit: int) -> void:
	_spirit = spirit
	_refresh_affordability()

## 取得当前鬼能。
## @return 鬼能数量。
func GetSpirit() -> int:
	return _spirit

## 重建牌面。
func _rebuild() -> void:
	if _card_row == null:
		return
	for child in _card_row.get_children():
		child.queue_free()
	_cards.clear()
	for ghost_id in available_ghosts:
		var card := _build_card(ghost_id)
		_card_row.add_child(card)
		_cards.append(card)
	_refresh_affordability()
	_play_card_motion()

## 给每张鬼牌挂上持续呼吸与悬停反馈，相位按序号错开，让牌面不至于死板。
func _play_card_motion() -> void:
	for i in _cards.size():
		var card := _cards[i] as Control
		if card == null or not is_instance_valid(card):
			continue
		card.pivot_offset = card.size * 0.5
		card.resized.connect(func() -> void:
			if is_instance_valid(card):
				card.pivot_offset = card.size * 0.5
		)
		# 呼吸幅度按序号递减，避免所有牌同步抖动显得杂乱。
		var scale_factor := 1.0 - float(i) * 0.12
		UIEffects.BreatheLoop(card, ExportSettings.ui_breathe_amplitude * scale_factor, ExportSettings.ui_breathe_period, float(i) * 0.17)
		UIEffects.AttachInteractive(card, ExportSettings.ui_hover_scale, ExportSettings.ui_press_scale, ExportSettings.ui_hover_duration)

## 构建一张鬼牌。
## @param ghost_id 鬼 id
## @return 鬼牌节点。
func _build_card(ghost_id: String) -> Control:
	var data := _load_ghost_data(ghost_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(card_width, 76)
	panel.set_meta("ghost_id", ghost_id)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _card_style(UIPalette.GLASS_BORDER))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = ResourceUtil.GetString(data, "display_name", ghost_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", UIPalette.TEXT_PRIMARY)
	box.add_child(name_label)

	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.add_theme_color_override("font_color", UIPalette.ACCENT)
	cost_label.text = "造价 %d" % ResourceUtil.GetInt(data, "cost") if show_cost and data != null else ""
	box.add_child(cost_label)

	var footprint_label := Label.new()
	footprint_label.name = "FootprintLabel"
	footprint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footprint_label.add_theme_font_size_override("font_size", 11)
	footprint_label.add_theme_color_override("font_color", UIPalette.TEXT_SECONDARY)
	var size_text := ""
	if data != null:
		var fp := ResourceUtil.GetArray(data, "footprint")
		var ap := ResourceUtil.GetArray(data, "appendages")
		size_text = "占位 %d 格" % (fp.size() + ap.size())
	footprint_label.text = size_text
	box.add_child(footprint_label)

	return panel

## 生成鬼牌卡片的玻璃质感样式盒。
## @param border 描边色。
## @return StyleBoxFlat。
func _card_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UIPalette.GLASS_BG
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	style.shadow_color = Color(UIPalette.PRIMARY.r, UIPalette.PRIMARY.g, UIPalette.PRIMARY.b, 0.22)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	return style

## 加载鬼数据资源。
## @param ghost_id 鬼 id
## @return GhostData 资源；加载失败返回 null。
func _load_ghost_data(ghost_id: String) -> Resource:
	var path := "res://Data/Ghosts/%s.tres" % ghost_id
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)

## 按当前鬼能刷新牌面可用性。
func _refresh_affordability() -> void:
	for card in _cards:
		var data := _load_ghost_data(String(card.get_meta("ghost_id", "")))
		if data == null:
			card.modulate = Color(1, 1, 1, 0.6)
			continue
		var cost := ResourceUtil.GetInt(data, "cost")
		if cost > _spirit:
			card.modulate = Color(1, 1, 1, 0.4)
		else:
			card.modulate = Color(1, 1, 1, 1)

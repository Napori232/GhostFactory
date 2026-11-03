extends Control

## 关卡选择界面。列出全部关卡卡片，展示解锁状态、关卡参数与历史星级。
## 视觉使用 UIPalette 的 23 色板：已解锁卡片描边用主色，星级用暖橙点缀，解锁状态用成功色。

## 未解锁卡片的整体压暗程度。保持禁用感但仍能读出关卡信息。
const LOCKED_MODULATE: Color = Color(0.72, 0.76, 0.88, 0.68)
const STAR_FILLED: String = "★"
const STAR_EMPTY: String = "☆"
const MAX_STARS: int = 3
## 卡片悬停时的目标缩放。
const CARD_POP_SCALE: float = 1.03
## 顶部进度条填充动画时长（秒）。
const PROGRESS_FILL_DURATION: float = 0.5

@onready var _background: BackgroundLayer = %Background
@onready var _title: Label = %Title
@onready var _cards_container: HBoxContainer = %Cards
@onready var _progress_label: Label = %ProgressLabel
@onready var _progress_track: Control = %ProgressTrack
@onready var _progress_fill: ColorRect = %ProgressFill
@onready var _back_button: Button = %BackButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UIPalette.ApplyTheme(self)
	_back_button.pressed.connect(_on_back_button_pressed)
	SignalBus.ProgressChanged.connect(_on_progress_changed)
	_style_back_button()
	_setup_background()
	Refresh()
	_play_intro_item(_title, 0.0)
	_play_intro_item(_progress_label, 0.08)

## 单个文本节点的入场动效：淡入并轻微放大。
## 标题类节点位于 VBoxContainer 内，由容器接管位置，因此用缩放与透明度而非位移做入场。
## @param node 目标控件
## @param delay 延迟秒数
func _play_intro_item(node: Control, delay: float) -> void:
	node.modulate.a = 0.0
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.96, 0.96)
	var tween := node.create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.4)
	tween.tween_property(node, "scale", Vector2.ONE, 0.45)

## 配置背景层：光斑强度与背景图占位说明文字。
func _setup_background() -> void:
	if _background == null:
		return
	_background.SetGlowIntensity(ExportSettings.ui_glow_intensity)
	var placeholder := _background.GetArtPlaceholder()
	if placeholder != null:
		placeholder.SetLabel(ExportSettings.ui_background_label)
	if ExportSettings.ui_background_art != "":
		_background.SetArt(ExportSettings.ui_background_art)

## 刷新关卡卡片与顶部进度统计。
func Refresh() -> void:
	_clear_cards()
	var total := ExportSettings.level_count
	for level_id in range(1, total + 1):
		_cards_container.add_child(_build_card(level_id))
	var cleared := _count_cleared_levels()
	_progress_label.text = "已通关 %d / %d" % [cleared, total]
	# 进度条宽度依赖容器布局完成后再计算，延后一帧执行。
	call_deferred("_animate_progress_deferred", float(cleared) / float(maxi(1, total)))
	_play_card_intro()

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

	box.add_child(_make_label("关卡 %d" % level_id, 20, UIPalette.TEXT_SECONDARY))
	if data == null:
		box.add_child(_make_label("数据缺失", 20, UIPalette.TEXT_PRIMARY))
		box.add_child(_make_label("关卡配置加载失败，无法开始。", 14, UIPalette.TEXT_SECONDARY))
	else:
		box.add_child(_make_label(data.display_name, 20, UIPalette.TEXT_PRIMARY))
		box.add_child(_make_label(data.description, 14, UIPalette.TEXT_SECONDARY))
		box.add_child(_make_label("时长 %d 秒" % data.time_limit, 14, UIPalette.TEXT_SECONDARY))
		box.add_child(_make_label("目标交付 %d" % data.goal_score, 14, UIPalette.TEXT_SECONDARY))
		box.add_child(_make_label("空间预算 %d 格" % data.space_budget, 14, UIPalette.TEXT_SECONDARY))
		box.add_child(_make_label(_format_stars(stars), 22, UIPalette.ACCENT))
		# 状态文案区分已通关、下一关推荐与未解锁，让玩家一眼知道该打哪关。
		var status_text := "未解锁"
		var status_color: Color = UIPalette.TEXT_DISABLED
		if unlocked:
			if stars > 0:
				status_text = "已通关"
				status_color = UIPalette.SUCCESS
			else:
				status_text = "可挑战"
				status_color = UIPalette.GLOW_CYAN
		box.add_child(_make_label(status_text, 14, status_color))

	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = "开始关卡" if unlocked else "未解锁"
	button.disabled = not unlocked or data == null
	button.pressed.connect(_on_card_pressed.bind(level_id))
	box.add_child(button)
	if unlocked:
		panel.mouse_entered.connect(_on_card_hovered.bind(panel))
		# 卡片持续轻微呼吸并左右轻摆，让列表有生气；未解锁卡片保持静止。
		panel.pivot_offset = panel.size * 0.5
		panel.resized.connect(func() -> void:
			if is_instance_valid(panel):
				panel.pivot_offset = panel.size * 0.5
		)
		var phase := float(level_id % 4) * 0.2
		UIEffects.BreatheLoop(panel, ExportSettings.ui_breathe_amplitude * 0.8, ExportSettings.ui_breathe_period * 1.2, phase)
		UIEffects.Sway(panel, 1.6, ExportSettings.ui_sway_period * 1.3, phase)
		UIEffects.AttachInteractive(panel, ExportSettings.ui_hover_scale, ExportSettings.ui_press_scale, ExportSettings.ui_hover_duration)
	return panel

## 返回主菜单按钮使用次要描边样式。
func _style_back_button() -> void:
	_back_button.add_theme_stylebox_override("normal", _make_button_style(UIPalette.BG_PANEL, UIPalette.BORDER))
	_back_button.add_theme_stylebox_override("hover", _make_button_style(UIPalette.BG_RAISED, UIPalette.PRIMARY))
	_back_button.add_theme_stylebox_override("pressed", _make_button_style(UIPalette.BG_PANEL, UIPalette.PRIMARY_DARK))
	_back_button.add_theme_stylebox_override("focus", _make_button_style(UIPalette.BG_PANEL, UIPalette.PRIMARY))

## 生成按钮样式盒。
## @param bg 背景色
## @param border 描边色
## @return StyleBoxFlat 样式。
func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

## 生成一个卡片用的 Label。
## @param text 显示文本
## @param font_size 字号
## @param color 文字颜色
## @return 配置好的 Label。
func _make_label(text: String, font_size: int, color: Color = UIPalette.TEXT_PRIMARY) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

## 生成卡片外观样式：已解锁卡片用玻璃面板加主色描边，未解锁用中性描边。
## @param unlocked 关卡是否已解锁
## @return StyleBoxFlat 样式。
func _make_card_style(unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UIPalette.GLASS_BG if unlocked else UIPalette.BG_PANEL
	style.set_corner_radius_all(16)
	style.set_content_margin_all(16.0)
	style.border_color = UIPalette.GLASS_BORDER if unlocked else UIPalette.BORDER
	style.border_width_left = 4 if unlocked else 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(UIPalette.PRIMARY.r, UIPalette.PRIMARY.g, UIPalette.PRIMARY.b, 0.25 if unlocked else 0.0)
	style.shadow_size = 12 if unlocked else 0
	style.shadow_offset = Vector2(0, 4)
	return style

## 卡片入场动画与悬停缩放。
func _play_card_intro() -> void:
	var cards: Array = []
	for child in _cards_container.get_children():
		if child is Control:
			# 对卡片内部内容做入场动画，保留卡片自身的 modulate 变暗语义。
			var body := child.get_node_or_null("Body")
			cards.append(body if body != null else child)
	UIEffects.PlayStagger(cards, 0.08)

## 卡片悬停时轻微放大。
## @param panel 悬停的卡片。
func _on_card_hovered(panel: Control) -> void:
	UIEffects.PopScale(panel, 1.0, CARD_POP_SCALE, 0.18)

## 延后一帧播放进度条动画，确保轨道宽度已由容器算好。
## @param ratio 已通关比例，0~1。
func _animate_progress_deferred(ratio: float) -> void:
	await get_tree().process_frame
	_animate_progress(ratio)

## 播放顶部进度条填充动画。
## @param ratio 已通关比例，0~1。
func _animate_progress(ratio: float) -> void:
	if _progress_track == null or _progress_fill == null:
		return
	var full_width: float = maxf(_progress_track.size.x, 1.0)
	var target := full_width * clampf(ratio, 0.0, 1.0)
	# 填充条从左侧生长，用与 UIEffects.FillBar 相同的缓动曲线。
	_progress_fill.size.x = 0.0
	var tween := _progress_fill.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_progress_fill, "size:x", target, PROGRESS_FILL_DURATION)

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

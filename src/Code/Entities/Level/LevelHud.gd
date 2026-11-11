class_name LevelHud
extends Control

## 关卡 HUD：资源条、目标进度、倒计时、八向罗盘、鬼牌栏、工具栏与结算面板。
## 界面固定在屏幕上，不随相机旋转；所有操作通过信号交给 Level.gd 处理。

## 玩家从鬼牌栏选中了一种鬼，准备放置。
## @param ghost_id 鬼的资源 id
signal GhostSelected(ghost_id: StringName)
## 接线模式开关。
## @param enabled 是否进入接线模式
signal ConnectToggled(enabled: bool)
## 一键把全部鬼切到运行态。
signal StartAllPressed
## 把当前选中的采集鬼搜索区扩为 5×5。
signal ExpandSearchPressed
## 拆除当前选中的鬼。
signal RemovePressed
## X-Ray 透视开关。
## @param enabled 是否开启透视
signal XRayToggled(enabled: bool)
## 相机旋转按钮。
## @param delta 档位增量
signal RotatePressed(delta: int)
## 相机缩放按钮。
## @param delta 档位增量
signal ZoomPressed(delta: int)
## 重开本关。
signal RestartPressed
## 返回关卡选择。
signal MenuPressed

@onready var spirit_label: Label = %SpiritLabel
@onready var progress_label: Label = %ProgressLabel
@onready var time_label: Label = %TimeLabel
@onready var compass_label: Label = %CompassLabel
@onready var zoom_label: Label = %ZoomLabel
@onready var hint_label: Label = %HintLabel
@onready var ghost_bar: HBoxContainer = %GhostBar
@onready var connect_button: Button = %ConnectButton
@onready var xray_button: Button = %XRayButton
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_stars: Label = %ResultStars
@onready var result_detail: Label = %ResultDetail

var _connect_active: bool = false
var _xray_active: bool = false
var _ghost_buttons: Array[Button] = []
var _base_hint: String = "左键放鬼/拾取/交付｜接线模式点线拆线｜右键转视角｜Q E 旋转｜滚轮缩放｜X 透视｜Delete 拆鬼"

func _ready() -> void:
	_apply_hud_theme()
	%StartAllButton.pressed.connect(func() -> void: StartAllPressed.emit())
	%ExpandSearchButton.pressed.connect(func() -> void: ExpandSearchPressed.emit())
	%RemoveButton.pressed.connect(func() -> void: RemovePressed.emit())
	%RestartButton.pressed.connect(func() -> void: RestartPressed.emit())
	%MenuButton.pressed.connect(func() -> void: MenuPressed.emit())
	%ResultCloseButton.pressed.connect(func() -> void: MenuPressed.emit())
	%RotateLeftButton.pressed.connect(func() -> void: RotatePressed.emit(-1))
	%RotateRightButton.pressed.connect(func() -> void: RotatePressed.emit(1))
	%ZoomInButton.pressed.connect(func() -> void: ZoomPressed.emit(-1))
	%ZoomOutButton.pressed.connect(func() -> void: ZoomPressed.emit(1))
	connect_button.pressed.connect(_on_connect_pressed)
	xray_button.pressed.connect(_on_xray_pressed)

## 让 HUD 与另外三个界面共用 UIPalette 色板（玻璃面板 + 霓虹描边按钮）。
## 工具栏一行有 10 个按钮，因此额外收紧按钮内边距，避免挤爆一行布局。
func _apply_hud_theme() -> void:
	UIPalette.ApplyTheme(self)
	if theme == null:
		return
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := theme.get_stylebox(state, "Button") as StyleBoxFlat
		if style == null:
			continue
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 6.0
		style.content_margin_bottom = 6.0

## 按关卡白名单生成鬼牌按钮。
## @param allowed 本关可用鬼 id 列表。
## @param library 鬼静态配置表。
func BuildGhostBar(allowed: Array[StringName], library: Dictionary) -> void:
	for button in _ghost_buttons:
		button.queue_free()
	_ghost_buttons.clear()
	for ghost_id in allowed:
		var data := library.get(ghost_id) as GhostData
		if data == null:
			continue
		var button := Button.new()
		button.text = "%s · %d 鬼能" % [data.display_name, data.cost]
		button.tooltip_text = "%s（%s）" % [data.display_name, data.DescribePorts()]
		button.pressed.connect(_on_ghost_button.bind(ghost_id))
		ghost_bar.add_child(button)
		_ghost_buttons.append(button)

## 取鬼牌栏当前生成的按钮数量，供 headless 结构测试核对。
## @return 按钮数量。
func GetGhostButtonCount() -> int:
	return _ghost_buttons.size()

## 刷新资源条与进度。
## @param snapshot Board.GetStateSnapshot() 的返回值。
func Refresh(snapshot: Dictionary) -> void:
	spirit_label.text = "鬼能  %d" % int(snapshot["spirit"])
	progress_label.text = "交付  %d / %d  %s" % [
		int(snapshot["delivered"]), int(snapshot["goal_amount"]), _form_name(String(snapshot["goal_form"]))
	]
	time_label.text = "剩余  %.1f s" % float(snapshot["time_left"])
	var used := 0
	for cell in snapshot["placeable"]:
		if _cell_occupied(snapshot, cell):
			used += 1
	hint_label.text = "%s｜可放置区 %d / %d 格" % [_base_hint, used, (snapshot["placeable"] as Array).size()]

## 更新罗盘与缩放档位显示。
## @param compass 当前方位文字。
## @param zoom 当前缩放文字。
func SetViewInfo(compass: String, zoom: String) -> void:
	compass_label.text = compass
	zoom_label.text = zoom

## 设置一行操作提示（会与可放置区计数拼接显示）。
## @param text 提示文本。
func SetHint(text: String) -> void:
	_base_hint = text

## 设置接线模式按钮外观。
## @param active 是否处于接线模式。
func SetConnectActive(active: bool) -> void:
	_connect_active = active
	connect_button.text = "接线中（点线可拆）" if active else "接线 / 拆线"

## 设置 X-Ray 按钮外观。
## @param active 是否开启透视。
func SetXRayActive(active: bool) -> void:
	_xray_active = active
	xray_button.text = "透视 开" if active else "透视 X"

## 显示结算面板。
## @param snapshot Board.GetStateSnapshot() 的返回值。
## @param won 是否通关；false 表示超时失败。
func ShowResult(snapshot: Dictionary, won: bool) -> void:
	result_panel.visible = true
	result_title.text = "关卡 %d 完成！" % int(snapshot["level_id"]) if won else "时间耗尽"
	result_stars.text = StarRating.ToText(int(snapshot["stars"])) if won else "☆☆☆"
	result_detail.text = "耗时 %.1f s   手动 %d 次   鬼能余额 %d   交付 %d / %d" % [
		float(snapshot["elapsed"]), int(snapshot["manual_count"]), int(snapshot["spirit"]),
		int(snapshot["delivered"]), int(snapshot["goal_amount"]),
	]

## 隐藏结算面板。
func HideResult() -> void:
	result_panel.visible = false

## 判断快照里某格是否被鬼或掉落物占用。
## @param snapshot 状态快照。
## @param cell 待判断的格坐标。
## @return 被占用返回 true。
func _cell_occupied(snapshot: Dictionary, cell: Vector2i) -> bool:
	for entry in snapshot["ghosts"]:
		if entry["cell"] == cell:
			return true
	for entry in snapshot["items"]:
		if entry["cell"] == cell:
			return true
	return false

## 形态 id 的中文名。
## @param form 形态 id。
## @return 中文名。
func _form_name(form: String) -> String:
	match form:
		"Spirit":
			return "鬼能"
		"Offer":
			return "贡品"
		"Impurity":
			return "杂质"
	return form

## 鬼牌按钮回调。
## @param ghost_id 选中的鬼 id。
func _on_ghost_button(ghost_id: StringName) -> void:
	SetHint("已选 %s，点地台空格放置；Esc 取消" % String(ghost_id))
	GhostSelected.emit(ghost_id)

## 接线按钮回调。
func _on_connect_pressed() -> void:
	_connect_active = not _connect_active
	SetConnectActive(_connect_active)
	ConnectToggled.emit(_connect_active)

## 透视按钮回调。
func _on_xray_pressed() -> void:
	_xray_active = not _xray_active
	SetXRayActive(_xray_active)
	XRayToggled.emit(_xray_active)

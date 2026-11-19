class_name Hud
extends CanvasLayer
## HUD：波次 / 预算 / 抵达计数 / 共振指数 / 建造栏 / 提示 / 结算面板。
## 只读 Sim 的公开状态，所有操作通过信号交给 Main。

signal BuildRequested(kind: String, type_id: String)
signal PauseRequested
signal RestoreRequested
signal RestartRequested
signal NextLevelRequested(level_id: String)
signal VariantRestartRequested
signal FirstNightRequested
signal LevelRequested(level_id: String)
signal IntroDismissed
signal TutorialSkipped
signal TutorialReplayRequested
signal RemoveRequested(cell: Vector2i)
signal EjectRequested(cell: Vector2i)
signal BeltPickRequested(cell: Vector2i)
signal EyeModeRequested

var sim: Sim
var _root: Control
var _bold: SystemFont

var _wave_value: Label
var _countdown_value: Label
var _budget_value: Label
var _dots: Array = []
var _pause_button: Button
var _view_button: Button

var _gauge: ResonanceGauge
var _peak_value: Label
var _standing_value: Label
var _enemy_value: Label
var _wave_preview: Label
var _armor_taught: bool = false

var _buttons: Dictionary = {}
var _button_kinds: Dictionary = {}
var _hint_label: Label
var _held_slot: HeldSlot
var _territory_value: Label
var _outlaw_value: Label
var _pressure_value: Label
var _build_bar: PanelContainer
var _bottom_row: HBoxContainer
var _right_panel: PanelContainer
var _hint_panel: PanelContainer
var _top_panel: PanelContainer
var _eye_bar: PanelContainer
var _inspector: PanelContainer
var _ins_name: Label
var _ins_role: Label
var _ins_stats: Label
var _ins_hint: Label
var _ins_remove: Button
var _ins_eject: Button
var _inspector_cell: Vector2i = Vector2i(-999, -999)

var _intro: Control
var _intro_continue: Button
var _intro_cards: Dictionary = {}
var _intro_tags: Dictionary = {}
var _eye_mode: bool = false
var _overlay: Control
var _overlay_title: Label
var _overlay_body: Label
var _overlay_button: Button
var _overlay_button2: Button
var _help: Control
var _toast: Label
var _toast_t: float = 0.0
var _last_clear_toast: float = -10.0
var _banner: Label
var _flash: ColorRect
var _boss_panel: PanelContainer
var _boss_bar: ProgressBar
var _boss_label: Label

var _tut: Control
var _tut_step_label: Label
var _tut_text: Label
var _tut_button: Button
var _tut_t: float = 0.0
var _res_bar: ProgressBar
var _res_label: Label


func Bind(sim_ref: Sim) -> void:
	sim = sim_ref
	layer = 10
	_bold = SystemFont.new()
	_bold.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC",
		"Noto Sans CJK SC", "Source Han Sans SC", "SimHei", "sans-serif",
	])
	_bold.font_weight = 700
	_bold.allow_system_fallback = true

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = ThemeFactory.BuildTheme()
	add_child(_root)

	_build_top_bar()
	_build_boss_bar()
	_build_right_panel()
	_build_hint()
	_build_bottom_bar()
	_build_held_slot()
	_build_inspector()
	_build_eye_bar()
	_build_tutorial()
	_build_toast()
	_build_clear_fx()
	_build_intro()
	_build_help()
	_build_overlay()

	sim.events.HintChanged.connect(_on_hint_changed)
	sim.events.RunFailed.connect(_on_run_failed)
	sim.events.RunCleared.connect(_on_run_cleared)
	sim.events.WaveStarted.connect(_on_wave_started)
	sim.events.WaveCleared.connect(_on_wave_cleared)
	sim.events.EnemyBreached.connect(_on_enemy_breached)
	sim.events.EnemyKilled.connect(_on_enemy_killed)
	sim.events.ResonanceBurst.connect(_on_resonance_burst)
	sim.events.TerritoryExpanded.connect(_on_territory_expanded)
	sim.events.OutlawRazed.connect(_on_outlaw_razed)

	_on_hint_changed(sim.CurrentHintText())


func Refresh(dt: float) -> void:
	if sim == null:
		return
	var total := maxi(1, sim.waves.defs.size())
	var current := clampi(sim.waves.next_index + 1, 1, total)
	_wave_value.text = "%d / %d" % [current, total]
	if sim.waves.state == SimWaves.PREP:
		_countdown_value.text = "%d 秒" % int(ceil(sim.waves.time_to_wave))
		_wave_preview.text = _next_wave_text()
	else:
		_countdown_value.text = "交战中"
		_wave_preview.text = "交战中"
	_budget_value.text = str(sim.economy.budget)

	for i in _dots.size():
		var dot: Panel = _dots[i]
		var on := i < sim.breaches
		dot.self_modulate = Palette.DANGER if on else Color(0.34, 0.12, 0.16)

	_gauge.SetValues(sim.ResonanceIndex(), sim.DamageLine(), sim.ClearLine())
	_peak_value.text = "%.2f" % sim.ResonanceIndex()

	var standing := 0
	for id in sim.ghosts:
		if sim.ghosts[id].standing:
			standing += 1
	_standing_value.text = "%d / %d" % [standing, sim.ghosts.size()]
	_enemy_value.text = str(sim.enemies.size())
	if _territory_value != null:
		var rect := sim.grid.build_rect
		_territory_value.text = "%d×%d" % [rect.size.x, rect.size.y]
	_outlaw_value.text = str(sim.OutlawCount())
	_outlaw_value.add_theme_color_override("font_color", Palette.DANGER if sim.OutlawCount() > 0 else Palette.TEXT)
	_pressure_value.text = "+%d" % sim.WavePressureBonus()
	_pressure_value.add_theme_color_override("font_color", Palette.WARN if sim.WavePressureBonus() > 0 else Palette.MUTED)

	var boss: SimEnemy = null
	for id in sim.enemies:
		var e: SimEnemy = sim.enemies[id]
		if e.IsBoss():
			boss = e
			break
	_boss_panel.visible = boss != null
	if boss != null:
		_boss_bar.max_value = boss.max_hp
		_boss_bar.value = boss.hp
		_boss_label.text = "魅王  %d / %d" % [int(ceil(boss.hp)), int(boss.max_hp)]

	_pause_button.text = "继续  (空格)" if sim.paused else "暂停  (空格)"

	for type_id in _buttons:
		var btn: Button = _buttons[type_id]
		var kind := String(_button_kinds.get(type_id, "ghost"))
		var cost := sim.CostOf(kind, type_id)
		btn.disabled = not sim.economy.IsUnlocked(type_id) or not sim.economy.CanAfford(cost)
		var def := GameData.DefinitionFor(kind, type_id)
		var role := String(def.get("role", ""))
		btn.tooltip_text = "%s\n%s\n造价 %d\n%s\n%s" % [
			String(def.get("name", type_id)),
			role,
			cost,
			_stats_line(kind, def),
			String(def.get("proverb", "")),
		]

	if _res_bar != null:
		var charge := clampf(sim.resonance_charge, 0.0, 1.0)
		_res_bar.value = charge * 100.0
		_res_label.text = "%d%%" % int(round(charge * 100.0))
		var col := Palette.WARN if charge >= 0.999 else Palette.ACCENT
		_res_label.add_theme_color_override("font_color", col)

	if not _eye_mode and sim.held_crystal >= 0 and sim.crystals.has(sim.held_crystal):
		_held_slot.SetCrystal(sim.crystals[sim.held_crystal])
	else:
		_held_slot.Clear()

	if _inspector.visible:
		_refresh_inspector()

	if _toast_t > 0.0:
		_toast_t -= dt
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)
		if _toast_t <= 0.0:
			_toast.visible = false

	if _tut_button != null:
		_tut_t += dt
		_tut_button.modulate = Color(1, 1, 1, 0.72 + 0.28 * (0.5 + 0.5 * sin(_tut_t * 4.0)))


func SetSelected(type_id: String) -> void:
	for id in _buttons:
		var btn: Button = _buttons[id]
		btn.set_pressed_no_signal(id == type_id)


func ShowToast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_t = 2.4


func ShowIntro() -> void:
	_intro.visible = true
	_set_play_ui_visible(false)
	var current := String(sim.level.get("id", "01"))
	for id in _intro_cards:
		var card: Panel = _intro_cards[id]
		card.add_theme_stylebox_override("panel", _card_style(false, String(id) == current))
		var tag: Label = _intro_tags.get(id)
		if tag != null:
			tag.visible = String(id) == current
	_intro_continue.text = "继续 · %s" % String(sim.level.get("name", "第一夜"))


## 开始界面期间把游戏内 HUD 收起来，避免从半透明背景里透出来。
func _set_play_ui_visible(on: bool) -> void:
	for panel in [_top_panel, _right_panel, _hint_panel, _build_bar, _inspector, _held_slot, _boss_panel]:
		if panel != null:
			panel.visible = on and (panel != _inspector or _inspector_cell.x >= 0) and (panel != _held_slot or (not _eye_mode and sim.held_crystal >= 0))
	if not on:
		_tut.visible = false


func HideIntro() -> void:
	_intro.visible = false
	_set_play_ui_visible(true)
	if _eye_mode:
		_eye_bar.visible = true
		_build_bar.visible = false
		_right_panel.visible = false
		_hint_panel.visible = false


func IsIntroVisible() -> bool:
	return _intro != null and _intro.visible


func HideOverlay() -> void:
	_overlay.visible = false


func ToggleHelp() -> void:
	_help.visible = not _help.visible


## 幽灵视角下收起建造相关的面板，只留下读数与一条操作提示。
func SetEyeMode(eye: bool) -> void:
	_eye_mode = eye
	if _view_button != null:
		_view_button.text = "上帝视角 (Tab)" if eye else "幽灵视角 (Tab)"
	if _eye_bar != null:
		_eye_bar.visible = eye
	if _build_bar != null:
		_build_bar.visible = not eye
	if _right_panel != null:
		_right_panel.visible = not eye
	if _hint_panel != null:
		_hint_panel.visible = not eye
	if eye:
		_held_slot.Clear()
		_inspector.visible = false
	elif _inspector_cell.x >= 0:
		_inspector.visible = true


## 选中一个格子上的实体，显示它的全部数值与可执行操作。
func ShowInspector(cell: Vector2i) -> void:
	if _eye_mode:
		return
	_inspector_cell = cell
	_inspector.visible = true
	_refresh_inspector()


func HideInspector() -> void:
	_inspector_cell = Vector2i(-999, -999)
	if _inspector != null:
		_inspector.visible = false


## 当前选中的格子（Main 在结构变化后用它判断选择是否还有效）。
func InspectorCell() -> Vector2i:
	return _inspector_cell


func _refresh_inspector() -> void:
	var entry := sim.CellEntity(_inspector_cell)
	if entry.is_empty():
		HideInspector()
		return
	var kind := String(entry.get("kind", ""))
	var id := int(entry.get("id", -1))
	var name := ""
	var role := ""
	var stats := ""
	var hint := ""
	var cost := 0
	var can_eject := false

	match kind:
		Sim.KIND_GHOST:
			var g: SimGhost = sim.ghosts.get(id)
			if g == null:
				HideInspector()
				return
			name = String(g.def.get("name", g.type_id))
			role = String(g.def.get("role", ""))
			cost = g.cost
			var state := "立正" if g.standing else "翘脚"
			if g.IsTopple():
				state = "待砸" if g.topple_armed else "已扣下"
			elif g.IsOscillate():
				state = "摆动中" if absf(g.angular_velocity) > 0.2 else "静止"
			elif g.IsBrace():
				state = ("撑着 %d 只" % g.support_load) if g.standing else "翘脚"
			var kind_name: String = String({"tilt": "倾角", "multi": "双支撑", "relay": "脉冲触发", "topple": "倾倒触发", "brace": "承重触发", "oscillate": "速度阈值"}.get(g.kind, "倾角"))
			stats = "阈值 %s · 周期 %.2fs · 振幅 %.2f · 射程 %.1f\n每次脉冲：%d 颗晶 × %.0f 单位　·　当前 %s" % [
				kind_name, g.EffPeriod(), g.EffAmplitude(), g.EffRange(),
				g.charges_per_pulse, g.charge_amount, state,
			]
			if g.IsMultiContact():
				stats += "\n需要同时顶住这只脚的支撑数：%d" % g.contacts_required
			if g.IsRelay():
				stats += "\n被脉冲扫到后 %.2fs 再发一次 · 冷却 %.2fs" % [g.relay_delay, g.relay_cooldown_time]
			if g.IsTopple():
				stats += "\n角度 ≥ %.2f 时倒下砸邻格 · 冲量 %.1f · 砸完回弹" % [g.topple_angle, g.strike_torque]
			if g.IsBrace():
				stats += "\n最多撑 %d 只 · 每撑一只多受 %.1f 倾覆力矩\n当前撑着 %d 只（有人靠才发脉冲）" % [g.support_capacity, g.support_weight, g.support_load]
			if g.IsOscillate():
				stats += "\n|角速度| ≥ %.2f 时发一次 · 冷却 %.2fs\n它要被人砸/顶一下才会荡起来" % [g.trigger_speed, g.speed_cooldown_time]
			if g.strike_torque > 0.0:
				stats += "\n倒下时会砸向朝向的邻格（冲量 %.1f）" % g.strike_torque
			hint = "「%s」" % String(g.def.get("proverb", ""))
		Sim.KIND_MECH:
			var m: SimMechanism = sim.mechanisms.get(id)
			if m == null:
				HideInspector()
				return
			name = String(m.def.get("name", m.type_id))
			role = String(m.def.get("role", ""))
			cost = m.cost
			var eff: String = String({"push": "顶脚 / 推身", "crank": "沿线段同时顶多只", "tune": "改写鬼的周期", "amp": "放大脉冲振幅", "reach": "延长脉冲射程"}.get(m.effect, m.effect))
			stats = "作用：%s · 每 %.1fs 耗 %.0f 鬼能\n" % [eff, m.push_period, m.energy_per_push]
			if m.effect == "tune":
				stats += "把半径 %.1f 格内的鬼改成 %.2fs 周期" % [m.effect_radius, m.target_period]
			elif m.effect == "amp":
				stats += "半径 %.1f 格内振幅 ×%.2f（封顶 ×%.1f）" % [m.effect_radius, m.amplitude_mult, sim.config.effect_amp_cap]
			elif m.effect == "reach":
				stats += "半径 %.1f 格内射程 ×%.2f（封顶 ×%.1f）" % [m.effect_radius, m.range_mult, sim.config.effect_range_cap]
			else:
				stats += "力矩 %.1f · 判定半径 %.2f · 伸出 %.1f 格" % [m.push_torque, m.head_radius, m.reach]
			stats += "\n插槽：%s" % _slot_text(m)
			can_eject = m.crystal_id >= 0
		Sim.KIND_CRYSTAL:
			var c: SimCrystal = sim.crystals.get(id)
			if c == null:
				HideInspector()
				return
			name = String(c.def.get("name", c.type_id))
			role = "鬼能容器"
			cost = c.cost
			var where := "地上"
			if c.slotted_in >= 0:
				where = "机关槽里"
			elif c.ride_belt >= 0:
				where = "传送带上"
			stats = "存量 %.0f / %.0f　·　位置：%s\n这一颗的鬼能可以被机关消耗 %.0f 次" % [
				c.charge, c.capacity, where, floor(c.charge / 1.0),
			]
			hint = "「%s」" % String(c.def.get("proverb", ""))
		Sim.KIND_BELT:
			var b: SimBelt = sim.belts.get(id)
			if b == null:
				HideInspector()
				return
			name = String(b.def.get("name", b.type_id))
			role = "物流 · 单向搬运"
			cost = b.cost
			var front := "空" if b.items.is_empty() else "有货"
			stats = "朝向 %s · %.1f 格/秒 · 容量 %d\n带面：%d / %d 颗（%s）　·　理论吞吐 ≈ %.1f 颗/秒" % [
				_facing_label(b.facing), b.speed, b.capacity, b.items.size(), b.capacity, front, b.speed,
			]
			can_eject = not b.items.is_empty()
			hint = "「%s」" % String(b.def.get("proverb", ""))
		Sim.KIND_SWAPPER:
			var s: SimSwapper = sim.swappers.get(id)
			if s == null:
				HideInspector()
				return
			name = String(s.def.get("name", s.type_id))
			role = "物流 · " + ("带面 / 机关 / 地面" if s.source == "belt" else "自动换晶")
			cost = s.cost
			stats = "每 %.1fs 一次动作 · 每次抽 %.0f 鬼能\n机关半径 %.1f · 地面 %.1f · 带面 %.1f" % [
				s.swap_period, s.drain, s.service_radius, s.crystal_radius, s.belt_radius,
			]
			if s.source == "belt":
				stats += "\n朝向 %s：正前方来料，背后回程" % _facing_label(s.facing)
			hint = "「%s」" % String(s.def.get("proverb", ""))
		_:
			HideInspector()
			return

	_ins_name.text = name
	_ins_role.text = role
	_ins_stats.text = stats
	_ins_hint.text = hint
	_ins_remove.text = "拆除 (Delete)　退 %d" % cost
	_ins_remove.visible = true
	_ins_eject.visible = can_eject
	_ins_eject.text = "拿下带面晶" if kind == Sim.KIND_BELT else "取出晶体"


func _slot_text(m: SimMechanism) -> String:
	if m.crystal_id < 0:
		return "空（插一颗充能鬼晶才会工作）"
	var c: SimCrystal = sim.crystals.get(m.crystal_id)
	if c == null:
		return "空"
	var pushes := int(floor(c.charge / maxf(0.01, m.energy_per_push)))
	return "%d / %d 单位 · 还能发力 %d 次 ≈ %.1f 秒" % [
		int(c.charge), int(c.capacity), pushes, float(pushes) * m.push_period,
	]


## 建造按钮 tooltip 里的精确数值，让玩家自己算账。
func _stats_line(kind: String, def: Dictionary) -> String:
	match kind:
		"ghost":
			var pulse: Dictionary = def.get("pulse", {})
			var line := "周期 %.2fs · 振幅 %.2f · 射程 %.1f · 每次 %d 颗 × %.0f" % [
				float(pulse.get("period", 2.0)), float(pulse.get("amplitude", 1.0)),
				float(pulse.get("range", 6.0)), int(pulse.get("charges_per_pulse", 1)),
				float(pulse.get("charge_amount", 2.0)),
			]
			if String(def.get("kind", "tilt")) == "multi":
				line += " · 需 %d 个支撑" % int(def.get("tilt", {}).get("contacts_required", 2))
			elif String(def.get("kind", "tilt")) == "relay":
				line += " · 被扫到后 %.2fs 再响" % float(def.get("relay", {}).get("delay", 0.12))
			elif String(def.get("kind", "tilt")) == "topple":
				line += " · 倾角过 %.2f 才砸 · 冲量 %.1f" % [
					float(def.get("topple", {}).get("topple_angle", 0.92)),
					float(def.get("link", {}).get("strike_torque", 1.0)),
				]
			elif String(def.get("kind", "tilt")) == "brace":
				line += " · 撑 %d 只 · 有人靠才响" % int(def.get("link", {}).get("support_capacity", 2))
			elif String(def.get("kind", "tilt")) == "oscillate":
				line += " · |角速度|≥%.2f 触发" % float(def.get("oscillate", {}).get("trigger_speed", 0.75))
			return line
		"mechanism":
			var eff := String(def.get("effect", "push"))
			var line2 := "每 %.1fs 耗 %.0f 鬼能" % [float(def.get("push_period", 2.0)), float(def.get("energy_per_push", 1.0))]
			if eff == "push" or eff == "crank":
				line2 += " · 力矩 %.1f · 判定 %.2f" % [float(def.get("force", 8.0)) * float(def.get("lever", 0.45)), float(def.get("head_radius", 0.22))]
			elif eff == "tune":
				line2 += " · 把 %.2fs 周期给半径 %.1f 的鬼" % [float(def.get("target_period", 2.0)), float(def.get("effect_radius", 5.0))]
			elif eff == "amp":
				line2 += " · 半径 %.1f 振幅 ×%.2f" % [float(def.get("effect_radius", 4.5)), float(def.get("amplitude_mult", 1.4))]
			elif eff == "reach":
				line2 += " · 半径 %.1f 射程 ×%.2f" % [float(def.get("effect_radius", 5.0)), float(def.get("range_mult", 1.5))]
			return line2
		"belt":
			return "%.1f 格/秒 · 容量 %d · 单向" % [float(def.get("speed", 1.0)), int(def.get("capacity", 1))]
		"swapper":
			var src := String(def.get("source", "ground"))
			var line3 := "每 %.1fs 一次 · 抽 %.0f" % [float(def.get("swap_period", 2.5)), float(def.get("drain", 1.0))]
			if src == "belt":
				line3 += " · 有朝向（来料 / 回程）"
			return line3
		"crystal":
			return "容量 %.0f 单位" % float(def.get("capacity", 3.0))
	return ""


func _facing_label(facing: int) -> String:
	match posmod(facing, 4):
		0:
			return "东"
		1:
			return "南"
		2:
			return "西"
	return "北"


# ---------------------------------------------------------------------------

func _build_top_bar() -> void:
	var bar := _panel()
	_top_panel = bar
	_place(bar, 0, 0, 1, 0, 16, 14, -16, 86)
	_root.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	bar.add_child(row)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	var title_text := String(sim.level.get("name", "鬼工厂"))
	var sub_text := String(sim.level.get("subtitle", "魅从四面来 · 守住中央"))
	var mod: Dictionary = sim.level.get("active_modifier", {})
	if not mod.is_empty():
		title_text += " · " + String(mod.get("name", ""))
		sub_text = String(mod.get("desc", "")) + " · " + sub_text
	var title := _label(title_text, 20, Palette.TEXT, true)
	var sub := _label(sub_text, 12, Palette.MUTED)
	var obj := _label("目标：守住 %d 波 · 漏 %d 只判负" % [sim.waves.defs.size(), sim.max_breaches], 11, Palette.WARN)
	title_box.add_child(title)
	title_box.add_child(sub)
	title_box.add_child(obj)
	row.add_child(title_box)
	row.add_child(_spacer())

	_wave_value = _label("1 / 4", 20, Palette.TEXT, true)
	_countdown_value = _label("30 秒", 20, Palette.TEXT, true)
	_budget_value = _label("80", 20, Palette.TEXT, true)
	_territory_value = _label("13 × 13", 20, Palette.TEXT, true)
	_outlaw_value = _label("0", 20, Palette.TEXT, true)
	_pressure_value = _label("+0", 20, Palette.MUTED, true)
	row.add_child(_stat_box("波次", _wave_value))
	row.add_child(_stat_box("下一波", _countdown_value))
	row.add_child(_stat_box("预算", _budget_value))
	row.add_child(_stat_box("领地", _territory_value))
	row.add_child(_stat_box("越界", _outlaw_value))
	row.add_child(_stat_box("鬼屋激增", _pressure_value))
	row.add_child(_breach_box())
	row.add_child(_spacer())

	var help := Button.new()
	help.text = "操作 (H)"
	help.focus_mode = Control.FOCUS_NONE
	help.pressed.connect(func(): ToggleHelp())
	help.custom_minimum_size = Vector2(104, 40)
	row.add_child(help)

	_view_button = Button.new()
	_view_button.text = "幽灵视角 (Tab)"
	_view_button.focus_mode = Control.FOCUS_NONE
	_view_button.custom_minimum_size = Vector2(148, 40)
	_view_button.pressed.connect(func(): EyeModeRequested.emit())
	row.add_child(_view_button)

	_pause_button = Button.new()
	_pause_button.text = "暂停  (空格)"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.pressed.connect(func(): PauseRequested.emit())
	_pause_button.custom_minimum_size = Vector2(128, 40)
	row.add_child(_pause_button)


func _build_boss_bar() -> void:
	_boss_panel = _panel()
	_place(_boss_panel, 0.5, 0, 0.5, 0, -230, 96, 230, 152)
	_boss_panel.visible = false
	_root.add_child(_boss_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_boss_panel.add_child(col)
	_boss_label = _label("魅王", 13, Palette.WARN, true)
	col.add_child(_boss_label)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(0, 12)
	_boss_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.05, 0.06)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.DANGER
	fill.set_corner_radius_all(4)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(_boss_bar)


func _build_right_panel() -> void:
	var panel := _panel()
	_right_panel = panel
	_place(panel, 1, 0.5, 1, 0.5, -258, -245, -16, 245)
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	col.add_child(_label("共振指数", 13, Palette.MUTED, true))
	_peak_value = _label("0.00", 26, Palette.ACCENT, true)
	col.add_child(_peak_value)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_gauge = ResonanceGauge.new()
	_gauge.custom_minimum_size = Vector2(22, 140)
	row.add_child(_gauge)
	var ticks := VBoxContainer.new()
	ticks.add_theme_constant_override("separation", 4)
	var top := _label("清场线", 12, Palette.DANGER)
	var top_v := _label("%.2f" % sim.ClearLine(), 14, Palette.TEXT)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 72)
	var mid := _label("伤害线", 12, Palette.WARN)
	var mid_v := _label("%.2f" % sim.DamageLine(), 14, Palette.TEXT)
	ticks.add_child(top)
	ticks.add_child(top_v)
	ticks.add_child(gap)
	ticks.add_child(mid)
	ticks.add_child(mid_v)
	row.add_child(ticks)

	col.add_child(_hline())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	grid.add_child(_label("立正的鬼", 13, Palette.MUTED))
	_standing_value = _label("0 / 0", 15, Palette.TEXT)
	_standing_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_standing_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_standing_value)
	grid.add_child(_label("场上的魅", 13, Palette.MUTED))
	_enemy_value = _label("0", 15, Palette.TEXT)
	_enemy_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_enemy_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_enemy_value)
	col.add_child(grid)

	col.add_child(_hline())
	col.add_child(_label("机器共振", 12, Palette.MUTED, true))
	_res_bar = ProgressBar.new()
	_res_bar.min_value = 0
	_res_bar.max_value = 100
	_res_bar.value = 0
	_res_bar.show_percentage = false
	_res_bar.custom_minimum_size = Vector2(0, 8)
	var rbg := StyleBoxFlat.new()
	rbg.bg_color = Color(0.06, 0.08, 0.12)
	rbg.set_corner_radius_all(3)
	var rfill := StyleBoxFlat.new()
	rfill.bg_color = Palette.ACCENT
	rfill.set_corner_radius_all(3)
	_res_bar.add_theme_stylebox_override("background", rbg)
	_res_bar.add_theme_stylebox_override("fill", rfill)
	col.add_child(_res_bar)
	_res_label = _label("0%", 12, Palette.ACCENT, true)
	col.add_child(_res_label)
	col.add_child(_label("多只同频鬼一起脉冲", 11, Palette.MUTED))

	col.add_child(_hline())
	col.add_child(_label("下一波", 12, Palette.MUTED, true))
	_wave_preview = _label("—", 13, Palette.TEXT)
	_wave_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wave_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_wave_preview)


func _build_hint() -> void:
	var panel := _panel()
	_hint_panel = panel
	_place(panel, 0, 1, 1, 1, 16, -168, -16, -132)
	_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var who := _label("秘书鬼", 12, Palette.ACCENT, true)
	who.custom_minimum_size = Vector2(58, 0)
	row.add_child(who)
	_hint_label = _label("", 13, Palette.TEXT)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_hint_label)


func _build_bottom_bar() -> void:
	var panel := _panel()
	_build_bar = panel
	_place(panel, 0, 1, 1, 1, 16, -126, -16, -16)
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var grid := GridContainer.new()
	grid.columns = 11
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)

	var group := ButtonGroup.new()
	group.allow_unpress = true
	for entry in GameData.Catalog():
		if not (entry is Dictionary):
			continue
		var kind := String(entry.get("kind", ""))
		var id := String(entry.get("id", ""))
		var hotkey := String(entry.get("hotkey", ""))
		grid.add_child(_build_button(kind, id, hotkey, group))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_bottom_row = row
	row.add_child(_spacer())
	var tip := _label("左键选中/建造 · Delete 拆除 · 右键取晶 · Tab 幽灵视角 · 空格暂停", 11, Palette.MUTED)
	row.add_child(tip)


func _build_button(kind: String, type_id: String, hotkey: String, group: ButtonGroup) -> Button:
	var def := GameData.DefinitionFor(kind, type_id)
	var btn := Button.new()
	var prefix := hotkey + " " if not hotkey.is_empty() else ""
	btn.text = "%s%s · %d" % [prefix, String(def.get("name", type_id)), int(def.get("cost", 0))]
	btn.toggle_mode = true
	btn.button_group = group
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(134, 30)
	btn.add_theme_font_size_override("font_size", 11)
	btn.toggled.connect(func(on: bool):
		if on:
			BuildRequested.emit(kind, type_id)
		else:
			BuildRequested.emit("", "")
	)
	_buttons[type_id] = btn
	_button_kinds[type_id] = kind
	return btn


func _build_held_slot() -> void:
	_held_slot = HeldSlot.new()
	if _bottom_row != null:
		_bottom_row.add_child(_held_slot)
		_bottom_row.move_child(_held_slot, 0)
	_held_slot.visible = false


## 选中实体后的信息 / 操作面板。数值给全，玩家可以自己算。
func _build_inspector() -> void:
	_inspector = _panel()
	_place(_inspector, 0, 0.5, 0, 0.5, 16, -165, 392, 165)
	_inspector.visible = false
	_root.add_child(_inspector)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_inspector.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	_ins_name = _label("", 20, Palette.TEXT, true)
	_ins_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_ins_name)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(28, 26)
	close.pressed.connect(func(): HideInspector())
	head.add_child(close)

	_ins_role = _label("", 12, Palette.ACCENT)
	_ins_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_ins_role)

	col.add_child(_hline())
	_ins_stats = _label("", 13, Palette.TEXT)
	_ins_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_ins_stats)
	col.add_child(_spacer())

	_ins_hint = _label("", 12, Palette.MUTED)
	_ins_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_ins_hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	_ins_remove = Button.new()
	_ins_remove.text = "拆除 (Delete)"
	_ins_remove.focus_mode = Control.FOCUS_NONE
	_ins_remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ins_remove.custom_minimum_size = Vector2(0, 34)
	_ins_remove.pressed.connect(func():
		if _inspector_cell.x >= 0:
			RemoveRequested.emit(_inspector_cell)
	)
	row.add_child(_ins_remove)
	_ins_eject = Button.new()
	_ins_eject.text = "取出晶体"
	_ins_eject.focus_mode = Control.FOCUS_NONE
	_ins_eject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ins_eject.custom_minimum_size = Vector2(0, 34)
	_ins_eject.pressed.connect(func():
		if _inspector_cell.x < 0:
			return
		var e := sim.CellEntity(_inspector_cell)
		if String(e.get("kind", "")) == Sim.KIND_BELT:
			BeltPickRequested.emit(_inspector_cell)
		else:
			EjectRequested.emit(_inspector_cell)
	)
	row.add_child(_ins_eject)


## 幽灵视角下的极简提示条。
func _build_eye_bar() -> void:
	_eye_bar = _panel()
	_place(_eye_bar, 0.5, 1, 0.5, 1, -380, -96, 380, -40)
	_eye_bar.visible = false
	_root.add_child(_eye_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_eye_bar.add_child(row)
	var title := _label("幽灵视角", 15, Palette.ACCENT, true)
	row.add_child(title)
	var tip := _label("WASD 移动 · 右键拖动观察 · Q/E 升降 · Shift 加速 · Tab 返回", 13, Palette.TEXT)
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tip)
	var back := Button.new()
	back.text = "返回 (Tab)"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): EyeModeRequested.emit())
	row.add_child(back)


func _build_tutorial() -> void:
	_tut = _panel()
	_place(_tut, 0, 0, 0, 0, 16, 100, 330, 300)
	_tut.visible = false
	_root.add_child(_tut)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_tut.add_child(col)
	_tut_step_label = _label("新手引导 · 1 / 4", 13, Palette.ACCENT, true)
	col.add_child(_tut_step_label)
	_tut_text = _label("", 15, Palette.TEXT)
	_tut_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tut_text.custom_minimum_size = Vector2(286, 108)
	col.add_child(_tut_text)
	var skip := Button.new()
	skip.text = "跳过引导"
	skip.focus_mode = Control.FOCUS_NONE
	skip.custom_minimum_size = Vector2(0, 30)
	skip.pressed.connect(func(): TutorialSkipped.emit())
	col.add_child(skip)


const TUTORIAL_TEXTS := [
	"选底部的「顶足机关」，放到翘脚鬼翘起的脚边（发光标记）。R 可以换朝向。",
	"点地上发光的充能鬼晶拿起来，拖到机关上松手（也可以点一下机关）。",
	"机关会顶起鬼的脚。鬼立正后开始发脉冲——看热力图亮起来。",
	"守住这一波。漏 10 只才输；右侧「下一波」会预告来向。",
]


## 显示第 step 步新手引导（0-3）。
func ShowTutorialStep(step: int) -> void:
	if _tut == null or step < 0 or step >= TUTORIAL_TEXTS.size():
		return
	_tut_step_label.text = "新手引导 · %d / %d" % [step + 1, TUTORIAL_TEXTS.size()]
	_tut_text.text = String(TUTORIAL_TEXTS[step])
	_tut.visible = true


func HideTutorial() -> void:
	if _tut != null:
		_tut.visible = false
	ClearBuildHighlight()


## 高亮某个建造按钮，把玩家的视线带到正确的入口。
func HighlightBuild(type_id: String) -> void:
	ClearBuildHighlight()
	var btn: Button = _buttons.get(type_id)
	if btn == null:
		return
	_tut_button = btn
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.05)
	sb.border_color = Palette.ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Palette.ACCENT)


func ClearBuildHighlight() -> void:
	if _tut_button == null:
		return
	_tut_button.remove_theme_stylebox_override("normal")
	_tut_button.remove_theme_color_override("font_color")
	_tut_button.modulate = Color.WHITE
	_tut_button = null


func _build_toast() -> void:
	_toast = _label("", 16, Palette.WARN, true)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	_place(_toast, 0.5, 0, 0.5, 0, -260, 100, 260, 136)
	_root.add_child(_toast)


func _build_clear_fx() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.95, 0.8, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	_banner = _label("一拱全爆", 68, Palette.WARN, true)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.02, 0.9))
	_banner.modulate.a = 0.0
	_banner.visible = false
	_place(_banner, 0.0, 0.30, 1.0, 0.30, 0, 0, 0, 90)
	_root.add_child(_banner)


func _play_clear_fx(title: String = "一拱全爆") -> void:
	_banner.text = title
	_banner.visible = true
	_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.10)
	tw.tween_interval(0.70)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func(): _banner.visible = false)

	_flash.color = Color(1.0, 0.95, 0.8, 0.32)
	var tw2 := create_tween()
	tw2.tween_property(_flash, "color:a", 0.0, 0.45)


func _build_intro() -> void:
	_intro = Control.new()
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro.visible = false
	_root.add_child(_intro)

	var bg := ColorRect.new()
	bg.color = Color(0.008, 0.014, 0.022, 0.985)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(bg)

	# 右上角的「月亮」：一层径向渐变，给标题区一点纵深
	var grad := Gradient.new()
	grad.set_color(0, Color(0.10, 0.30, 0.32, 0.55))
	grad.set_color(1, Color(0.01, 0.02, 0.03, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512
	var glow := TextureRect.new()
	glow.texture = tex
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.modulate = Color(1, 1, 1, 0.55)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(glow, 0, 0, 0, 0, 760, -160, 1760, 840)
	_intro.add_child(glow)

	# 标题区
	var title := _label("鬼  工  厂", 58, Palette.TEXT, true)
	_place(title, 0, 0, 0, 0, 76, 86, 980, 168)
	_intro.add_child(title)

	var sub := _label("G H O S T   F A C T O R Y   ·   v 1 5", 13, Palette.MUTED)
	_place(sub, 0, 0, 0, 0, 80, 170, 980, 194)
	_intro.add_child(sub)

	var rule := ColorRect.new()
	rule.color = Palette.ACCENT
	_place(rule, 0, 0, 0, 0, 80, 206, 440, 208)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(rule)

	var tagline := _label("鬼不会自己动。给它力，它才动。", 21, Palette.ACCENT)
	_place(tagline, 0, 0, 0, 0, 80, 226, 980, 258)
	_intro.add_child(tagline)

	var desc := _label("一间阴间工场，一张不断扩张的大地图。用会自己干活的怪机器顶住四面来的魅；每台机关只吃一颗鬼晶的鬼能，用完了，等下一颗。", 13, Palette.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(desc, 0, 0, 0, 0, 80, 264, 700, 318)
	_intro.add_child(desc)

	var keys := _label("空格 暂停　·　Tab 幽灵视角　·　Delete 拆除　·　H 帮助", 12, Palette.MUTED)
	_place(keys, 0, 0, 0, 0, 80, 322, 700, 346)
	_intro.add_child(keys)

	# 夜卡
	var choose := _label("选择一夜", 13, Palette.MUTED, true)
	_place(choose, 0, 0, 0, 0, 80, 380, 400, 404)
	_intro.add_child(choose)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_place(row, 0, 0, 0, 0, 76, 406, 1524, 618)
	_intro.add_child(row)
	for level_id in GameData.LevelIds():
		var id := String(level_id)
		if GameData.Level(id).is_empty():
			continue
		row.add_child(_make_night_card(id))

	# 底部操作
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	_place(buttons, 0, 0, 0, 0, 76, 642, 1524, 700)
	_intro.add_child(buttons)

	_intro_continue = Button.new()
	_intro_continue.text = "继续"
	_intro_continue.focus_mode = Control.FOCUS_NONE
	_intro_continue.custom_minimum_size = Vector2(340, 48)
	_intro_continue.add_theme_font_size_override("font_size", 17)
	_intro_continue.pressed.connect(_on_intro_start)
	buttons.add_child(_intro_continue)

	var first := Button.new()
	first.text = "从第一夜开始"
	first.focus_mode = Control.FOCUS_NONE
	first.custom_minimum_size = Vector2(180, 48)
	first.pressed.connect(func(): FirstNightRequested.emit())
	buttons.add_child(first)

	var help := Button.new()
	help.text = "操作说明 (H)"
	help.focus_mode = Control.FOCUS_NONE
	help.custom_minimum_size = Vector2(160, 48)
	help.pressed.connect(func(): ToggleHelp())
	buttons.add_child(help)

	buttons.add_child(_spacer())
	var version := _label("设计稿 v15 的可玩切片　·　内容全在 Data/", 11, Palette.MUTED)
	buttons.add_child(version)

	var foot_rule := ColorRect.new()
	foot_rule.color = Palette.BORDER
	_place(foot_rule, 0, 0, 0, 0, 76, 836, 1524, 837)
	foot_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_child(foot_rule)
	var foot := _label("没有贴图 / 字体 / 音频文件：模型与音效全部由代码生成，中文字体走系统回退。", 11, Palette.MUTED)
	_place(foot, 0, 0, 0, 0, 76, 846, 1200, 872)
	_intro.add_child(foot)


func _make_night_card(level_id: String) -> Panel:
	var level := GameData.Level(level_id)
	var level_name := String(level.get("name", level_id))
	var card := Panel.new()
	card.custom_minimum_size = Vector2(470, 208)
	card.add_theme_stylebox_override("panel", _card_style(false, false))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_right = -18
	box.offset_top = 14
	box.offset_bottom = -14
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var roman := _label(_roman(GameData.LevelIds().find(level_id) + 1), 26, Palette.ACCENT, true)
	head.add_child(roman)
	var tag := _label("当前这一夜", 11, Palette.WARN, true)
	head.add_child(tag)
	_intro_tags[level_id] = tag
	head.add_child(_spacer())

	var name := _label(level_name, 22, Palette.TEXT, true)
	box.add_child(name)
	var subtitle := _label(String(level.get("subtitle", "")), 12, Palette.MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle)
	box.add_child(_hline())

	var waves: Array = level.get("waves", [])
	var total_reward := 0
	for r in level.get("rewards", []):
		if r is Dictionary:
			total_reward += int(r.get("budget", 0))
	var stats := _label("%d 波　·　预算 %d　·　通关再得 %d　·　漏 %d 只判负" % [
		waves.size(), int(level.get("budget", 0)), total_reward, int(level.get("max_breaches", 10)),
	], 12, Palette.TEXT)
	box.add_child(stats)
	box.add_child(_spacer())
	var foot := _label("开始这一夜  →", 13, Palette.ACCENT, true)
	box.add_child(foot)

	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.tooltip_text = "%s\n%s" % [level_name, String(level.get("subtitle", ""))]
	hit.mouse_entered.connect(func():
		card.add_theme_stylebox_override("panel", _card_style(true, level_id == String(sim.level.get("id", ""))))
	)
	hit.mouse_exited.connect(func():
		card.add_theme_stylebox_override("panel", _card_style(false, level_id == String(sim.level.get("id", ""))))
	)
	hit.pressed.connect(func(): LevelRequested.emit(level_id))
	card.add_child(hit)

	_intro_cards[level_id] = card
	return card


func _card_style(hovered: bool, current: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.14, 0.17, 0.97) if hovered else Color(0.055, 0.085, 0.115, 0.96)
	sb.border_color = Palette.ACCENT if (hovered or current) else Palette.BORDER
	sb.set_border_width_all(2 if current else 1)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	return sb


func _roman(n: int) -> String:
	match n:
		1:
			return "Ⅰ"
		2:
			return "Ⅱ"
		3:
			return "Ⅲ"
	return str(n)


func _build_help() -> void:
	_help = Control.new()
	_help.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help.mouse_filter = Control.MOUSE_FILTER_STOP
	_help.visible = false
	_root.add_child(_help)

	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.04, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help.add_child(dim)

	var panel := _panel()
	_place(panel, 0.5, 0.5, 0.5, 0.5, -320, -300, 320, 300)
	_help.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(_label("玩法与操作", 24, Palette.TEXT, true))
	var loop := _label("循环：机关顶鬼 → 鬼立正 → 脉冲 → 充能 / 伤害 → 再建造。", 13, Palette.ACCENT)
	loop.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(loop)
	var advanced := _label("进阶：三只同频鬼一起脉冲 → 机器共振；节拍机关能改写鬼的周期，共鸣腔放大振幅，传声筒拉长射程。", 12, Palette.WARN)
	advanced.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(advanced)
	var logistics := _label("物流：鬼屋充能 → 去程带 → 装卸臂 → 机关；空晶走回程带回家。带子只往前，臂有朝向。", 12, Palette.CRYSTAL)
	logistics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(logistics)
	var linkage := _label("联动：鬼倒下会砸向它倒朝的那一格（砸脚帮它站，砸身把它推倒）；撑鬼能撑住倒向它的邻鬼。锤鬼 / 撑鬼 / 摆锤鬼是三种新触发。", 12, Palette.WARN)
	linkage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(linkage)
	var rows := [
		["目标", "守住全部波次；漏 10 只判负，可回溯到上一波"],
		["左键", "选中 / 建造 / 拿晶（按住晶可以拖到目标格）"],
		["Delete", "拆除选中的东西（全额退款）"],
		["拖动", "按住鬼 / 机关 / 传送带 / 装卸臂拖到空格"],
		["右键", "机关取出鬼晶 / 取消选择 / 放下手上的鬼晶"],
		["Tab", "幽灵视角：平视、自由移动（WASD + 右键拖动观察 + Q/E 升降）"],
		["1-9 B N 0", "快速选中 鬼 / 机关 / 传送带 / 装卸臂 / 鬼晶"],
		["R", "旋转放置朝向（4 向）"],
		["空格", "暂停 / 继续（暂停中可建造）"],
		["Q / E", "上帝视角旋转 45° / 幽灵视角升降"],
		["滚轮", "五档缩放"],
		["W A S D", "上帝视角平移 / 幽灵视角移动"],
		["Home", "复位视角"],
		["H", "打开 / 关闭本面板"],
	]
	for row in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		var key := _label(row[0], 14, Palette.ACCENT, true)
		key.custom_minimum_size = Vector2(100, 0)
		line.add_child(key)
		var desc := _label(row[1], 14, Palette.TEXT)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(desc)
		col.add_child(line)
	col.add_child(_spacer())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	var replay := Button.new()
	replay.text = "重看新手引导"
	replay.focus_mode = Control.FOCUS_NONE
	replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay.pressed.connect(func():
		_help.visible = false
		TutorialReplayRequested.emit()
	)
	buttons.add_child(replay)
	var close := Button.new()
	close.text = "关闭"
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func(): _help.visible = false)
	buttons.add_child(close)
	col.add_child(buttons)


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_root.add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var panel := _panel()
	_place(panel, 0.5, 0.5, 0.5, 0.5, -320, -200, 320, 200)
	_overlay.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	_overlay_title = _label("", 30, Palette.TEXT, true)
	col.add_child(_overlay_title)
	_overlay_body = _label("", 16, Palette.MUTED)
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_overlay_body)
	_overlay_button = Button.new()
	_overlay_button.focus_mode = Control.FOCUS_NONE
	_overlay_button.custom_minimum_size = Vector2(0, 48)
	col.add_child(_overlay_button)
	_overlay_button2 = Button.new()
	_overlay_button2.focus_mode = Control.FOCUS_NONE
	_overlay_button2.custom_minimum_size = Vector2(0, 40)
	_overlay_button2.visible = false
	col.add_child(_overlay_button2)


# ---------------------------------------------------------------------------

func _on_intro_start() -> void:
	_intro.visible = false
	IntroDismissed.emit()


func _on_hint_changed(text: String) -> void:
	if _hint_label != null:
		_hint_label.text = text


func _wave_has_armor(index: int) -> bool:
	var waves: Array = sim.level.get("waves", [])
	if index < 0 or index >= waves.size():
		return false
	for grp in waves[index].get("groups", []):
		if float(grp.get("armor", 1.0)) < 0.8:
			return true
	return false


func _next_wave_text() -> String:
	var wave := sim.NextWave()
	var groups: Array = wave.get("groups", [])
	var lines: Array = []
	var total_count := 0
	var effective_hp := 0.0
	var armored := 0
	var bonus := sim.WavePressureBonus()
	for grp in groups:
		var count := maxi(1, int(grp.get("count", 1))) + bonus
		var dir := _direction_label(float(grp.get("center_deg", 90.0)), float(grp.get("arc_deg", 0.0)))
		var label := _enemy_label(grp)
		lines.append("%s · %s ×%d" % [dir, label, count])
	total_count = WaveMath.Count(wave, bonus)
	effective_hp = WaveMath.Threat(wave, bonus)
	armored = WaveMath.ArmoredCount(wave, bonus)
	if lines.is_empty():
		return "—"
	var text := "\n".join(lines)
	text += "\n合计 %d 只 · 有效 HP %d%s" % [total_count, int(round(effective_hp)), (" · 甲 %d" % armored) if armored > 0 else ""]
	if bonus > 0:
		text += "\n鬼屋激增：每组 +%d 只（越界 %d）" % [bonus, sim.OutlawCount()]
	var rewards: Array = sim.level.get("rewards", [])
	var index := sim.waves.next_index
	if index >= 0 and index < rewards.size():
		var r: Dictionary = rewards[index]
		text += "\n清空奖励：+%d 预算" % int(r.get("budget", 0))
	return text


func _direction_label(center_deg: float, arc_deg: float) -> String:
	if arc_deg >= 359.0:
		return "四面"
	var deg := fposmod(center_deg, 360.0)
	if deg < 22.5 or deg >= 337.5:
		return "东"
	if deg < 67.5:
		return "东南"
	if deg < 112.5:
		return "南"
	if deg < 157.5:
		return "西南"
	if deg < 202.5:
		return "西"
	if deg < 247.5:
		return "西北"
	if deg < 292.5:
		return "北"
	return "东北"


func _enemy_label(grp: Dictionary) -> String:
	if bool(grp.get("boss", false)):
		return "魅王"
	if float(grp.get("armor", 1.0)) < 0.8:
		return "甲魅"
	if float(grp.get("speed", 0.5)) > 0.8:
		return "疾魅"
	if float(grp.get("hp", 50.0)) > 120.0:
		return "厚魅"
	return "魅"


func _on_wave_started(index: int) -> void:
	if not _armor_taught and _wave_has_armor(index):
		_armor_taught = true
		ShowToast("第 %d 波 · 甲魅：普通脉冲磨得慢，清场线才能直接抹掉" % (index + 1))
	else:
		ShowToast("第 %d 波来袭" % (index + 1))


func _on_wave_cleared(index: int) -> void:
	var reward := 0
	var unlock_name := ""
	var rewards: Array = sim.level.get("rewards", [])
	if index >= 0 and index < rewards.size():
		var r: Dictionary = rewards[index]
		reward = int(r.get("budget", 0))
		if r.has("unlock"):
			unlock_name = GameData.DisplayName(String(r["unlock"]))
	var text := "第 %d 波清空" % (index + 1)
	if reward > 0:
		text += " · 预算 +%d" % reward
	if not unlock_name.is_empty():
		text += " · 新图纸：%s" % unlock_name
	var rect := sim.grid.build_rect
	if rect.size.x > 5:
		text += " · 领地 %d×%d" % [rect.size.x, rect.size.y]
	ShowToast(text)


func _on_enemy_killed(_id: int, _pos: Vector2, by_clear: bool) -> void:
	if not by_clear:
		return
	if sim.time - _last_clear_toast < 1.5:
		return
	_last_clear_toast = sim.time
	_play_clear_fx()


func _on_resonance_burst(_pos: Vector2, amplitude: float, _radius: float) -> void:
	_play_clear_fx("机器共振")
	ShowToast("共振波段 ×%.1f" % amplitude)


func _on_enemy_breached(_id: int, total: int) -> void:
	ShowToast("漏了一只 · %d / %d" % [total, sim.max_breaches])


func _on_territory_expanded(rect: Rect2i, annexed: int) -> void:
	var text := "领地扩张 · %d × %d" % [rect.size.x, rect.size.y]
	if annexed > 0:
		text += " · 收编 %d 处越界造物" % annexed
	ShowToast(text)


func _on_outlaw_razed(_cell: Vector2i, kind: String) -> void:
	var label := "造物"
	match kind:
		Sim.KIND_GHOST:
			label = "鬼"
		Sim.KIND_MECH:
			label = "机关"
		Sim.KIND_BELT:
			label = "传送带"
		Sim.KIND_SWAPPER:
			label = "装卸装置"
	ShowToast("一处越界%s被魅拆了" % label)


func _on_run_failed(reason: String) -> void:
	_overlay_title.add_theme_color_override("font_color", Palette.DANGER)
	if reason == "boss":
		_overlay_title.text = "魅王踏进了核心"
		_overlay_body.text = "魅王抵达了中央——这一夜结束了。\n\n回溯到上一波刚打完的时刻：布局、鬼、机关、鬼能全部回滚，已解锁的东西保留。\n\n本次脉冲 %d 次 · 消灭 %d 只 · 越线抹杀 %d 只" % [
			int(sim.stats.get("pulses", 0)),
			int(sim.stats.get("killed", 0)),
			int(sim.stats.get("cleared_killed", 0)),
		]
	else:
		_overlay_title.text = "装置被拆穿了"
		_overlay_body.text = "抵达中央的魅满了 %d 只。\n\n回溯到上一波刚打完的时刻：布局、鬼、机关、鬼能全部回滚，已解锁的东西保留。\n\n本次脉冲 %d 次 · 消灭 %d 只 · 越线抹杀 %d 只" % [
			sim.max_breaches,
			int(sim.stats.get("pulses", 0)),
			int(sim.stats.get("killed", 0)),
			int(sim.stats.get("cleared_killed", 0)),
		]
	_overlay_button.text = "回溯到上一波"
	_reset_overlay_primary()
	_reset_overlay_secondary()
	_overlay_button.pressed.connect(_on_overlay_restore)
	_overlay_button2.visible = false
	_overlay.visible = true
	var hint := ""
	if int(sim.stats.get("cleared_killed", 0)) == 0:
		hint = "\n\n提示：两只同频鬼摆成一条线，热力图叠过清场线就能一拱全灭。"
	elif sim.economy.budget >= 30:
		hint = "\n\n提示：你还有 %d 预算没花，下一波前可以再补一只鬼或一台机关。" % sim.economy.budget
	else:
		hint = "\n\n提示：回溯后先看右侧「下一波」的来向，把鬼和机关整体拖到那条路上。"
	_overlay_body.text += hint


func _on_run_cleared() -> void:
	_overlay_title.text = "这一夜守住了"
	_overlay_title.add_theme_color_override("font_color", Palette.ACCENT)
	var tags: Array = NightReport.Tags(sim.stats, sim.breaches)
	var tag_line := ""
	for i in tags.size():
		if i > 0:
			tag_line += " · "
		tag_line += String(tags[i])
	var summary := NightReport.Summary(sim.stats, sim.breaches)
	var mod: Dictionary = sim.level.get("active_modifier", {})
	var prefix := ""
	if not mod.is_empty():
		prefix = "约束：%s\n" % String(mod.get("desc", ""))
	_overlay_body.text = "%s夜间报告 · %s\n%s\n\n脉冲 %d 次 · 消灭 %d 只 · 越线抹杀 %d 只 · 剩余预算 %d" % [
		prefix,
		tag_line,
		summary,
		int(sim.stats.get("pulses", 0)),
		int(sim.stats.get("killed", 0)),
		int(sim.stats.get("cleared_killed", 0)),
		sim.economy.budget,
	]
	var next_id := String(sim.level.get("next_level", ""))
	var has_next := not next_id.is_empty() and not GameData.Level(next_id).is_empty()
	_reset_overlay_primary()
	if has_next:
		var next_name := String(GameData.Level(next_id).get("name", next_id))
		_overlay_button.text = "下一夜 · %s" % next_name
		_overlay_button.pressed.connect(_on_overlay_next)
	else:
		_overlay_button.text = "再守一夜"
		_overlay_button.pressed.connect(_on_overlay_restart)

	_reset_overlay_secondary()
	if GameData.Modifiers().is_empty():
		_overlay_button2.text = "重打本夜"
		_overlay_button2.pressed.connect(_on_overlay_restart)
	else:
		_overlay_button2.text = "换约束重打"
		_overlay_button2.pressed.connect(_on_overlay_variant)
	_overlay_button2.visible = true
	_overlay.visible = true


func _reset_overlay_primary() -> void:
	for cb in [_on_overlay_restore, _on_overlay_restart, _on_overlay_next]:
		if _overlay_button.pressed.is_connected(cb):
			_overlay_button.pressed.disconnect(cb)


func _reset_overlay_secondary() -> void:
	for cb in [_on_overlay_restart, _on_overlay_variant]:
		if _overlay_button2.pressed.is_connected(cb):
			_overlay_button2.pressed.disconnect(cb)


func _on_overlay_variant() -> void:
	VariantRestartRequested.emit()


func _on_overlay_next() -> void:
	NextLevelRequested.emit(String(sim.level.get("next_level", "")))


func _on_overlay_restore() -> void:
	_overlay.visible = false
	RestoreRequested.emit()


func _on_overlay_restart() -> void:
	RestartRequested.emit()


# ---------------------------------------------------------------------------

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", _bold)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _stat_box(caption: String, value: Label) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(_label(caption, 12, Palette.MUTED))
	box.add_child(value)
	return box


func _breach_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label("抵达中央", 12, Palette.MUTED))
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 3)
	for i in sim.max_breaches:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(9, 9)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.DANGER
		sb.set_corner_radius_all(3)
		dot.add_theme_stylebox_override("panel", sb)
		dot.self_modulate = Palette.BORDER
		dots.add_child(dot)
		_dots.append(dot)
	box.add_child(dots)
	return box


func _hline() -> ColorRect:
	var line := ColorRect.new()
	line.color = Palette.BORDER
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, or_: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = or_
	c.offset_bottom = ob

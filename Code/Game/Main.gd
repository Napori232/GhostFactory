extends Node3D
## 游戏入口：装配数据、模拟、场景、HUD 与输入。
## 它只做「接线」和交互判定，不放玩法规则——规则全在 Sim 里。

const INVALID_CELL := Vector2i(-999, -999)

var sim: Sim
@onready var rig: CameraRig = $CameraRig
@onready var world: WorldView = $World
@onready var hud: Hud = $HUD
@onready var sfx: Sfx = $Sfx

var pending_kind: String = ""
var pending_type: String = ""
var pending_facing: int = 0
var hover_cell: Vector2i = INVALID_CELL
var _drag_from: Vector2i = INVALID_CELL
var _crystal_drag_from: Vector2i = INVALID_CELL
var _hotkeys: Dictionary = {}   # keycode -> [kind, type_id]
var _selected_cell: Vector2i = INVALID_CELL

var _accum: float = 0.0
var _slowmo: float = 0.0
var _save: SaveService
var _meta: Dictionary = {}
var _counted_waves: Dictionary = {}
var _tut_active := false
var _tut_step := -1


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_save = SaveService.new()
	_meta = _save.LoadMeta()
	var requested := _requested_level()
	GameSession.current_level = requested if not requested.is_empty() else String(_meta.get("current_level", "01"))
	if GameData.Level(GameSession.current_level).is_empty():
		GameSession.current_level = "01"
	var requested_mod := _requested_modifier()
	if not requested_mod.is_empty():
		GameSession.modifier_id = requested_mod

	var validation := GameData.Validate()
	if not bool(validation.get("ok", false)):
		push_error("Main: 内容数据不自洽 " + str(validation.get("errors", [])))
	var level := GameData.Level(GameSession.current_level)
	if level.is_empty():
		push_error("Main: 关卡数据缺失 " + GameSession.current_level)
		return
	level = LevelModifier.Apply(level, GameData.Modifier(GameSession.modifier_id))
	var cfg := SimConfig.FromDictionary(GameData.Game())
	sim = Sim.new()
	sim.Setup(level, cfg)
	sim.events.Built.connect(_on_tut_built)
	sim.events.CrystalInserted.connect(_on_tut_inserted)
	sim.events.GhostPulse.connect(_on_tut_pulse)
	sim.events.WaveCleared.connect(_on_tut_wave_cleared)
	sim.events.Built.connect(_on_structure_changed)
	sim.events.Removed.connect(_on_structure_changed_removed)
	sim.events.Moved.connect(_on_structure_moved)

	rig.Bind(sim.grid, int(level.get("start_zoom", 1)))
	world.Bind(sim, rig.camera)
	hud.Bind(sim)
	_connect_hud()
	_setup_hotkeys()
	sim.events.TerritoryExpanded.connect(func(_rect: Rect2i, _n: int): rig.RebindLimits(sim.grid))
	sfx.Bind(sim)

	sim.SetPaused(true)
	if GameSession.autostart:
		GameSession.autostart = false
		sim.SetPaused(false)
		hud.HideIntro()
		if not bool(_meta.get("tutorial_done", false)):
			_start_tutorial()
	else:
		hud.ShowIntro()
	_setup_progress()
	_run_dev_args()


func _process(delta: float) -> void:
	if sim == null:
		return
	var real_dt := minf(delta, 0.1)
	if _slowmo > 0.0:
		_slowmo = maxf(0.0, _slowmo - real_dt)
	var dt := real_dt * (0.3 if _slowmo > 0.0 else 1.0)
	if not sim.paused and sim.run_state == Sim.PLAYING:
		_accum += dt
		var step := sim.config.tick_step
		var guard := 0
		while _accum >= step and guard < 8:
			sim.Step(step)
			_accum -= step
			guard += 1
	else:
		_accum = 0.0

	world.Sync(real_dt)
	if not hud.IsIntroVisible():
		rig.Update(real_dt)
	hud.Refresh(real_dt)
	# 鼠标在 HUD 上松开时，release 会被 Control 吃掉；下一帧发现键已松开就取消拖拽。
	if _drag_from != INVALID_CELL and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_drag_from = INVALID_CELL
	if _crystal_drag_from != INVALID_CELL and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# 拖到 HUD 上松手：晶还在手里，不清掉
		_crystal_drag_from = INVALID_CELL
	if rig.IsEye():
		world.SetCursor(INVALID_CELL, 0, false, false)
	else:
		_update_hover()
	_flush_requested_restore()


# ---------------------------------------------------------------------------
# 输入
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventMouseMotion:
		if rig.IsEye() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			rig.Look(event.relative.x, event.relative.y)
		return
	if event is InputEventMouseButton:
		if rig.IsEye():
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_primary_press(event.position)
			else:
				_on_primary_release(event.position)
		elif event.pressed:
			match event.button_index:
				MOUSE_BUTTON_RIGHT:
					_secondary_click()
				MOUSE_BUTTON_WHEEL_UP:
					rig.Zoom(-1)
				MOUSE_BUTTON_WHEEL_DOWN:
					rig.Zoom(1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB, KEY_V:
				if not hud.IsIntroVisible():
					_toggle_eye()
			KEY_SPACE:
				_toggle_pause()
			KEY_R:
				if not rig.IsEye():
					pending_facing = posmod(pending_facing + 1, 4)
			KEY_ESCAPE:
				if rig.IsEye():
					_toggle_eye()
				else:
					_cancel()
			KEY_DELETE, KEY_BACKSPACE:
				_remove_selected()
			KEY_H:
				if rig.IsEye():
					_exit_eye()
				hud.ToggleHelp()
			KEY_Q:
				if not rig.IsEye():
					rig.Rotate(-1)
			KEY_E:
				if not rig.IsEye():
					rig.Rotate(1)
			KEY_HOME:
				if rig.IsEye():
					_exit_eye()
				rig.Reset()
			_:
				if not rig.IsEye() and _hotkeys.has(event.keycode):
					var entry: Array = _hotkeys[event.keycode]
					_select_build(String(entry[0]), String(entry[1]))


## 按下左键：建造 / 拿晶照旧立即执行；鬼和机关则进入「可能拖动」状态。
func _on_primary_press(screen_pos: Vector2) -> void:
	var cell := _cell_under_screen(screen_pos)
	if cell == INVALID_CELL or not sim.grid.InField(cell):
		return
	if sim.held_crystal >= 0 or pending_kind != "":
		_click_at(cell)
		return
	var entry := sim.CellEntity(cell)
	if entry.is_empty():
		_clear_selection()
		return
	var kind := String(entry.get("kind", ""))
	if kind == Sim.KIND_CRYSTAL:
		# 按下就拿起来：可以就地松开（继续拿着），也可以直接拖到目标格松手。
		if bool(sim.PickCrystal(cell).get("ok", false)):
			_crystal_drag_from = cell
			return
		_click_at(cell)
		return
	if kind == Sim.KIND_GHOST or kind == Sim.KIND_MECH or kind == Sim.KIND_BELT or kind == Sim.KIND_SWAPPER:
		_drag_from = cell
	else:
		_click_at(cell)


## 松开左键：拖到别的格子 = 挪位；原地松开 = 原来那次点击。
func _on_primary_release(screen_pos: Vector2) -> void:
	# 鬼晶：原地松手 = 继续拿着；拖到别的格松手 = 放下 / 插进机关
	if _crystal_drag_from != INVALID_CELL:
		var from_c := _crystal_drag_from
		_crystal_drag_from = INVALID_CELL
		var target_c := _cell_under_screen(screen_pos)
		if target_c == INVALID_CELL or target_c == from_c:
			return
		if _place_held(target_c):
			return
		return
	if _drag_from == INVALID_CELL:
		return
	var from := _drag_from
	_drag_from = INVALID_CELL
	var cell := _cell_under_screen(screen_pos)
	if cell == INVALID_CELL or cell == from:
		_click_at(from)
		return
	var result := sim.MoveEntity(from, cell)
	if not bool(result.get("ok", false)):
		hud.ShowToast(_reason(String(result.get("reason", ""))))
	else:
		hud.ShowToast("挪好了")


func _click_at(cell: Vector2i) -> void:
	if cell == INVALID_CELL or not sim.grid.InField(cell):
		return

	if sim.held_crystal >= 0:
		var entry := sim.CellEntity(cell)
		var kind_held := String(entry.get("kind", ""))
		if entry.is_empty() or kind_held == Sim.KIND_BELT:
			_report(sim.DropHeld(cell), "这里放不下")
		elif kind_held == Sim.KIND_MECH:
			_report(sim.InsertHeld(cell), "插不进去")
		else:
			hud.ShowToast("鬼晶只能放在空地、传送带或机关插槽")
		return

	if pending_kind != "":
		var result := sim.Build(pending_kind, pending_type, cell, pending_facing)
		if bool(result.get("ok", false)):
			hud.ShowToast("造好了")
		else:
			hud.ShowToast(_reason(String(result.get("reason", ""))))
		return

	var entry2 := sim.CellEntity(cell)
	if entry2.is_empty():
		_clear_selection()
		return
	if String(entry2.get("kind", "")) == Sim.KIND_CRYSTAL:
		_report(sim.PickCrystal(cell), "拿不起来")
		return
	_select_cell(cell)


## 选中某个格子上的实体：世界里打选中环，HUD 显示数值与拆除/取出。
func _select_cell(cell: Vector2i) -> void:
	if sim.CellEntity(cell).is_empty():
		_clear_selection()
		return
	_selected_cell = cell
	world.SetSelection(cell)
	hud.ShowInspector(cell)


func _clear_selection() -> void:
	_selected_cell = INVALID_CELL
	world.ClearSelection()
	hud.HideInspector()


## 拆除选中的东西（全额退款）。拆传送带时带面上的晶会落到地上。
func _remove_selected() -> void:
	if _selected_cell.x < 0:
		hud.ShowToast("先左键选中一样东西，再按 Delete")
		return
	var entry := sim.CellEntity(_selected_cell)
	if entry.is_empty():
		_clear_selection()
		return
	var kind := String(entry.get("kind", ""))
	var id := int(entry.get("id", -1))
	var name := _entity_name(kind, id)
	var cost := _entity_cost(kind, id)
	var result := sim.RemoveAt(_selected_cell)
	if bool(result.get("ok", false)):
		hud.ShowToast("拆了「%s」· 退回 %d" % [name, cost])
		_clear_selection()
	else:
		hud.ShowToast(_reason(String(result.get("reason", ""))))


func _entity_name(kind: String, id: int) -> String:
	match kind:
		Sim.KIND_GHOST:
			var g: SimGhost = sim.ghosts.get(id)
			return String(g.def.get("name", "鬼")) if g != null else "鬼"
		Sim.KIND_MECH:
			var m: SimMechanism = sim.mechanisms.get(id)
			return String(m.def.get("name", "机关")) if m != null else "机关"
		Sim.KIND_CRYSTAL:
			var c: SimCrystal = sim.crystals.get(id)
			return String(c.def.get("name", "鬼晶")) if c != null else "鬼晶"
		Sim.KIND_BELT:
			var b: SimBelt = sim.belts.get(id)
			return String(b.def.get("name", "传送带")) if b != null else "传送带"
		Sim.KIND_SWAPPER:
			var s: SimSwapper = sim.swappers.get(id)
			return String(s.def.get("name", "装卸装置")) if s != null else "装卸装置"
	return "东西"


func _entity_cost(kind: String, id: int) -> int:
	match kind:
		Sim.KIND_GHOST:
			var g: SimGhost = sim.ghosts.get(id)
			return g.cost if g != null else 0
		Sim.KIND_MECH:
			var m: SimMechanism = sim.mechanisms.get(id)
			return m.cost if m != null else 0
		Sim.KIND_CRYSTAL:
			var c: SimCrystal = sim.crystals.get(id)
			return c.cost if c != null else 0
		Sim.KIND_BELT:
			var b: SimBelt = sim.belts.get(id)
			return b.cost if b != null else 0
		Sim.KIND_SWAPPER:
			var s: SimSwapper = sim.swappers.get(id)
			return s.cost if s != null else 0
	return 0


func _on_hud_remove(cell: Vector2i) -> void:
	_selected_cell = cell
	_remove_selected()


func _on_hud_eject(cell: Vector2i) -> void:
	var r := sim.EjectCrystal(cell)
	if bool(r.get("ok", false)):
		hud.ShowToast("取出了插槽里的鬼晶")
	else:
		hud.ShowToast("这个槽是空的")
	if _selected_cell == cell:
		hud.ShowInspector(cell)


func _on_hud_belt_pick(cell: Vector2i) -> void:
	var r := sim.PickCrystal(cell)
	if bool(r.get("ok", false)):
		hud.ShowToast("拿起了带面上的鬼晶")
	else:
		hud.ShowToast("带面上没有鬼晶")
	if _selected_cell == cell:
		hud.ShowInspector(cell)


func _on_structure_changed(_kind: String, _id: int, _cell: Vector2i) -> void:
	if _selected_cell.x < 0:
		return
	if sim.CellEntity(_selected_cell).is_empty():
		_clear_selection()
	else:
		world.SetSelection(_selected_cell)
		hud.ShowInspector(_selected_cell)


func _on_structure_changed_removed(_kind: String, _id: int) -> void:
	if _selected_cell.x >= 0 and sim.CellEntity(_selected_cell).is_empty():
		_clear_selection()


func _on_structure_moved(_kind: String, _id: int, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if _selected_cell == from_cell:
		_selected_cell = to_cell
		world.SetSelection(to_cell)
		hud.ShowInspector(to_cell)


## 把手里那颗晶放到 cell：空地/带子 → 放下，机关 → 插槽。
func _place_held(cell: Vector2i) -> bool:
	if cell == INVALID_CELL:
		return false
	var entry := sim.CellEntity(cell)
	var k := String(entry.get("kind", ""))
	var r: Dictionary
	if entry.is_empty() or k == Sim.KIND_BELT:
		r = sim.DropHeld(cell)
	elif k == Sim.KIND_MECH:
		r = sim.InsertHeld(cell)
	else:
		hud.ShowToast("鬼晶只能放在空地、传送带或机关插槽")
		return false
	if bool(r.get("ok", false)):
		return true
	hud.ShowToast(_reason(String(r.get("reason", ""))))
	return false


## 右键：优先「从机关里取出鬼晶」；其次取消当前操作。
func _secondary_click() -> void:
	if _drag_from != INVALID_CELL or _crystal_drag_from != INVALID_CELL:
		_drag_from = INVALID_CELL
		_crystal_drag_from = INVALID_CELL
		return
	if pending_kind != "" or sim.held_crystal >= 0:
		_cancel()
		return
	var entry := sim.CellEntity(hover_cell)
	var k := String(entry.get("kind", ""))
	if k == Sim.KIND_MECH:
		var r := sim.EjectCrystal(hover_cell)
		if bool(r.get("ok", false)):
			hud.ShowToast("取出晶体")
		else:
			hud.ShowToast(_reason(String(r.get("reason", ""))))
		return
	if k == Sim.KIND_BELT:
		if bool(sim.PickCrystal(hover_cell).get("ok", false)):
			hud.ShowToast("拿起带面晶")
			return
	_clear_selection()


func _cancel() -> void:
	if _crystal_drag_from != INVALID_CELL:
		_crystal_drag_from = INVALID_CELL
	if _drag_from != INVALID_CELL:
		_drag_from = INVALID_CELL
		return
	if pending_kind != "":
		_clear_build()
		return
	if sim.held_crystal >= 0:
		var r := sim.DropHeld(hover_cell)
		if not bool(r.get("ok", false)):
			hud.ShowToast("这里放不下，找个空格")
		return
	if _selected_cell.x >= 0:
		_clear_selection()


func _toggle_eye() -> void:
	if hud.IsIntroVisible():
		return
	if rig.IsEye():
		_exit_eye()
	else:
		_enter_eye()


func _enter_eye() -> void:
	_clear_selection()
	rig.ToggleMode()
	hud.SetEyeMode(true)
	world.SetCursor(INVALID_CELL, 0, false, false)
	world.SetHeldPreview(INVALID_CELL, false)
	hud.ShowToast("幽灵视角 · Tab 返回 · WASD 移动 · 右键拖动观察 · Q/E 升降")


func _exit_eye() -> void:
	if not rig.IsEye():
		return
	rig.ExitEye()
	hud.SetEyeMode(false)
	hud.ShowToast("回到上帝视角")


func _select_build(kind: String, type_id: String) -> void:
	pending_kind = kind
	pending_type = type_id
	pending_facing = 0
	hud.SetSelected(type_id)


## 建造栏快捷键来自 Data/content.json，新增内容不需要改这里。
func _setup_hotkeys() -> void:
	_hotkeys.clear()
	for entry in GameData.Catalog():
		if not (entry is Dictionary):
			continue
		var hk := String(entry.get("hotkey", ""))
		if hk.is_empty():
			continue
		var key := hk.to_upper().unicode_at(0)
		if key <= 0:
			continue
		_hotkeys[key] = [String(entry.get("kind", "")), String(entry.get("id", ""))]


func _clear_build() -> void:
	pending_kind = ""
	pending_type = ""
	hud.SetSelected("")


func _toggle_pause() -> void:
	if sim.run_state != Sim.PLAYING:
		return
	if hud.IsIntroVisible():
		return
	sim.SetPaused(not sim.paused)


# ---------------------------------------------------------------------------
# 悬停 / 拾取
# ---------------------------------------------------------------------------

func _update_hover() -> void:
	var cell := _cell_under_mouse()
	if cell != hover_cell:
		hover_cell = cell
	var valid := false
	var show_arrow := false
	if _drag_from != INVALID_CELL:
		valid = _can_move_to(cell)
	elif pending_kind != "":
		show_arrow = true
		valid = _can_place(cell)
	elif sim.held_crystal >= 0:
		valid = _can_drop(cell)
	else:
		valid = _cell_valid_for_cursor(cell)
	world.SetCursor(hover_cell, pending_facing, valid, show_arrow)
	if sim.held_crystal >= 0:
		world.SetHeldPreview(hover_cell, valid)
	else:
		world.SetHeldPreview(INVALID_CELL, false)


func _cell_under_mouse() -> Vector2i:
	return _cell_under_screen(get_viewport().get_mouse_position())


func _cell_under_screen(screen_pos: Vector2) -> Vector2i:
	if rig == null or rig.camera == null:
		return INVALID_CELL
	var origin := rig.camera.project_ray_origin(screen_pos)
	var dir := rig.camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return INVALID_CELL
	var t := -origin.y / dir.y
	if t <= 0.0:
		return INVALID_CELL
	var hit := origin + dir * t
	return sim.grid.WorldToCell(Vector2(hit.x, hit.z))


func _can_place(cell: Vector2i) -> bool:
	if cell == INVALID_CELL or not sim.CanBuildAt(cell):
		return false
	if sim.cells.has(cell):
		return false
	if not sim.economy.IsUnlocked(pending_type):
		return false
	return sim.economy.CanAfford(sim.CostOf(pending_kind, pending_type))


func _can_drop(cell: Vector2i) -> bool:
	if cell == INVALID_CELL:
		return false
	var entry := sim.CellEntity(cell)
	if entry.is_empty():
		return sim.CanBuildAt(cell)
	return String(entry.get("kind", "")) == Sim.KIND_MECH \
		or String(entry.get("kind", "")) == Sim.KIND_BELT


func _can_move_to(cell: Vector2i) -> bool:
	if cell == INVALID_CELL or not sim.CanBuildAt(cell):
		return false
	return not sim.cells.has(cell)


func _cell_valid_for_cursor(cell: Vector2i) -> bool:
	if cell == INVALID_CELL or not sim.grid.InField(cell):
		return false
	var entry := sim.CellEntity(cell)
	if entry.is_empty():
		return true
	var kind := String(entry.get("kind", ""))
	return kind == Sim.KIND_CRYSTAL or kind == Sim.KIND_MECH or kind == Sim.KIND_BELT or kind == Sim.KIND_SWAPPER


func _report(result: Dictionary, fallback: String) -> void:
	if bool(result.get("ok", false)):
		return
	hud.ShowToast(_reason(String(result.get("reason", ""))) if result.has("reason") else fallback)


func _reason(code: String) -> String:
	match code:
		"outside_build":
			return "只能造在亮框以内"
		"occupied":
			return "这一格已经有东西了"
		"no_budget":
			return "预算不够"
		"locked":
			return "还没解锁"
		"unknown_type":
			return "没有这种图纸"
		"empty_hand":
			return "手上没有东西"
		"hands_full":
			return "一次只能拿一块鬼晶"
		"no_crystal":
			return "这里没有鬼晶"
		"not_mechanism":
			return "要插在机关上"
		"slot_full":
			return "槽里已经有晶了"
		"empty_crystal":
			return "空的插进去也没用"
		"slot_empty":
			return "这个槽是空的"
		"run_not_playing":
			return "这一局已经结束了"
		"cannot_move":
			return "这个不能整体挪位"
	return "做不到"


# ---------------------------------------------------------------------------
# HUD 接线
# ---------------------------------------------------------------------------

func _connect_hud() -> void:
	hud.BuildRequested.connect(func(kind: String, type_id: String):
		if kind.is_empty():
			_clear_build()
		else:
			_select_build(kind, type_id)
	)
	hud.PauseRequested.connect(_toggle_pause)
	hud.RestoreRequested.connect(_request_restore)
	hud.RestartRequested.connect(func(): get_tree().reload_current_scene())
	hud.NextLevelRequested.connect(_on_next_level)
	hud.VariantRestartRequested.connect(_on_variant_restart)
	hud.FirstNightRequested.connect(_on_first_night)
	hud.TutorialSkipped.connect(_finish_tutorial)
	hud.TutorialReplayRequested.connect(_start_tutorial)
	hud.IntroDismissed.connect(_on_intro_dismissed)
	hud.LevelRequested.connect(_on_level_requested)
	hud.RemoveRequested.connect(_on_hud_remove)
	hud.EjectRequested.connect(_on_hud_eject)
	hud.BeltPickRequested.connect(_on_hud_belt_pick)
	hud.EyeModeRequested.connect(_toggle_eye)


func _on_intro_dismissed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	sim.SetPaused(false)
	if not bool(_meta.get("tutorial_done", false)):
		_start_tutorial()


## 从开始界面直接选一夜：在同一进程里重载场景，并跳过开始界面。
func _on_level_requested(level_id: String) -> void:
	if level_id.is_empty():
		return
	if level_id == GameSession.current_level:
		hud.HideIntro()
		_on_intro_dismissed()
		return
	GameSession.current_level = level_id
	GameSession.modifier_id = ""
	GameSession.autostart = true
	_meta["current_level"] = level_id
	_save.SaveMeta(_meta)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().reload_current_scene()


func _start_tutorial() -> void:
	hud.HideIntro()
	sim.SetPaused(false)
	_tut_active = true
	_tut_step = 0
	hud.ShowTutorialStep(0)
	hud.HighlightBuild("pusher")
	world.ShowCellMarker(_tutorial_foot_cell(), Palette.ACCENT)


func _tutorial_foot_cell() -> Vector2i:
	for g in sim.ghosts.values():
		var d := Vector2i.ZERO
		match int(g.facing):
			0:
				d = Vector2i(1, 0)
			1:
				d = Vector2i(0, 1)
			2:
				d = Vector2i(-1, 0)
			3:
				d = Vector2i(0, -1)
		return g.cell + d
	return INVALID_CELL


func _first_charged_crystal() -> SimCrystal:
	for id in sim.crystals:
		var c: SimCrystal = sim.crystals[id]
		if c.slotted_in < 0 and c.cell.x >= 0 and c.charge >= 1.0:
			return c
	return null


func _on_tut_built(kind: String, _id: int, _cell: Vector2i) -> void:
	if not _tut_active or _tut_step != 0 or kind != "mechanism":
		return
	_tut_step = 1
	hud.ClearBuildHighlight()
	hud.ShowTutorialStep(1)
	world.HideCellMarker()
	var c := _first_charged_crystal()
	if c != null:
		world.ShowCellMarker(c.cell, Palette.CRYSTAL)


func _on_tut_inserted(_mech_id: int, _crystal_id: int) -> void:
	if not _tut_active or _tut_step != 1:
		return
	_tut_step = 2
	hud.ShowTutorialStep(2)
	world.HideCellMarker()


func _on_tut_pulse(_ghost_id: int, _pos: Vector2, _amp: float, _period: float) -> void:
	if not _tut_active or _tut_step != 2:
		return
	_tut_step = 3
	hud.ShowTutorialStep(3)


func _on_tut_wave_cleared(index: int) -> void:
	if not _tut_active or _tut_step != 3 or index != 0:
		return
	_finish_tutorial()


func _finish_tutorial() -> void:
	if not _tut_active:
		return
	_tut_active = false
	hud.HideTutorial()
	world.HideCellMarker()
	_meta["tutorial_done"] = true
	_save.SaveMeta(_meta)


func _on_next_level(level_id: String) -> void:
	if level_id.is_empty():
		return
	GameSession.current_level = level_id
	GameSession.modifier_id = ""
	_meta["current_level"] = level_id
	_save.SaveMeta(_meta)
	get_tree().reload_current_scene()


## 从第一夜重新开始（会清掉当前夜规）。
func _on_first_night() -> void:
	GameSession.current_level = "01"
	GameSession.modifier_id = ""
	_meta["current_level"] = "01"
	_save.SaveMeta(_meta)
	get_tree().reload_current_scene()


## 换一条夜规重打当前关卡（在 Data/modifiers.json 里循环）。
func _on_variant_restart() -> void:
	var mods := GameData.Modifiers()
	if mods.is_empty():
		get_tree().reload_current_scene()
		return
	var ids: Array = []
	for m in mods:
		ids.append(String(m.get("id", "")))
	var index := ids.find(GameSession.modifier_id)
	GameSession.modifier_id = String(ids[(index + 1) % ids.size()])
	get_tree().reload_current_scene()


var _restore_pending: bool = false


func _request_restore() -> void:
	_restore_pending = true


func _flush_requested_restore() -> void:
	if not _restore_pending:
		return
	_restore_pending = false
	sim.RestoreSnapshot()
	_accum = 0.0
	hud.HideOverlay()
	hud.ShowToast("已回溯到上一波")


# ---------------------------------------------------------------------------
# 元进度：只存「最佳波次 / 累计通关」这类跨局数据，不存波次中途状态。
# ---------------------------------------------------------------------------

## 支持 `-- --level=02` 直接载入某一夜（调试 / 验证用）。
func _requested_level() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			return arg.substr("--level=".length())
	# 开发场景固定关卡，避免存档里的 current_level 把测试带偏
	var dev_levels := {
		"--dev-shot": "01", "--dev-smoke": "01", "--dev-input": "01",
		"--dev-tutorial": "01", "--dev-tutorial-flow": "01", "--dev-help": "01",
		"--dev-resonance": "01", "--dev-shot-variant": "01",
		"--dev-select": "01", "--dev-held": "01", "--dev-crystal": "01",
		"--dev-shot2": "02",
		"--dev-shot3": "03", "--dev-eye": "03", "--dev-gallery": "03",
		"--dev-link": "03", "--dev-behemoth": "03",
	}
	for arg in OS.get_cmdline_user_args():
		if dev_levels.has(arg):
			return String(dev_levels[arg])
	return ""


func _requested_modifier() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--modifier="):
			return arg.substr("--modifier=".length())
	return ""


func _setup_progress() -> void:
	sim.events.WaveCleared.connect(_on_wave_cleared_progress)
	sim.events.RunCleared.connect(_on_run_cleared_progress)
	sim.events.EnemyKilled.connect(_on_enemy_killed_fx)
	sim.events.EnemyBreached.connect(func(_id: int, _total: int): rig.Shake(0.10))
	sim.events.RunFailed.connect(func(_reason: String): rig.Shake(0.30))
	sim.events.RunCleared.connect(func(): rig.Shake(0.16))
	sim.events.RunFailed.connect(func(_reason: String): _exit_eye())
	sim.events.RunCleared.connect(func(): _exit_eye())
	sim.events.ResonanceBurst.connect(_on_resonance_burst_fx)


## 越线抹杀时给一点「世界慢下来」的余韵——纯表现，不影响规则。
func _on_enemy_killed_fx(_id: int, _pos: Vector2, by_clear: bool) -> void:
	if by_clear:
		_slowmo = maxf(_slowmo, 0.55)
		rig.Shake(0.20)
	else:
		rig.Shake(0.035)


func _on_resonance_burst_fx(_pos: Vector2, _amp: float, _radius: float) -> void:
	_slowmo = maxf(_slowmo, 0.28)
	rig.Shake(0.35)


func _on_wave_cleared_progress(index: int) -> void:
	if _counted_waves.has(index):
		return
	_counted_waves[index] = true
	_meta["best_wave"] = maxi(int(_meta.get("best_wave", 0)), index + 1)
	var st: Dictionary = _meta.get("stats", {})
	st["cleared_waves"] = int(st.get("cleared_waves", 0)) + 1
	_meta["stats"] = st
	_save.SaveMeta(_meta)


func _on_run_cleared_progress() -> void:
	var st: Dictionary = _meta.get("stats", {})
	st["runs"] = int(st.get("runs", 0)) + 1
	_meta["stats"] = st
	_save.SaveMeta(_meta)


# ---------------------------------------------------------------------------
# 开发用：无头冒烟 / 截图
# ---------------------------------------------------------------------------

func _run_dev_args() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--dev-shot"):
		_dev_shot()
	elif args.has("--dev-smoke"):
		_dev_smoke()
	elif args.has("--dev-input"):
		_dev_input()
	elif args.has("--dev-tutorial"):
		_dev_tutorial_shot()
	elif args.has("--dev-tutorial-flow"):
		_dev_tutorial_flow()
	elif args.has("--dev-help"):
		_dev_help_shot()
	elif args.has("--dev-resonance"):
		_dev_resonance_shot()
	elif args.has("--dev-shot2"):
		_dev_shot2()
	elif args.has("--dev-shot3"):
		_dev_shot3()
	elif args.has("--dev-gallery"):
		_dev_gallery()
	elif args.has("--dev-shot-variant"):
		_dev_shot_variant()
	elif args.has("--dev-behemoth"):
		_dev_behemoth()
	elif args.has("--dev-eye"):
		_dev_eye()
	elif args.has("--dev-select"):
		_dev_select()
	elif args.has("--dev-held"):
		_dev_held()
	elif args.has("--dev-click-card"):
		_dev_click_card()
	elif args.has("--dev-link"):
		_dev_link()
	elif args.has("--dev-crystal"):
		_dev_crystal()


## 庞然大物：在第三夜上把参考机器一次搭好，跑一段并截图。
## 这是「内容上限」的可执行证明：同一个 Build，测试里也在跑。
func _dev_behemoth() -> void:
	await get_tree().process_frame
	hud.HideIntro()
	sim.SetPaused(false)
	var built := Behemoth.Build(sim)
	print("DEV_BEHEMOTH built=%d failed=%s" % [int(built["built"]), str(built["failed"])])
	for i in 10:
		await get_tree().create_timer(3.0).timeout
		var r := Behemoth.Report(sim)
		print("DEV_BEHEMOTH t=%.0f standing=%d/%d pulses=%d belt=%d loader=%d hot=%d kill=%d clear=%d breach=%d" % [
			float(r["time"]), int(r["standing"]), int(r["ghosts"]), int(r["pulses"]),
			int(r["belt_transfers"]), int(r["loader_swaps"]), int(r["hot_cells"]),
			int(r["killed"]), int(r["cleared_killed"]), int(r["breaches"]),
		])
	await _save_shot("behemoth")
	# 近距离：等六只鬼都立正（机器从换料抖动里恢复）再拍，看核心的十字与两条带子
	rig.zoom_index = 2
	rig.focus = Vector2(0.0, 0.0)
	for i in 80:
		await get_tree().create_timer(0.1).timeout
		var standing := 0
		for gid in sim.ghosts:
			if sim.ghosts[gid].standing:
				standing += 1
		if standing >= 6:
			break
	await _save_shot("behemoth_close")
	get_tree().quit(0)


## 端到端验证「按住鬼 → 拖到另一格 → 松开」这条输入链。
func _dev_input() -> void:
	await get_tree().process_frame
	hud.HideIntro()
	sim.SetPaused(false)
	await get_tree().create_timer(0.2).timeout
	var ghost: SimGhost = sim.ghosts.values()[0]
	var from_cell := ghost.cell
	var to_cell := Vector2i(from_cell.x + 2, from_cell.y - 1)
	var from_pos := _screen_of_cell(from_cell)
	var to_pos := _screen_of_cell(to_cell)
	_parse_click(from_pos, true)
	await get_tree().process_frame
	_parse_click(to_pos, false)
	await get_tree().process_frame
	await get_tree().process_frame
	var ok := ghost.cell == to_cell
	print("DEV_INPUT from=%s target=%s result=%s moved=%s" % [
		str(from_cell), str(to_cell), str(ghost.cell), str(ok),
	])
	get_tree().quit(0 if ok else 1)


func _dev_tutorial_shot() -> void:
	# 只拍新手引导：隐藏开场、启动第一步、让玩家看到金圈与高亮按钮。
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	hud.HideIntro()
	sim.SetPaused(false)
	_start_tutorial()
	await get_tree().create_timer(0.6).timeout
	await _save_shot("tutorial")
	get_tree().quit(0)


func _dev_tutorial_flow() -> void:
	# 验证引导状态机：建造机关 → 拿晶插入 → 等待脉冲。
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	hud.HideIntro()
	sim.SetPaused(false)
	_start_tutorial()
	await get_tree().create_timer(0.4).timeout
	sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)
	await get_tree().create_timer(0.4).timeout
	await _save_shot("tutorial_step2")
	if bool(sim.PickCrystal(Vector2i(5, 8)).get("ok", false)):
		sim.InsertHeld(Vector2i(4, 8))
	await get_tree().create_timer(1.2).timeout
	await _save_shot("tutorial_step3")
	get_tree().quit(0)


func _dev_help_shot() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	hud.HideIntro()
	hud.ToggleHelp()
	await get_tree().create_timer(0.3).timeout
	await _save_shot("help")
	get_tree().quit(0)


func _dev_resonance_shot() -> void:
	# 三只同频鬼一起脉冲，拍下「机器共振」的大波段。
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	hud.HideIntro()
	sim.SetPaused(false)
	sim.economy.Unlock("swing")
	sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)
	sim.PickCrystal(Vector2i(5, 8))
	sim.InsertHeld(Vector2i(4, 8))
	sim.Build("ghost", "swing", Vector2i(6, 8), 0)
	sim.Build("mechanism", "pusher", Vector2i(7, 8), 2)
	sim.PickCrystal(Vector2i(5, 6))
	sim.InsertHeld(Vector2i(7, 8))
	sim.Build("ghost", "waver", Vector2i(9, 8), 0)
	sim.Build("mechanism", "pusher", Vector2i(10, 8), 2)
	var res := sim.Build("crystal", "crystal", Vector2i(9, 6))
	var c: SimCrystal = sim.crystals.get(int(res.get("id", -1)))
	if c != null:
		c.charge = 5.0
	sim.PickCrystal(Vector2i(9, 6))
	sim.InsertHeld(Vector2i(10, 8))
	sim.SpawnEnemy(Vector2(3.0, 0.0), 120.0, 0.0)
	var start_time := sim.time
	while sim.time - start_time < 3.0:
		await get_tree().process_frame
		if int(sim.stats.get("resonance_bursts", 0)) >= 1:
			break
	await get_tree().create_timer(0.06).timeout
	await _save_shot("resonance")
	get_tree().quit(0)


func _dev_shot_variant() -> void:
	# 夜规结算面板：拍「约束 + 夜间报告 + 换约束重打」
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	hud.HideIntro()
	sim.stats = {
		"pulses": 38, "killed": 12, "cleared_killed": 4, "breached": 0,
		"built": 10, "spent": 50, "manual_inserts": 9, "auto_swaps": 2, "moves": 1,
	}
	sim._win()
	await get_tree().create_timer(0.4).timeout
	await _save_shot("variant_victory")
	get_tree().quit(0)


## 内容陈列：把每一种鬼 / 机关 / 带子 / 臂都摆出来拍一张，检查新模型与配色。
func _dev_gallery() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	hud.HideIntro()
	sim.SetPaused(false)
	sim.economy.budget = 5000
	for cell in sim.cells.keys():
		if sim.cells.has(cell):
			sim.RemoveAt(cell)
	for entry in GameData.Catalog():
		sim.economy.Unlock(String(entry.get("id", "")))
	sim.ExpandTerritory(6)
	var ghost_ids := ["waver", "swing", "lantern", "hum", "toll", "relay", "anchor"]
	for i in ghost_ids.size():
		sim.Build("ghost", ghost_ids[i], Vector2i(4 + i * 2, 8), 0)
	var mech_ids := ["pusher", "crank", "tuner", "amp", "reach"]
	for i in mech_ids.size():
		sim.Build("mechanism", mech_ids[i], Vector2i(4 + i * 2, 11), 0)
		sim.Build("crystal", "crystal", Vector2i(4 + i * 2, 12), 0)
	sim.Build("belt", "belt", Vector2i(4, 14), 0)
	sim.Build("belt", "belt", Vector2i(5, 14), 0)
	sim.Build("belt", "express", Vector2i(6, 14), 0)
	sim.Build("swapper", "arm", Vector2i(8, 14), 3)
	sim.Build("swapper", "hand", Vector2i(10, 14), 0)
	sim.Build("crystal", "cell", Vector2i(12, 14), 0)
	sim.Build("ghost", "relay", Vector2i(14, 8), 0)
	rig.zoom_index = 2
	await get_tree().create_timer(1.0).timeout
	await _save_shot("gallery")
	get_tree().quit(0)


func _dev_shot2() -> void:
	# 第二夜（走廊）：拍准备阶段与两只鬼摆成一条线的样子。
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	await _save_shot("night2_intro")
	hud.HideIntro()
	sim.SetPaused(false)
	sim.Build("mechanism", "pusher", Vector2i(5, 4), 2)
	if bool(sim.PickCrystal(Vector2i(6, 4)).get("ok", false)):
		sim.InsertHeld(Vector2i(5, 4))
	sim.Build("ghost", "swing", Vector2i(11, 4), 0)
	sim.Build("mechanism", "pusher", Vector2i(12, 4), 2)
	if bool(sim.PickCrystal(Vector2i(8, 4)).get("ok", false)):
		sim.InsertHeld(Vector2i(12, 4))
	await get_tree().create_timer(2.6).timeout
	await _save_shot("night2")
	get_tree().quit(0)


## 第三夜（大地图）：拍开局的小领地、一条物流线，以及领地外引鬼的越界哨站。
func _dev_shot3() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	await _save_shot("night3_intro")
	hud.HideIntro()
	sim.SetPaused(false)
	sim.economy.Unlock("arm")
	sim.economy.budget = maxi(sim.economy.budget, 200)
	# 起手机关上电
	if bool(sim.PickCrystal(Vector2i(10, 11)).get("ok", false)):
		sim.InsertHeld(Vector2i(11, 10))
	# 领地内摆一条短物流线
	sim.Build("belt", "belt", Vector2i(12, 12), 0)
	sim.Build("belt", "belt", Vector2i(13, 12), 0)
	sim.Build("swapper", "arm", Vector2i(12, 13), 3)
	# 越界哨站：一只鬼 + 一台机关，脚下会亮红环，每波多引 1 只魅
	sim.Build("ghost", "waver", Vector2i(6, 11), 0)
	sim.Build("mechanism", "pusher", Vector2i(7, 11), 2)
	await get_tree().create_timer(0.5).timeout
	if bool(sim.PickCrystal(Vector2i(12, 11)).get("ok", false)):
		sim.InsertHeld(Vector2i(7, 11))
	await get_tree().create_timer(2.4).timeout
	await _save_shot("night3")
	get_tree().quit(0)


## 幽灵视角：在第三夜搭好参考机器，站到核心旁边平视它；顺便验证 W 是往前走。
func _dev_eye() -> void:
	await get_tree().process_frame
	hud.HideIntro()
	sim.SetPaused(false)
	Behemoth.Build(sim)
	await get_tree().create_timer(2.4).timeout
	_enter_eye()
	rig.MoveEyeTo(Vector2i(11, 7), sim.grid, 1.6)
	var target := Vector3(0.0, 1.1, 0.0)
	var d := target - rig.eye_pos
	rig.eye_yaw = atan2(-d.x, -d.z)
	rig.eye_pitch = 0.03
	await get_tree().create_timer(0.4).timeout
	var before := rig.eye_pos.distance_to(target)
	_press_key(KEY_W, true)
	await get_tree().create_timer(0.5).timeout
	_press_key(KEY_W, false)
	var after := rig.eye_pos.distance_to(target)
	print("DEV_EYE pos=%s eye=%s closer=%.2f->%.2f" % [str(rig.eye_pos), str(rig.IsEye()), before, after])
	# W 测试之后回到一个能看清整台机器的站位
	rig.MoveEyeTo(Vector2i(11, 7), sim.grid, 1.7)
	var d2 := target - rig.eye_pos
	rig.eye_yaw = atan2(-d2.x, -d2.z)
	rig.eye_pitch = -0.10
	await get_tree().create_timer(0.4).timeout
	await _save_shot("eye_view")
	_exit_eye()
	get_tree().quit(0)


func _press_key(key: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = pressed
	Input.parse_input_event(ev)


## 点开始界面的第二张夜卡：验证「选关 → 重载 → 直接开局」这条路。
func _dev_click_card() -> void:
	await get_tree().process_frame
	if GameSession.current_level != "02":
		await get_tree().create_timer(0.6).timeout
		var card: Panel = hud._intro_cards.get("02")
		if card != null:
			var center := card.get_global_rect().get_center()
			_parse_click(center, true)
			await get_tree().create_timer(0.08).timeout
			_parse_click(center, false)
		await get_tree().create_timer(1.5).timeout
		print("DEV_CARD clicked level=%s intro=%s" % [GameSession.current_level, str(hud.IsIntroVisible())])
		get_tree().quit(0)
	else:
		print("DEV_CARD reloaded level=%s autostart_left=%s intro=%s" % [
			GameSession.current_level, str(GameSession.autostart), str(hud.IsIntroVisible())])
		get_tree().quit(0)


## 鬼晶手感：按住晶 → 拖到机关上松手 → 插进去；右键机关 → 取出。
func _dev_crystal() -> void:
	await get_tree().process_frame
	hud.HideIntro()
	sim.SetPaused(false)
	sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)
	await get_tree().create_timer(0.2).timeout
	var from := _screen_of_cell(Vector2i(5, 8))
	var to := _screen_of_cell(Vector2i(4, 8))
	_parse_click(from, true)
	await get_tree().create_timer(0.1).timeout
	_parse_click(to, false)
	await get_tree().create_timer(0.2).timeout
	var entry := sim.CellEntity(Vector2i(4, 8))
	var mid := int(entry.get("id", -1))
	var m: SimMechanism = sim.mechanisms.get(mid)
	var inserted := m != null and m.crystal_id >= 0
	print("DEV_CRYSTAL drag_inserted=%s held_after_insert=%d" % [str(inserted), sim.held_crystal])
	hover_cell = Vector2i(4, 8)
	_secondary_click()
	await get_tree().create_timer(0.2).timeout
	var m2: SimMechanism = sim.mechanisms.get(mid)
	print("DEV_CRYSTAL after_eject mech_crystal=%d held=%d" % [
		m2.crystal_id if m2 != null else -1, sim.held_crystal,
	])
	get_tree().quit(0)


## 机械联动演示：锤鬼砸摆锤；长撬 + 撑鬼一起把锚鬼撑起来。
func _dev_link() -> void:
	await get_tree().process_frame
	hud.HideIntro()
	sim.SetPaused(false)
	# 上排：顶足 → 锤鬼 → 摆锤
	sim.Build("mechanism", "pusher", Vector2i(9, 12), 0)
	sim.Build("ghost", "hammer", Vector2i(10, 12), 0)
	sim.Build("ghost", "pendulum", Vector2i(11, 12), 0)
	# 下排：长撬 + 撑鬼 → 锚鬼
	sim.Build("ghost", "anchor", Vector2i(10, 13), 0)
	sim.Build("mechanism", "crank", Vector2i(9, 13), 0)
	sim.Build("ghost", "prop", Vector2i(11, 13), 0)
	sim.Build("mechanism", "pusher", Vector2i(12, 13), 2)
	# 供电（用地图上的充能晶 + 一颗新晶）
	sim.PickCrystal(Vector2i(10, 11))
	sim.InsertHeld(Vector2i(9, 12))
	sim.PickCrystal(Vector2i(12, 11))
	sim.InsertHeld(Vector2i(9, 13))
	var rb := sim.Build("crystal", "crystal", Vector2i(13, 12))
	var c: SimCrystal = sim.crystals.get(int(rb.get("id", -1)))
	if c != null:
		c.charge = 5.0
	sim.PickCrystal(Vector2i(13, 12))
	sim.InsertHeld(Vector2i(12, 13))
	rig.focus = Vector2(0.0, 1.0)
	rig.zoom_index = 2
	await get_tree().create_timer(0.5).timeout
	await _save_shot("link_setup")
	await get_tree().create_timer(2.5).timeout
	var brace: SimGhost = null
	var anchor: SimGhost = null
	var pend: SimGhost = null
	for gid in sim.ghosts:
		var g: SimGhost = sim.ghosts[gid]
		if g.type_id == "prop":
			brace = g
		elif g.type_id == "anchor":
			anchor = g
		elif g.type_id == "pendulum":
			pend = g
	print("DEV_LINK strikes=%d pend_pulses=%d brace_load=%d anchor_standing=%s links=%d" % [
		int(sim.stats.get("strikes", 0)),
		pend.pulse_total if pend != null else -1,
		brace.support_load if brace != null else -1,
		str(anchor.standing) if anchor != null else "?",
		sim.links.size(),
	])
	await _save_shot("link")
	_enter_eye()
	rig.MoveEyeTo(Vector2i(11, 16), sim.grid, 2.2)
	var target := Vector3(0.0, 0.8, 1.5)
	var d := target - rig.eye_pos
	rig.eye_yaw = atan2(-d.x, -d.z)
	rig.eye_pitch = -0.38
	await get_tree().create_timer(0.5).timeout
	await _save_shot("link_eye")
	_exit_eye()
	get_tree().quit(0)


## 选中 / 拆除：验证左键选中出现数值面板、Delete 全额退款。
func _dev_select() -> void:
	await get_tree().process_frame
	hud.HideIntro()
	sim.SetPaused(false)
	var before := sim.economy.budget
	var ghosts_before := sim.ghosts.size()
	_select_cell(Vector2i(3, 8))
	await get_tree().create_timer(0.6).timeout
	await _save_shot("inspector")
	_remove_selected()
	await get_tree().create_timer(0.4).timeout
	print("DEV_SELECT budget_before=%d after=%d ghosts=%d->%d cell_empty=%s" % [
		before, sim.economy.budget, ghosts_before, sim.ghosts.size(),
		str(not sim.cells.has(Vector2i(3, 8))),
	])
	await _save_shot("after_remove")
	# 再看一眼机关面板：作用 / 耗能 / 每颗晶能撑多久
	sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)
	_select_cell(Vector2i(4, 8))
	await get_tree().create_timer(0.4).timeout
	await _save_shot("inspector_mech")
	get_tree().quit(0)


## 手持槽：拿起来 / 放下，检查图标是否跟着消失。
func _dev_held() -> void:
	await get_tree().process_frame
	hud.HideIntro()
	sim.SetPaused(false)
	sim.PickCrystal(Vector2i(5, 8))
	await get_tree().create_timer(0.5).timeout
	await _save_shot("held")
	sim.DropHeld(Vector2i(7, 8))
	await get_tree().create_timer(0.5).timeout
	print("DEV_HELD held=%d slot_visible=%s" % [sim.held_crystal, str(hud._held_slot.visible)])
	await _save_shot("held_dropped")
	get_tree().quit(0)


func _screen_of_cell(cell: Vector2i) -> Vector2:
	var w := sim.grid.CellToWorld(cell)
	return rig.camera.unproject_position(Vector3(w.x, 0.25, w.y))


## 把视口坐标换算成窗口坐标再注入：工程用了 canvas_items 拉伸，
## Input.parse_input_event 收到的是窗口坐标，直接塞视口坐标会点偏。
func _parse_click(pos: Vector2, pressed: bool) -> void:
	var win := Vector2(get_window().size)
	var vp := get_viewport().get_visible_rect().size
	var scale := Vector2(1, 1)
	if vp.x > 0.0 and vp.y > 0.0:
		scale = win / vp
	var p := pos * scale
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)


func _dev_smoke() -> void:
	await get_tree().process_frame
	hud.HideIntro()
	sim.SetPaused(false)
	sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)
	sim.PickCrystal(Vector2i(5, 8))
	sim.InsertHeld(Vector2i(4, 8))
	await get_tree().create_timer(7.0).timeout
	var standing := false
	var pulses := 0
	for id in sim.ghosts:
		standing = standing or sim.ghosts[id].standing
		pulses += sim.ghosts[id].pulse_total
	print("SMOKE_OK standing=%s pulses=%d pulses_stat=%d budget=%d enemies=%d state=%s" % [
		str(standing), pulses, int(sim.stats.get("pulses", 0)),
		sim.economy.budget, sim.enemies.size(), String(sim.run_state),
	])
	get_tree().quit(0)


func _dev_shot() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	await _save_shot("intro")
	hud.HideIntro()
	sim.SetPaused(false)
	sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)
	sim.PickCrystal(Vector2i(5, 8))
	sim.InsertHeld(Vector2i(4, 8))
	await get_tree().create_timer(2.2).timeout
	await _save_shot("play")

	# 第二只鬼：同频，但振幅更大、射程更短。两只一起立正后拍一张干涉图。
	sim.economy.Unlock("swing")
	sim.Build("ghost", "swing", Vector2i(6, 8), 0)
	sim.Build("mechanism", "pusher", Vector2i(7, 8), 2)
	if bool(sim.PickCrystal(Vector2i(5, 6)).get("ok", false)):
		sim.InsertHeld(Vector2i(7, 8))
	await get_tree().create_timer(2.6).timeout
	await _save_shot("duo")

	# 在两只鬼的叠加点放一只厚魅，让它被清场线直接抹掉，拍下「一拱全爆」的反馈
	sim.SpawnEnemy(Vector2(-1.5, 2.0), 500.0, 0.0)
	await get_tree().create_timer(0.28).timeout
	await _save_shot("clear")
	await get_tree().create_timer(0.8).timeout

	# 甲魅与普通魅的对照：放在场边、射程外，只拍造型
	sim.SpawnEnemy(Vector2(4.6, -4.4), 130.0, 0.0, 0.4)
	sim.SpawnEnemy(Vector2(5.4, -3.2), 40.0, 0.0, 1.0)
	await get_tree().create_timer(0.5).timeout
	await _save_shot("armor")

	# 搬运手：自动化换晶的第一个形态
	sim.economy.Unlock("hand")
	sim.Build("swapper", "hand", Vector2i(7, 7))
	await get_tree().create_timer(1.0).timeout
	await _save_shot("swapper")

	# 魅王：只拍它站在场外、血条在顶上的样子
	sim.SpawnEnemy(Vector2(4.2, -4.2), 320.0, 0.19, 0.2, true)
	await get_tree().create_timer(0.6).timeout
	await _save_shot("boss")

	# 把第一波改成从西边来，让它走进鬼的射程，拍一张交战画面
	if sim.waves.defs.size() > 0:
		var groups: Array = sim.waves.defs[0].get("groups", [])
		if groups.size() > 0:
			groups[0]["center_deg"] = 180.0
	sim.waves.prep_timer = 0.1
	await get_tree().create_timer(5.0).timeout
	await _save_shot("wave")

	# 结算面板：造一份「清场流 + 半自动 + 调场」的统计，拍夜间报告
	sim.stats = {
		"pulses": 46, "killed": 14, "cleared_killed": 9, "breached": 0,
		"built": 12, "spent": 74, "manual_inserts": 3, "auto_swaps": 6, "moves": 4,
	}
	sim._win()
	await get_tree().create_timer(0.4).timeout
	await _save_shot("victory")
	get_tree().quit(0)


func _save_shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("SHOT_FAILED " + name)
		return
	var dir := "res://_shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/%s.png" % [dir, name]
	var err := img.save_png(path)
	print("SHOT %s err=%d path=%s" % [name, err, ProjectSettings.globalize_path(path)])

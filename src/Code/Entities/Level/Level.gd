class_name LevelController
extends Node3D

## 关卡流程根：装配棋盘、3D 视图、相机与 HUD，按操作优先级分派输入，处理通关与失败结算。
## 输入一律在 _unhandled_input 里直接读 keycode，不修改 project.godot 的 [input] 段。
## 操作优先级（GameDesign §5.5）：视角 → 接线 → 放置 → 切状态 → 拾取 → 交付 → 拆除。

@onready var board: Board = $Board
@onready var view: BoardView3D = $World
@onready var grid_floor: GridFloor = $World/GridFloor
@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: LevelHud = $UILayer/HUD

var level_id: int = 1
var _library: Dictionary = {}
var _running: bool = false
var _selected_ghost: StringName = &""
var _connect_mode: bool = false
var _connect_from: Vector2i = Vector2i(-1, -1)
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _right_dragging: bool = false
var _middle_dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _xray: bool = false

func _ready() -> void:
	SignalBus.LevelCompleted.connect(_on_level_completed)
	SignalBus.LevelFailed.connect(_on_level_failed)
	hud.GhostSelected.connect(_on_ghost_selected)
	hud.ConnectToggled.connect(_on_connect_toggled)
	hud.StartAllPressed.connect(_on_start_all)
	hud.ExpandSearchPressed.connect(_on_expand_search)
	hud.RemovePressed.connect(_on_remove)
	hud.XRayToggled.connect(_on_xray_toggled)
	hud.RotatePressed.connect(_on_rotate)
	hud.ZoomPressed.connect(_on_zoom)
	hud.RestartPressed.connect(_on_restart)
	hud.MenuPressed.connect(_on_menu)
	var pending := GlobalValue.TakePendingLevelId()
	StartLevel(pending if pending >= 1 else 1)

## 载入并开局一关。
## @param id 关卡序号，从 1 开始；越界时钳制到 1~3。
func StartLevel(id: int) -> void:
	level_id = clampi(id, 1, 3)
	var data := Board.LoadLevelData(level_id)
	if data == null:
		push_error("关卡资源加载失败：%d" % level_id)
		return
	_library = Board.LoadGhostLibrary()
	board.Setup(data, _library)
	_running = true
	_selected_ghost = &""
	_connect_mode = false
	_connect_from = Vector2i(-1, -1)
	_selected_cell = Vector2i(-1, -1)
	_xray = false
	var snapshot := board.GetStateSnapshot()
	grid_floor.Build(data.grid_size)
	view.BuildStatic(snapshot)
	view.SetXRay(false)
	view.SetSelected(-1)
	camera_rig.Setup(data.grid_size, data.camera_yaw, data.camera_zoom)
	hud.BuildGhostBar(data.GetAllowedGhostIds(), _library)
	hud.HideResult()
	hud.SetConnectActive(false)
	hud.SetXRayActive(false)
	hud.Refresh(snapshot)
	hud.SetViewInfo(camera_rig.GetCompassText(), camera_rig.GetZoomText())
	hud.SetHint(_make_intro_hint(data))
	view.Refresh(snapshot)
	SignalBus.LevelStarted.emit(level_id)

## 按本关配置拼开场提示：三关都有生产带，但只有开放运输鬼的关才需要讲接线规则。
## @param data 关卡数据。
## @return 一行提示文案。
func _make_intro_hint(data: LevelData) -> String:
	var only_producer := data.allowed_ghost_ids.size() == 1 and data.allowed_ghost_ids.has(&"producer")
	var hint := "绿色格是生产专属区，只能放生产鬼"
	if data.HasProducerZone():
		hint += "（本关 %d 格）" % data.GetProducerOnlyCells().size()
	hint += "；蓝色格用来接掉落物" if only_producer else "；蓝色格留给其他鬼"
	if data.allowed_ghost_ids.has(&"transporter"):
		return hint + "｜接线只许转一次 90°，被墙挡住就放一只中转鬼把线拆成两段"
	return hint + "｜本关全手动：点地面掉落物拾取，再点交付口交付"

func _process(delta: float) -> void:
	if not _running or board == null:
		return
	board.Advance(delta)
	var snapshot := board.GetStateSnapshot()
	hud.Refresh(snapshot)
	hud.SetViewInfo(camera_rig.GetCompassText(), camera_rig.GetZoomText())
	view.Refresh(snapshot)

## 统一分派输入。UI 按钮已先行消费自己的点击，这里只处理落在 3D 视口的部分。
## @param event 输入事件。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key(event)

## 处理鼠标按键：右键 / 中键 / 滚轮优先级最高，其次左键放置与点选。
## @param event 鼠标按键事件。
func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_right_dragging = event.pressed
			_last_mouse_pos = event.position
			if not event.pressed:
				camera_rig.SnapYaw()
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_MIDDLE:
			_middle_dragging = event.pressed
			_last_mouse_pos = event.position
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_UP:
			camera_rig.ZoomStep(-1)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_DOWN:
			camera_rig.ZoomStep(1)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_LEFT:
			if not event.pressed:
				return
			var cell: Vector2i
			if _selected_ghost != &"" and not _connect_mode:
				# 放置是选空格，只走地面取整，避免斜俯视下前方鬼模型挡住落点。
				cell = Picker3D.PickCell(camera_rig.GetCamera(), event.position)
			else:
				cell = _pick_cell(event.position)
			if cell.x < 0:
				return
			if _connect_mode:
				_handle_connect_click(cell)
			else:
				_handle_normal_click(cell)
			get_viewport().set_input_as_handled()

## 右键转视角、中键平移，只改相机 transform，不产生任何游戏事件。
## @param event 鼠标移动事件。
func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	var delta: Vector2 = event.position - _last_mouse_pos
	_last_mouse_pos = event.position
	if _right_dragging:
		camera_rig.DragYaw(delta.x * 0.6)
	elif _middle_dragging:
		camera_rig.PanBy(Vector3(-delta.x * 0.02, 0.0, delta.y * 0.02))

## 键盘快捷键：Q/E 八向旋转、X 透视、WASD 平移、Delete 拆除、Esc 取消。
## @param event 键盘事件。
func _on_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_Q:
			camera_rig.RotateStep(-1)
		KEY_E:
			camera_rig.RotateStep(1)
		KEY_X:
			_toggle_xray()
		KEY_DELETE, KEY_BACKSPACE:
			_on_remove()
		KEY_ESCAPE:
			_cancel_selection()
		KEY_W:
			camera_rig.PanBy(Vector3(0.0, 0.0, -0.5))
		KEY_S:
			camera_rig.PanBy(Vector3(0.0, 0.0, 0.5))
		KEY_A:
			camera_rig.PanBy(Vector3(-0.5, 0.0, 0.0))
		KEY_D:
			camera_rig.PanBy(Vector3(0.5, 0.0, 0.0))

## 先精确命中最近的鬼实体，落空再按 y=0 平面取整（CodePlan §5.9.4 两条路径）。
## @param mouse_pos 屏幕坐标。
## @return 命中的格坐标。
func _pick_cell(mouse_pos: Vector2) -> Vector2i:
	var camera := camera_rig.GetCamera()
	var ghost_cell := Picker3D.PickGhostCell(camera, mouse_pos, view.GetGhostEntries())
	if ghost_cell.x >= 0:
		return ghost_cell
	return Picker3D.PickCell(camera, mouse_pos)

## 普通点击：放置模式优先；否则点鬼切状态、点掉落物拾取、点交付口交付。
## @param cell 命中的格坐标。
func _handle_normal_click(cell: Vector2i) -> void:
	if _selected_ghost != &"":
		if board.CanPlace(_selected_ghost, cell):
			var ghost := board.PlaceGhost(_selected_ghost, cell)
			if ghost != null:
				# 放置即启动，降低课堂演示的上手门槛；点击仍可切暂停 / 待机。
				board.SetGhostStateAt(cell, GhostInstance.STATE_RUNNING)
				_selected_cell = cell
				view.SetSelected(ghost.uid)
				hud.SetHint("已放置并启动，点鬼可切换状态")
		else:
			var hint := "不能放：需在可放置区的空格，且鬼能足够"
			if board.level != null and board.level.HasProducerZone():
				if _selected_ghost == &"producer" and not board.level.IsProducerOnly(cell):
					hint = "生产鬼只能放在绿色生产专属格"
				elif board.level.IsProducerOnly(cell):
					hint = "绿色格是生产专属区，只能放生产鬼；其他鬼请放蓝色格"
			hud.SetHint(hint)
		return
	_selected_cell = cell
	var ghost := board.GetGhostAt(cell)
	if ghost != null:
		view.SetSelected(ghost.uid)
		var state := board.CycleGhostStateAt(cell)
		hud.SetHint("状态切换为 %s" % state)
		return
	view.SetSelected(-1)
	if board.GetItemAt(cell) != null:
		var amount := board.PickupItemAt(cell)
		hud.SetHint("拾取 %d 件，已入鬼能池（不计手动）" % amount)
		return
	var facility := board.GetFacilityAt(cell)
	if facility != null:
		if facility.kind == FacilityPlacement.KIND_DELIVERY:
			if board.DeliverFromPool(cell):
				hud.SetHint("交付 1 件，手动次数 +1")
			else:
				hud.SetHint("鬼能池为空，先拾取地面掉落物")
		else:
			hud.SetHint("仓库口由连线自动收货")
		return
	# 空格上若恰好有连线经过，普通模式下点一下也能拆线（掉落物已在前面被拾取）。
	if board.IsLinkBodyAt(cell) and board.RemoveLinkAtCell(cell):
		hud.SetHint("已拆除连线（点线身可拆线，接线模式 / 普通模式都行）")
		return

## 接线点击：第一下选上游鬼（点在已有线身上则直接拆线），第二下选下游鬼或设施。
## 第二下若这对起点 → 终点已经连过，再点一次就是拆除该线（toggle 语义）。
## @param cell 命中的格坐标。
func _handle_connect_click(cell: Vector2i) -> void:
	if _connect_from.x < 0:
		var start := board.GetGhostAt(cell)
		if start == null:
			if board.IsLinkBodyAt(cell) and board.RemoveLinkAtCell(cell):
				hud.SetHint("已拆除连线（接线模式下点一下线身即可拆线）")
			elif board.GetFacilityAt(cell) != null:
				hud.SetHint("设施只能作连线终点；接线起点必须是一只鬼")
			else:
				hud.SetHint("接线起点必须是一只鬼；点已有连线的线身可拆线")
			return
		if start.data.GetOutputPort() == null:
			hud.SetHint("这只鬼没有输出口（生产鬼的产出走地面掉落，要连就从采集鬼开始）")
			return
		_connect_from = cell
		hud.SetHint("已选起点，请点下游鬼或交付口 / 仓库口；重复点已连的终点可拆线")
		return
	if cell == _connect_from:
		_connect_from = Vector2i(-1, -1)
		hud.SetHint("已取消本次接线，可重新选起点")
		return
	if board.RemoveLink(_connect_from, cell):
		hud.SetHint("已拆除这条连线（同一对起点终点再点一次即拆线）")
		_connect_from = Vector2i(-1, -1)
		return
	var ok := false
	if board.GetFacilityAt(cell) != null:
		ok = board.ConnectToFacility(_connect_from, cell)
	elif board.GetGhostAt(cell) != null:
		ok = board.ConnectGhosts(_connect_from, cell)
	hud.SetHint("连线成功" if ok else "连线失败：只能转一次 90°；被墙挡住就先用中转鬼接一段，或检查标签/输出口")
	_connect_from = Vector2i(-1, -1)

## 鬼牌栏选中回调。
## @param ghost_id 鬼的资源 id。
func _on_ghost_selected(ghost_id: StringName) -> void:
	_selected_ghost = ghost_id
	_connect_mode = false
	hud.SetConnectActive(false)

## 接线模式开关回调。
## @param enabled 是否开启。
func _on_connect_toggled(enabled: bool) -> void:
	_connect_mode = enabled
	_connect_from = Vector2i(-1, -1)
	if enabled:
		_selected_ghost = &""
		hud.SetHint("接线 / 拆线：点起点鬼 → 终点建线；重复点同一终点或点线身即拆线")

## 一键启动全部鬼。
func _on_start_all() -> void:
	for ghost in board.ghosts:
		board.SetGhostStateAt(ghost.cell, GhostInstance.STATE_RUNNING)
	hud.SetHint("全部鬼已启动")

## 把当前选中的采集鬼搜索区扩为 5×5，覆盖生产群四邻；超出软上限会按 C9 变慢。
func _on_expand_search() -> void:
	var ghost := board.GetGhostAt(_selected_cell)
	if ghost == null or ghost.data.category != GhostData.CATEGORY_COLLECTION:
		hud.SetHint("先点选一只采集鬼，再扩大搜索区")
		return
	var cells: Array[Vector2i] = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var candidate: Vector2i = ghost.cell + Vector2i(dx, dy)
			if GridUtil.InBounds(candidate, board.level.grid_size):
				cells.append(candidate)
	board.SetSearchArea(ghost.cell, cells)
	hud.SetHint("采集范围扩为 %d 格（超软上限 9 格会变慢）" % cells.size())

## 拆除当前选中的鬼。
func _on_remove() -> void:
	if _selected_cell.x < 0:
		hud.SetHint("先点选一只鬼，再按 Delete 或点拆除")
		return
	if board.RemoveGhostAt(_selected_cell):
		hud.SetHint("已拆除并全额退还鬼能")
		_selected_cell = Vector2i(-1, -1)
		view.SetSelected(-1)
	else:
		hud.SetHint("该格没有可拆除的鬼")

## X-Ray 按钮回调。
## @param enabled 是否开启透视。
func _on_xray_toggled(enabled: bool) -> void:
	_xray = enabled
	view.SetXRay(_xray)

## 键盘 X 切换透视。
func _toggle_xray() -> void:
	_xray = not _xray
	view.SetXRay(_xray)
	hud.SetXRayActive(_xray)

## 相机旋转按钮回调。
## @param delta 档位增量。
func _on_rotate(delta: int) -> void:
	camera_rig.RotateStep(delta)

## 相机缩放按钮回调。
## @param delta 档位增量。
func _on_zoom(delta: int) -> void:
	camera_rig.ZoomStep(delta)

## 重开本关。
func _on_restart() -> void:
	StartLevel(level_id)

## 返回关卡选择。
func _on_menu() -> void:
	_running = false
	SceneRouter.GotoLevelSelect()

## 通关：显示结算、写入最佳星级并解锁下一关。
## @param completed_id 关卡编号。
## @param stars 结算星级。
func _on_level_completed(completed_id: int, stars: int) -> void:
	_running = false
	hud.ShowResult(board.GetStateSnapshot(), true)
	SaveManager.SetBestStars(completed_id, stars)
	SaveManager.UnlockLevel(completed_id + 1)
	SaveManager.SetCurrentLevel(mini(completed_id + 1, ExportSettings.level_count))
	SaveManager.SaveGame()

## 超时失败：显示结算面板。
## @param failed_id 关卡编号。
func _on_level_failed(failed_id: int) -> void:
	_running = false
	hud.ShowResult(board.GetStateSnapshot(), false)

## Esc 取消放置与接线模式。
func _cancel_selection() -> void:
	_selected_ghost = &""
	_connect_mode = false
	_connect_from = Vector2i(-1, -1)
	hud.SetConnectActive(false)
	hud.SetHint("已取消放置 / 接线模式")

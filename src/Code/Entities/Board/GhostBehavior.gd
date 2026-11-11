class_name GhostBehavior
extends RefCounted

## 鬼行为基类（静态分派）。每只鬼只描述「自己被推进一个 tick 时做什么」，
## 摆在一起会涌现出什么由连线与物理联动决定，不设组合规则表（GameDesign §8）。
##
## 注意：这里的 board 参数刻意不标注具体类型，避免与 Board.gd 形成脚本级循环依赖；
## 调用方必须传已 Setup 过的 Board 实例。

## 推进一只运行中的鬼一个 tick。
## @param board 已初始化的 Board 实例。
## @param ghost 待推进的 GhostInstance。
## @param dt 本 tick 的时长，单位：秒。
static func RunTick(board, ghost, dt: float) -> void:
	if ghost == null or ghost.data == null:
		return
	# 推动链专用行为优先：只要 .tres 带了 behavior_id，就只跑它自己的那段，
	# 不给四个大类加判定分支（Docs/GameDesign.md §8.1「不设组合规则表」）。
	match ghost.data.behavior_id:
		&"pusher":
			_pusher_tick(board, ghost, dt)
			return
		&"hang":
			_hang_tick(board, ghost, dt)
			return
	match ghost.data.category:
		GhostData.CATEGORY_PRODUCTION:
			_producer_tick(board, ghost, dt)
		GhostData.CATEGORY_COLLECTION:
			_collector_tick(board, ghost, dt)
		GhostData.CATEGORY_PROCESSING:
			_processor_tick(board, ghost, dt)
		GhostData.CATEGORY_TRANSPORT:
			_transporter_tick(board, ghost, dt)

## 生产鬼：每 2.0 s 产 1 个鬼能，优先掉在四邻空格；四邻满则进自身缓冲，缓冲满进故障。
## @param board 棋盘实例。
## @param ghost 生产鬼实例。
## @param dt 本 tick 时长，单位：秒。
static func _producer_tick(board, ghost, dt: float) -> void:
	var cycle := maxf(ExportSettings.sim_producer_cycle, 0.05)
	ghost.timer += dt
	if ghost.timer < cycle:
		return
	ghost.timer -= cycle
	var empty: Array[Vector2i] = board.grid.GetEmptyNeighbors(ghost.cell)
	if not empty.is_empty():
		var cell: Vector2i = empty[board.rng.randi_range(0, empty.size() - 1)]
		# 缓冲里有存货时优先把手上的吐出来，产出总数不变。
		if not ghost.output_buffer.is_empty():
			ghost.output_buffer.pop_front()
		board.SpawnItem(cell, "Spirit", 1)
		SignalBus.SpiritProduced.emit(1)
		SignalBus.SpiritDropped.emit(cell, 1)
		board.MarkChanged()
	elif not ghost.IsOutputFull():
		ghost.output_buffer.append("Spirit")
		SignalBus.BufferStateChanged.emit(board, ghost.IsOutputFull())
		board.MarkChanged()
	else:
		board.SetFault(ghost)

## 采集鬼：在搜索区内逐格找最近的掉落物，拾进输出缓冲；输出满则背压等待。
## @param board 棋盘实例。
## @param ghost 采集鬼实例。
## @param dt 本 tick 时长，单位：秒。
static func _collector_tick(board, ghost, dt: float) -> void:
	if ghost.IsOutputFull():
		return
	var cells: Array[Vector2i] = board.GetSearchCells(ghost)
	# 搜索区软上限 9 格，每超 1 格步进 +10%（GameDesign §13）。
	var penalty := 1.0 + float(maxi(0, cells.size() - ExportSettings.sim_search_soft_cap)) * 0.10
	var interval := maxf(ExportSettings.sim_collector_interval * penalty, 0.05)
	ghost.timer += dt
	if ghost.timer < interval:
		return
	ghost.timer -= interval
	var best_cell := Vector2i(-1, -1)
	var best_dist := 2147483647
	for cell in board.grid.GetAllItemCells():
		if not cells.has(cell):
			continue
		if not _has_reachable_neighbor(board, ghost, cell):
			continue
		var dist := GridUtil.Manhattan(ghost.cell, cell)
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
	if best_cell.x < 0:
		return
	var item = board.grid.GetItemAt(best_cell)
	if item == null:
		return
	var form := String(item.form)
	if board.ConsumeItem(best_cell, 1):
		ghost.output_buffer.append(form)
		board.MarkChanged()

## 判断掉落物四邻是否至少有一格可达（GameDesign §4.8.1 相邻格拾取）。
## @param board 棋盘实例。
## @param ghost 采集鬼实例。
## @param cell 掉落物所在格。
## @return 可达时返回 true。
static func _has_reachable_neighbor(board, ghost, cell: Vector2i) -> bool:
	for neighbor in GridUtil.Neighbors4(cell):
		if neighbor == ghost.cell or board.grid.IsFree(neighbor):
			return true
	return false

## 运输鬼：把输入缓冲里的一件原样转进输出缓冲，供下游连线取走。
## 沿线的实际搬运由 BoardRunner 按连线结算。
## @param board 棋盘实例。
## @param ghost 运输鬼实例。
## @param dt 本 tick 时长，单位：秒。
static func _transporter_tick(board, ghost, dt: float) -> void:
	if ghost.input_buffer.is_empty() or ghost.IsOutputFull():
		return
	ghost.timer += dt
	if ghost.timer < maxf(ExportSettings.sim_transporter_interval, 0.01):
		return
	ghost.timer -= maxf(ExportSettings.sim_transporter_interval, 0.01)
	ghost.output_buffer.append(ghost.input_buffer.pop_front())
	board.MarkChanged()

## 处理鬼：按配方把鬼能加工成贡品，每 4 件额外产 1 件杂质；杂质回收成鬼能。
## @param board 棋盘实例。
## @param ghost 处理鬼实例。
## @param dt 本 tick 时长，单位：秒。
static func _processor_tick(board, ghost, dt: float) -> void:
	if ghost.input_buffer.is_empty():
		ghost.fault_timer += dt
		if ghost.fault_timer >= ExportSettings.sim_fault_timeout:
			board.SetFault(ghost)
		return
	ghost.fault_timer = 0.0
	if ghost.IsOutputFull():
		return
	var form := String(ghost.input_buffer[0])
	var interval := maxf(ExportSettings.sim_processor_cycle, 0.05)
	if form == "Impurity":
		interval = maxf(ExportSettings.sim_processor_recycle_interval, 0.05)
	ghost.timer += dt
	if ghost.timer < interval:
		return
	ghost.timer -= interval
	ghost.input_buffer.pop_front()
	var output_form: StringName
	if form == "Impurity":
		ghost.output_buffer.append("Spirit")
		output_form = &"Spirit"
	else:
		ghost.output_buffer.append("Offer")
		output_form = &"Offer"
		ghost.process_counter += 1
		if ghost.process_counter % 4 == 0:
			board.SpawnImpurityNear(ghost.cell)
	SignalBus.ItemProcessed.emit(output_form)
	board.MarkChanged()

## 推舌鬼：每 2.0 s 朝四邻中的柔体出舌，把整条链推开一格（Docs/Ghosts.md 推舌鬼）。
## 策划案写的是「抓住后拉近再推出」，以格结算时「拉近一格」与「推开一格」是同一个位移，
## 这里只做推，避免一次出舌动两格破坏「一格是最小结算单位」（GameDesign §8.2）。
## @param board 棋盘实例。
## @param ghost 推舌鬼实例。
## @param dt 本 tick 时长，单位：秒。
static func _pusher_tick(board, ghost, dt: float) -> void:
	var cycle := maxf(ExportSettings.sim_pusher_cycle, 0.05)
	ghost.timer += dt
	if ghost.timer < cycle:
		return
	var directions := PushResolver.PushableDirections(board, ghost.cell)
	if directions.is_empty():
		return
	ghost.timer -= cycle
	var direction: Vector2i = directions[board.rng.randi_range(0, directions.size() - 1)]
	var result := PushResolver.TryPush(board, ghost.cell, direction)
	if bool(result["ok"]):
		ghost.process_counter += 1
		board.MarkChanged()

## 吊死鬼：被推动后下一 tick 沿反方向荡回原位，是推动链的中继（Docs/Ghosts.md 吊死鬼）。
## @param board 棋盘实例。
## @param ghost 吊死鬼实例。
## @param dt 本 tick 时长，单位：秒。
static func _hang_tick(board, ghost, dt: float) -> void:
	if ghost.sway_dir == Vector2i.ZERO:
		return
	var back: Vector2i = ghost.cell - ghost.sway_dir
	ghost.sway_dir = Vector2i.ZERO
	board.MoveGhost(ghost, back)

## 被推动链推动后的反应。每只鬼只描述自己的反应，组合结果由摆放几何涌现。
## @param board 棋盘实例。
## @param ghost 被推动的鬼实例。
## @param direction 本次推力的世界四邻方向。
static func OnPushed(board, ghost, direction: Vector2i) -> void:
	match ghost.data.behavior_id:
		&"miser":
			# 守财鬼：被推一次掉 1 鬼能——永动机引擎的核心件。
			var empty: Array[Vector2i] = board.grid.GetEmptyNeighbors(ghost.cell)
			if empty.is_empty():
				return
			var cell: Vector2i = empty[board.rng.randi_range(0, empty.size() - 1)]
			board.SpawnItem(cell, "Spirit", 1)
			SignalBus.SpiritProduced.emit(1)
			SignalBus.SpiritDropped.emit(cell, 1)
			board.MarkChanged()
		&"hang":
			# 记下推力方向，下一 tick 荡回原位。
			ghost.sway_dir = direction
		_:
			pass

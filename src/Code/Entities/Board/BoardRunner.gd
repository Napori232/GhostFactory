class_name BoardRunner
extends RefCounted

## 全局时序驱动。按固定 tick 推进：先收集并执行每只运行中的鬼的自身行为，
## 再沿已建立的连线结算搬运与交付。所有判定只认 Vector2i 格坐标。

## 推进一个 tick。
## @param board 已初始化的 Board 实例。
## @param dt 本 tick 时长，单位：秒。
static func RunTick(board, dt: float) -> void:
	for ghost in board.ghosts:
		if ghost.state != GhostInstance.STATE_RUNNING:
			continue
		GhostBehavior.RunTick(board, ghost, dt)
	_run_links(board, dt)

## 沿连线搬运：运输耗时按路径实际经过的格数 × 每格步进；下游缓冲满则背压停止。
## @param board 棋盘实例。
## @param dt 本 tick 时长，单位：秒。
static func _run_links(board, dt: float) -> void:
	for link in board.connections.links:
		var from = board.FindGhostByUid(int(link["from_uid"]))
		if from == null or from.state != GhostInstance.STATE_RUNNING:
			continue
		if from.output_buffer.is_empty():
			continue
		var to_cell: Vector2i = link["to_cell"]
		# 连线是贴地管路，途经每一格都要走：绕墙的弯越多，输送越慢（策划案「连线每经过一格占一格」）。
		var path_cells: Array = link["path"]
		var distance := maxi(1, path_cells.size() - 1)
		# 连线是管道抽象：路径长度按 0.3 s/格计入，管线容量允许多件并行在途，
		# 避免长距离线路把吞吐压到无法通关（sim_line_capacity 默认 3）。
		var capacity := maxi(1, ExportSettings.sim_line_capacity)
		var travel := maxf(ExportSettings.sim_transporter_interval, 0.01) * float(distance) / float(capacity)
		travel = maxf(travel, ExportSettings.sim_transporter_interval)
		link["timer"] = float(link["timer"]) + dt
		if float(link["timer"]) < travel:
			continue
		link["timer"] = 0.0
		var form := String(from.output_buffer[0])
		var to_uid := int(link["to_uid"])
		if to_uid == ConnectionLayer.NO_GHOST:
			var facility = board.GetFacilityAt(to_cell)
			if facility == null:
				continue
			if board.DeliverToFacility(form, facility, false):
				from.output_buffer.pop_front()
				board.MarkChanged()
			else:
				SignalBus.LineBlocked.emit(board)
		else:
			var to = board.FindGhostByUid(to_uid)
			if to == null or to.IsInputFull():
				SignalBus.LineBlocked.emit(board)
				continue
			from.output_buffer.pop_front()
			to.input_buffer.append(form)
			SignalBus.BufferStateChanged.emit(board, to.IsInputFull())
			board.MarkChanged()

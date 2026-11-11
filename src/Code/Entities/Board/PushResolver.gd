class_name PushResolver
extends RefCounted

## 推动链结算（Docs/GameDesign.md §8.3、Docs/PhysicsLayer.md §3）。
##
## 规则只有三条：
##   1. 推力沿世界四邻方向逐格推进，推力方向与相机朝向无关；
##   2. 柔体让位一格，刚体是止点——链撞上刚体则整条链都不动；
##   3. 位移以格为最小结算单位，动画只负责把这一格铺顺。
##
## 本文件只读写 Vector2i 格坐标，不认识任何表现层节点，也不引入 3D 物理。

## 单条推动链的最大长度，防止首尾相接的环形布局把循环跑死。
const MAX_CHAIN: int = 32

## 尝试从 origin 格沿 direction 推开一条链。
## @param board 已初始化的棋盘实例。
## @param origin 推力起点格（通常是推舌鬼自身所在格，不含在链内）。
## @param direction 世界四邻方向之一。
## @return {ok: bool, chain: Array, reason: String}；
##         chain 为被推动的鬼，按由近到远排列；ok 为 false 时 chain 为空。
static func TryPush(board, origin: Vector2i, direction: Vector2i) -> Dictionary:
	if direction == Vector2i.ZERO:
		return {"ok": false, "chain": [], "reason": "方向无效"}
	var chain: Array = []
	var cursor := origin + direction
	var steps := 0
	while steps < MAX_CHAIN:
		steps += 1
		if not GridUtil.InBounds(cursor, board.level.grid_size):
			return {"ok": false, "chain": [], "reason": "出界"}
		if board.grid.obstacles.has(cursor):
			return {"ok": false, "chain": [], "reason": "障碍"}
		if board.grid.facility_cells.has(cursor):
			return {"ok": false, "chain": [], "reason": "设施"}
		if board.grid.GetItemAt(cursor) != null:
			return {"ok": false, "chain": [], "reason": "掉落物占格"}
		var ghost = board.grid.GetGhostAt(cursor)
		if ghost == null:
			break
		# 刚体是止点：推力到它为止，整条链一格都不动。
		if ghost.data.movability != GhostData.MOVABILITY_SOFT:
			return {"ok": false, "chain": [], "reason": "刚体止点"}
		chain.append(ghost)
		cursor += direction
	if chain.is_empty():
		return {"ok": false, "chain": [], "reason": "前方无鬼"}
	# 从链尾往链头依次挪，避免前方格还占着自己的老位置。
	for index in range(chain.size() - 1, -1, -1):
		var mover = chain[index]
		if not board.MoveGhost(mover, mover.cell + direction):
			return {"ok": false, "chain": [], "reason": "目标格被占"}
	# 每只鬼只描述自己被推时的反应，组合效果由摆放几何决定（GameDesign §8.1）。
	for pushed in chain:
		GhostBehavior.OnPushed(board, pushed, direction)
	return {"ok": true, "chain": chain, "reason": ""}

## 取某格四邻中可以推动的方向，用于推舌鬼选方向。
## @param board 棋盘实例。
## @param origin 推舌鬼所在格。
## @return 四邻中「下一格是柔体鬼」的方向数组。
static func PushableDirections(board, origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in GridUtil.Neighbors4(Vector2i.ZERO):
		var neighbor: Vector2i = origin + direction
		if not GridUtil.InBounds(neighbor, board.level.grid_size):
			continue
		var ghost = board.grid.GetGhostAt(neighbor)
		if ghost != null and ghost.data.movability == GhostData.MOVABILITY_SOFT:
			result.append(direction)
	return result

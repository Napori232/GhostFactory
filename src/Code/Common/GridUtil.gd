class_name GridUtil
extends RefCounted

## 网格几何工具。纯静态函数集合，不持有任何状态。
## 网格坐标用 Vector2i 表示，(0,0) 为左上角；世界坐标以格子左上角为原点，格子中心偏移半个 CELL_SIZE。

## 一格的世界像素尺寸。
const CELL_SIZE: float = 64.0

## 格子中心的半格偏移量。
const HALF_CELL: float = CELL_SIZE * 0.5

## 格子左上角的世界坐标。
## @param cell 网格坐标。
## @return 该格左上角的世界坐标，例如 (0,0) 返回 (0,0)。
static func CellToWorldCorner(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * CELL_SIZE, float(cell.y) * CELL_SIZE)

## 格子中心的世界坐标。
## @param cell 网格坐标。
## @return 该格中心的世界坐标，例如 (0,0) 返回 (32,32)。
static func CellToWorld(cell: Vector2i) -> Vector2:
	return CellToWorldCorner(cell) + Vector2(HALF_CELL, HALF_CELL)

## 世界坐标反查格子。
## @param world 世界坐标。
## @return 该世界坐标所在的网格坐标。
static func WorldToCell(world: Vector2) -> Vector2i:
	return Vector2i(int(floor(world.x / CELL_SIZE)), int(floor(world.y / CELL_SIZE)))

## 判断格子是否在给定尺寸内。
## @param cell 待判断的网格坐标。
## @param size 网格尺寸（格）。
## @return 越界时返回 false。
static func InBounds(cell: Vector2i, size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y

## 取得四邻格（不含自身）。
## @param cell 中心格。
## @return 顺序固定为 上、右、下、左 的四个格子。
static func Neighbors4(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.append(cell + Vector2i(0, -1))
	result.append(cell + Vector2i(1, 0))
	result.append(cell + Vector2i(0, 1))
	result.append(cell + Vector2i(-1, 0))
	return result

## 两格之间的曼哈顿距离。
## @param a 起点格。
## @param b 终点格。
## @return |dx| + |dy|。
static func Manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## 归一化一组占位格：去重并整体平移到最小 (0,0)。
## @param cells 相对偏移格列表。
## @return 去重、平移后按 (y, x) 排序的数组；输入为空时返回空数组。
static func NormalizeFootprint(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.is_empty():
		return []
	var unique: Dictionary = {}
	var min_coord := Vector2i(2147483647, 2147483647)
	for c in cells:
		unique[c] = true
		min_coord = Vector2i(mini(min_coord.x, c.x), mini(min_coord.y, c.y))
	var result: Array[Vector2i] = []
	for c: Vector2i in unique.keys():
		result.append(c - min_coord)
	result.sort_custom(_compare_cell)
	return result

## 计算一组占位格的包围盒。
## @param cells 占位格列表。
## @return 包围盒；输入为空时返回零矩形。
static func FootprintBounds(cells: Array[Vector2i]) -> Rect2i:
	if cells.is_empty():
		return Rect2i(Vector2i.ZERO, Vector2i.ZERO)
	var min_coord := Vector2i(2147483647, 2147483647)
	var max_coord := Vector2i(-2147483648, -2147483648)
	for c in cells:
		min_coord = Vector2i(mini(min_coord.x, c.x), mini(min_coord.y, c.y))
		max_coord = Vector2i(maxi(max_coord.x, c.x), maxi(max_coord.y, c.y))
	return Rect2i(min_coord, max_coord - min_coord + Vector2i.ONE)

## 整体平移一组占位格。
## @param cells 占位格列表。
## @param offset 平移量（格）。
## @return 平移后的新数组，不修改入参。
static func Translate(cells: Array[Vector2i], offset: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c in cells:
		result.append(c + offset)
	return result

## 求两组占位格的重叠部分。
## @param a 第一组占位格。
## @param b 第二组占位格。
## @return 同时属于两组的格子（去重并排序）；无重叠时返回空数组。
static func Overlap(a: Array[Vector2i], b: Array[Vector2i]) -> Array[Vector2i]:
	var set_b: Dictionary = {}
	for c in b:
		set_b[c] = true
	var result: Array[Vector2i] = []
	var seen: Dictionary = {}
	for c in a:
		if set_b.has(c) and not seen.has(c):
			seen[c] = true
			result.append(c)
	result.sort_custom(_compare_cell)
	return result

## 生成两点之间的 L 形折线路径。
## @param from_cell 起点格。
## @param to_cell 终点格。
## @param prefer_x_first true 表示先走 X 轴再走 Y 轴，false 反之。
## @return 含起点与终点的路径格列表，路径正交不斜。
static func PathL(from_cell: Vector2i, to_cell: Vector2i, prefer_x_first: bool = true) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	path.append(from_cell)
	if prefer_x_first:
		var step_x := signi(to_cell.x - from_cell.x)
		if step_x != 0:
			var x := from_cell.x + step_x
			while true:
				path.append(Vector2i(x, from_cell.y))
				if x == to_cell.x:
					break
				x += step_x
		var step_y := signi(to_cell.y - from_cell.y)
		if step_y != 0:
			var y := from_cell.y + step_y
			while true:
				path.append(Vector2i(to_cell.x, y))
				if y == to_cell.y:
					break
				y += step_y
	else:
		var step_y2 := signi(to_cell.y - from_cell.y)
		if step_y2 != 0:
			var y2 := from_cell.y + step_y2
			while true:
				path.append(Vector2i(from_cell.x, y2))
				if y2 == to_cell.y:
					break
				y2 += step_y2
		var step_x2 := signi(to_cell.x - from_cell.x)
		if step_x2 != 0:
			var x2 := from_cell.x + step_x2
			while true:
				path.append(Vector2i(x2, to_cell.y))
				if x2 == to_cell.x:
					break
				x2 += step_x2
	return path

## 生成两点之间绕开障碍的正交最短路径（广度优先搜索）。
## 起终点总是保留在路径里；两点之间被障碍完全隔断时返回空数组。
## @param from_cell 起点格。
## @param to_cell 终点格。
## @param is_blocked 判定某格不可通行的回调，签名 (cell: Vector2i) -> bool。
## @param bounds 网格尺寸，用于裁剪搜索范围。
## @return 含起点与终点的路径格列表；不可达时为空数组。
static func PathAvoiding(from_cell: Vector2i, to_cell: Vector2i, is_blocked: Callable, bounds: Vector2i) -> Array[Vector2i]:
	if not InBounds(from_cell, bounds) or not InBounds(to_cell, bounds):
		return []
	if from_cell == to_cell:
		var single: Array[Vector2i] = [from_cell]
		return single
	var came_from: Dictionary = {}
	var visited: Dictionary = {from_cell: true}
	var queue: Array[Vector2i] = [from_cell]
	var found := false
	while not queue.is_empty() and not found:
		var current: Vector2i = queue.pop_front()
		for next in Neighbors4(current):
			if visited.has(next) or not InBounds(next, bounds):
				continue
			if next != to_cell and bool(is_blocked.call(next)):
				continue
			visited[next] = true
			came_from[next] = current
			if next == to_cell:
				found = true
				break
			queue.append(next)
	if not found:
		return []
	var path: Array[Vector2i] = [to_cell]
	var cursor: Vector2i = to_cell
	while cursor != from_cell:
		cursor = came_from[cursor]
		path.append(cursor)
	path.reverse()
	return path

## 生成「最多一次 90° 转弯」的 L 形连线路径，并绕开障碍格。
## 依次尝试两种走向（先 X 后 Y / 先 Y 后 X），取较短且全程不撞墙的一条；
## 两种都撞墙时返回空数组——此时必须靠中转鬼把线路拆成两段（每段各一次转弯）。
## 与 PathAvoiding 的区别：本函数不允许折返式绕行，是为了让墙真正逼出「物理联动」。
## @param from_cell 起点格。
## @param to_cell 终点格。
## @param is_blocked 判定某格不可通行的回调，签名 (cell: Vector2i) -> bool。
## @param bounds 网格尺寸，用于裁剪路径范围。
## @return 含起点与终点的路径格列表；无合法 L 形路径时为空数组。
static func PathOneTurn(from_cell: Vector2i, to_cell: Vector2i, is_blocked: Callable, bounds: Vector2i) -> Array[Vector2i]:
	if not InBounds(from_cell, bounds) or not InBounds(to_cell, bounds):
		return []
	var best: Array[Vector2i] = []
	for i in range(2):
		var prefer_x_first := i == 0
		var candidate := PathL(from_cell, to_cell, prefer_x_first)
		var valid := true
		for cell in candidate:
			if not InBounds(cell, bounds):
				valid = false
				break
			if cell != from_cell and cell != to_cell and bool(is_blocked.call(cell)):
				valid = false
				break
		if not valid:
			continue
		if best.is_empty() or candidate.size() < best.size():
			best = candidate
	return best

## 统计一条正交路径的 90° 转弯次数。
## @param path 含起点与终点的路径格列表。
## @return 转弯次数；直线为 0，L 形为 1。
static func CountTurns(path: Array[Vector2i]) -> int:
	if path.size() < 3:
		return 0
	var turns := 0
	var previous := path[1] - path[0]
	for i in range(2, path.size()):
		var direction: Vector2i = path[i] - path[i - 1]
		if direction != previous:
			turns += 1
		previous = direction
	return turns

## 把任意数组转换成 Vector2i 数组。
## 编辑器赋值、脚本动态赋值都可能给出无类型数组，这里统一转换，避免 setter 因类型不匹配而丢值。
## @param value 原始值，可以是 Array[Vector2i]、Array 或单个 Vector2i。
## @return 转换后的格子数组；无法识别的元素被跳过。
static func ToCellArray(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if value is Array:
		for item in value:
			if item is Vector2i:
				result.append(item)
			elif item is Vector2:
				result.append(Vector2i(item))
	elif value is Vector2i:
		result.append(value)
	return result

## 格子排序比较：先 y 后 x。
## @param a 左操作数。
## @param b 右操作数。
## @return a 是否排在 b 前面。
static func _compare_cell(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x

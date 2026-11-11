class_name Picker3D
extends RefCounted

## 3D 拾取。两条路径：
## 1) 屏幕射线 → y=0 平面求交 → 格坐标，负责选空格与放置预览；
## 2) 与鬼占位 AABB 求交，只取最近命中，负责选中已有鬼（CodePlan §5.9.4）。
## 相机绕场景中心旋转，格子始终在 XZ 平面轴对齐，因此与偏航无关。

## 表示未命中任何格子。
const NO_CELL: Vector2i = Vector2i(-1, -1)

## 射线打到 y=0 平面后取整，得到格坐标。
## @param camera 正交相机节点。
## @param mouse_pos 屏幕坐标（像素）。
## @return 命中的格坐标；射线与地面平行时返回 NO_CELL。
static func PickCell(camera: Camera3D, mouse_pos: Vector2) -> Vector2i:
	if camera == null:
		return NO_CELL
	var origin := camera.project_ray_origin(mouse_pos)
	var normal := camera.project_ray_normal(mouse_pos)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(origin, normal)
	if hit == null:
		return NO_CELL
	return Grid3D.World3DToCell(hit)

## 只命中最前面的可见鬼实体；被完全遮挡的鬼不会被点到，需转视角或开 X-Ray。
## @param camera 正交相机节点。
## @param mouse_pos 屏幕坐标（像素）。
## @param ghost_entries 鬼占位条目数组，每项含 cell（Vector2i）。
## @return 最近命中的鬼所在格；无命中返回 NO_CELL。
static func PickGhostCell(camera: Camera3D, mouse_pos: Vector2, ghost_entries: Array[Dictionary]) -> Vector2i:
	if camera == null:
		return NO_CELL
	var origin := camera.project_ray_origin(mouse_pos)
	var normal := camera.project_ray_normal(mouse_pos)
	var best_cell := NO_CELL
	var best_distance := INF
	var half := Vector3(0.4, 0.4, 0.4)
	for entry in ghost_entries:
		var cell: Vector2i = entry.get("cell", NO_CELL)
		if cell == NO_CELL:
			continue
		var center: Vector3 = Grid3D.CellToWorld3DCenter(cell) + Vector3(0.0, 0.4, 0.0)
		var bounds := AABB(center - half, half * 2.0)
		var hit = bounds.intersects_ray(origin, normal)
		if hit == null:
			continue
		var distance: float = origin.distance_to(hit)
		if distance < best_distance:
			best_distance = distance
			best_cell = cell
	return best_cell

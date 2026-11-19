class_name SimGrid
extends RefCounted
## 只负责「格子坐标 <-> 世界平面坐标」与边界判定。
## 刻意不保存占用表：占用只在 Sim 里存一份，避免两套真相打架。

var width: int = 13
var height: int = 13
var cell_size: float = 1.0
var build_rect: Rect2i = Rect2i(1, 1, 11, 11)


## 配置尺寸与可放置区域。
func Configure(w: int, h: int, cs: float, build: Rect2i) -> void:
	width = maxi(1, w)
	height = maxi(1, h)
	cell_size = maxf(0.01, cs)
	build_rect = build


## 格子中心的世界平面坐标（x, z）。场地中心为原点。
func CellToWorld(cell: Vector2i) -> Vector2:
	return Vector2(
		(float(cell.x) - float(width - 1) * 0.5) * cell_size,
		(float(cell.y) - float(height - 1) * 0.5) * cell_size)


## 世界平面坐标落在哪个格子。
func WorldToCell(world: Vector2) -> Vector2i:
	var fx := world.x / cell_size + float(width - 1) * 0.5
	var fy := world.y / cell_size + float(height - 1) * 0.5
	return Vector2i(roundi(fx), roundi(fy))


## 是否在场地内（含不可放置的边缘行）。
func InField(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## 是否在可放置区域内。
func InBuildArea(cell: Vector2i) -> bool:
	return build_rect.has_point(cell)


## 场地外接半径（世界单位），刷怪环用。
func FieldRadius() -> float:
	return Vector2(float(width), float(height)).length() * 0.5 * cell_size

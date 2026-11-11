class_name Grid3D
extends RefCounted

## 3D 表现层专用的坐标换算。只做「格坐标 <-> 世界坐标」，不含任何玩法判定。
## 逻辑世界是单层平面网格（Docs/GameDesign.md §5.7），放在 y=0 的 XZ 平面上；
## Godot +Z 朝南，而逻辑 y 向北为正，所以 z 取负。
##
## 注意：GridUtil 是 2D 像素系（CELL_SIZE=64），两者不可混用。

## 一格的世界单位长度。Docs/GameDesign.md §13：1 格 = 1.0 世界单位。
const CELL: float = 1.0
## 八向吸附的单档角度（度）。
const YAW_STEP: float = 45.0

## 格坐标换世界坐标，返回该格的原点（西北角）。
## @param cell 格坐标，y 向北为正。
## @return 世界坐标 (x * CELL, 0, -y * CELL)。
static func CellToWorld3D(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * CELL, 0.0, -float(cell.y) * CELL)

## 格坐标换世界坐标，返回该格的中心点。
## @param cell 格坐标。
## @return 格中心的世界坐标，用于摆放模型。
static func CellToWorld3DCenter(cell: Vector2i) -> Vector3:
	return Vector3((float(cell.x) + 0.5) * CELL, 0.0, -(float(cell.y) + 0.5) * CELL)

## 世界坐标反查格坐标。射线打到 y=0 平面后调用，与相机朝向无关。
## @param pos 世界坐标。
## @return 所在的格坐标。
static func World3DToCell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(-pos.z / CELL))

## 整张地台的中心点，供相机围绕场景旋转用。
## @param grid_size 网格尺寸（格）。
## @return 地台中心的世界坐标。
static func GridCenter3D(grid_size: Vector2i) -> Vector3:
	return Vector3(float(grid_size.x) * CELL * 0.5, 0.0, -float(grid_size.y) * CELL * 0.5)

## 把任意偏航角吸附到最近的 45° 档。
## @param degrees 输入角度（度），可为任意实数。
## @return 45 的整数倍角度，已归一化到 [0, 360)。
static func SnapYawDegrees(degrees: float) -> float:
	var snapped := roundf(degrees / YAW_STEP) * YAW_STEP
	return fmod(fmod(snapped, 360.0) + 360.0, 360.0)

## 把档位序号换成偏航角。
## @param step 档位序号，0~7 对应八个方位。
## @return 已归一化的角度（度）。
static func YawStepToDegrees(step: int) -> float:
	return SnapYawDegrees(float(step) * YAW_STEP)

## 三档缩放对应的正交相机视野高度，单位：格。
## @param zoom_level 缩放档位，0 / 1 / 2。
## @return 视野高度 8 / 12 / 16，越界时钳制到合法档位。
static func ZoomLevelToSize(zoom_level: int) -> float:
	const SIZES: Array[float] = [8.0, 12.0, 16.0]
	return SIZES[clampi(zoom_level, 0, SIZES.size() - 1)]

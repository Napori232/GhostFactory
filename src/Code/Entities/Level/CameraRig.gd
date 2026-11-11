class_name CameraRig
extends Node3D

## 斜俯视相机支架。俯仰固定 -45°，偏航按 45° 八档吸附，缩放三档 8 / 12 / 16 格。
## 硬约束（GameDesign §5.4）：相机只写自己的 transform，不回调玩法层、
## 不触发意图、不消耗关卡时间、不改变任何格坐标。

## 八个方位的中文名，索引与 yaw 档位一致。
const COMPASS_NAMES: Array[String] = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]

@onready var camera: Camera3D = $Camera3D

var grid_size: Vector2i = Vector2i(10, 8)
var yaw_step: int = 0
var zoom_level: int = 1

var _center: Vector3 = Vector3.ZERO
var _yaw_tween: Tween = null
var _zoom_tween: Tween = null

## 按关卡初始档位装配相机。
## @param size 网格尺寸（格）。
## @param initial_yaw 初始偏航档位 0~7。
## @param initial_zoom 初始缩放档位 0~2。
func Setup(size: Vector2i, initial_yaw: int, initial_zoom: int) -> void:
	grid_size = size
	_center = Grid3D.GridCenter3D(size)
	position = _center
	yaw_step = clampi(initial_yaw, 0, 7)
	zoom_level = clampi(initial_zoom, 0, 2)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(ExportSettings.view_pitch_degrees, 0.0, 0.0)
	camera.position = Vector3(0.0, 12.0, 12.0)
	camera.size = Grid3D.ZoomLevelToSize(zoom_level)
	camera.near = 0.1
	camera.far = 200.0
	rotation_degrees = Vector3(0.0, Grid3D.YawStepToDegrees(yaw_step), 0.0)

## 取相机节点，供射线拾取使用。
## @return 正交相机节点。
func GetCamera() -> Camera3D:
	return camera

## 键盘八向旋转，带 0.2 s 补间。
## @param delta 档位增量，+1 顺时针一档，-1 逆时针一档。
func RotateStep(delta: int) -> void:
	yaw_step = (yaw_step + delta + 8) % 8
	_tween_yaw(Grid3D.YawStepToDegrees(yaw_step))

## 右键拖拽期间实时跟手（不吸附）。
## @param degrees_delta 本次鼠标位移换算出的偏航增量（度）。
func DragYaw(degrees_delta: float) -> void:
	if _yaw_tween != null and _yaw_tween.is_valid():
		_yaw_tween.kill()
	rotation_degrees.y = wrapf(rotation_degrees.y + degrees_delta, 0.0, 360.0)

## 松手后吸附到最近的 45° 档。
func SnapYaw() -> void:
	var snapped := Grid3D.SnapYawDegrees(rotation_degrees.y)
	yaw_step = int(roundf(snapped / Grid3D.YAW_STEP)) % 8
	_tween_yaw(snapped)

## 滚轮三档缩放，带 0.15 s 补间。
## @param delta 档位增量，+1 拉远，-1 拉近。
func ZoomStep(delta: int) -> void:
	zoom_level = clampi(zoom_level + delta, 0, 2)
	var target := Grid3D.ZoomLevelToSize(zoom_level)
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(camera, "size", target, ExportSettings.view_zoom_duration)

## 平移相机支架，限制在地台边界内。
## @param delta 世界坐标位移。
func PanBy(delta: Vector3) -> void:
	var half_x := float(grid_size.x) * Grid3D.CELL * 0.5
	var half_z := float(grid_size.y) * Grid3D.CELL * 0.5
	var target := position + delta
	target.x = clampf(target.x, _center.x - half_x, _center.x + half_x)
	target.z = clampf(target.z, _center.z - half_z, _center.z + half_z)
	position = target

## 复位到关卡初始取景。
## @param initial_yaw 初始偏航档位。
## @param initial_zoom 初始缩放档位。
func ResetView(initial_yaw: int, initial_zoom: int) -> void:
	position = _center
	zoom_level = clampi(initial_zoom, 0, 2)
	camera.size = Grid3D.ZoomLevelToSize(zoom_level)
	yaw_step = clampi(initial_yaw, 0, 7)
	_tween_yaw(Grid3D.YawStepToDegrees(yaw_step))

## 取当前方位文字，供八向罗盘显示。
## @return 形如「北 · 0°」的文字。
func GetCompassText() -> String:
	return "%s · %d°" % [COMPASS_NAMES[yaw_step], int(Grid3D.YawStepToDegrees(yaw_step))]

## 取当前缩放档位说明。
## @return 形如「视野 12 格」的文字。
func GetZoomText() -> String:
	return "视野 %d 格" % int(Grid3D.ZoomLevelToSize(zoom_level))

## 偏航补间。
## @param target_degrees 目标角度（度）。
func _tween_yaw(target_degrees: float) -> void:
	if _yaw_tween != null and _yaw_tween.is_valid():
		_yaw_tween.kill()
	_yaw_tween = create_tween()
	_yaw_tween.tween_property(self, "rotation_degrees:y", target_degrees, ExportSettings.view_rotate_duration)

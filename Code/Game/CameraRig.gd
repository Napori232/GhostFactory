class_name CameraRig
extends Node3D
## 相机。两种模式（§7.11.2 的双视角）：
##
##   BUILD —— 上帝视角：斜俯视、固定俯角、8 向旋转、5 档缩放、WASD 平移。
##   EYE   —— 幽灵视角：站在机关之间平视，WASD 自由移动、鼠标观察、Q/E 升降。
##
## 两种模式都只影响「看得清」，不参与任何玩法判定。
## 视角切换不暂停世界。

enum Mode { BUILD, EYE }

const DISTANCES := [12.5, 16.5, 21.5, 30.0, 40.0]
const PITCH_DEG := 52.0
const YAW_STEP := 45.0
const BUILD_FOV := 42.0
const EYE_FOV := 62.0
const EYE_HEIGHT := 1.55
const EYE_SPEED := 6.0
const EYE_SPRINT := 2.0
const EYE_MIN_Y := 0.55
const EYE_MAX_Y := 14.0
const EYE_MARGIN := 8.0

var camera: Camera3D
var focus := Vector2.ZERO
var yaw_deg: float = 45.0
var zoom_index: int = 1
var mode: int = Mode.BUILD

# 幽灵视角状态
var eye_pos: Vector3 = Vector3.ZERO
var eye_yaw: float = PI * 0.25
var eye_pitch: float = 0.0
var _eye_velocity: Vector3 = Vector3.ZERO
var _eye_seeded: bool = false

var _grid: SimGrid
var _target_yaw: float = 45.0
var _dist_current: float = 16.5
var _limits := Rect2(-5.0, -5.0, 10.0, 10.0)
var _shake: float = 0.0
@onready var _scene_camera: Camera3D = get_node_or_null("Camera3D")


## 短促的镜头震动。纯表现，不影响任何判定。
func Shake(intensity: float, _duration: float = 0.2) -> void:
	_shake = maxf(_shake, intensity)


func _ready() -> void:
	camera = _scene_camera
	if camera == null:
		camera = Camera3D.new()
		camera.near = 0.1
		camera.far = 200.0
		add_child(camera)
	camera.fov = BUILD_FOV
	camera.current = true
	_apply(_dist_current)


func Bind(grid: SimGrid, start_zoom: int = 1) -> void:
	_grid = grid
	RebindLimits(grid)
	zoom_index = clampi(start_zoom, 0, DISTANCES.size() - 1)
	Reset()


## 领地扩张后重新计算可平移范围（相机能看的地方跟着地图走）。
func RebindLimits(grid: SimGrid) -> void:
	var min_w := grid.CellToWorld(Vector2i.ZERO) - Vector2(0.5, 0.5) * grid.cell_size
	var max_w := grid.CellToWorld(Vector2i(grid.width - 1, grid.height - 1)) + Vector2(0.5, 0.5) * grid.cell_size
	_limits = Rect2(min_w, max_w - min_w)
	focus.x = clampf(focus.x, _limits.position.x, _limits.end.x)
	focus.y = clampf(focus.y, _limits.position.y, _limits.end.y)


func Reset() -> void:
	mode = Mode.BUILD
	if camera != null:
		camera.fov = BUILD_FOV
	focus = Vector2.ZERO
	_target_yaw = 45.0
	_dist_current = DISTANCES[zoom_index]
	_eye_seeded = false
	_eye_velocity = Vector3.ZERO


func Rotate(step: int) -> void:
	if mode == Mode.EYE:
		return
	_target_yaw += YAW_STEP * float(step)


func Zoom(step: int) -> void:
	if mode == Mode.EYE:
		return
	zoom_index = clampi(zoom_index + step, 0, DISTANCES.size() - 1)


func IsEye() -> bool:
	return mode == Mode.EYE


## 切换上帝视角 / 幽灵视角。切到幽灵视角时，从当前注视点站起来，
## 朝向与上帝视角一致——玩家不会在切换时迷失方向。
func ToggleMode() -> void:
	if mode == Mode.BUILD:
		_enter_eye()
	else:
		ExitEye()


func ExitEye() -> void:
	if mode == Mode.EYE:
		# 回到上帝视角时，落在你刚才站的位置、朝你刚才看的方向
		focus = Vector2(eye_pos.x, eye_pos.z)
		focus.x = clampf(focus.x, _limits.position.x, _limits.end.x)
		focus.y = clampf(focus.y, _limits.position.y, _limits.end.y)
		yaw_deg = rad_to_deg(eye_yaw)
		_target_yaw = yaw_deg
		mode = Mode.BUILD
		if camera != null:
			camera.fov = BUILD_FOV


func _enter_eye() -> void:
	eye_pos = Vector3(focus.x, EYE_HEIGHT, focus.y)
	eye_yaw = deg_to_rad(yaw_deg)
	eye_pitch = 0.0
	_eye_velocity = Vector3.ZERO
	_eye_seeded = true
	mode = Mode.EYE
	if camera != null:
		camera.fov = EYE_FOV
		camera.position = eye_pos
		camera.look_at(eye_pos + EyeDir(eye_yaw, eye_pitch), Vector3.UP)


## 鼠标观察。dx / dy 为相对位移（像素）。
func Look(dx: float, dy: float) -> void:
	if mode != Mode.EYE:
		return
	eye_yaw -= dx * 0.0032
	eye_pitch = clampf(eye_pitch - dy * 0.0026, deg_to_rad(-72.0), deg_to_rad(72.0))


## 走进某个格子附近（调试 / 教程用）。
func MoveEyeTo(cell: Vector2i, grid: SimGrid, height: float = EYE_HEIGHT) -> void:
	var w := grid.CellToWorld(cell)
	eye_pos = Vector3(w.x, height, w.y)
	_eye_velocity = Vector3.ZERO


func Update(dt: float) -> void:
	if mode == Mode.EYE:
		_update_eye(dt)
		return
	_update_build(dt)


## 上帝视角平移：W 往「镜头看的方向」走（远离镜头），S 往镜头走。
## 之前 W/S 反了，就是这里把 forward 用成了反方向。
func _update_build(dt: float) -> void:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if input != Vector2.ZERO:
		var speed := 7.0 * float(DISTANCES[zoom_index]) / 16.5
		focus += PanDelta(yaw_deg, input.normalized()) * speed * dt
		focus.x = clampf(focus.x, _limits.position.x, _limits.end.x)
		focus.y = clampf(focus.y, _limits.position.y, _limits.end.y)

	var k := 1.0 - exp(-9.0 * dt)
	yaw_deg = lerpf(yaw_deg, _target_yaw, k)
	_dist_current = lerpf(_dist_current, DISTANCES[zoom_index], k)
	_shake = move_toward(_shake, 0.0, dt * 1.8)
	_apply(_dist_current)


## 上帝视角下，输入 (x=右, y=前) 对应的世界平移方向。
static func PanDelta(yaw_deg_value: float, input: Vector2) -> Vector2:
	var yaw := deg_to_rad(yaw_deg_value)
	var forward := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	return right * input.x + forward * input.y


## 幽灵视角的朝向单位向量。
static func EyeDir(yaw: float, pitch: float) -> Vector3:
	var cp := cos(pitch)
	return Vector3(-sin(yaw) * cp, sin(pitch), -cos(yaw) * cp)


func _update_eye(dt: float) -> void:
	if not _eye_seeded:
		_enter_eye()
	var intent := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		intent.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		intent.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		intent.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		intent.x += 1.0
	var vertical := 0.0
	if Input.is_key_pressed(KEY_Q):
		vertical -= 1.0
	if Input.is_key_pressed(KEY_E):
		vertical += 1.0

	var forward := Vector2(-sin(eye_yaw), -cos(eye_yaw))
	var right := Vector2(cos(eye_yaw), -sin(eye_yaw))
	var horizontal := forward * intent.y + right * intent.x
	if horizontal.length() > 1.0:
		horizontal = horizontal.normalized()
	var speed := EYE_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= EYE_SPRINT
	var target := Vector3(horizontal.x, vertical, horizontal.y)
	if target.length() > 1.0:
		target = target.normalized()
	target *= speed
	_eye_velocity = _eye_velocity.lerp(target, 1.0 - exp(-14.0 * dt))
	eye_pos += _eye_velocity * dt

	# 幽灵可以飘出场地，但别飘到看不见的地方
	var margin := EYE_MARGIN
	if _grid != null:
		eye_pos.x = clampf(eye_pos.x, _limits.position.x - margin, _limits.end.x + margin)
		eye_pos.z = clampf(eye_pos.z, _limits.position.y - margin, _limits.end.y + margin)
	eye_pos.y = clampf(eye_pos.y, EYE_MIN_Y, EYE_MAX_Y)

	camera.position = eye_pos
	camera.look_at(eye_pos + EyeDir(eye_yaw, eye_pitch), Vector3.UP)


func _apply(dist: float) -> void:
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(PITCH_DEG)
	var dir := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	if camera == null:
		return
	var target := Vector3(focus.x, 0.4, focus.y)
	var shake_offset := Vector3.ZERO
	if _shake > 0.0005:
		shake_offset = Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6), randf_range(-1.0, 1.0)) * _shake
	camera.position = Vector3(focus.x, 0.0, focus.y) + dir * dist + shake_offset
	camera.look_at(target + shake_offset * 0.4, Vector3.UP)

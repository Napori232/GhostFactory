class_name GhostView
extends Node3D
## 鬼的表现层：一个绕地面支点倾斜的机械体。
## 倾角直接来自 SimGhost.angle，不做任何额外动画逻辑——
## 玩家看到的姿态就是判定用的那个角度。
##
## 两种造型（由 Data/ghosts/*.json 的 geometry.style 决定）：
##   lean  —— 单脚翘起的图腾（翘脚鬼）
##   swing —— 带配重的摆臂（摆臂鬼）

var id: int = -1
var _body: Node3D
var _body_mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _foot: MeshInstance3D
var _lean: Vector2 = Vector2.RIGHT
var _stand_emission: float = 0.45


func Bind(sim: Sim, ghost_id: int) -> void:
	id = ghost_id
	var g: SimGhost = sim.ghosts.get(ghost_id)
	if g != null:
		_build(g)


func _build(g: SimGhost) -> void:
	var geo: Dictionary = g.def.get("geometry", {})
	var body_color := Color(String(geo.get("color", "#79d4ff")))
	var glow_color := Color(String(geo.get("glow", "#c8f2ff")))
	var size_arr: Array = geo.get("body", [0.62, 1.02, 0.46])
	var body_size := Vector3(float(size_arr[0]), float(size_arr[1]), float(size_arr[2]))

	_body = Node3D.new()
	add_child(_body)

	_body_mat = Palette.Glow(body_color.darkened(0.15), 0.0)
	_body_mat.rim_enabled = true
	_body_mat.rim = 0.55
	_body_mat.rim_tint = 0.3
	_head_mat = Palette.Glow(glow_color.darkened(0.12), 0.0)

	var style := String(geo.get("style", "lean"))
	match style:
		"swing":
			_build_swing(body_color, body_size)
			_stand_emission = 0.55
		"bell":
			_build_bell(body_color, body_size)
			_stand_emission = 0.62
		"drum":
			_build_drum(body_color, body_size)
			_stand_emission = 0.5
		"antenna":
			_build_antenna(body_color, body_size)
			_stand_emission = 0.7
		"anchor":
			_build_anchor(body_color, body_size)
			_stand_emission = 0.42
		"lantern":
			_build_lantern(body_color, body_size)
			_stand_emission = 0.6
		"hammer":
			_build_hammer(body_color, body_size)
			_stand_emission = 0.55
		"prop":
			_build_prop(body_color, body_size)
			_stand_emission = 0.5
		"pendulum":
			_build_pendulum(body_color, body_size)
			_stand_emission = 0.65
		_:
			_build_lean(body_color, body_size)
			_stand_emission = 0.45

	_build_foot(body_color)
	_build_ring(glow_color)


func _build_lean(body_color: Color, body_size: Vector3) -> void:
	# 固定的那条腿与脚：不随身体旋转，是「受力点」的视觉锚
	var leg := MeshInstance3D.new()
	var leg_mesh := BoxMesh.new()
	leg_mesh.size = Vector3(0.13, 0.66, 0.13)
	leg.mesh = leg_mesh
	leg.material_override = _body_mat
	leg.position = Vector3(0, 0.34, 0.22)
	leg.rotation.x = -0.30
	add_child(leg)

	var torso := MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(body_size.x * 0.72, body_size.y * 0.62, body_size.z * 0.78)
	torso.mesh = torso_mesh
	torso.material_override = _body_mat
	torso.position = Vector3(0, body_size.y * 0.72, 0)
	_body.add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.16
	head_mesh.height = 0.32
	head_mesh.radial_segments = 16
	head_mesh.rings = 8
	head.mesh = head_mesh
	head.material_override = _head_mat
	head.position = Vector3(0, body_size.y * 1.16, 0)
	_body.add_child(head)

	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.09, 0.42, 0.09)
		arm.mesh = arm_mesh
		arm.material_override = _body_mat
		arm.position = Vector3(0.26 * side, body_size.y * 0.88, 0.02)
		arm.rotation.z = 0.12 * side
		_body.add_child(arm)

	# 翘起的那只脚：随身体一起动，立正时会落回地面附近
	var raised := MeshInstance3D.new()
	var raised_mesh := BoxMesh.new()
	raised_mesh.size = Vector3(0.16, 0.09, 0.30)
	raised.mesh = raised_mesh
	raised.material_override = Palette.Solid(body_color.darkened(0.5), 0.0, 0.8)
	raised.position = Vector3(0, 0.16, -0.26)
	raised.rotation.x = 0.5
	_body.add_child(raised)


func _build_swing(_body_color: Color, body_size: Vector3) -> void:
	# 一根立杆 + 顶部配重：倾角越大，顶部摆得越远，一眼能读出「快倒了」
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.10, body_size.y * 0.98, 0.10)
	post.mesh = post_mesh
	post.material_override = _body_mat
	post.position = Vector3(0, body_size.y * 0.48, 0)
	_body.add_child(post)

	var cross := MeshInstance3D.new()
	var cross_mesh := BoxMesh.new()
	cross_mesh.size = Vector3(0.62, 0.06, 0.08)
	cross.mesh = cross_mesh
	cross.material_override = _body_mat
	cross.position = Vector3(0, body_size.y * 0.72, 0)
	_body.add_child(cross)

	var bob := MeshInstance3D.new()
	var bob_mesh := SphereMesh.new()
	bob_mesh.radius = 0.23
	bob_mesh.height = 0.46
	bob_mesh.radial_segments = 16
	bob_mesh.rings = 8
	bob.mesh = bob_mesh
	bob.material_override = _head_mat
	bob.position = Vector3(0, body_size.y * 0.99, 0)
	_body.add_child(bob)

	# 两侧小配重，暗示「周期可以靠配重改」
	for side in [-1.0, 1.0]:
		var weight := MeshInstance3D.new()
		var weight_mesh := BoxMesh.new()
		weight_mesh.size = Vector3(0.10, 0.16, 0.10)
		weight.mesh = weight_mesh
		weight.material_override = Palette.Solid(_body_color_dark(), 0.7, 0.35)
		weight.position = Vector3(0.28 * side, body_size.y * 0.72, 0)
		_body.add_child(weight)


func _body_color_dark() -> Color:
	return _body_mat.albedo_color.darkened(0.35)


## 守夜钟：一根吊杆 + 一口钟，钟口朝下。
func _build_bell(body_color: Color, body_size: Vector3) -> void:
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.1, body_size.y * 0.9, 0.1)
	post.mesh = post_mesh
	post.material_override = Palette.Solid(body_color.darkened(0.45), 0.6, 0.4)
	post.position = Vector3(0, body_size.y * 0.45, 0)
	_body.add_child(post)

	var bell := MeshInstance3D.new()
	var bell_mesh := CylinderMesh.new()
	bell_mesh.top_radius = 0.12
	bell_mesh.bottom_radius = body_size.x * 0.5
	bell_mesh.height = body_size.y * 0.42
	bell_mesh.radial_segments = 20
	bell.mesh = bell_mesh
	bell.material_override = _body_mat
	bell.position = Vector3(0, body_size.y * 0.78, 0)
	_body.add_child(bell)

	var clapper := MeshInstance3D.new()
	var clapper_mesh := SphereMesh.new()
	clapper_mesh.radius = 0.09
	clapper_mesh.height = 0.18
	clapper_mesh.radial_segments = 10
	clapper_mesh.rings = 5
	clapper.mesh = clapper_mesh
	clapper.material_override = _head_mat
	clapper.position = Vector3(0, body_size.y * 0.56, 0)
	_body.add_child(clapper)


## 低鸣鬼：扁鼓 + 鼓架。
func _build_drum(body_color: Color, body_size: Vector3) -> void:
	var shell := MeshInstance3D.new()
	var shell_mesh := CylinderMesh.new()
	shell_mesh.top_radius = body_size.x * 0.5
	shell_mesh.bottom_radius = body_size.x * 0.42
	shell_mesh.height = body_size.y * 0.62
	shell_mesh.radial_segments = 20
	shell.mesh = shell_mesh
	shell.material_override = _body_mat
	shell.position = Vector3(0, body_size.y * 0.5, 0)
	_body.add_child(shell)

	var skin := MeshInstance3D.new()
	var skin_mesh := CylinderMesh.new()
	skin_mesh.top_radius = body_size.x * 0.44
	skin_mesh.bottom_radius = body_size.x * 0.44
	skin_mesh.height = 0.04
	skin_mesh.radial_segments = 20
	skin.mesh = skin_mesh
	skin.material_override = _head_mat
	skin.position = Vector3(0, body_size.y * 0.81, 0)
	_body.add_child(skin)

	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.08, 0.34, 0.08)
		leg.mesh = leg_mesh
		leg.material_override = Palette.Solid(body_color.darkened(0.5), 0.5, 0.5)
		leg.position = Vector3(0.22 * side, 0.17, 0.1)
		_body.add_child(leg)


## 接力鬼：一根天线 + 三层接收环。
func _build_antenna(body_color: Color, body_size: Vector3) -> void:
	var mast := MeshInstance3D.new()
	var mast_mesh := BoxMesh.new()
	mast_mesh.size = Vector3(0.07, body_size.y, 0.07)
	mast.mesh = mast_mesh
	mast.material_override = Palette.Solid(body_color.darkened(0.45), 0.55, 0.4)
	mast.position = Vector3(0, body_size.y * 0.5, 0)
	_body.add_child(mast)

	for i in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		var r := 0.16 + 0.09 * float(i)
		torus.inner_radius = r
		torus.outer_radius = r + 0.035
		torus.rings = 20
		torus.ring_segments = 6
		ring.mesh = torus
		ring.rotation.x = PI * 0.5
		ring.position = Vector3(0, body_size.y * (0.45 + 0.19 * float(i)), 0)
		ring.material_override = _head_mat
		_body.add_child(ring)

	var tip := MeshInstance3D.new()
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.1
	tip_mesh.height = 0.2
	tip_mesh.radial_segments = 10
	tip_mesh.rings = 5
	tip.mesh = tip_mesh
	tip.material_override = _head_mat
	tip.position = Vector3(0, body_size.y, 0)
	_body.add_child(tip)


## 锤鬼：一根立杆 + 顶部横着的重锤；倒下时整根砸向它朝向的那一格。
func _build_hammer(body_color: Color, body_size: Vector3) -> void:
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.12, body_size.y * 0.92, 0.12)
	post.mesh = post_mesh
	post.material_override = Palette.Solid(body_color.darkened(0.4), 0.6, 0.4)
	post.position = Vector3(0, body_size.y * 0.46, 0)
	_body.add_child(post)

	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.62, 0.3, 0.36)
	head.mesh = head_mesh
	head.material_override = _body_mat
	head.position = Vector3(0, body_size.y * 0.96, 0.18)
	_body.add_child(head)

	var face := MeshInstance3D.new()
	var face_mesh := BoxMesh.new()
	face_mesh.size = Vector3(0.5, 0.12, 0.08)
	face.mesh = face_mesh
	face.material_override = _head_mat
	face.position = Vector3(0, body_size.y * 0.96, 0.38)
	_body.add_child(face)

	var counter := MeshInstance3D.new()
	var counter_mesh := BoxMesh.new()
	counter_mesh.size = Vector3(0.3, 0.22, 0.22)
	counter.mesh = counter_mesh
	counter.material_override = _head_mat
	counter.position = Vector3(0, body_size.y * 0.96, -0.24)
	_body.add_child(counter)


## 撑鬼：一个 A 字撑架，朝 +Z 伸出一块承重垫——那块垫就是它撑住邻鬼的地方。
func _build_prop(body_color: Color, body_size: Vector3) -> void:
	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.14, body_size.y * 0.9, 0.14)
	post.mesh = post_mesh
	post.material_override = Palette.Solid(body_color.darkened(0.35), 0.55, 0.4)
	post.position = Vector3(0, body_size.y * 0.45, 0)
	_body.add_child(post)

	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.1, body_size.y * 0.62, 0.1)
		leg.mesh = leg_mesh
		leg.material_override = _body_mat
		leg.position = Vector3(0.22 * side, body_size.y * 0.3, -0.16)
		leg.rotation.x = 0.5
		leg.rotation.z = -0.25 * side
		_body.add_child(leg)

	var brace := MeshInstance3D.new()
	var brace_mesh := BoxMesh.new()
	brace_mesh.size = Vector3(0.16, 0.12, 0.52)
	brace.mesh = brace_mesh
	brace.material_override = _body_mat
	brace.position = Vector3(0, body_size.y * 0.62, 0.22)
	brace.rotation.x = -0.45
	_body.add_child(brace)

	var pad := MeshInstance3D.new()
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(0.42, 0.1, 0.3)
	pad.mesh = pad_mesh
	pad.material_override = _head_mat
	pad.position = Vector3(0, body_size.y * 0.86, 0.34)
	_body.add_child(pad)


## 摆锤鬼：一根长臂 + 顶部重锤。整根随角度摆，速度过阈值才响。
func _build_pendulum(body_color: Color, body_size: Vector3) -> void:
	var pivot := MeshInstance3D.new()
	var pivot_mesh := CylinderMesh.new()
	pivot_mesh.top_radius = 0.16
	pivot_mesh.bottom_radius = 0.2
	pivot_mesh.height = 0.18
	pivot_mesh.radial_segments = 14
	pivot.mesh = pivot_mesh
	pivot.material_override = Palette.Solid(body_color.darkened(0.5), 0.7, 0.35)
	pivot.position = Vector3(0, 0.1, 0)
	add_child(pivot)

	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.1, body_size.y * 1.05, 0.1)
	arm.mesh = arm_mesh
	arm.material_override = Palette.Solid(body_color.darkened(0.3), 0.7, 0.3)
	arm.position = Vector3(0, body_size.y * 0.52, 0)
	_body.add_child(arm)

	var bob := MeshInstance3D.new()
	var bob_mesh := SphereMesh.new()
	bob_mesh.radius = 0.25
	bob_mesh.height = 0.5
	bob_mesh.radial_segments = 16
	bob_mesh.rings = 8
	bob.mesh = bob_mesh
	bob.material_override = _body_mat
	bob.position = Vector3(0, body_size.y * 1.08, 0)
	_body.add_child(bob)

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.1
	core_mesh.height = 0.2
	core_mesh.radial_segments = 8
	core_mesh.rings = 4
	core.mesh = core_mesh
	core.material_override = _head_mat
	core.position = Vector3(0, body_size.y * 1.08, 0)
	_body.add_child(core)
func _build_anchor(body_color: Color, body_size: Vector3) -> void:
	var block := MeshInstance3D.new()
	var block_mesh := BoxMesh.new()
	block_mesh.size = Vector3(body_size.x, body_size.y * 0.62, body_size.z)
	block.mesh = block_mesh
	block.material_override = Palette.Solid(body_color.darkened(0.3), 0.85, 0.3)
	block.position = Vector3(0, body_size.y * 0.62, 0)
	_body.add_child(block)
	for side in [-1.0, 1.0]:
		var lock := MeshInstance3D.new()
		var lock_mesh := BoxMesh.new()
		lock_mesh.size = Vector3(0.16, body_size.y * 0.3, 0.2)
		lock.mesh = lock_mesh
		lock.material_override = _head_mat
		lock.position = Vector3(body_size.x * 0.55 * side, body_size.y * 0.62, 0)
		_body.add_child(lock)


## 提灯鬼：一根提着灯的细杆。
func _build_lantern(body_color: Color, body_size: Vector3) -> void:
	var hook := MeshInstance3D.new()
	var hook_mesh := BoxMesh.new()
	hook_mesh.size = Vector3(0.06, body_size.y, 0.06)
	hook.mesh = hook_mesh
	hook.material_override = Palette.Solid(body_color.darkened(0.5), 0.5, 0.5)
	hook.position = Vector3(0, body_size.y * 0.5, 0)
	_body.add_child(hook)

	var cage := MeshInstance3D.new()
	var cage_mesh := BoxMesh.new()
	cage_mesh.size = Vector3(0.3, 0.36, 0.3)
	cage.mesh = cage_mesh
	cage.material_override = _body_mat
	cage.position = Vector3(0, body_size.y * 0.78, 0.02)
	_body.add_child(cage)

	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.11
	core_mesh.height = 0.22
	core_mesh.radial_segments = 10
	core_mesh.rings = 5
	core.mesh = core_mesh
	core.material_override = _head_mat
	core.position = Vector3(0, body_size.y * 0.78, 0.02)
	_body.add_child(core)


func _build_foot(body_color: Color) -> void:
	_foot = MeshInstance3D.new()
	var foot_mesh := BoxMesh.new()
	foot_mesh.size = Vector3(0.20, 0.09, 0.30)
	_foot.mesh = foot_mesh
	_foot.material_override = Palette.Solid(body_color.darkened(0.5), 0.0, 0.8)
	_foot.position = Vector3(0, 0.05, 0.40)
	add_child(_foot)


func _build_ring(glow_color: Color) -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.58
	torus.rings = 32
	torus.ring_segments = 8
	_ring.mesh = torus
	_ring.rotation.x = PI * 0.5
	_ring.position = Vector3(0, 0.035, 0)
	_ring_mat = Palette.Additive(glow_color, 0.0)
	_ring.material_override = _ring_mat
	_ring.visible = false
	add_child(_ring)


func Sync(sim: Sim, _now: float) -> void:
	var g: SimGhost = sim.ghosts.get(id)
	if g == null:
		visible = false
		return
	visible = true
	position = Vector3(g.base.x, 0.0, g.base.y)
	_lean = g.LeanDir()
	rotation.y = atan2(_lean.x, _lean.y)
	_body.rotation.x = g.angle

	var energy := 0.0
	var head_energy := 0.0
	if g.standing:
		energy = _stand_emission
		head_energy = _stand_emission * 1.55
	_body_mat.emission_energy_multiplier = energy
	_head_mat.emission_energy_multiplier = head_energy

	_ring.visible = g.standing
	if g.standing:
		var breath := 0.5 + 0.5 * sin(g.phase)
		_ring.scale = Vector3.ONE * (1.0 + 0.10 * breath)
		_ring_mat.albedo_color.a = 0.22 + 0.32 * breath

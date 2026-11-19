class_name SwapperView
extends Node3D
## 搬运手：一个会转的机械臂。换晶时爪尖发亮——
## 它没有槽、不存晶，只负责把地上的充能晶和机关里的空晶对调。

var id: int = -1
var _arm: Node3D
var _arm_mat: StandardMaterial3D
var _claw_mat: StandardMaterial3D


func Bind(sim: Sim, swapper_id: int) -> void:
	id = swapper_id
	var s: SimSwapper = sim.swappers.get(swapper_id)
	if s != null:
		_build(s)


func _build(s: SimSwapper) -> void:
	var geo: Dictionary = s.def.get("geometry", {})
	var color := Color(String(geo.get("color", "#8fb7c9")))
	var claw_color := Color(String(geo.get("claw_color", "#5be0c0")))
	var base_arr: Array = geo.get("base", [0.66, 0.24, 0.66])
	var arm_len := float(geo.get("arm", 0.46))

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(float(base_arr[0]), float(base_arr[1]), float(base_arr[2]))
	base.mesh = base_mesh
	base.material_override = Palette.Solid(color.darkened(0.45), 0.6, 0.4)
	base.position = Vector3(0, float(base_arr[1]) * 0.5, 0)
	add_child(base)

	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.08
	post_mesh.bottom_radius = 0.12
	post_mesh.height = 0.72
	post_mesh.radial_segments = 12
	post.mesh = post_mesh
	post.material_override = Palette.Solid(color, 0.7, 0.35)
	post.position = Vector3(0, 0.36 + float(base_arr[1]) * 0.5, 0)
	add_child(post)

	_arm = Node3D.new()
	_arm.position = Vector3(0, 0.82 + float(base_arr[1]) * 0.5, 0)
	add_child(_arm)

	_arm_mat = Palette.Glow(color.lightened(0.1), 0.0)
	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(arm_len, 0.07, 0.07)
	beam.mesh = beam_mesh
	beam.material_override = _arm_mat
	beam.position = Vector3(arm_len * 0.5, 0, 0)
	_arm.add_child(beam)

	_claw_mat = Palette.Glow(claw_color, 0.4)
	var claw := MeshInstance3D.new()
	var claw_mesh := SphereMesh.new()
	claw_mesh.radius = 0.1
	claw_mesh.height = 0.2
	claw_mesh.radial_segments = 10
	claw_mesh.rings = 5
	claw.mesh = claw_mesh
	claw.material_override = _claw_mat
	claw.position = Vector3(arm_len, 0, 0)
	_arm.add_child(claw)


func Sync(sim: Sim, now: float, _dt: float) -> void:
	var s: SimSwapper = sim.swappers.get(id)
	if s == null:
		visible = false
		return
	visible = true
	position = Vector3(s.base.x, 0.0, s.base.y)
	_arm.rotation.y = now * 1.1

	var glow := 0.0
	if s.work_pulse > 0.0:
		glow = clampf(s.work_pulse / 0.5, 0.0, 1.0)
	_arm_mat.emission_energy_multiplier = glow * 1.6
	_claw_mat.emission_energy_multiplier = 0.4 + glow * 2.4
	_arm.scale = Vector3.ONE * (1.0 + glow * 0.08)

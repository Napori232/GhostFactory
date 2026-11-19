class_name BeltView
extends Node3D
## 传送带：一块贴地的带面 + 循环滚动的横条。
## 横条的移动方向 = 带子的朝向，速度 = 数据里的 speed——
## 玩家不用读数字就知道这条带子往哪走、多快。
## 带面上有货时，带面会亮一点（物流是不是通的，一眼可见）。

var id: int = -1
var _slats: Array = []
var _slat_mat: StandardMaterial3D
var _base_mat: StandardMaterial3D
var _speed: float = 1.0
var _offset: float = 0.0
var _count: int = 5


func Bind(sim: Sim, belt_id: int) -> void:
	id = belt_id
	var b: SimBelt = sim.belts.get(belt_id)
	if b != null:
		_build(b)


func _build(b: SimBelt) -> void:
	var geo: Dictionary = b.def.get("geometry", {})
	var base_color := Color(String(geo.get("color", "#6d7f96")))
	var stripe_color := Color(String(geo.get("stripe", "#a8e6ff")))
	_speed = b.speed

	# 底槽：一个浅浅的凹面，读作「轨道」
	_base_mat = Palette.Solid(base_color.darkened(0.35), 0.3, 0.75)
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.96, 0.10, 0.96)
	base.mesh = box
	base.material_override = _base_mat
	base.position = Vector3(0, 0.05, 0)
	add_child(base)

	# 两侧挡边
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.06, 0.12, 0.96)
		rail.mesh = rail_mesh
		rail.material_override = Palette.Solid(base_color.darkened(0.1), 0.45, 0.5)
		rail.position = Vector3(0.45 * side, 0.12, 0)
		add_child(rail)

	_slat_mat = Palette.Glow(stripe_color, 0.0)
	for i in _count:
		var slat := MeshInstance3D.new()
		var slat_mesh := BoxMesh.new()
		slat_mesh.size = Vector3(0.74, 0.05, 0.10)
		slat.mesh = slat_mesh
		slat.material_override = _slat_mat
		add_child(slat)
		_slats.append(slat)


func Sync(sim: Sim, now: float, dt: float) -> void:
	var b: SimBelt = sim.belts.get(id)
	if b == null:
		visible = false
		return
	visible = true
	position = Vector3(b.base.x, 0.0, b.base.y)
	var dir := b.PushDir()
	rotation.y = atan2(dir.x, dir.y)

	_offset = fmod(_offset + dt * b.speed, 1.0)
	var span := 0.86
	for i in _slats.size():
		var t := fmod(float(i) / float(_slats.size()) + _offset, 1.0)
		var slat: MeshInstance3D = _slats[i]
		slat.position = Vector3(0, 0.11, -span * 0.5 + span * t)

	var loaded := not b.items.is_empty()
	var pulse := 0.0
	if loaded:
		pulse = 0.55 + 0.25 * sin(now * 6.0)
	_slat_mat.emission_energy_multiplier = pulse
	_base_mat.emission_enabled = loaded
	_base_mat.emission = _slat_mat.albedo_color
	_base_mat.emission_energy_multiplier = pulse * 0.35

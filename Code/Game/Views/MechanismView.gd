class_name MechanismView
extends Node3D
## 顶足机关：底座 + 顶杆 + 插槽。
## 顶杆伸出的长度直接反映它此刻是否在发力（pushing）。

var id: int = -1
var _rod: MeshInstance3D
var _head: MeshInstance3D
var _slot: MeshInstance3D
var _slot_mat: StandardMaterial3D
var _base_mat: StandardMaterial3D
var _rod_len: float = 0.22
var _reach: float = 0.62
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D


func Bind(sim: Sim, mech_id: int) -> void:
	id = mech_id
	var m: SimMechanism = sim.mechanisms.get(mech_id)
	if m != null:
		_build(m)


func _build(m: SimMechanism) -> void:
	var geo: Dictionary = m.def.get("geometry", {})
	var base_color := Color(String(geo.get("color", "#c9a06a")))
	var slot_color := Color(String(geo.get("slot_color", "#5be0c0")))
	var base_arr: Array = geo.get("base", [0.78, 0.32, 0.78])
	_reach = m.reach

	_base_mat = Palette.Solid(base_color.darkened(0.35), 0.7, 0.35)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(float(base_arr[0]), float(base_arr[1]), float(base_arr[2]))
	base.mesh = base_mesh
	base.material_override = _base_mat
	base.position = Vector3(0, float(base_arr[1]) * 0.5, 0)
	add_child(base)

	var collar := MeshInstance3D.new()
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.16
	collar_mesh.bottom_radius = 0.2
	collar_mesh.height = 0.16
	collar_mesh.radial_segments = 16
	collar.mesh = collar_mesh
	collar.material_override = Palette.Solid(base_color, 0.8, 0.3)
	collar.position = Vector3(0, float(base_arr[1]) + 0.06, 0)
	add_child(collar)

	if m.ModifiesGhosts():
		# 改鬼机关没有顶杆：一圈浮在底座上的环，工作时呼吸。
		_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.26
		torus.outer_radius = 0.33
		torus.rings = 28
		torus.ring_segments = 8
		_ring.mesh = torus
		_ring.rotation.x = PI * 0.5
		_ring.position = Vector3(0, float(base_arr[1]) + 0.3, 0)
		_ring_mat = Palette.Glow(slot_color, 0.0)
		_ring.material_override = _ring_mat
		add_child(_ring)
		_build_slot(float(base_arr[1]), slot_color)
		return

	# 顶杆沿本地 +Z
	_rod = MeshInstance3D.new()
	var rod_mesh := BoxMesh.new()
	rod_mesh.size = Vector3(0.12, 0.12, 1.0)
	_rod.mesh = rod_mesh
	_rod.material_override = Palette.Solid(base_color.lightened(0.15), 0.85, 0.25)
	_rod.position = Vector3(0, float(base_arr[1]) * 0.8, 0.22 * 0.5)
	_rod.scale = Vector3(1, 1, 0.22)
	add_child(_rod)

	# 活塞筒，让「顶」这个动作有来源
	var housing := MeshInstance3D.new()
	var housing_mesh := BoxMesh.new()
	housing_mesh.size = Vector3(0.26, 0.24, 0.34)
	housing.mesh = housing_mesh
	housing.material_override = Palette.Solid(base_color.darkened(0.2), 0.75, 0.3)
	housing.position = Vector3(0, float(base_arr[1]) * 0.8 + 0.04, 0.16)
	add_child(housing)

	_head = MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.1
	head_mesh.height = 0.2
	head_mesh.radial_segments = 12
	head_mesh.rings = 6
	_head.mesh = head_mesh
	_head.material_override = Palette.Solid(base_color.lightened(0.3), 0.9, 0.2)
	_head.position = Vector3(0, float(base_arr[1]) * 0.8, 0.22)
	add_child(_head)

	# 插槽
	_build_slot(float(base_arr[1]), slot_color)


func _build_slot(base_height: float, slot_color: Color) -> void:
	_slot = MeshInstance3D.new()
	var slot_mesh := SphereMesh.new()
	slot_mesh.radius = 0.11
	slot_mesh.height = 0.22
	slot_mesh.radial_segments = 6
	slot_mesh.rings = 3
	_slot.mesh = slot_mesh
	_slot_mat = Palette.Glow(slot_color, 0.0)
	_slot.material_override = _slot_mat
	_slot.position = Vector3(0, base_height + 0.26, 0)
	_slot.visible = false
	add_child(_slot)


func Sync(sim: Sim, now: float, dt: float) -> void:
	var m: SimMechanism = sim.mechanisms.get(id)
	if m == null:
		visible = false
		return
	visible = true
	position = Vector3(m.base.x, 0.0, m.base.y)
	var dir := m.PushDir()
	rotation.y = atan2(dir.x, dir.y)

	var target_len := m.reach if m.pushing else 0.22
	if _rod != null:
		_rod_len = lerpf(_rod_len, target_len, clampf(dt * 14.0, 0.0, 1.0))
		_rod.scale = Vector3(1, 1, _rod_len)
		_rod.position.z = _rod_len * 0.5
		_head.position.z = _rod_len
	if _ring != null:
		_ring.visible = true
		var s := 1.0 if not m.pushing else (1.0 + 0.10 * sin(now * 4.0))
		_ring.scale = Vector3.ONE * s
		_ring_mat.emission_energy_multiplier = 0.0 if not m.pushing else (0.7 + 0.5 * sin(now * 4.0))

	if m.crystal_id >= 0 and sim.crystals.has(m.crystal_id):
		var c: SimCrystal = sim.crystals[m.crystal_id]
		_slot.visible = true
		var ratio := clampf(c.charge / maxf(c.capacity, 0.001), 0.0, 1.0)
		_slot_mat.emission_energy_multiplier = 0.25 + ratio * 2.2
		_slot.scale = Vector3.ONE * (0.85 + 0.15 * ratio)
	else:
		_slot.visible = false

	var glow := 0.0
	if m.pushing:
		glow = 0.45 + 0.35 * sin(now * 18.0)
	_base_mat.emission_enabled = glow > 0.0
	_base_mat.emission = Palette.MECH
	_base_mat.emission_energy_multiplier = glow

class_name CrystalView
extends Node3D
## 鬼晶：八面体容器。亮度 = 存量，一眼看出「满 / 空」。

var id: int = -1
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var held_mode: bool = false


func Bind(sim: Sim, crystal_id: int) -> void:
	id = crystal_id
	var c: SimCrystal = sim.crystals.get(crystal_id)
	var geo: Dictionary = c.def.get("geometry", {}) if c != null else {}
	_build(Color(String(geo.get("color", "#4fe0c4"))), float(geo.get("radius", 0.22)), float(geo.get("height", 0.46)))


func _build(color: Color, radius: float, height: float) -> void:
	_mesh = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 4
	mesh.rings = 2
	_mesh.mesh = mesh
	_mat = Palette.Glow(color, 0.4)
	_mesh.material_override = _mat
	add_child(_mesh)


func Sync(sim: Sim, now: float, _dt: float) -> void:
	var c: SimCrystal = sim.crystals.get(id)
	if c == null:
		visible = false
		return

	if held_mode:
		visible = sim.held_crystal == id
		position = Vector3(0.42, -0.30, -0.85)
		scale = Vector3.ONE * 0.55
		rotation = Vector3(now * 0.9, now * 1.7, 0.3)
		_set_energy(c)
		return

	visible = true
	if c.slotted_in >= 0 and sim.mechanisms.has(c.slotted_in):
		var m: SimMechanism = sim.mechanisms[c.slotted_in]
		position = Vector3(m.base.x, 0.72, m.base.y)
		scale = Vector3.ONE * 0.62
		rotation = Vector3(0, now * 1.6, 0)
	elif c.cell.x >= 0:
		var w := sim.grid.CellToWorld(c.cell)
		position = Vector3(w.x, 0.34 + sin(now * 1.8 + float(id)) * 0.05, w.y)
		scale = Vector3.ONE
		rotation = Vector3(0, now * 1.2 + float(id) + PI * 0.25, 0)
	else:
		visible = false
	_set_energy(c)


func _set_energy(c: SimCrystal) -> void:
	var ratio := clampf(c.charge / maxf(c.capacity, 0.001), 0.0, 1.0)
	_mat.emission_energy_multiplier = 0.06 + ratio * 0.75

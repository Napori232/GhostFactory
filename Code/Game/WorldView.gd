class_name WorldView
extends Node3D
## 场景表现层：静态地景 + 实体节点 + 光标 + 特效。
## 所有状态都从 Sim 读，视图不保存任何规则状态。

const GROUND_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 base_color : source_color = vec3(0.031, 0.047, 0.068);
uniform vec3 line_color : source_color = vec3(0.10, 0.16, 0.20);
uniform float cell_size = 1.0;
uniform vec2 field_size = vec2(13.0, 13.0);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 g = abs(fract(wp.xz / cell_size + 0.5) - 0.5);
	float line = smoothstep(0.455, 0.5, max(g.x, g.y));
	vec2 half_size = field_size * 0.5;
	vec2 q = abs(wp.xz) / half_size;
	float inside = step(q.x, 1.0) * step(q.y, 1.0);
	float edge = 1.0 - smoothstep(0.55, 1.0, max(q.x, q.y));
	vec3 col = mix(base_color * 0.35, base_color, inside);
	col = mix(col, line_color, line * inside * 0.75);
	col *= mix(0.45, 1.0, clamp(edge, 0.0, 1.0));
	ALBEDO = col;
}
"""

var sim: Sim
var camera: Camera3D

var _ghost_nodes: Dictionary = {}
var _mech_nodes: Dictionary = {}
var _crystal_nodes: Dictionary = {}
var _swapper_nodes: Dictionary = {}
var _belt_nodes: Dictionary = {}
var _enemy_nodes: Dictionary = {}
var _rings: Array = []
var _heat: HeatmapView
var _bounds_nodes: Array = []
var _outlaw_nodes: Array = []
var _select_marker: MeshInstance3D
var _select_t: float = 0.0
var _link_nodes: Array = []
var _link_timer: float = 0.0
var _held_preview: MeshInstance3D
var _held_preview_mat: StandardMaterial3D

var _cursor: MeshInstance3D
var _cursor_mat: StandardMaterial3D
var _arrow: MeshInstance3D
var _arrow_mat: StandardMaterial3D
var _markers: Array = []
var _marker_mats: Array = []
var _now: float = 0.0
var _tut_marker: MeshInstance3D
var _tut_marker_t: float = 0.0


func Bind(sim_ref: Sim, cam: Camera3D) -> void:
	sim = sim_ref
	camera = cam
	_build_ground()
	_build_bounds()
	_build_center()
	_build_cursor()
	_build_spawn_markers()
	_heat = HeatmapView.new()
	add_child(_heat)
	_heat.Bind(sim)
	_build_select_marker()
	_build_held_preview()

	sim.events.Built.connect(_on_structure_changed)
	sim.events.Removed.connect(_on_structure_changed_removed)
	sim.events.Moved.connect(_on_moved)
	sim.events.WorldRestored.connect(_rebuild_all)
	sim.events.TerritoryExpanded.connect(_on_territory_expanded)
	sim.events.OutlawRazed.connect(func(_cell: Vector2i, _kind: String): _rebuild_outlaw_rings())
	sim.events.EnemySpawned.connect(_on_enemy_spawned)
	sim.events.EnemyKilled.connect(_on_enemy_killed)
	sim.events.EnemyBreached.connect(_on_enemy_breached)
	sim.events.GhostPulse.connect(_on_pulse)
	sim.events.GhostStruck.connect(_on_ghost_struck)
	sim.events.ResonanceBurst.connect(_on_resonance_burst)
	sim.events.GhostStood.connect(_on_stood)
	sim.events.CrystalInserted.connect(_on_crystal_moved)
	sim.events.CrystalEjected.connect(_on_crystal_moved)
	sim.events.SwapperWorked.connect(_on_swapper_worked)

	_rebuild_all()


func Sync(dt: float) -> void:
	_now += dt
	for id in _ghost_nodes:
		var n: GhostView = _ghost_nodes[id]
		if is_instance_valid(n):
			n.Sync(sim, _now)
	for id in _mech_nodes:
		var m: MechanismView = _mech_nodes[id]
		if is_instance_valid(m):
			m.Sync(sim, _now, dt)
	for id in _crystal_nodes:
		var c: CrystalView = _crystal_nodes[id]
		if is_instance_valid(c):
			c.Sync(sim, _now, dt)
	for id in _swapper_nodes:
		var s: SwapperView = _swapper_nodes[id]
		if is_instance_valid(s):
			s.Sync(sim, _now, dt)
	for id in _belt_nodes:
		var b: BeltView = _belt_nodes[id]
		if is_instance_valid(b):
			b.Sync(sim, _now, dt)
	for id in _enemy_nodes:
		var e: EnemyView = _enemy_nodes[id]
		if is_instance_valid(e):
			e.Sync(sim, _now, dt)
	_heat.Update(dt)
	_update_spawn_markers()
	_link_timer -= dt
	if _link_timer <= 0.0:
		_link_timer = 0.1
		_update_links()
	if _held_preview != null and _held_preview.visible:
		_held_preview.rotation.y += dt * 1.8


## 鼠标悬停格与放置朝向预览。valid=false 时显示为禁用色。
func SetCursor(cell: Vector2i, facing: int, valid: bool, show_arrow: bool) -> void:
	if _cursor == null:
		return
	var in_field := sim.grid.InField(cell)
	_cursor.visible = in_field
	_arrow.visible = in_field and show_arrow
	if not in_field:
		return
	var w := sim.grid.CellToWorld(cell)
	_cursor.position = Vector3(w.x, 0.05, w.y)
	var col := Palette.ACCENT if valid else Palette.DANGER
	_cursor_mat.albedo_color = Color(col.r, col.g, col.b, 0.28 if valid else 0.34)

	var dir := Vector2(1, 0)
	match posmod(facing, 4):
		1:
			dir = Vector2(0, 1)
		2:
			dir = Vector2(-1, 0)
		3:
			dir = Vector2(0, -1)
	_arrow.position = Vector3(w.x + dir.x * 0.38, 0.07, w.y + dir.y * 0.38)
	_arrow.rotation.y = atan2(dir.x, dir.y)
	_arrow_mat.albedo_color = Color(col.r, col.g, col.b, 0.85)


# ---------------------------------------------------------------------------

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(48, 48)
	ground.mesh = plane
	var shader := Shader.new()
	shader.code = GROUND_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("cell_size", sim.grid.cell_size)
	mat.set_shader_parameter("field_size", Vector2(float(sim.grid.width), float(sim.grid.height)))
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_bounds() -> void:
	for n in _bounds_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_bounds_nodes.clear()
	var r := sim.grid.build_rect
	var min_w := sim.grid.CellToWorld(r.position) - Vector2(0.5, 0.5) * sim.grid.cell_size
	var max_w := sim.grid.CellToWorld(r.position + r.size - Vector2i.ONE) + Vector2(0.5, 0.5) * sim.grid.cell_size
	var mid := (min_w + max_w) * 0.5
	var span := max_w - min_w
	var mat := Palette.Additive(Palette.ACCENT, 0.32)
	var thick := 0.045
	_bounds_nodes.append(_add_bar(Vector3(mid.x, 0.06, min_w.y), Vector3(span.x + thick, 0.02, thick), mat))
	_bounds_nodes.append(_add_bar(Vector3(mid.x, 0.06, max_w.y), Vector3(span.x + thick, 0.02, thick), mat))
	_bounds_nodes.append(_add_bar(Vector3(min_w.x, 0.06, mid.y), Vector3(thick, 0.02, span.y + thick), mat))
	_bounds_nodes.append(_add_bar(Vector3(max_w.x, 0.06, mid.y), Vector3(thick, 0.02, span.y + thick), mat))


func _on_territory_expanded(_rect: Rect2i, _annexed: int) -> void:
	_build_bounds()
	_rebuild_outlaw_rings()


## 领地外的造物脚下打一圈红环：扩张的代价要看得见。
func _rebuild_outlaw_rings() -> void:
	for n in _outlaw_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_outlaw_nodes.clear()
	if not sim.allow_outlaw:
		return
	for cell in sim.outlaw_cells:
		var w := sim.grid.CellToWorld(cell)
		var ring := MeshInstance3D.new()
		ring.mesh = _ring_mesh(0.3, 0.52, 24)
		ring.position = Vector3(w.x, 0.09, w.y)
		ring.material_override = Palette.Glow(Palette.DANGER, 1.9)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_outlaw_nodes.append(ring)


func _build_center() -> void:
	# 平环：贴地的红色圆环，比圆环体更稳、也不会被地面/热力图裁掉
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh(maxf(0.1, sim.center_radius - 0.14), sim.center_radius, 72)
	ring.position = Vector3(0, 0.1, 0)
	var ring_mat := Palette.Glow(Color(0.85, 0.10, 0.16), 2.0)
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	# 内圈一圈短刻线，读作「保护区域」而不是一块色块
	for i in 8:
		var a := TAU * float(i) / 8.0
		var tick := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.03, 0.22)
		tick.mesh = box
		tick.position = Vector3(cos(a) * (sim.center_radius - 0.34), 0.1, sin(a) * (sim.center_radius - 0.34))
		tick.rotation.y = -a
		tick.material_override = Palette.Glow(Palette.DANGER.darkened(0.1), 1.1)
		tick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tick)

	var light := OmniLight3D.new()
	light.light_color = Palette.DANGER
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.position = Vector3(0, 1.5, 0)
	add_child(light)


## 新手引导用：在某个格子上放一个脉动的金圈。
func ShowCellMarker(cell: Vector2i, color: Color) -> void:
	if _tut_marker == null:
		_tut_marker = MeshInstance3D.new()
		_tut_marker.mesh = _ring_mesh(0.34, 0.48, 32)
		add_child(_tut_marker)
	var w := sim.grid.CellToWorld(cell)
	_tut_marker.position = Vector3(w.x, 0.045, w.y)
	_tut_marker.material_override = Palette.Glow(color, 2.2)
	_tut_marker.visible = true
	_tut_marker_t = 0.0


## 隐藏引导标记。
func HideCellMarker() -> void:
	if _tut_marker != null:
		_tut_marker.visible = false


func _build_select_marker() -> void:
	_select_marker = MeshInstance3D.new()
	_select_marker.mesh = _ring_mesh(0.38, 0.52, 32)
	_select_marker.material_override = Palette.Glow(Palette.ACCENT, 2.0)
	_select_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_select_marker.visible = false
	add_child(_select_marker)


## 选中某个格子上的实体：脚下打一个脉动青环。
func SetSelection(cell: Vector2i) -> void:
	if _select_marker == null:
		return
	if cell.x < 0 or cell.y < 0:
		_select_marker.visible = false
		return
	var w := sim.grid.CellToWorld(cell)
	_select_marker.position = Vector3(w.x, 0.07, w.y)
	_select_marker.visible = true
	_select_t = 0.0


func ClearSelection() -> void:
	if _select_marker != null:
		_select_marker.visible = false


## 手持鬼晶的落点预览：一个半透明的水晶悬在鼠标下的格子上。
## 它挂在世界里而不是相机前，所以不会和 HUD 打架。
func _build_held_preview() -> void:
	_held_preview = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.42
	mesh.radial_segments = 4
	mesh.rings = 2
	_held_preview.mesh = mesh
	_held_preview_mat = Palette.Additive(Palette.CRYSTAL, 0.6)
	_held_preview.material_override = _held_preview_mat
	_held_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held_preview.visible = false
	add_child(_held_preview)


func SetHeldPreview(cell: Vector2i, valid: bool) -> void:
	if _held_preview == null:
		return
	if cell.x < 0 or sim.held_crystal < 0:
		_held_preview.visible = false
		return
	var w := sim.grid.CellToWorld(cell)
	_held_preview.position = Vector3(w.x, 0.58, w.y)
	var col := Palette.CRYSTAL
	var c: SimCrystal = sim.crystals.get(sim.held_crystal)
	if c != null:
		col = Color(String(c.def.get("geometry", {}).get("color", "#4fe0c4")))
	if not valid:
		col = Palette.DANGER
	_held_preview_mat.albedo_color = Color(col.r, col.g, col.b, 0.55 if valid else 0.4)
	_held_preview.visible = true


## 撑鬼的支撑连杆：每 0.1 秒从 Sim.links 同步一次。
func _update_links() -> void:
	var count: int = sim.links.size()
	for i in _link_nodes.size():
		var n: MeshInstance3D = _link_nodes[i]
		if is_instance_valid(n):
			n.visible = i < count
	for i in count:
		var link: Dictionary = sim.links[i]
		var from_g: SimGhost = sim.ghosts.get(int(link.get("from", -1)))
		var to_g: SimGhost = sim.ghosts.get(int(link.get("to", -1)))
		if from_g == null or to_g == null:
			continue
		var node := _ensure_link_node(i)
		var a := from_g.base
		var b := to_g.base
		var mid := (a + b) * 0.5
		var d := b - a
		node.position = Vector3(mid.x, 0.52, mid.y)
		node.rotation.y = atan2(-d.y, d.x)
		node.scale = Vector3(maxf(0.2, d.length()), 1.0, 1.0)
		node.visible = true


func _ensure_link_node(index: int) -> MeshInstance3D:
	while _link_nodes.size() <= index:
		var node := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 0.05, 0.05)
		node.mesh = box
		node.material_override = Palette.Glow(Palette.ACCENT, 1.6)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_link_nodes.append(node)
	return _link_nodes[index]


func _on_ghost_struck(_striker_id: int, _target_id: int, pos: Vector2, helps: bool) -> void:
	_play_ring(pos, 1.5, Palette.ACCENT if helps else Palette.WARN, 0.35)


func _process(delta: float) -> void:
	if _tut_marker != null and _tut_marker.visible:
		_tut_marker_t += delta
		var s := 1.0 + 0.12 * sin(_tut_marker_t * 4.0)
		_tut_marker.scale = Vector3(s, 1.0, s)
	if _select_marker != null and _select_marker.visible:
		_select_t += delta
		var s2 := 1.0 + 0.08 * sin(_select_t * 4.5)
		_select_marker.scale = Vector3(s2, 1.0, s2)


func _ring_mesh(inner: float, outer: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0i := Vector3(cos(a0) * inner, 0.0, sin(a0) * inner)
		var p1i := Vector3(cos(a1) * inner, 0.0, sin(a1) * inner)
		var p0o := Vector3(cos(a0) * outer, 0.0, sin(a0) * outer)
		var p1o := Vector3(cos(a1) * outer, 0.0, sin(a1) * outer)
		_add_tri(st, p0i, p0o, p1o)
		_add_tri(st, p0i, p1o, p1i)
	return st.commit()


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal(Vector3.UP)
	st.add_vertex(a)
	st.set_normal(Vector3.UP)
	st.add_vertex(b)
	st.set_normal(Vector3.UP)
	st.add_vertex(c)


func _build_spawn_markers() -> void:
	# 准备阶段的「下一波来向」信标：柱子 + 顶端光球，按甲/普通变色。
	for i in 8:
		var mat := Palette.Additive(Palette.DANGER, 0.3)
		var pillar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.10, 1.0, 0.10)
		pillar.mesh = box
		pillar.material_override = mat
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var orb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		sphere.radial_segments = 10
		sphere.rings = 5
		orb.mesh = sphere
		orb.material_override = mat
		orb.position = Vector3(0, 0.56, 0)
		pillar.add_child(orb)
		pillar.visible = false
		add_child(pillar)
		_markers.append(pillar)
		_marker_mats.append(mat)


func _update_spawn_markers() -> void:
	var specs: Array = []
	if sim.waves.state == SimWaves.PREP:
		var wave := sim.NextWave()
		for grp in wave.get("groups", []):
			specs.append_array(_marker_specs(grp))
	var shown := mini(specs.size(), _markers.size())
	var pulse := 0.20 + 0.14 * sin(_now * 3.2)
	for i in _markers.size():
		var marker: MeshInstance3D = _markers[i]
		if i >= shown:
			marker.visible = false
			continue
		var spec: Dictionary = specs[i]
		var angle: float = spec["angle"]
		var radius := minf(sim.spawn_radius, 6.7)
		marker.position = Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)
		marker.visible = true
		var is_boss := bool(spec.get("boss", false))
		marker.scale = Vector3(1.5, 1.8, 1.5) if is_boss else Vector3.ONE
		var col: Color = Palette.DANGER
		if is_boss:
			col = Color(1.0, 0.86, 0.45)
		elif bool(spec["armored"]):
			col = Palette.WARN
		var mat: StandardMaterial3D = _marker_mats[i]
		mat.albedo_color = Color(col.r, col.g, col.b, pulse)


func _marker_specs(grp: Dictionary) -> Array:
	var center := deg_to_rad(float(grp.get("center_deg", 90.0)))
	var arc := float(grp.get("arc_deg", 0.0))
	var armored := float(grp.get("armor", 1.0)) < 0.8
	var boss := bool(grp.get("boss", false))
	var out: Array = []
	if arc <= 0.1:
		out.append({"angle": center, "armored": armored, "boss": boss})
	elif arc >= 359.0:
		for k in 4:
			out.append({"angle": TAU * float(k) / 4.0, "armored": armored, "boss": boss})
	else:
		out.append({"angle": center - deg_to_rad(arc) * 0.5, "armored": armored, "boss": boss})
		out.append({"angle": center + deg_to_rad(arc) * 0.5, "armored": armored, "boss": boss})
	return out


func _build_cursor() -> void:
	_cursor = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.92, 0.92)
	_cursor.mesh = plane
	_cursor_mat = Palette.Additive(Palette.ACCENT, 0.3)
	_cursor.material_override = _cursor_mat
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.visible = false
	add_child(_cursor)

	_arrow = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.10, 0.02, 0.30)
	_arrow.mesh = box
	_arrow_mat = Palette.Additive(Palette.ACCENT, 0.85)
	_arrow.material_override = _arrow_mat
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.visible = false
	add_child(_arrow)


func _add_bar(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	bar.mesh = box
	bar.material_override = mat
	bar.position = pos
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar)
	return bar


# ---------------------------------------------------------------------------

func _rebuild_all() -> void:
	for dict in [_ghost_nodes, _mech_nodes, _crystal_nodes, _swapper_nodes, _belt_nodes, _enemy_nodes]:
		for id in dict:
			var n = dict[id]
			if is_instance_valid(n):
				n.queue_free()
		dict.clear()

	for id in sim.ghosts:
		var gv := GhostView.new()
		gv.Bind(sim, id)
		add_child(gv)
		_ghost_nodes[id] = gv
	for id in sim.mechanisms:
		var mv := MechanismView.new()
		mv.Bind(sim, id)
		add_child(mv)
		_mech_nodes[id] = mv
	for id in sim.belts:
		var bv := BeltView.new()
		bv.Bind(sim, id)
		add_child(bv)
		_belt_nodes[id] = bv
	for id in sim.crystals:
		var cv := CrystalView.new()
		cv.Bind(sim, id)
		add_child(cv)
		_crystal_nodes[id] = cv
	for id in sim.swappers:
		var sv := SwapperView.new()
		sv.Bind(sim, id)
		add_child(sv)
		_swapper_nodes[id] = sv
	for id in sim.enemies:
		var ev := EnemyView.new()
		ev.Bind(sim, id)
		add_child(ev)
		_enemy_nodes[id] = ev
	_rebuild_outlaw_rings()


func _on_structure_changed(_kind: String, _id: int, _cell: Vector2i) -> void:
	_rebuild_all()


func _on_structure_changed_removed(_kind: String, _id: int) -> void:
	_rebuild_all()


func _on_moved(_kind: String, _id: int, _from_cell: Vector2i, _to_cell: Vector2i) -> void:
	_rebuild_all()


func _on_swapper_worked(swapper_id: int, _mech_id: int, _crystal_id: int) -> void:
	var s: SimSwapper = sim.swappers.get(swapper_id)
	if s != null:
		_play_ring(s.base, 0.9, Palette.CRYSTAL, 0.35)
	_rebuild_all()


func _on_crystal_moved(_mech_id: int, _crystal_id: int) -> void:
	_rebuild_all()


func _on_enemy_spawned(enemy_id: int, _pos: Vector2, _hp: float) -> void:
	if _enemy_nodes.has(enemy_id):
		return
	var ev := EnemyView.new()
	ev.Bind(sim, enemy_id)
	add_child(ev)
	_enemy_nodes[enemy_id] = ev


func _on_enemy_killed(enemy_id: int, pos: Vector2, by_clear: bool) -> void:
	var ev: EnemyView = _enemy_nodes.get(enemy_id)
	if ev != null and is_instance_valid(ev):
		ev.queue_free()
	_enemy_nodes.erase(enemy_id)
	_play_ring(pos, 2.4 if by_clear else 1.2, Palette.WARN if by_clear else Palette.ENEMY, 0.45 if by_clear else 0.3)


func _on_enemy_breached(enemy_id: int, _total: int) -> void:
	var ev: EnemyView = _enemy_nodes.get(enemy_id)
	var pos := Vector2.ZERO
	if ev != null and is_instance_valid(ev):
		pos = Vector2(ev.position.x, ev.position.z)
		ev.queue_free()
	_enemy_nodes.erase(enemy_id)
	_play_ring(pos, 1.6, Palette.DANGER, 0.4)


func _on_pulse(ghost_id: int, pos: Vector2, _amplitude: float, _period: float) -> void:
	var g: SimGhost = sim.ghosts.get(ghost_id)
	var range_units := g.pulse_range if g != null else 6.0
	_play_ring(pos, range_units, Palette.GHOST, 0.8)


func _on_resonance_burst(pos: Vector2, _amplitude: float, radius: float) -> void:
	_play_ring(pos, radius, Color(1.0, 0.78, 0.35), 1.0)
	_play_ring(pos, radius * 0.55, Color(1.0, 0.95, 0.8), 0.7)


func _on_stood(ghost_id: int) -> void:
	var g: SimGhost = sim.ghosts.get(ghost_id)
	if g == null:
		return
	_play_ring(g.base, 1.4, Palette.ACCENT, 0.5)


func _play_ring(pos: Vector2, range_units: float, color: Color, duration: float = 0.75) -> void:
	var ring: PulseRing = null
	for r in _rings:
		if is_instance_valid(r) and not r.visible:
			ring = r
			break
	if ring == null:
		if _rings.size() >= 28:
			return
		ring = PulseRing.new()
		add_child(ring)
		_rings.append(ring)
	ring.Play(pos, range_units, color, duration)

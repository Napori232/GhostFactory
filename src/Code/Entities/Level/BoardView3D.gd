class_name BoardView3D
extends Node3D

## 3D 表现层：把 Board.GetStateSnapshot() 的只读投影画成几何体占位。
## 规则层完全不依赖本视图；遮挡、X-Ray、选中描边只影响可见性与点选，不参与任何判定。
## 美术约定：只用引擎内置 Mesh 程序化拼装，不引用 Art/ 下任何 WIP 资源；
## 深蓝地台 + 暖橙管线的冷色调配色，靠造型轮廓与自发光区分语义，不依赖贴图与后处理。

## 鬼能的占位颜色。
const FORM_COLORS: Dictionary = {
	"Spirit": Color(0.35, 0.85, 0.95),
	"Offer": Color(0.98, 0.78, 0.32),
	"Impurity": Color(0.48, 0.28, 0.62),
}

## 状态浮标配色：脚下光环与文字共用，一眼能读出运行 / 故障 / 暂停。
const STATE_COLORS: Dictionary = {
	"IDLE": Color(0.65, 0.68, 0.75),
	"RUNNING": Color(0.45, 0.95, 0.55),
	"PAUSED": Color(0.45, 0.72, 0.98),
	"FAULT": Color(1.0, 0.35, 0.35),
}

## 管线与地台的固定配色。
const LINE_COLOR: Color = Color(0.98, 0.63, 0.28)
const TILE_FRAME: Color = Color(0.06, 0.10, 0.18)
const TILE_PLAYABLE: Color = Color(0.18, 0.36, 0.55)
const TILE_PRODUCER: Color = Color(0.20, 0.55, 0.38)
const TILE_VOID: Color = Color(0.10, 0.12, 0.18)
const WALL_BODY: Color = Color(0.26, 0.27, 0.34)
const WALL_CAP: Color = Color(0.42, 0.44, 0.56)

@onready var cell_markers: Node3D = $CellMarkers
@onready var obstacles_root: Node3D = $Obstacles
@onready var facilities_root: Node3D = $Facilities
@onready var lines_root: Node3D = $Lines
@onready var ghosts_root: Node3D = $Ghosts
@onready var items_root: Node3D = $Items

var _last_revision: int = -1
var _xray: bool = false
var _selected_uid: int = -1
var _ghost_entries: Array[Dictionary] = []
var _ghost_materials: Array[StandardMaterial3D] = []
var _floaters: Array[Dictionary] = []
var _time: float = 0.0

## 掉落物轻微上下浮动，纯表现层动画，不写回任何规则状态。
## @param delta 帧间隔，单位：秒。
func _process(delta: float) -> void:
	if _floaters.is_empty():
		return
	_time += delta
	for item in _floaters:
		var node: Node3D = item["node"]
		if is_instance_valid(node):
			node.position.y = float(item["base_y"]) + sin(_time * 2.4 + float(item["phase"])) * 0.045

## 按关卡静态数据重建地台标记、障碍墙与设施（切关时调用一次）。
## @param snapshot Board.GetStateSnapshot() 的返回值。
func BuildStatic(snapshot: Dictionary) -> void:
	_clear(cell_markers)
	_clear(obstacles_root)
	_clear(facilities_root)
	var grid_size: Vector2i = snapshot["grid_size"]
	var placeable: Array = snapshot["placeable"]
	var producer_only: Array = snapshot.get("producer_only", [])
	var obstacles: Array = snapshot["obstacles"]
	var facilities: Array = snapshot["facilities"]
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			var center: Vector3 = Grid3D.CellToWorld3DCenter(cell)
			if obstacles.has(cell):
				_make_box(cell_markers, Vector3(0.94, 0.02, 0.94), center + Vector3(0, 0.012, 0), Color(0.16, 0.16, 0.21), 0.0, 1.0)
				_make_box(obstacles_root, Vector3(0.86, 0.62, 0.86), center + Vector3(0, 0.33, 0), WALL_BODY, 0.05, 1.0)
				_make_box(obstacles_root, Vector3(0.90, 0.06, 0.90), center + Vector3(0, 0.66, 0), WALL_CAP, 0.12, 1.0)
				_make_box(obstacles_root, Vector3(0.58, 0.02, 0.05), center + Vector3(0, 0.70, 0), Color(0.62, 0.68, 0.85), 0.35, 1.0)
			elif placeable.has(cell):
				# 双层地台：深色底板露出 0.06 格边框，亮色面板浮在上面。
				var is_producer_only := producer_only.has(cell)
				var tile_color := TILE_PRODUCER if is_producer_only else TILE_PLAYABLE
				_make_box(cell_markers, Vector3(0.96, 0.016, 0.96), center + Vector3(0, 0.010, 0), TILE_FRAME, 0.0, 1.0)
				_make_box(cell_markers, Vector3(0.84, 0.022, 0.84), center + Vector3(0, 0.024, 0), tile_color, 0.18 if is_producer_only else 0.12, 1.0)
				if is_producer_only:
					# 绿色生产专属格加一圈光环，比纯文字更容易在斜俯视下认出来。
					_make_torus(cell_markers, 0.30, 0.36, center + Vector3(0, 0.05, 0), Color(0.55, 0.95, 0.72), 0.55, 1.0)
					_make_label(cell_markers, "生产", center + Vector3(0, 0.22, 0), Color(0.62, 0.95, 0.76), 20)
			else:
				_make_box(cell_markers, Vector3(0.94, 0.02, 0.94), center + Vector3(0, 0.012, 0), TILE_VOID, 0.0, 1.0)
	for entry in facilities:
		var fac_cell: Vector2i = entry["cell"]
		var fac_center: Vector3 = Grid3D.CellToWorld3DCenter(fac_cell)
		var is_delivery: bool = String(entry["kind"]) == "DELIVERY"
		var base_color := Color(0.95, 0.72, 0.30) if is_delivery else Color(0.85, 0.50, 0.28)
		# 台座 → 发光立柱 → 顶部接收环，避免设施只是一块贴字平板。
		_make_box(facilities_root, Vector3(0.94, 0.10, 0.94), fac_center + Vector3(0, 0.05, 0), Color(0.09, 0.11, 0.18), 0.0, 1.0)
		_make_box(facilities_root, Vector3(0.80, 0.14, 0.80), fac_center + Vector3(0, 0.16, 0), base_color, 0.35, 1.0)
		_make_cylinder(facilities_root, 0.19, 0.24, 0.38, fac_center + Vector3(0, 0.42, 0), base_color, 0.45, 1.0)
		_make_torus(facilities_root, 0.22, 0.30, fac_center + Vector3(0, 0.63, 0), base_color, 0.85, 1.0)
		var title := "交付·%s" % _form_name(String(entry["accepted_form"])) if is_delivery else "仓库·鬼能"
		_make_label(facilities_root, title, fac_center + Vector3(0, 0.98, 0), base_color, 30)
	_last_revision = -1

## 按状态版本号增量刷新鬼、掉落物与连线。
## @param snapshot Board.GetStateSnapshot() 的返回值。
func Refresh(snapshot: Dictionary) -> void:
	var revision := int(snapshot["revision"])
	if revision == _last_revision:
		return
	_last_revision = revision
	_rebuild_ghosts(snapshot["ghosts"])
	_rebuild_items(snapshot["items"])
	_rebuild_lines(snapshot["links"])

## 切换 X-Ray：只把鬼模型改半透，地台、格线、掉落物与设施保持不透明。
## @param enabled 是否开启透视。
func SetXRay(enabled: bool) -> void:
	_xray = enabled
	var alpha := ExportSettings.view_xray_alpha if enabled else 1.0
	for material in _ghost_materials:
		if material == null:
			continue
		var c := material.albedo_color
		material.albedo_color = Color(c.r, c.g, c.b, alpha)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED

## 设置当前选中的鬼，触发选中描边。
## @param uid 鬼实例编号；-1 表示取消选中。
func SetSelected(uid: int) -> void:
	if _selected_uid == uid:
		return
	_selected_uid = uid
	_last_revision = -1

## 取当前鬼占位条目，供 Picker3D 精确命中。
## @return 含 cell 的字典数组。
func GetGhostEntries() -> Array[Dictionary]:
	return _ghost_entries.duplicate(true)

## 重建全部鬼模型：底座 + 状态环 + 按类别区分的主体造型 + 选中环 + 标签。
## Picker3D 用固定 0.8 的 AABB 命中，所有实体部件都收在这个高度内，改造型不影响点选。
## @param entries 状态快照里的鬼列表。
func _rebuild_ghosts(entries: Array) -> void:
	_clear(ghosts_root)
	_ghost_entries.clear()
	_ghost_materials.clear()
	var alpha := ExportSettings.view_xray_alpha if _xray else 1.0
	for entry in entries:
		var cell: Vector2i = entry["cell"]
		var uid := int(entry["uid"])
		var state := String(entry["state"])
		var category := String(entry.get("category", ""))
		var color: Color = entry["color"]
		var center: Vector3 = Grid3D.CellToWorld3DCenter(cell)
		var emission := 0.45 if state == "RUNNING" else 0.14
		if state == "FAULT":
			color = Color(0.95, 0.32, 0.32)
			emission = 0.7
		var pedestal := _make_cylinder(ghosts_root, 0.38, 0.44, 0.10, center + Vector3(0, 0.05, 0), Color(0.09, 0.12, 0.19), 0.05, alpha)
		_ghost_materials.append(pedestal.material_override as StandardMaterial3D)
		var state_color: Color = STATE_COLORS.get(state, Color.WHITE)
		var ring := _make_torus(ghosts_root, 0.32, 0.40, center + Vector3(0, 0.11, 0), state_color, 0.75, alpha)
		_ghost_materials.append(ring.material_override as StandardMaterial3D)
		for part in _build_ghost_shape(category, center, color, emission, alpha):
			_ghost_materials.append(part.material_override as StandardMaterial3D)
		if uid == _selected_uid:
			_make_torus(ghosts_root, 0.43, 0.48, center + Vector3(0, 0.13, 0), Color(1.0, 0.95, 0.60), 1.0, 0.95)
		_make_label(ghosts_root, String(entry["name"]), center + Vector3(0, 1.02, 0), Color(0.94, 0.96, 1.0), 30)
		_make_label(ghosts_root, "[%s] %d/%d" % [state, int(entry["input_count"]), int(entry["output_count"])], center + Vector3(0, 1.34, 0), state_color, 24)
		_ghost_entries.append({"cell": cell, "uid": uid})

## 按鬼的类别拼出可分辨的轮廓：炉体 / 漏斗 / 运输台 / 双塔。
## @param category GhostData.category 的字符串值。
## @param center 格中心世界坐标。
## @param color 该鬼的基色。
## @param emission 自发光强度。
## @param alpha 不透明度。
## @return 新建的 MeshInstance3D 数组。
func _build_ghost_shape(category: String, center: Vector3, color: Color, emission: float, alpha: float) -> Array[MeshInstance3D]:
	var parts: Array[MeshInstance3D] = []
	match category:
		"PRODUCTION":
			# 生产鬼：蒸馏炉 + 顶部冒出的鬼能球。
			parts.append(_make_cylinder(ghosts_root, 0.27, 0.34, 0.46, center + Vector3(0, 0.34, 0), color, emission, alpha))
			parts.append(_make_sphere(ghosts_root, 0.15, center + Vector3(0, 0.68, 0), Color(0.60, 0.94, 1.0), 0.85, alpha))
		"COLLECTION":
			# 采集鬼：上宽下窄的漏斗 + 收集口光环。
			parts.append(_make_cylinder(ghosts_root, 0.36, 0.11, 0.48, center + Vector3(0, 0.35, 0), color, emission, alpha))
			parts.append(_make_torus(ghosts_root, 0.29, 0.35, center + Vector3(0, 0.60, 0), color, 0.60, alpha))
		"TRANSPORT":
			# 运输鬼：低矮载台 + 朝北的指向条与前端灯。
			parts.append(_make_box(ghosts_root, Vector3(0.56, 0.34, 0.56), center + Vector3(0, 0.30, 0), color, emission, alpha))
			parts.append(_make_box(ghosts_root, Vector3(0.11, 0.06, 0.56), center + Vector3(0, 0.51, 0), Color(0.98, 0.86, 0.58), 0.55, alpha))
			parts.append(_make_sphere(ghosts_root, 0.08, center + Vector3(0, 0.53, -0.30), Color(1.0, 0.92, 0.65), 0.8, alpha))
		"PROCESSING":
			# 处理鬼：双塔 + 中间反应球。
			parts.append(_make_cylinder(ghosts_root, 0.14, 0.16, 0.50, center + Vector3(-0.18, 0.36, 0), color, emission, alpha))
			parts.append(_make_cylinder(ghosts_root, 0.14, 0.16, 0.50, center + Vector3(0.18, 0.36, 0), color, emission, alpha))
			parts.append(_make_sphere(ghosts_root, 0.17, center + Vector3(0, 0.62, 0), Color(0.98, 0.80, 0.42), 0.65, alpha))
		_:
			parts.append(_make_box(ghosts_root, Vector3(0.76, 0.72, 0.76), center + Vector3(0, 0.38, 0), color, emission, alpha))
	return parts

## 重建全部掉落物：低分段球当晶体，脚下加一圈淡光环，并登记浮动动画。
## @param entries 状态快照里的掉落物列表。
func _rebuild_items(entries: Array) -> void:
	_clear(items_root)
	_floaters.clear()
	for entry in entries:
		var cell: Vector2i = entry["cell"]
		var form := String(entry["form"])
		var amount := int(entry["amount"])
		var color: Color = FORM_COLORS.get(form, Color.WHITE)
		var center: Vector3 = Grid3D.CellToWorld3DCenter(cell)
		_make_torus(items_root, 0.20, 0.25, center + Vector3(0, 0.045, 0), color, 0.35, 1.0)
		var gem := _make_gem(items_root, 0.18, center + Vector3(0, 0.24, 0), color, 0.7)
		_floaters.append({"node": gem, "base_y": gem.position.y, "phase": float(cell.x) * 0.7 + float(cell.y) * 1.3})
		if amount > ExportSettings.sim_stack_threshold:
			_make_label(items_root, "×%d" % amount, center + Vector3(0, 0.58, 0), Color.WHITE, 26)

## 重建连线：发光圆管逐段铺设，起点 / 终点 / 转角补接头球，看起来像真实管路。
## @param entries 状态快照里的连线列表。
func _rebuild_lines(entries: Array) -> void:
	_clear(lines_root)
	for entry in entries:
		var path: Array = entry["path"]
		for i in range(path.size() - 1):
			var a: Vector2i = path[i]
			var b: Vector2i = path[i + 1]
			var mid: Vector3 = (Grid3D.CellToWorld3DCenter(a) + Grid3D.CellToWorld3DCenter(b)) * 0.5
			var pipe := _make_cylinder(lines_root, 0.055, 0.055, 1.0, mid + Vector3(0, 0.075, 0), LINE_COLOR, 0.55, 1.0)
			# CylinderMesh 默认沿 Y；沿格线铺平后分别对齐世界 X / Z 轴。
			if b.x != a.x:
				pipe.rotation_degrees.z = 90.0
			else:
				pipe.rotation_degrees.x = 90.0
		for i in range(path.size()):
			var prev: Vector2i = path[maxi(i - 1, 0)]
			var next: Vector2i = path[mini(i + 1, path.size() - 1)]
			var is_turn := prev.x != next.x and prev.y != next.y
			if i == 0 or i == path.size() - 1 or is_turn:
				var joint_cell: Vector2i = path[i]
				_make_sphere(lines_root, 0.085, Grid3D.CellToWorld3DCenter(joint_cell) + Vector3(0, 0.075, 0), LINE_COLOR, 0.8, 1.0)

## 创建一个带材质的方块。
## @param parent 挂载节点。
## @param size 方块尺寸（世界单位）。
## @param pos 中心位置。
## @param color 基色。
## @param emission 自发光强度，0 表示关闭。
## @param alpha 不透明度。
## @return 新建的 MeshInstance3D。
func _make_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission: float, alpha: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = pos
	instance.material_override = _material(color, emission, alpha)
	parent.add_child(instance)
	return instance

## 创建一个圆柱 / 圆台（炉体、立柱、管线共用）。
## @param parent 挂载节点。
## @param top_radius 顶面半径。
## @param bottom_radius 底面半径。
## @param height 高度。
## @param pos 中心位置。
## @param color 基色。
## @param emission 自发光强度。
## @param alpha 不透明度。
## @return 新建的 MeshInstance3D。
func _make_cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, pos: Vector3, color: Color, emission: float, alpha: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	cylinder.radial_segments = 16
	instance.mesh = cylinder
	instance.position = pos
	instance.material_override = _material(color, emission, alpha)
	parent.add_child(instance)
	return instance

## 创建一个水平光环（状态环 / 选中环 / 设施接收口）。
## @param parent 挂载节点。
## @param inner_radius 内半径。
## @param outer_radius 外半径。
## @param pos 中心位置。
## @param color 基色。
## @param emission 自发光强度。
## @param alpha 不透明度。
## @return 新建的 MeshInstance3D。
func _make_torus(parent: Node3D, inner_radius: float, outer_radius: float, pos: Vector3, color: Color, emission: float, alpha: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner_radius
	torus.outer_radius = outer_radius
	torus.rings = 16
	torus.ring_segments = 24
	instance.mesh = torus
	instance.position = pos
	instance.material_override = _material(color, emission, alpha)
	parent.add_child(instance)
	return instance

## 创建一个小球占位。
## @param parent 挂载节点。
## @param radius 球半径（世界单位）。
## @param pos 中心位置。
## @param color 基色。
## @param emission 自发光强度。
## @param alpha 不透明度。
## @return 新建的 MeshInstance3D。
func _make_sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, emission: float, alpha: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	instance.mesh = sphere
	instance.position = pos
	instance.material_override = _material(color, emission, alpha)
	parent.add_child(instance)
	return instance

## 创建一个低分段晶体（掉落物），靠棱面而不是贴图区分形态。
## @param parent 挂载节点。
## @param radius 外接半径。
## @param pos 中心位置。
## @param color 基色。
## @param emission 自发光强度。
## @return 新建的 MeshInstance3D。
func _make_gem(parent: Node3D, radius: float, pos: Vector3, color: Color, emission: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var gem := SphereMesh.new()
	gem.radius = radius
	gem.height = radius * 2.2
	gem.radial_segments = 6
	gem.rings = 3
	instance.mesh = gem
	instance.position = pos
	instance.material_override = _material(color, emission, 1.0)
	parent.add_child(instance)
	return instance

## 创建始终朝向玩家的 Billboard 文字。
## @param parent 挂载节点。
## @param text 文本内容。
## @param pos 位置。
## @param color 文字颜色。
## @param font_size 字号。
## @return 新建的 Label3D。
func _make_label(parent: Node3D, text: String, pos: Vector3, color: Color, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = font_size
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color(0.02, 0.03, 0.06)
	parent.add_child(label)
	return label

## 构造标准材质。gl_compatibility 后端不依赖环境贴图，因此保持 metallic = 0，
## 只用 albedo + emission + 略低的粗糙度做层次，避免金属度把颜色压黑。
## @param color 基色。
## @param emission 自发光强度。
## @param alpha 不透明度。
## @return 材质资源。
func _material(color: Color, emission: float, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = 0.5
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

## 清空一个节点下的全部子节点。
## @param parent 待清空的节点。
func _clear(parent: Node3D) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

## 形态 id 的中文名。
## @param form 形态 id。
## @return 中文名。
func _form_name(form: String) -> String:
	match form:
		"Spirit":
			return "鬼能"
		"Offer":
			return "贡品"
		"Impurity":
			return "杂质"
	return form

class_name GridFloor
extends MeshInstance3D

## 3D 地台：有厚度的底板，尺寸随关卡网格变化。
## 格线由每格 CellMarker 之间的缝隙 + 底板深色形成，避免 shader / UV 纹理在
## gl_compatibility 下的兼容差异；对应 CodePlan §5.9.5 的「格线与格子对齐」要求。
## 另负责整关的灯光氛围：外圈发光边框 + 温和环境光，不启用阴影 / 雾 / 后处理，
## 保证 gl_compatibility 后端行为一致。

## 外圈边框与背景的配色，沿用深蓝冷色调。
const BORDER_COLOR: Color = Color(0.25, 0.45, 0.75)
const SKY_COLOR: Color = Color(0.05, 0.06, 0.11)
const AMBIENT_COLOR: Color = Color(0.50, 0.60, 0.85)

## 按关卡网格尺寸重建地台。
## @param grid_size 网格尺寸（格），1 格 = 1.0 世界单位。
func Build(grid_size: Vector2i) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(float(grid_size.x) * Grid3D.CELL, 0.12, float(grid_size.y) * Grid3D.CELL)
	mesh = box
	position = Vector3(float(grid_size.x) * Grid3D.CELL * 0.5, -0.06, -float(grid_size.y) * Grid3D.CELL * 0.5)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.07, 0.09, 0.14)
	material.roughness = 0.9
	material_override = material

	# 切关会重复调用 Build，先清掉上一关挂在本节点下的装饰与环境。
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build_border(grid_size)
	_setup_environment()
	_setup_sun()

## 在地台四边铺细发光条，让棋盘边界在斜俯视下清晰可辨。
## @param grid_size 网格尺寸（格）。
func _build_border(grid_size: Vector2i) -> void:
	var width := float(grid_size.x) * Grid3D.CELL
	var depth := float(grid_size.y) * Grid3D.CELL
	var cx := width * 0.5
	var cz := -depth * 0.5
	_add_bar(Vector3(width + 0.12, 0.03, 0.06), Vector3(cx, 0.02, 0.03))
	_add_bar(Vector3(width + 0.12, 0.03, 0.06), Vector3(cx, 0.02, -depth - 0.03))
	_add_bar(Vector3(0.06, 0.03, depth + 0.12), Vector3(-0.03, 0.02, cz))
	_add_bar(Vector3(0.06, 0.03, depth + 0.12), Vector3(width + 0.03, 0.02, cz))

## 创建一条边框条。
## @param size 方块尺寸。
## @param pos 中心位置。
func _add_bar(size: Vector3, pos: Vector3) -> void:
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = size
	bar.mesh = bar_mesh
	bar.position = pos
	var bar_material := StandardMaterial3D.new()
	bar_material.albedo_color = BORDER_COLOR
	bar_material.emission_enabled = true
	bar_material.emission = BORDER_COLOR
	bar_material.emission_energy_multiplier = 0.45
	bar.material_override = bar_material
	add_child(bar)

## 用纯色背景 + 定色环境光把整关统一到冷色调，避免默认灰蓝天空冲淡发光部件。
## 只设 background / ambient，不碰 tonemap、fog、glow 等兼容性敏感项。
func _setup_environment() -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = 0.7
	env_node.environment = env
	add_child(env_node)

## 把主光调成偏暖白，让暖橙管线与冷蓝地台形成对比；不改强度与阴影开关。
func _setup_sun() -> void:
	var world := get_parent()
	if world == null:
		return
	var sun := world.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = Color(1.0, 0.94, 0.86)

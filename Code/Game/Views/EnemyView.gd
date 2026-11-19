class_name EnemyView
extends Node3D
## 魅：不受物理影响的暗色实体，径直走向中央。
## 体型与颜色由血量 / 速度决定：快魅小而亮，厚魅大而暗——
## 玩家不需要读数字就能分辨「这个是冲过来的」还是「这个要磨」。

var id: int = -1
var _body_mat: StandardMaterial3D
var _body: MeshInstance3D
var _spawn_t: float = 0.0
var _body_scale: float = 1.0


func Bind(sim: Sim, enemy_id: int) -> void:
	id = enemy_id
	_build(sim)


func _build(sim: Sim) -> void:
	var e: SimEnemy = sim.enemies.get(id)
	var tank := 0.0
	var fast := 0.0
	var armored := false
	var boss := false
	if e != null:
		tank = clampf((e.max_hp - 40.0) / 130.0, 0.0, 1.0)
		fast = clampf((e.speed - 0.5) / 0.45, 0.0, 1.0)
		armored = e.IsArmored()
		boss = e.IsBoss()
	_body_scale = 0.9 + tank * 0.35 + (0.18 if armored else 0.0)
	if boss:
		_body_scale = 2.0

	_body_mat = Palette.Rim(Color(0.09, 0.05, 0.12), Palette.ENEMY, 0.9)
	if armored:
		_body_mat = Palette.Rim(Color(0.10, 0.11, 0.14), Color(0.85, 0.55, 0.25), 1.1)
		_body_mat.metallic = 0.7
		_body_mat.roughness = 0.35
	if boss:
		_body_mat = Palette.Rim(Color(0.07, 0.05, 0.09), Color(1.0, 0.76, 0.32), 1.3)
		_body_mat.metallic = 0.55
		_body_mat.roughness = 0.4
	_body_mat.emission_energy_multiplier = 0.35 + fast * 0.55
	_body = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.20 + tank * 0.07
	capsule.height = 0.74 + tank * 0.18
	capsule.radial_segments = 12
	capsule.rings = 6
	_body.mesh = capsule
	_body.material_override = _body_mat
	_body.position = Vector3(0, 0.52, 0)
	add_child(_body)

	# 甲魅：一圈厚重的护甲环，和普通魅一眼区分
	if armored:
		var shell := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.25
		torus.outer_radius = 0.34
		torus.rings = 24
		torus.ring_segments = 8
		shell.mesh = torus
		shell.rotation.x = PI * 0.5
		shell.position = Vector3(0, 0.55, 0)
		shell.material_override = Palette.Solid(Color(0.18, 0.16, 0.14), 0.9, 0.3)
		add_child(shell)

	var eye_color := Color(1.0, 0.62, 0.25) if fast > 0.35 else Color(1.0, 0.28, 0.38)
	if armored:
		eye_color = Color(1.0, 0.82, 0.35)
	if boss:
		eye_color = Color(1.0, 0.88, 0.55)
		var crown := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.26
		torus.outer_radius = 0.34
		torus.rings = 24
		torus.ring_segments = 8
		crown.mesh = torus
		crown.rotation.x = PI * 0.5
		crown.position = Vector3(0, 0.94, 0)
		crown.material_override = Palette.Glow(Color(1.0, 0.8, 0.35), 2.4)
		add_child(crown)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.042 + fast * 0.008 + (0.022 if boss else 0.0)
		eye_mesh.height = eye_mesh.radius * 2.0
		eye_mesh.radial_segments = 8
		eye_mesh.rings = 4
		eye.mesh = eye_mesh
		eye.material_override = Palette.Glow(eye_color, 3.0)
		eye.position = Vector3(0.07 * side, 0.63, -0.19)
		add_child(eye)


func Sync(sim: Sim, now: float, dt: float) -> void:
	var e: SimEnemy = sim.enemies.get(id)
	if e == null:
		visible = false
		return
	visible = true
	_spawn_t = minf(1.0, _spawn_t + dt * 4.0)
	var bob := sin(now * 2.6 + float(id) * 0.7) * 0.05
	position = Vector3(e.pos.x, 0.05 + bob, e.pos.y)
	rotation.y = atan2(-e.pos.x, -e.pos.y)
	var s := (0.35 + 0.65 * _spawn_t) * _body_scale
	scale = Vector3.ONE * s

	var hp := e.HealthRatio()
	_body_mat.albedo_color = Color(0.09, 0.05, 0.12).lerp(Color(0.45, 0.06, 0.12), 1.0 - hp)
	_body_mat.emission_energy_multiplier = 0.35 + (1.0 - hp) * 1.4

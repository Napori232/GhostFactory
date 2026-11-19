class_name PulseRing
extends Node3D
## 脉冲可视化：一圈从鬼的位置向外扩散的细环。
## 用 shader 在方形贴图上画环，而不是缩放一个圆环模型——
## 这样无论扩到多远，环的粗细都保持不变。

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 ring_color : source_color = vec4(0.55, 0.9, 1.0, 1.0);
uniform float progress = 0.0;
uniform float thickness = 0.022;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float ring = 1.0 - smoothstep(thickness * 0.3, thickness, abs(d - progress));
	float fade = 1.0 - smoothstep(0.5, 1.0, progress);
	ALBEDO = ring_color.rgb;
	ALPHA = ring * fade * ring_color.a;
}
"""

var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _dur: float = 0.75
var _life: float = 0.0
var _active: bool = false
var _color: Color = Color(0.55, 0.9, 1.0)


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)  # 半径 1，靠节点 scale 放大到目标射程
	_mesh.mesh = plane
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mesh.material_override = _mat
	add_child(_mesh)
	visible = false
	set_process(false)


## 播放一次脉冲环。range_units 决定扩散半径。
func Play(pos: Vector2, range_units: float, color: Color, duration: float = 0.75) -> void:
	position = Vector3(pos.x, 0.055, pos.y)
	scale = Vector3.ONE * maxf(0.5, range_units)
	_dur = maxf(0.05, duration)
	_life = 0.0
	_color = color
	_active = true
	_mat.set_shader_parameter("ring_color", Color(color.r, color.g, color.b, 0.95))
	_mat.set_shader_parameter("progress", 0.1)
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	if not _active:
		return
	_life += delta
	var t := clampf(_life / _dur, 0.0, 1.0)
	var eased := 0.1 + 0.9 * (1.0 - pow(1.0 - t, 2.4))
	_mat.set_shader_parameter("progress", eased)
	_mat.set_shader_parameter("ring_color", Color(_color.r, _color.g, _color.b, pow(1.0 - t, 1.4) * 0.95))
	if t >= 1.0:
		_active = false
		visible = false
		set_process(false)

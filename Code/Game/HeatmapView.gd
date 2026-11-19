class_name HeatmapView
extends MeshInstance3D
## 共振热力图：把 Sim.heat（每格的合成振幅）烘成一张单通道贴图，
## 铺在一块半透明平面上。只给「哪儿热」，不给数字与解法。

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D heat_tex : filter_nearest, repeat_disable;
uniform vec3 tint_low : source_color = vec3(0.10, 0.45, 0.42);
uniform vec3 tint_mid : source_color = vec3(0.85, 0.62, 0.18);
uniform vec3 tint_high : source_color = vec3(1.0, 0.84, 0.52);
uniform vec2 tex_size = vec2(13.0, 13.0);

float contour(float v, float t) {
	return 1.0 - smoothstep(0.0, 0.03, abs(v - t));
}

void fragment() {
	float v = texture(heat_tex, UV).r;   // 1.0 = 清场线
	// 压缩高值：一台巨型机器能把整片场抬到 4~6 倍清场线，
	// 线性映射会把整张图烧成白色，反而看不见装置。
	float t = v / (1.0 + v * 1.8);
	float alpha = smoothstep(0.08, 0.34, t) * 0.19;
	vec3 c = mix(tint_low, tint_mid, smoothstep(0.12, 0.40, t));
	c = mix(c, tint_high, smoothstep(0.40, 0.72, t));
	float line = contour(v, 0.25) + contour(v, 0.5) + contour(v, 1.0) + contour(v, 2.0) + contour(v, 3.0);
	c = mix(c, vec3(1.0), clamp(line, 0.0, 1.0) * 0.22);
	alpha += clamp(line, 0.0, 1.0) * 0.08;

	// 格子边界：让「按格标注」看得见
	vec2 cs = abs(fract(UV * tex_size) - 0.5);
	float grid = smoothstep(0.46, 0.5, max(cs.x, cs.y));
	alpha = max(alpha, grid * 0.10 * step(0.06, v));

	ALBEDO = c;
	ALPHA = alpha;
}
"""

var sim: Sim
var _texture: ImageTexture
var _material: ShaderMaterial
var _image: Image
var _timer: float = 0.0


func Bind(sim_ref: Sim) -> void:
	sim = sim_ref
	var plane := PlaneMesh.new()
	plane.size = Vector2(float(sim.grid.width), float(sim.grid.height)) * sim.grid.cell_size
	mesh = plane
	position = Vector3(0, 0.045, 0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	material_override = _material
	_material.set_shader_parameter("tint_low", Color(0.10, 0.45, 0.42))
	_material.set_shader_parameter("tint_mid", Color(0.85, 0.62, 0.18))
	_material.set_shader_parameter("tint_high", Color(1.0, 0.84, 0.52))
	_rebuild_texture()


func Update(dt: float) -> void:
	_timer -= dt
	if _timer > 0.0:
		return
	_timer = 1.0 / maxf(1.0, sim.config.heat_sample_hz)
	_refresh()


func _rebuild_texture() -> void:
	var w := sim.heat_w
	var h := sim.heat_h
	if w <= 0 or h <= 0:
		return
	_image = Image.create(w, h, false, Image.FORMAT_R8)
	_texture = ImageTexture.create_from_image(_image)
	_material.set_shader_parameter("heat_tex", _texture)
	_material.set_shader_parameter("tex_size", Vector2(float(w), float(h)))
	_refresh()


func _refresh() -> void:
	if _image == null or _texture == null:
		return
	var w := sim.heat_w
	var h := sim.heat_h
	if sim.heat.size() != w * h:
		return
	var clear_line := maxf(sim.ClearLine(), 0.001)
	var bytes := PackedByteArray()
	bytes.resize(w * h)
	for i in w * h:
		bytes[i] = clampi(int(round(sim.heat[i] / clear_line * 255.0)), 0, 255)
	_image.set_data(w, h, false, Image.FORMAT_R8, bytes)
	_texture.update(_image)

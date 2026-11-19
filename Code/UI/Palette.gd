class_name Palette
extends RefCounted
## 全工程唯一色板。改配色只改这里。

const BG := Color(0.027, 0.043, 0.067)
const PANEL := Color(0.067, 0.102, 0.141)
const PANEL_SOLID := Color(0.043, 0.063, 0.086)
const BORDER := Color(0.149, 0.22, 0.29)
const TEXT := Color(0.863, 0.91, 0.949)
const MUTED := Color(0.561, 0.651, 0.722)
const ACCENT := Color(0.31, 0.839, 0.753)
const WARN := Color(1.0, 0.706, 0.329)
const DANGER := Color(1.0, 0.373, 0.427)
const GHOST := Color(0.475, 0.831, 1.0)
const MECH := Color(0.788, 0.627, 0.416)
const CRYSTAL := Color(0.31, 0.878, 0.769)
const ENEMY := Color(0.78, 0.24, 0.42)
const GROUND := Color(0.043, 0.062, 0.086)


## 不透明实体材质。
static func Solid(color: Color, metallic: float = 0.1, roughness: float = 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


## 自发光材质（能量 0..）。
static func Glow(color: Color, energy: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.0
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## 半透明加色材质（脉冲环、热力图叠加用）。
static func Additive(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	return m


## 带轮廓光的暗色材质（魅）。
static func Rim(color: Color, rim_color: Color, rim_amount: float = 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	m.metallic = 0.0
	m.rim_enabled = true
	m.rim = rim_amount
	m.rim_tint = 0.1
	m.emission_enabled = true
	m.emission = rim_color
	m.emission_energy_multiplier = 0.35
	return m

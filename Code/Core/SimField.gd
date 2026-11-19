class_name SimField
extends RefCounted
## 脉冲场：把「正在发脉冲的鬼」当成波源，算出任意一点的合成振幅。
##
## 物理口径（见 docs/ARCHITECTURE.md）：
##   - 每个源有固有周期 period、当前相位 phase、振幅 amplitude、有效半径 range。
##   - 距离衰减：线性衰减到 range 处归零。
##   - 传播延迟：相位随距离滞后 2π·d/(speed·period)。
##   - 同周期（同一频率）的源相干叠加：复数相量相加，反相即抵消。
##   - 不同周期不锁相：按能量相加（RMS），即 sqrt(Σ|S|²)。
## 这样「同频同相变强 / 同频反相变冷 / 异频拍频」都能自动涌现，
## 不需要任何写死的组合规则表。

var speed: float = 6.0

var _pos: PackedVector2Array = PackedVector2Array()
var _period: PackedFloat64Array = PackedFloat64Array()
var _phase: PackedFloat64Array = PackedFloat64Array()
var _amp: PackedFloat64Array = PackedFloat64Array()
var _range: PackedFloat64Array = PackedFloat64Array()


## 清空所有波源（每 tick 由 Sim 重建，源数量很小）。
func Clear() -> void:
	_pos.clear()
	_period.clear()
	_phase.clear()
	_amp.clear()
	_range.clear()


## 追加一个波源。
func AddSource(pos: Vector2, period: float, phase: float, amplitude: float, range_units: float) -> void:
	if period <= 0.0 or amplitude <= 0.0 or range_units <= 0.0:
		return
	_pos.append(pos)
	_period.append(period)
	_phase.append(phase)
	_amp.append(amplitude)
	_range.append(range_units)


## 波源数量。
func SourceCount() -> int:
	return _pos.size()


## 采样某点的合成振幅（峰值包络口径）。
func EnvelopeAt(p: Vector2) -> float:
	var count := _pos.size()
	if count == 0:
		return 0.0
	# 以周期为键分组：只有同周期的波才相干叠加。
	var real := {}
	var imag := {}
	for i in count:
		var d := p.distance_to(_pos[i])
		var r := _range[i]
		if d >= r:
			continue
		var a := _amp[i] * (1.0 - d / r)
		if a <= 0.0:
			continue
		var wavelength_factor := speed * _period[i]
		var angle := _phase[i]
		if wavelength_factor > 0.0:
			angle -= TAU * d / wavelength_factor
		var key := int(round(_period[i] * 1000.0))
		real[key] = float(real.get(key, 0.0)) + cos(angle) * a
		imag[key] = float(imag.get(key, 0.0)) + sin(angle) * a
	var power := 0.0
	for key in real:
		var re: float = real[key]
		var im: float = imag[key]
		power += re * re + im * im
	return sqrt(power)

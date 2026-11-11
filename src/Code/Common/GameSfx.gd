class_name GameSfx
extends RefCounted

## 程序化音效库：运行时合成 16-bit PCM，不依赖任何外部音频文件。
## 下周计划 §6-7 要求的四个基础音（放置 / 拾取 / 加工 / 交付）全部由这里产出，
## 另补界面与状态提示音，以及一段可循环的工厂环境底噪，让设置面板的五条音量通道都有实际内容。

## 采样率（Hz）。22050 足够覆盖这些短促的合成音，且内存占用小。
const MIX_RATE: int = 22050
## 全局输出增益，留足余量避免削波。
const BASE_GAIN: float = 0.32
## 环境底噪的循环长度（秒）。
const AMBIENT_SECONDS: float = 8.0

const ID_PLACE: StringName = &"place"
const ID_PICKUP: StringName = &"pickup"
const ID_PROCESS: StringName = &"process"
const ID_DELIVER: StringName = &"deliver"
const ID_CONNECT: StringName = &"connect"
const ID_DISCONNECT: StringName = &"disconnect"
const ID_DROP: StringName = &"drop"
const ID_IMPURITY: StringName = &"impurity"
const ID_FAULT: StringName = &"fault"
const ID_COMPLETE: StringName = &"complete"
const ID_FAILED: StringName = &"failed"

## 全部一次性音效 id，供测试与音量校验遍历。
const SFX_IDS: Array[StringName] = [
	ID_PLACE, ID_PICKUP, ID_PROCESS, ID_DELIVER,
	ID_CONNECT, ID_DISCONNECT, ID_DROP, ID_IMPURITY,
	ID_FAULT, ID_COMPLETE, ID_FAILED,
]

static var _cache: Dictionary = {}
static var _ambient: AudioStreamWAV = null

## 取一个一次性音效流，同一 id 复用缓存。
## @param id SFX_IDS 中的音效标识。
## @return 合成好的音频流；未知 id 返回 null。
static func Get(id: StringName) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var samples: PackedFloat32Array = _make_samples(id)
	if samples.is_empty():
		return null
	var stream := _render(samples, false)
	_cache[id] = stream
	return stream

## 取可循环的工厂环境底噪（低频和弦 + 缓慢起伏）。
## @return 循环音频流。
static func GetAmbient() -> AudioStreamWAV:
	if _ambient != null:
		return _ambient
	var samples := _make_ambient()
	_ambient = _render(samples, true)
	return _ambient

## 按 id 分派到对应音色。
## @param id 音效标识。
## @return 单声道振幅数组；未知 id 返回空数组。
static func _make_samples(id: StringName) -> PackedFloat32Array:
	match id:
		ID_PLACE:
			return _make_place()
		ID_PICKUP:
			return _make_pickup()
		ID_PROCESS:
			return _make_process()
		ID_DELIVER:
			return _make_deliver()
		ID_CONNECT:
			return _make_connect()
		ID_DISCONNECT:
			return _make_disconnect()
		ID_DROP:
			return _make_drop()
		ID_IMPURITY:
			return _make_impurity()
		ID_FAULT:
			return _make_fault()
		ID_COMPLETE:
			return _make_complete()
		ID_FAILED:
			return _make_failed()
	return PackedFloat32Array()

## 分配一段给定秒数的振幅数组。
## @param seconds 时长（秒）。
## @return 全零数组。
static func _buffer(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(maxi(1, int(seconds * float(MIX_RATE))))
	samples.fill(0.0)
	return samples

## 确定性伪噪声，保证每次运行音色一致。
## @param i 采样序号。
## @return -1.0~1.0 的噪声值。
static func _noise(i: int) -> float:
	return fmod(sin(float(i) * 12.9898 + 78.233) * 43758.5453, 1.0) * 2.0 - 1.0

## 方波（带一点柔化，避免过亮）。
## @param phase 0~1 的相位。
## @return -1.0~1.0 的波形值。
static func _square(phase: float) -> float:
	return tanh(sin(TAU * phase) * 4.0)

## 把振幅数组打包成 AudioStreamWAV。
## @param samples 单声道振幅数组。
## @param loop 是否设置整段循环。
## @return 可直接交给 AudioStreamPlayer 的音频流。
static func _render(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var count := samples.size()
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		# 软限幅：既保留力度，也不让 16-bit 定点数溢出。
		var value := tanh(samples[i]) * 0.92
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

## 在指定区间叠加一个带包络的音符。
## @param samples 目标振幅数组。
## @param start 起始秒数。
## @param duration 时长（秒）。
## @param freq 基频（Hz）。
## @param gain 音量。
## @param wave 0 正弦 / 1 方波 / 2 三角波。
## @param decay 指数衰减系数，越大越短促。
static func _add_note(
	samples: PackedFloat32Array,
	start: float,
	duration: float,
	freq: float,
	gain: float,
	wave: int,
	decay: float
) -> void:
	var first := maxi(0, int(start * float(MIX_RATE)))
	var last := mini(samples.size(), int((start + duration) * float(MIX_RATE)))
	for i in range(first, last):
		var t := float(i - first) / float(MIX_RATE)
		var env := exp(-t * decay)
		var phase := fmod(t * freq, 1.0)
		var tone: float
		match wave:
			1:
				tone = _square(phase)
			2:
				tone = 1.0 - 4.0 * absf(phase - 0.5)
			_:
				tone = sin(TAU * phase)
		samples[i] += tone * env * gain

## 放置：低频「咚」+ 一瞬机械撞击噪声。
static func _make_place() -> PackedFloat32Array:
	var out := _buffer(0.20)
	for i in out.size():
		var t := float(i) / float(MIX_RATE)
		var freq := 190.0 - 105.0 * minf(t / 0.20, 1.0)
		var env := exp(-t * 17.0)
		var knock := _noise(i) * exp(-t * 70.0) * 0.45
		out[i] = (sin(TAU * freq * t) * 0.85 * env + knock) * BASE_GAIN
	return out

## 拾取：清脆的双泛音「叮」。
static func _make_pickup() -> PackedFloat32Array:
	var out := _buffer(0.18)
	_add_note(out, 0.0, 0.18, 880.0, 0.62, 0, 22.0)
	_add_note(out, 0.0, 0.18, 1320.0, 0.30, 0, 30.0)
	_add_note(out, 0.0, 0.18, 1760.0, 0.14, 0, 38.0)
	for i in out.size():
		out[i] *= BASE_GAIN
	return out

## 加工：低频齿轮转动 + 轻微金属摩擦。
static func _make_process() -> PackedFloat32Array:
	var out := _buffer(0.32)
	for i in out.size():
		var t := float(i) / float(MIX_RATE)
		var attack := minf(t / 0.02, 1.0)
		var env := attack * exp(-maxf(t - 0.02, 0.0) * 8.0)
		var wobble := 1.0 + 0.06 * sin(TAU * 7.0 * t)
		var body := sin(TAU * 112.0 * wobble * t) * 0.55
		var gear := _square(fmod(t * 224.0 * wobble, 1.0)) * 0.22
		var grit := _noise(i) * 0.08 * (0.5 + 0.5 * sin(TAU * 28.0 * t))
		out[i] = (body + gear + grit) * env * BASE_GAIN
	return out

## 交付：三音上行「完成一次交付」。
static func _make_deliver() -> PackedFloat32Array:
	var out := _buffer(0.52)
	_add_note(out, 0.00, 0.20, 523.25, 0.55, 0, 12.0)
	_add_note(out, 0.10, 0.24, 659.25, 0.55, 0, 10.0)
	_add_note(out, 0.20, 0.30, 783.99, 0.60, 0, 8.0)
	_add_note(out, 0.20, 0.30, 1567.98, 0.12, 0, 14.0)
	for i in out.size():
		out[i] *= BASE_GAIN
	return out

## 接线：短促的卡扣声。
static func _make_connect() -> PackedFloat32Array:
	var out := _buffer(0.12)
	_add_note(out, 0.0, 0.10, 1180.0, 0.36, 1, 42.0)
	_add_note(out, 0.0, 0.12, 640.0, 0.30, 0, 34.0)
	for i in out.size():
		out[i] = (out[i] + _noise(i) * exp(-float(i) / float(MIX_RATE) * 130.0) * 0.22) * BASE_GAIN
	return out

## 拆线：下行短音。
static func _make_disconnect() -> PackedFloat32Array:
	var out := _buffer(0.16)
	for i in out.size():
		var t := float(i) / float(MIX_RATE)
		var freq := 760.0 - 380.0 * minf(t / 0.16, 1.0)
		out[i] = sin(TAU * freq * t) * exp(-t * 24.0) * 0.60 * BASE_GAIN
	return out

## 掉落：极轻的一颗「嗒」，避免高频事件刷屏。
static func _make_drop() -> PackedFloat32Array:
	var out := _buffer(0.07)
	_add_note(out, 0.0, 0.07, 1480.0, 0.20, 0, 70.0)
	for i in out.size():
		out[i] *= BASE_GAIN
	return out

## 杂质：不谐和的双音，提示「出问题了」。
static func _make_impurity() -> PackedFloat32Array:
	var out := _buffer(0.24)
	_add_note(out, 0.0, 0.24, 233.0, 0.42, 2, 13.0)
	_add_note(out, 0.0, 0.24, 311.0, 0.34, 2, 15.0)
	for i in out.size():
		out[i] *= BASE_GAIN
	return out

## 故障：低频颤动嗡鸣。
static func _make_fault() -> PackedFloat32Array:
	var out := _buffer(0.30)
	for i in out.size():
		var t := float(i) / float(MIX_RATE)
		var tremolo := 0.6 + 0.4 * sin(TAU * 11.0 * t)
		out[i] = (sin(TAU * 96.0 * t) * 0.6 + _square(fmod(t * 48.0, 1.0)) * 0.25) * tremolo * exp(-t * 7.0) * BASE_GAIN
	return out

## 通关：四音上行琶音。
static func _make_complete() -> PackedFloat32Array:
	var out := _buffer(0.82)
	_add_note(out, 0.00, 0.30, 523.25, 0.48, 0, 7.0)
	_add_note(out, 0.14, 0.32, 659.25, 0.48, 0, 7.0)
	_add_note(out, 0.28, 0.34, 783.99, 0.50, 0, 6.0)
	_add_note(out, 0.42, 0.40, 1046.50, 0.55, 0, 5.0)
	_add_note(out, 0.42, 0.40, 1567.98, 0.10, 0, 9.0)
	for i in out.size():
		out[i] *= BASE_GAIN
	return out

## 失败：下行低音 + 一点噪声。
static func _make_failed() -> PackedFloat32Array:
	var out := _buffer(0.50)
	for i in out.size():
		var t := float(i) / float(MIX_RATE)
		var freq := 330.0 - 175.0 * minf(t / 0.50, 1.0)
		out[i] = (sin(TAU * freq * t) * 0.65 + _square(fmod(t * freq * 0.5, 1.0)) * 0.18 + _noise(i) * 0.05) * exp(-t * 6.0) * BASE_GAIN
	return out

## 环境底噪：8 秒内整数周期的低频和弦，循环点天然无缝。
static func _make_ambient() -> PackedFloat32Array:
	var out := _buffer(AMBIENT_SECONDS)
	for i in out.size():
		var t := float(i) / float(MIX_RATE)
		var swell := 0.65 + 0.35 * sin(TAU * 0.125 * t)
		var chord := sin(TAU * 55.0 * t) * 0.50
		chord += sin(TAU * 82.5 * t) * 0.26
		chord += sin(TAU * 110.0 * t) * 0.18
		chord += sin(TAU * 165.0 * t) * 0.08
		out[i] = chord * swell * 0.16
	return out

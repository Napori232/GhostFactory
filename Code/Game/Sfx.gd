class_name Sfx
extends Node
## 程序化音效：启动时用正弦 / 方波 / 噪声合成，不依赖任何音频文件。
## 它只订阅 SimEvents，不参与规则；删掉这个节点游戏照样能跑。

const RATE := 22050
const POOL_SIZE := 10

var _streams: Dictionary = {}
var _players: Array = []
var _next: int = 0
var _pulse_gate: float = 0.0


func _ready() -> void:
	_build_streams()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


## 接到模拟事件上。
func Bind(sim: Sim) -> void:
	sim.events.GhostPulse.connect(_on_pulse)
	sim.events.GhostStood.connect(func(_id: int): Play("stand", -8.0))
	sim.events.GhostFell.connect(func(_id: int): Play("fall", -12.0))
	sim.events.MechanismPushed.connect(func(_id: int, _pos: Vector2): Play("push", -20.0))
	sim.events.Built.connect(func(_kind: String, _id: int, _cell: Vector2i): Play("build", -6.0))
	sim.events.CrystalInserted.connect(func(_m: int, _c: int): Play("insert", -5.0))
	sim.events.SwapperWorked.connect(func(_s: int, _m: int, _c: int): Play("insert", -9.0))
	sim.events.BeltDelivered.connect(func(_b: int, _c: int): Play("belt", -22.0))
	sim.events.OutlawRazed.connect(func(_cell: Vector2i, _kind: String): Play("fall", -6.0))
	sim.events.EnemyKilled.connect(_on_enemy_killed)
	sim.events.EnemyBreached.connect(func(_id: int, _total: int): Play("breach", -4.0, 1.0))
	sim.events.WaveStarted.connect(func(_index: int): Play("wave", -6.0, 1.0))
	sim.events.RunFailed.connect(func(_reason: String): Play("fail", -2.0, 1.0))
	sim.events.RunCleared.connect(func(): Play("win", -2.0, 1.0))
	sim.events.ResonanceBurst.connect(func(_pos: Vector2, _amp: float, _radius: float): Play("resonance", -2.0, 1.0))


## 播放一个音效。volume_db 为相对音量，pitch 用于轻微随机化。
func Play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name) or _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.play()


func _on_pulse(_ghost_id: int, _pos: Vector2, _amplitude: float, _period: float) -> void:
	_pulse_gate -= 1
	if _pulse_gate > 0:
		return
	_pulse_gate = 2
	Play("pulse", -15.0, 1.0)


func _on_enemy_killed(_id: int, _pos: Vector2, by_clear: bool) -> void:
	if by_clear:
		Play("clear", -3.0, 1.0)
	else:
		Play("enemy_die", -10.0, 0.92 + randf() * 0.16)


# ---------------------------------------------------------------------------
# 合成
# ---------------------------------------------------------------------------

func _build_streams() -> void:
	_streams["pulse"] = _tone(0.30, 140.0, 52.0, 0, 0.42, 0.04, 1.9)
	_streams["stand"] = _tone(0.10, 520.0, 760.0, 2, 0.30, 0.0, 2.2)
	_streams["fall"] = _tone(0.22, 210.0, 80.0, 0, 0.24, 0.10, 1.5)
	_streams["push"] = _tone(0.09, 150.0, 110.0, 1, 0.14, 0.25, 2.0)
	_streams["build"] = _tone(0.10, 300.0, 430.0, 1, 0.18, 0.0, 2.6)
	_streams["insert"] = _tone(0.07, 680.0, 900.0, 2, 0.20, 0.0, 2.0)
	_streams["belt"] = _tone(0.045, 420.0, 520.0, 1, 0.09, 0.30, 3.2)
	_streams["enemy_die"] = _tone(0.16, 380.0, 120.0, 0, 0.22, 0.72, 2.2)
	_streams["breach"] = _tone(0.26, 150.0, 68.0, 1, 0.22, 0.30, 1.4)
	_streams["wave"] = _tone(0.70, 58.0, 92.0, 0, 0.28, 0.0, 1.2)
	_streams["fail"] = _tone(0.95, 190.0, 44.0, 0, 0.32, 0.16, 1.0)
	_streams["clear"] = _chord(0.72, [220.0, 330.0, 440.0, 660.0], 0.22, 1.1)
	_streams["resonance"] = _chord(1.2, [55.0, 82.5, 110.0, 165.0], 0.30, 0.7)
	_streams["win"] = _arpeggio(0.9, [262.0, 330.0, 392.0, 523.0], 0.16)


## 单个音：频率从 f0 滑到 f1。
## kind: 0=正弦 1=方波 2=复合；noise 为噪声混合比；decay 越大衰减越快。
func _tone(duration: float, f0: float, f1: float, kind: int, amp: float, noise: float, decay: float) -> AudioStreamWAV:
	var count := maxi(1, int(duration * RATE))
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var u := float(i) / float(count)
		var f := lerpf(f0, f1, u)
		phase += TAU * f / float(RATE)
		var v := 0.0
		match kind:
			0:
				v = sin(phase)
			1:
				v = 1.0 if sin(phase) >= 0.0 else -1.0
			_:
				v = sin(phase) * 0.65 + sin(phase * 2.01) * 0.35
		if noise > 0.0:
			v = lerpf(v, randf() * 2.0 - 1.0, noise)
		var env := pow(maxf(0.0, 1.0 - u), decay)
		var sample := int(clampf(v * env * amp, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


## 多音同时响（和弦）。
func _chord(duration: float, freqs: Array, amp: float, decay: float) -> AudioStreamWAV:
	var count := maxi(1, int(duration * RATE))
	var data := PackedByteArray()
	data.resize(count * 2)
	var phases := PackedFloat64Array()
	phases.resize(freqs.size())
	for i in count:
		var u := float(i) / float(count)
		var v := 0.0
		for j in freqs.size():
			phases[j] += TAU * float(freqs[j]) / float(RATE)
			v += sin(phases[j])
		v /= float(maxi(1, freqs.size()))
		var env := pow(maxf(0.0, 1.0 - u), decay)
		var sample := int(clampf(v * env * amp, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	return _wrap(data)


## 依次响起的琶音。
func _arpeggio(duration: float, freqs: Array, note_len: float) -> AudioStreamWAV:
	var count := maxi(1, int(duration * RATE))
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		var idx := mini(int(t / note_len), freqs.size() - 1)
		var local := fmod(t, note_len)
		phase += TAU * float(freqs[idx]) / float(RATE)
		var env := exp(-local * 6.0) * 0.8
		var sample := int(clampf(sin(phase) * env * 0.3, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	return _wrap(data)


func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav

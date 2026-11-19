class_name SimGhost
extends RefCounted
## 鬼：纯被动的机械体。它只有一条「物理阈值」和一个固有周期，没有动力。
##
## 触发形态（Data/ghosts/*.json 的 "kind"，默认 tilt）：
##   tilt      —— 倒立摆：被外力顶到倾角阈值才立正（翘脚鬼 / 摆臂鬼 / 守夜钟…）。
##   multi     —— 多点支撑：倾角够直还不够，必须同时有 contacts_required 个支撑。
##   relay     —— 接力：自己不站，被别的脉冲扫到时迟 delay 秒再发一次。
##   topple    —— 倾倒触发：站着不干活，被推倒（角度过 topple_angle）的那一下才砸。
##   brace     —— 承重触发：自己站住，撑住倒向它的邻鬼；有人靠着才发脉冲。
##   oscillate —— 速度阈值：不站也不倒，摆得够快（|角速度| ≥ trigger_speed）才发脉冲。
##
## 鬼与鬼之间还有两种「物理层」联动，任何 kind 都吃：
##   strike  —— 倒下的鬼会砸进它倒向的那一格：砸到脚（对方朝它倒）→ 压住脚帮它立正；
##              砸到身体（对方背对它）→ 把它推倒。冲量按 strike_torque 结算。
##   support —— 撑鬼站着时，撑住所有「倒向它」的邻鬼：算一个支撑，并持续压住对方的脚。
##
## 倾角动力学仍是单自由度倒立摆：
##   θ̈ = (重力矩 + 推力力矩 + 承重力矩) / 转动惯量 - 阻尼·θ̇

const KIND_TILT := "tilt"
const KIND_MULTI := "multi"
const KIND_RELAY := "relay"
const KIND_TOPPLE := "topple"
const KIND_BRACE := "brace"
const KIND_OSCILLATE := "oscillate"

var id: int = -1
var type_id: String = ""
var def: Dictionary = {}
var cell: Vector2i = Vector2i.ZERO
var facing: int = 0  # 0=+x, 1=+z, 2=-x, 3=-z，即「向哪边翘」
var base: Vector2 = Vector2.ZERO

var kind: String = KIND_TILT
var contacts_required: int = 1

var angle: float = 0.0
var angular_velocity: float = 0.0
var standing: bool = false
var phase: float = 0.0
var pulse_total: int = 0

# 解析后的参数（避免每 tick 查字典）
var rest_angle: float = 0.55
var stand_angle: float = 0.13
var hysteresis: float = 0.10
var gravity: float = 5.6
var stop_stiffness: float = 9.0
var damping: float = 3.2
var inertia: float = 1.0
var foot_offset: float = 0.42
var body_offset: float = 0.0
var foot_radius: float = 0.16
var body_radius: float = 0.30
var topple_factor: float = 1.25
var pulse_amplitude: float = 1.0
var pulse_period: float = 2.0
var pulse_range: float = 6.0
var charges_per_pulse: int = 1
var charge_amount: float = 1.0
var cost: int = 0

# 机关改写的参数（每 tick 由 Sim 重算，0 / 1 表示没有改动）
var amp_mult: float = 1.0
var range_mult: float = 1.0
var period_override: float = 0.0

# 接力鬼的状态
var relay_delay: float = 0.12
var relay_cooldown_time: float = 0.8
var relay_due: float = -1.0        # 绝对时钟：到点就发一次
var relay_cooldown_left: float = 0.0
var relay_active: float = 0.0      # > 0 时作为波源参与场
var relay_period: float = 2.0
var relay_phase: float = 0.0

# 鬼与鬼的物理联动
var strike_torque: float = 1.0      # 倒下时给邻鬼的角速度冲量（0 = 不砸）
var strike_cooldown_time: float = 0.6
var strike_cooldown_left: float = 0.0
var strike_pending: bool = false    # 本 tick 要结算一次砸击（Sim 处理）
var pending_impulse: float = 0.0    # 下一 tick 施加的角速度冲量（被邻鬼砸中）
var pulse_on_strike: bool = false   # 砸击时是否同时发一次脉冲
var support_capacity: int = 0       # 撑鬼最多撑几只
var support_weight: float = 1.5     # 每撑一只，自己多受多少倾覆力矩
var support_load: int = 0           # 当前撑住几只（Sim 每 tick 写）
var support_load_prev: int = 0

# 倾倒触发
var topple_angle: float = 0.92
var rearm_angle: float = 0.32
var topple_armed: bool = true

# 速度阈值
var trigger_speed: float = 1.2
var speed_cooldown_time: float = 0.7
var speed_cooldown_left: float = 0.0
var speed_armed: bool = true

# 冲击脉冲的短暂波源窗口
var burst_active: float = 0.0
var burst_period: float = 2.0
var burst_phase: float = 0.0


## 从定义字典初始化。返回 self 便于链式调用。
func Configure(id_: int, type_id_: String, d: Dictionary, cell_: Vector2i, facing_: int, base_: Vector2) -> SimGhost:
	id = id_
	type_id = type_id_
	def = d
	cell = cell_
	facing = facing_
	base = base_
	cost = int(d.get("cost", 0))
	kind = String(d.get("kind", KIND_TILT))
	var tilt: Dictionary = d.get("tilt", {})
	rest_angle = float(tilt.get("rest_angle", 0.55))
	stand_angle = float(tilt.get("stand_angle", 0.13))
	hysteresis = float(tilt.get("hysteresis", 0.10))
	gravity = float(tilt.get("gravity", 5.6))
	stop_stiffness = float(tilt.get("stop_stiffness", 9.0))
	damping = float(tilt.get("damping", 3.2))
	inertia = maxf(0.01, float(tilt.get("inertia", 1.0)))
	contacts_required = maxi(1, int(tilt.get("contacts_required", 1)))
	var contact: Dictionary = d.get("contact", {})
	foot_offset = float(contact.get("foot_offset", 0.42))
	body_offset = float(contact.get("body_offset", 0.0))
	foot_radius = float(contact.get("foot_radius", 0.16))
	body_radius = float(contact.get("body_radius", 0.30))
	topple_factor = float(contact.get("topple_factor", 1.25))
	var pulse: Dictionary = d.get("pulse", {})
	pulse_amplitude = float(pulse.get("amplitude", 1.0))
	pulse_period = maxf(0.05, float(pulse.get("period", 2.0)))
	pulse_range = maxf(0.1, float(pulse.get("range", 6.0)))
	charges_per_pulse = maxi(0, int(pulse.get("charges_per_pulse", 1)))
	charge_amount = float(pulse.get("charge_amount", 1.0))
	var relay: Dictionary = d.get("relay", {})
	relay_delay = maxf(0.02, float(relay.get("delay", 0.12)))
	relay_cooldown_time = maxf(0.0, float(relay.get("cooldown", 0.8)))
	relay_period = pulse_period
	relay_phase = 0.0
	relay_due = -1.0
	relay_cooldown_left = 0.0
	relay_active = 0.0
	# 物理联动：所有鬼默认会「倒下砸邻格」，数据可以关掉或加强
	var link: Dictionary = d.get("link", {})
	strike_torque = maxf(0.0, float(link.get("strike_torque", 1.0)))
	strike_cooldown_time = maxf(0.05, float(link.get("cooldown", 0.6)))
	pulse_on_strike = bool(link.get("pulse_on_strike", false))
	support_capacity = maxi(0, int(link.get("support_capacity", 0)))
	support_weight = maxf(0.0, float(link.get("support_weight", 1.5)))
	var top: Dictionary = d.get("topple", {})
	topple_angle = clampf(float(top.get("topple_angle", 0.92)), 0.1, PI * 0.5)
	rearm_angle = clampf(float(top.get("rearm_angle", 0.32)), 0.0, topple_angle)
	var osc: Dictionary = d.get("oscillate", {})
	trigger_speed = maxf(0.05, float(osc.get("trigger_speed", 1.2)))
	speed_cooldown_time = maxf(0.05, float(osc.get("cooldown", 0.7)))
	amp_mult = 1.0
	range_mult = 1.0
	period_override = 0.0
	# 初始就处于翘脚状态（rest），不立正。
	angle = rest_angle
	angular_velocity = 0.0
	standing = false
	phase = 0.0
	support_load = 0
	support_load_prev = 0
	topple_armed = true
	speed_armed = true
	strike_pending = false
	pending_impulse = 0.0
	burst_active = 0.0
	burst_period = pulse_period
	burst_phase = 0.0
	return self


## 翘起方向的单位向量。
func LeanDir() -> Vector2:
	match facing:
		0:
			return Vector2(1, 0)
		1:
			return Vector2(0, 1)
		2:
			return Vector2(-1, 0)
	return Vector2(0, -1)


## 受力点（翘起的那只脚）的世界坐标。
func FootWorld() -> Vector2:
	return base + LeanDir() * foot_offset


## 身体中心的世界坐标。
func BodyWorld() -> Vector2:
	return base + LeanDir() * body_offset


func IsRelay() -> bool:
	return kind == KIND_RELAY


func IsMultiContact() -> bool:
	return kind == KIND_MULTI


func IsTopple() -> bool:
	return kind == KIND_TOPPLE


func IsBrace() -> bool:
	return kind == KIND_BRACE


func IsOscillate() -> bool:
	return kind == KIND_OSCILLATE


## 这只鬼是不是「站着发脉冲」的普通阈值鬼。
func IsTiltLike() -> bool:
	return kind == KIND_TILT or kind == KIND_MULTI or kind == KIND_BRACE


## 当前生效的固有周期（机关改写优先）。
func EffPeriod() -> float:
	return period_override if period_override > 0.0 else pulse_period


## 当前生效的脉冲振幅（机关放大后）。
func EffAmplitude() -> float:
	return pulse_amplitude * amp_mult


## 当前生效的射程（机关延长后）。
func EffRange() -> float:
	return pulse_range * range_mult


## 推进一个物理步长。push_torque 为外部机关施加的力矩（负=往下压脚，正=推身体）。
## contacts 为本 tick 同时顶住这只鬼的支撑数（机关 + 撑鬼）。
## 返回 true 表示本步产生了一次脉冲。
func Step(dt: float, push_torque: float, events: SimEvents, now: float = 0.0, contacts: int = 1) -> bool:
	if IsRelay():
		# 接力鬼没有倾角物理：它只在被脉冲扫到时动作（调度在 Sim 里）。
		return false
	# 被别的鬼砸中：冲量在下一 tick 开始时进角速度
	if absf(pending_impulse) > 0.0001:
		angular_velocity += pending_impulse / inertia
		pending_impulse = 0.0

	match kind:
		KIND_TOPPLE:
			return _step_topple(dt, push_torque, events, now)
		KIND_OSCILLATE:
			return _step_oscillate(dt, push_torque, events, now)
		_:
			return _step_tilt(dt, push_torque, events, now, contacts)


## 普通倾角鬼（含 multi / brace）。
func _step_tilt(dt: float, push_torque: float, events: SimEvents, now: float, contacts: int) -> bool:
	var torque := push_torque
	if IsBrace():
		# 承重：撑得越多，自己越容易被压翻
		torque += float(support_load) * support_weight
		if support_load > support_capacity:
			torque += float(support_load - support_capacity) * support_weight
	_apply_gravity(torque, dt)

	var supports_ok := contacts_required <= 1 or contacts >= contacts_required
	var just_stood := false
	var pulsed := false
	if not standing and angle <= stand_angle and supports_ok:
		standing = true
		var p := EffPeriod()
		phase = fmod(now, p) / p * TAU
		events.GhostStood.emit(id)
		# 撑鬼没人靠的时候不响：它的触发是「承重」，不是「立正」
		if not IsBrace() or support_load > 0:
			pulse_total += 1
			events.GhostPulse.emit(id, base, EffAmplitude(), p)
			pulsed = true
		just_stood = true
	elif standing and (angle > stand_angle + hysteresis or not supports_ok):
		standing = false
		phase = 0.0
		events.GhostFell.emit(id)
		# 倒下的鬼砸向它倒向的邻格
		if strike_torque > 0.0 and strike_cooldown_left <= 0.0:
			strike_pending = true
			strike_cooldown_left = strike_cooldown_time

	if not standing:
		support_load_prev = support_load
		return false

	# 撑鬼从「没人靠」变成「有人靠」的那一下，立刻响一次
	if IsBrace() and support_load > 0 and support_load_prev == 0 and not pulsed:
		var p2 := EffPeriod()
		phase = fmod(now, p2) / p2 * TAU
		pulse_total += 1
		events.GhostPulse.emit(id, base, EffAmplitude(), p2)
		pulsed = true
	support_load_prev = support_load

	if just_stood or pulsed:
		return pulsed
	var prev := phase
	var period := EffPeriod()
	if now > 0.0:
		phase = fmod(now, period) / period * TAU
		if phase < prev:
			# 撑鬼只在承重时按周期响
			if not IsBrace() or support_load > 0:
				pulse_total += 1
				events.GhostPulse.emit(id, base, EffAmplitude(), period)
				return true
	else:
		phase += TAU * dt / period
		if phase >= TAU:
			phase -= TAU
			if not IsBrace() or support_load > 0:
				pulse_total += 1
				events.GhostPulse.emit(id, base, EffAmplitude(), period)
				return true
	return false


## 倾倒触发：不站，角度扣过 topple_angle 的那一下把 strike_pending 交给 Sim。
## 砸完自动回弹，等下一次被推倒。
func _step_topple(dt: float, push_torque: float, events: SimEvents, now: float) -> bool:
	var torque := push_torque
	_apply_gravity(torque, dt)
	standing = false
	if topple_armed and angle >= topple_angle and strike_cooldown_left <= 0.0:
		topple_armed = false
		strike_pending = true
		strike_cooldown_left = strike_cooldown_time
		# 回弹：像弹簧把锤子顶回来，让同一台顶足机关能反复锤
		angular_velocity = -maxf(5.0, absf(angular_velocity) * 1.2)
	elif not topple_armed and angle <= rearm_angle:
		topple_armed = true
	return false


## 速度阈值：不站也不倒，|角速度| 过阈值时才发一次（然后要等它慢下来再武装）。
func _step_oscillate(dt: float, push_torque: float, events: SimEvents, now: float) -> bool:
	var torque := push_torque
	_apply_gravity(torque, dt)
	standing = false
	var speed := absf(angular_velocity)
	if speed_armed and speed >= trigger_speed and speed_cooldown_left <= 0.0:
		speed_armed = false
		speed_cooldown_left = speed_cooldown_time
		strike_pending = true
		return true
	if not speed_armed and speed <= trigger_speed * 0.45:
		speed_armed = true
	return false


## 共用的倒立摆积分。torque 会被直接改写。
func _apply_gravity(torque: float, dt: float) -> void:
	var total := torque
	if angle < rest_angle:
		total += gravity * (0.12 + sin(angle))
	else:
		total -= (angle - rest_angle) * stop_stiffness
	angular_velocity += total / inertia * dt
	angular_velocity *= exp(-damping * dt)
	angle += angular_velocity * dt
	if angle <= 0.0:
		angle = 0.0
		if angular_velocity < 0.0:
			angular_velocity = 0.0
	if angle >= PI * 0.5:
		angle = PI * 0.5
		if angular_velocity > 0.0:
			angular_velocity = 0.0


## 每 tick 的计时器（Sim 对所有鬼调用）。
func TickTimers(dt: float) -> void:
	strike_cooldown_left = maxf(0.0, strike_cooldown_left - dt)
	speed_cooldown_left = maxf(0.0, speed_cooldown_left - dt)
	burst_active = maxf(0.0, burst_active - dt)
	if IsRelay():
		relay_cooldown_left = maxf(0.0, relay_cooldown_left - dt)
		relay_active = maxf(0.0, relay_active - dt)


## 让接力鬼排一次发射（被脉冲扫到时由 Sim 调用）。
func ScheduleRelay(now: float, source_period: float) -> void:
	if relay_cooldown_left > 0.0:
		return
	var due := now + relay_delay
	if relay_due < 0.0 or due < relay_due:
		relay_due = due
	relay_period = maxf(0.05, source_period)


## 到点发射。返回 true 表示这一 tick 真的发出去了。
func FireRelay(now: float, events: SimEvents) -> bool:
	if relay_due < 0.0 or now + 0.0001 < relay_due:
		return false
	relay_due = -1.0
	relay_cooldown_left = relay_cooldown_time
	relay_active = relay_period
	relay_phase = fmod(now, relay_period) / relay_period * TAU
	pulse_total += 1
	events.GhostPulse.emit(id, base, EffAmplitude(), relay_period)
	return true


## 发一次「冲击脉冲」：把一次性脉冲变成短窗口的场源，并走正常的充能/接力链。
func FireStrikePulse(events: SimEvents) -> void:
	var p := EffPeriod()
	pulse_total += 1
	burst_active = maxf(burst_active, 0.55)
	burst_period = p
	# 砸击是「一下」，从波峰开始，别从零 crossings 开始
	burst_phase = PI * 0.5
	events.GhostPulse.emit(id, base, EffAmplitude(), p)


## 存档 / 回溯用的快照。
func Export() -> Dictionary:
	return {
		"id": id,
		"type": type_id,
		"cell": [cell.x, cell.y],
		"facing": facing,
		"angle": angle,
		"angular_velocity": angular_velocity,
		"phase": phase,
		"standing": standing,
		"pulse_total": pulse_total,
		"relay_due": relay_due,
		"relay_cd": relay_cooldown_left,
		"relay_active": relay_active,
		"relay_period": relay_period,
		"relay_phase": relay_phase,
		"support_load": support_load,
		"support_load_prev": support_load_prev,
		"topple_armed": topple_armed,
		"speed_armed": speed_armed,
		"strike_cd": strike_cooldown_left,
		"speed_cd": speed_cooldown_left,
		"burst_active": burst_active,
		"burst_period": burst_period,
		"burst_phase": burst_phase,
	}


## 从快照恢复（保留 id）。
func Import(data: Dictionary) -> void:
	id = int(data.get("id", id))
	type_id = String(data.get("type", type_id))
	var c: Array = data.get("cell", [cell.x, cell.y])
	cell = Vector2i(int(c[0]), int(c[1]))
	facing = int(data.get("facing", facing))
	angle = float(data.get("angle", angle))
	angular_velocity = float(data.get("angular_velocity", 0.0))
	phase = float(data.get("phase", phase))
	standing = bool(data.get("standing", standing))
	pulse_total = int(data.get("pulse_total", pulse_total))
	relay_due = float(data.get("relay_due", -1.0))
	relay_cooldown_left = float(data.get("relay_cd", 0.0))
	relay_active = float(data.get("relay_active", 0.0))
	relay_period = float(data.get("relay_period", pulse_period))
	relay_phase = float(data.get("relay_phase", 0.0))
	support_load = int(data.get("support_load", 0))
	support_load_prev = int(data.get("support_load_prev", support_load))
	topple_armed = bool(data.get("topple_armed", true))
	speed_armed = bool(data.get("speed_armed", true))
	strike_cooldown_left = float(data.get("strike_cd", 0.0))
	speed_cooldown_left = float(data.get("speed_cd", 0.0))
	burst_active = float(data.get("burst_active", 0.0))
	burst_period = float(data.get("burst_period", pulse_period))
	burst_phase = float(data.get("burst_phase", 0.0))

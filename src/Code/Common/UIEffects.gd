class_name UIEffects
extends RefCounted

## UI 动效库。提供缩放弹跳、淡入淡出、粒子迸发与呼吸脉冲等常用动效。
## 动效全部用 Tween 实现，不依赖美术资源。

## 节点弹入时的缩放曲线。
const POP_EASE: int = Tween.EASE_OUT
## 缩放动画时长。
const POP_DURATION: float = 0.28
## 弹入后的目标缩放。
const POP_SCALE: float = 1.06
## 淡入淡出时长。
const FADE_DURATION: float = 0.22

## 让节点做一次缩放弹跳，用于按钮点击、鬼牌入场与卡片获得焦点。
## @param node 目标节点，必须是 Control。
## @param from_scale 起始缩放。
## @param to_scale 结束缩放。
## @param duration 动画时长（秒）。
static func PopScale(node: Control, from_scale: float = 0.85, to_scale: float = POP_SCALE, duration: float = POP_DURATION) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(from_scale, from_scale)
	var tween := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(POP_EASE)
	tween.tween_property(node, "scale", Vector2(to_scale, to_scale), duration)
	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.6)

## 让 2D 节点做一次缩放弹跳，用于鬼与线鬼落位时的反馈。
## @param node 目标节点，必须是 Node2D。
## @param from_scale 起始缩放。
## @param to_scale 结束缩放。
## @param duration 动画时长（秒）。
static func PopScale2D(node: Node2D, from_scale: float = 0.7, to_scale: float = 1.0, duration: float = POP_DURATION) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.scale = Vector2(from_scale, from_scale)
	var tween := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(POP_EASE)
	tween.tween_property(node, "scale", Vector2(to_scale, to_scale), duration)

## 让节点做一次呼吸缩放循环，用于强调当前选中项。
## @param node 目标节点，必须是 Control。
## @param min_scale 最小缩放。
## @param max_scale 最大缩放。
## @param duration 单次往返时长（秒）。
static func Breathe(node: Control, min_scale: float = 0.96, max_scale: float = 1.04, duration: float = 1.2) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var tween := node.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2(max_scale, max_scale), duration)
	tween.tween_property(node, "scale", Vector2(min_scale, min_scale), duration)

## 让节点持续做正弦呼吸缩放，用于界面元素整体活起来的氛围动效。
## 幅度按基准缩放的相对比例给出，多个元素可用 phase 错开节奏。
## @param node 目标节点，必须是 Control。
## @param amplitude 相对幅度，0.03 表示上下浮动 3%。
## @param period 单次呼吸周期（秒）。
## @param phase 相位偏移，周期比例 0~1。
static func BreatheLoop(node: Control, amplitude: float = 0.03, period: float = 2.4, phase: float = 0.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var base := node.scale
	var tween := node.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(factor: float) -> void:
		if is_instance_valid(node):
			node.scale = base * factor
	, 1.0 - amplitude, 1.0 + amplitude, period * 0.5)
	tween.tween_method(func(factor: float) -> void:
		if is_instance_valid(node):
			node.scale = base * factor
	, 1.0 + amplitude, 1.0 - amplitude, period * 0.5)
	if phase != 0.0:
		tween.tween_interval(period * phase)

## 让节点持续做左右摇摆，用于卡片、图标与装饰件的摆动。
## @param node 目标节点，必须是 Control。
## @param angle_deg 摆动幅度（度）。
## @param period 单次摆动周期（秒）。
## @param phase 相位偏移，周期比例 0~1。
static func Sway(node: Control, angle_deg: float = 3.0, period: float = 3.2, phase: float = 0.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var base := node.rotation
	var tween := node.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(angle: float) -> void:
		if is_instance_valid(node):
			node.rotation = base + angle
	, 0.0, deg_to_rad(angle_deg), period * 0.25)
	tween.tween_method(func(angle: float) -> void:
		if is_instance_valid(node):
			node.rotation = base + angle
	, deg_to_rad(angle_deg), deg_to_rad(-angle_deg), period * 0.25)
	tween.tween_method(func(angle: float) -> void:
		if is_instance_valid(node):
			node.rotation = base + angle
	, deg_to_rad(-angle_deg), 0.0, period * 0.25)
	tween.tween_method(func(angle: float) -> void:
		if is_instance_valid(node):
			node.rotation = base + angle
	, 0.0, deg_to_rad(angle_deg), period * 0.25)
	if phase != 0.0:
		tween.tween_interval(period * phase)

## 让节点持续上下浮动，用于主视觉占位与装饰元素。
## @param node 目标节点，必须是 Control。
## @param distance 浮动距离（像素）。
## @param period 单次浮动周期（秒）。
## @param phase 相位偏移，周期比例 0~1。
static func FloatBob(node: Control, distance: float = 6.0, period: float = 3.0, phase: float = 0.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base := node.position
	var tween := node.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(offset: float) -> void:
		if is_instance_valid(node):
			node.position = base + Vector2(0, offset)
	, -distance, distance, period * 0.5)
	tween.tween_method(func(offset: float) -> void:
		if is_instance_valid(node):
			node.position = base + Vector2(0, offset)
	, distance, -distance, period * 0.5)
	if phase != 0.0:
		tween.tween_interval(period * phase)

## 让节点亮度持续呼吸，用于需要提亮的重点元素。
## @param node 目标节点，必须是 CanvasItem。
## @param strength 亮度变化幅度，0.25 表示最亮时比基准亮 25%。
## @param period 单次呼吸周期（秒）。
static func GlowPulse(node: CanvasItem, strength: float = 0.25, period: float = 2.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base := node.modulate
	var tween := node.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(factor: float) -> void:
		if is_instance_valid(node):
			node.modulate = Color(base.r * factor, base.g * factor, base.b * factor, base.a)
	, 1.0, 1.0 + strength, period * 0.5)
	tween.tween_method(func(factor: float) -> void:
		if is_instance_valid(node):
			node.modulate = Color(base.r * factor, base.g * factor, base.b * factor, base.a)
	, 1.0 + strength, 1.0, period * 0.5)

## 给控件挂上悬停放大与按下回弹的交互反馈。
## 重复调用不会叠加多个补间。
## @param node 目标控件。
## @param hover_scale 悬停时的缩放倍数。
## @param press_scale 按下时的缩放倍数。
## @param duration 过渡时长（秒）。
static func AttachInteractive(node: Control, hover_scale: float = 1.05, press_scale: float = 0.96, duration: float = 0.16) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta("ui_interactive_attached"):
		return
	node.set_meta("ui_interactive_attached", true)
	node.mouse_entered.connect(func() -> void:
		_scale_to(node, hover_scale, duration, Tween.TRANS_BACK)
	)
	node.mouse_exited.connect(func() -> void:
		_scale_to(node, 1.0, duration, Tween.TRANS_QUAD)
	)
	# 按下反馈只对带点按信号的控件有效，纯展示容器（如卡片）没有该信号。
	if node is BaseButton:
		var button := node as BaseButton
		button.button_down.connect(func() -> void:
			_scale_to(node, press_scale, duration * 0.6, Tween.TRANS_QUAD)
		)
		button.button_up.connect(func() -> void:
			_scale_to(node, hover_scale, duration, Tween.TRANS_BACK)
		)

## 把控件缩放到目标值，重复触发时复用同一个补间。
## @param node 目标控件。
## @param target_scale 目标缩放倍数。
## @param duration 过渡时长（秒）。
## @param trans 缓动类型。
static func _scale_to(node: Control, target_scale: float, duration: float, trans: int) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var tween: Tween = null
	if node.has_meta("ui_interactive_tween"):
		tween = node.get_meta("ui_interactive_tween") as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	tween = node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(trans).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2(target_scale, target_scale), duration)
	node.set_meta("ui_interactive_tween", tween)

## 节点淡入。
## @param node 目标节点，必须是 CanvasItem。
## @param duration 时长（秒）。
static func FadeIn(node: CanvasItem, duration: float = FADE_DURATION) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.modulate.a = 0.0
	var tween := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(node, "modulate:a", 1.0, duration)

## 节点淡出，完成后隐藏。
## @param node 目标节点，必须是 CanvasItem。
## @param duration 时长（秒）。
static func FadeOut(node: CanvasItem, duration: float = FADE_DURATION) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tween := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.tween_callback(node.hide)

## 节点从下方滑入并淡入，用于列表项依次入场。
## @param node 目标节点，必须是 Control。
## @param offset_y 起始纵向偏移（像素）。
## @param duration 时长（秒）。
static func SlideIn(node: Control, offset_y: float = 24.0, duration: float = 0.3) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base_position := node.position
	node.position = base_position + Vector2(0, offset_y)
	node.modulate.a = 0.0
	var tween := node.create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", base_position, duration)
	tween.tween_property(node, "modulate:a", 1.0, duration)

## 依次播放列表项的入场动画。
## @param nodes 待播放的节点列表。
## @param gap 每项之间的间隔（秒）。
static func PlayStagger(nodes: Array, gap: float = 0.06) -> void:
	var delay := 0.0
	for node in nodes:
		if node is Control:
			var target: Control = node
			target.modulate.a = 0.0
			var tween := target.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.tween_interval(delay)
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(target, "modulate:a", 1.0, 0.25)
		delay += gap

## 在指定位置迸发一簇粒子，用于交付成功、鬼能增加与拆除反馈。
## 纯代码生成，不依赖粒子资源文件。
## @param parent 粒子挂载的父节点。
## @param world_pos 世界坐标。
## @param color 粒子颜色。
## @param amount 粒子数量。
## @param lifetime 粒子存活时长（秒）。
## @param speed 初速度。
static func Burst(parent: Node, world_pos: Vector2, color: Color = UIPalette.SUCCESS, amount: int = 18, lifetime: float = 0.7, speed: float = 180.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var particles := CPUParticles2D.new()
	particles.position = world_pos
	particles.amount = maxi(1, amount)
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0, 320)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = color
	parent.add_child(particles)
	# 一轮寿命结束后自行清理。
	var timer := parent.get_tree().create_timer(lifetime + 0.4)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)

## 在控件中心迸发粒子，坐标自动换算。
## @param node 目标控件。
## @param color 粒子颜色。
## @param amount 粒子数量。
static func BurstAtControl(node: Control, color: Color = UIPalette.SUCCESS, amount: int = 18) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tree := node.get_tree()
	if tree == null:
		return
	Burst(node.get_parent(), node.global_position + node.size * 0.5, color, amount)

## 数字滚动到目标值，用于鬼能与计分的变化反馈。
## @param label 目标标签。
## @param from 起始值。
## @param to 目标值。
## @param duration 时长（秒）。
static func CountTo(label: Label, from: int, to: int, duration: float = 0.4) -> void:
	if label == null or not is_instance_valid(label):
		return
	var tween := label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void:
		label.text = str(int(round(value)))
	, float(from), float(to), duration)

## 横向进度条填充动画。
## @param bar 进度条节点，宽度代表进度。
## @param from_ratio 起始比例 0~1。
## @param to_ratio 目标比例 0~1。
## @param duration 时长（秒）。
static func FillBar(bar: Control, from_ratio: float, to_ratio: float, duration: float = 0.4) -> void:
	if bar == null or not is_instance_valid(bar):
		return
	var full_width := bar.size.x
	var tween := bar.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(bar, "size:x", full_width * to_ratio, duration)

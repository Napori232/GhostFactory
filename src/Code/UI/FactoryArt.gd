class_name FactoryArt
extends RefCounted

## 程序化工厂视觉：不依赖任何外部贴图，用 CanvasItem 的 draw_* 直接画出主视觉与背景。
## 美术素材到位后由 ArtPlaceholder 优先显示真实纹理，本模块自动退居兜底。

## 主视觉（工厂剖面图）的程序化类别。
const KIND_KEY_ART: StringName = &"key_art"
## 铺满全屏的废弃工厂远景类别。
const KIND_BACKDROP: StringName = &"backdrop"

## 渐变分段数，越大越平滑。
const BAND_COUNT: int = 28
## 主视觉里星点的数量。
const DUST_COUNT: int = 26
## 背景远景里窗格灯的数量。
const WINDOW_COUNT: int = 34

## 某个类别是否是本模块支持的程序化图案。
## @param kind 待判断的类别名。
## @return 支持时返回 true。
static func IsValidKind(kind: StringName) -> bool:
	return kind == KIND_KEY_ART or kind == KIND_BACKDROP

## 按类别把程序化图案画到目标控件上。
## @param ci 接收绘制指令的 CanvasItem（通常就是 ArtPlaceholder 自己）。
## @param kind KIND_KEY_ART 或 KIND_BACKDROP。
## @param canvas_size 控件尺寸，图案按尺寸自适应。
## @param phase 动画相位（秒），用于烟雾、光点与幽灵漂浮。
static func Draw(ci: CanvasItem, kind: StringName, canvas_size: Vector2, phase: float) -> void:
	if ci == null or canvas_size.x <= 1.0 or canvas_size.y <= 1.0:
		return
	if kind == KIND_KEY_ART:
		_draw_key_art(ci, canvas_size, phase)
	elif kind == KIND_BACKDROP:
		_draw_backdrop(ci, canvas_size, phase)

## 固定种子的伪随机数，保证每次运行画面一致。
## @param index 序号。
## @param salt 扰动盐值。
## @return 0.0~1.0 的确定性随机数。
static func _rand(index: int, salt: float = 0.0) -> float:
	return absf(fmod(sin(float(index) * 12.9898 + salt * 78.233) * 43758.5453, 1.0))

## 竖向渐变铺底。
## @param ci 目标控件。
## @param canvas_size 控件尺寸。
## @param top 顶部颜色。
## @param bottom 底部颜色。
static func _draw_gradient(ci: CanvasItem, canvas_size: Vector2, top: Color, bottom: Color) -> void:
	var band_height := canvas_size.y / float(BAND_COUNT)
	for i in BAND_COUNT:
		var t := float(i) / float(BAND_COUNT - 1)
		ci.draw_rect(Rect2(0.0, band_height * i, canvas_size.x, band_height + 1.0), top.lerp(bottom, t), true)

## 画一栋带锯齿屋顶与烟囱的厂房剪影。
## @param ci 目标控件。
## @param base_rect 厂房主体矩形。
## @param body 主体颜色。
## @param trim 描边颜色。
## @param chimney_count 烟囱数量。
## @param phase 动画相位，用于烟。
## @param smoke_alpha 烟雾不透明度倍率。
static func _draw_factory_block(
	ci: CanvasItem,
	base_rect: Rect2,
	body: Color,
	trim: Color,
	chimney_count: int,
	phase: float,
	smoke_alpha: float
) -> void:
	ci.draw_rect(base_rect, body, true)
	# 锯齿屋顶：每两个齿一组的斜顶线。
	var tooth := maxf(base_rect.size.x / 9.0, 8.0)
	var x := base_rect.position.x
	while x < base_rect.end.x - tooth * 0.5:
		var peak := Vector2(x + tooth * 0.5, base_rect.position.y - tooth * 0.55)
		ci.draw_line(Vector2(x, base_rect.position.y), peak, trim, 2.0)
		ci.draw_line(peak, Vector2(minf(x + tooth, base_rect.end.x), base_rect.position.y), trim, 2.0)
		x += tooth
	ci.draw_line(Vector2(base_rect.position.x, base_rect.position.y), Vector2(base_rect.end.x, base_rect.position.y), trim, 2.0)
	# 烟囱与缓慢上升的烟。
	for c in maxi(0, chimney_count):
		var step := base_rect.size.x / float(maxi(1, chimney_count + 1))
		var cx := base_rect.position.x + step * float(c + 1)
		var ch_height := base_rect.size.y * (0.42 + _rand(c, 3.0) * 0.3)
		var ch_width := maxf(base_rect.size.x * 0.045, 5.0)
		ci.draw_rect(Rect2(cx - ch_width * 0.5, base_rect.position.y - ch_height, ch_width, ch_height), body, true)
		ci.draw_rect(Rect2(cx - ch_width * 0.5, base_rect.position.y - ch_height, ch_width, 3.0), trim, true)
		for p in 4:
			var t := fmod(phase * 0.35 + float(p) * 0.25 + _rand(c, float(p) + 1.0), 1.0)
			var drift := sin(t * 5.0 + float(c)) * ch_width * 1.4
			var radius := ch_width * (0.45 + t * 0.9)
			var smoke := Color(trim.r, trim.g, trim.b, smoke_alpha * (1.0 - t) * 0.55)
			ci.draw_circle(
				Vector2(cx + drift, base_rect.position.y - ch_height - t * base_rect.size.y * 0.55),
				radius,
				smoke
			)

## 画一个齿轮：外圈锯齿 + 内圈 + 轮毂。
## @param ci 目标控件。
## @param center 圆心。
## @param radius 半径。
## @param color 线条颜色。
## @param phase 动画相位，用于缓慢旋转。
static func _draw_gear(ci: CanvasItem, center: Vector2, radius: float, color: Color, phase: float) -> void:
	var spin := phase * 0.35
	ci.draw_arc(center, radius, 0.0, TAU, 32, color, 2.0, true)
	ci.draw_arc(center, radius * 0.62, 0.0, TAU, 24, Color(color.r, color.g, color.b, color.a * 0.65), 1.5, true)
	for tooth in 12:
		var angle := spin + float(tooth) * TAU / 12.0
		var dir := Vector2(cos(angle), sin(angle))
		ci.draw_line(center + dir * radius * 0.96, center + dir * radius * 1.22, color, 3.0)
	ci.draw_circle(center, radius * 0.16, color)

## 画一只发光小幽灵：光晕 + 身体 + 眼睛 + 飘带。
## @param ci 目标控件。
## @param center 中心点。
## @param radius 半径。
## @param tint 主体颜色。
## @param phase 动画相位。
static func _draw_ghost(ci: CanvasItem, center: Vector2, radius: float, tint: Color, phase: float) -> void:
	ci.draw_circle(center, radius * 2.1, Color(tint.r, tint.g, tint.b, 0.07))
	ci.draw_circle(center, radius * 1.45, Color(tint.r, tint.g, tint.b, 0.13))
	ci.draw_circle(center, radius, Color(tint.r, tint.g, tint.b, 0.9))
	# 底部飘带，随时间轻微摆动。
	for tail in 3:
		var offset := (float(tail) - 1.0) * radius * 0.55
		var wave := sin(phase * 2.0 + float(tail)) * radius * 0.16
		ci.draw_line(
			Vector2(center.x + offset, center.y + radius * 0.6),
			Vector2(center.x + offset + wave, center.y + radius * 1.5),
			Color(tint.r, tint.g, tint.b, 0.55),
			maxf(radius * 0.22, 1.0)
		)
	var eye := Color(UIPalette.BG_DEEP.r, UIPalette.BG_DEEP.g, UIPalette.BG_DEEP.b, 0.85)
	ci.draw_circle(center + Vector2(-radius * 0.32, -radius * 0.12), radius * 0.14, eye)
	ci.draw_circle(center + Vector2(radius * 0.32, -radius * 0.12), radius * 0.14, eye)

## 主视觉：夜色工厂剖面 + 齿轮管道 + 三只幽灵。
## @param ci 目标控件。
## @param canvas_size 控件尺寸。
## @param phase 动画相位。
static func _draw_key_art(ci: CanvasItem, canvas_size: Vector2, phase: float) -> void:
	var w := canvas_size.x
	var h := canvas_size.y
	_draw_gradient(ci, canvas_size, UIPalette.BG_GRADIENT_TOP, UIPalette.BG_DEEP)

	# 背后月晕与漂浮尘埃。
	var moon := Vector2(w * 0.72, h * 0.24)
	var moon_r := minf(w, h) * 0.13
	ci.draw_circle(moon, moon_r * 2.4, Color(UIPalette.GLOW_CYAN.r, UIPalette.GLOW_CYAN.g, UIPalette.GLOW_CYAN.b, 0.045))
	ci.draw_circle(moon, moon_r, Color(UIPalette.TEXT_PRIMARY.r, UIPalette.TEXT_PRIMARY.g, UIPalette.TEXT_PRIMARY.b, 0.10))
	ci.draw_arc(moon, moon_r, 0.0, TAU, 40, Color(UIPalette.GLOW_CYAN.r, UIPalette.GLOW_CYAN.g, UIPalette.GLOW_CYAN.b, 0.35), 2.0, true)
	for i in DUST_COUNT:
		var px := _rand(i, 1.0) * w
		var py := _rand(i, 2.0) * h * 0.78
		var twinkle := 0.35 + 0.35 * sin(phase * 1.6 + _rand(i, 3.0) * TAU)
		ci.draw_circle(Vector2(px, py), 1.2 + _rand(i, 4.0) * 1.6, Color(1.0, 1.0, 1.0, twinkle * 0.32))

	# 远景厂房剪影（压低对比度，做纵深）。
	var far := Rect2(w * 0.02, h * 0.48, w * 0.96, h * 0.28)
	_draw_factory_block(
		ci, far,
		Color(UIPalette.BG_PANEL.r, UIPalette.BG_PANEL.g, UIPalette.BG_PANEL.b, 0.85),
		Color(UIPalette.BORDER.r, UIPalette.BORDER.g, UIPalette.BORDER.b, 0.55),
		3, phase, 0.35
	)

	# 主厂房剖面：外壳 + 三层楼板 + 发光窗格。
	var body := Rect2(w * 0.12, h * 0.30, w * 0.62, h * 0.52)
	ci.draw_rect(body, Color(UIPalette.BG_PANEL.r, UIPalette.BG_PANEL.g, UIPalette.BG_PANEL.b, 0.96), true)
	ci.draw_rect(body, Color(UIPalette.PRIMARY.r, UIPalette.PRIMARY.g, UIPalette.PRIMARY.b, 0.55), false, 2.0)
	for floor_index in 3:
		var fy := body.position.y + body.size.y * (0.33 + float(floor_index) * 0.30)
		ci.draw_line(Vector2(body.position.x, fy), Vector2(body.end.x, fy), Color(UIPalette.BORDER.r, UIPalette.BORDER.g, UIPalette.BORDER.b, 0.85), 2.0)
		for bay in 5:
			var bx := body.position.x + body.size.x * (0.09 + float(bay) * 0.18)
			var lit := _rand(floor_index * 7 + bay, 5.0) > 0.32
			var window_color := Color(UIPalette.ACCENT.r, UIPalette.ACCENT.g, UIPalette.ACCENT.b, 0.75 if lit else 0.12)
			ci.draw_rect(Rect2(bx, fy - body.size.y * 0.20, body.size.x * 0.10, body.size.y * 0.15), window_color, true)
	# 屋顶烟囱与管线。
	_draw_factory_block(
		ci, Rect2(body.position.x + body.size.x * 0.08, body.position.y - h * 0.10, body.size.x * 0.30, h * 0.10),
		Color(UIPalette.BG_RAISED.r, UIPalette.BG_RAISED.g, UIPalette.BG_RAISED.b, 1.0),
		Color(UIPalette.ACCENT.r, UIPalette.ACCENT.g, UIPalette.ACCENT.b, 0.65),
		2, phase, 0.55
	)
	var pipe_x := body.end.x - body.size.x * 0.06
	ci.draw_line(Vector2(pipe_x, body.position.y - h * 0.04), Vector2(pipe_x, body.end.y + h * 0.06), Color(UIPalette.ACCENT.r, UIPalette.ACCENT.g, UIPalette.ACCENT.b, 0.55), maxf(w * 0.012, 3.0))
	ci.draw_line(Vector2(pipe_x, body.end.y + h * 0.06), Vector2(w * 0.94, body.end.y + h * 0.06), Color(UIPalette.ACCENT.r, UIPalette.ACCENT.g, UIPalette.ACCENT.b, 0.55), maxf(w * 0.012, 3.0))
	ci.draw_circle(Vector2(pipe_x, body.position.y - h * 0.04), maxf(w * 0.014, 4.0), UIPalette.ACCENT)

	# 外挂齿轮，体现「机关联动」。
	_draw_gear(ci, Vector2(w * 0.80, h * 0.52), minf(w, h) * 0.105, Color(UIPalette.GLOW_CYAN.r, UIPalette.GLOW_CYAN.g, UIPalette.GLOW_CYAN.b, 0.65), phase)
	_draw_gear(ci, Vector2(w * 0.88, h * 0.66), minf(w, h) * 0.065, Color(UIPalette.PRIMARY_LIGHT.r, UIPalette.PRIMARY_LIGHT.g, UIPalette.PRIMARY_LIGHT.b, 0.55), -phase * 0.8)

	# 地面与蓝图网格。
	var ground_y := body.end.y + h * 0.02
	ci.draw_rect(Rect2(0.0, ground_y, w, h - ground_y), Color(UIPalette.BG_DEEP.r, UIPalette.BG_DEEP.g, UIPalette.BG_DEEP.b, 0.92), true)
	var spacing := maxf(w / 14.0, 12.0)
	var gx := 0.0
	while gx <= w:
		ci.draw_line(Vector2(gx, ground_y), Vector2(gx, h), Color(UIPalette.BORDER.r, UIPalette.BORDER.g, UIPalette.BORDER.b, 0.28), 1.0)
		gx += spacing
	ci.draw_line(Vector2(0.0, ground_y), Vector2(w, ground_y), Color(UIPalette.PRIMARY.r, UIPalette.PRIMARY.g, UIPalette.PRIMARY.b, 0.7), 2.0)

	# 交付口：发光立柱 + 接收环。
	var terminal := Vector2(w * 0.90, ground_y + (h - ground_y) * 0.42)
	ci.draw_rect(Rect2(terminal.x - w * 0.02, terminal.y - h * 0.09, w * 0.04, h * 0.09), Color(UIPalette.SUCCESS.r, UIPalette.SUCCESS.g, UIPalette.SUCCESS.b, 0.55), true)
	ci.draw_arc(terminal + Vector2(0.0, -h * 0.09), w * 0.035, 0.0, TAU, 28, UIPalette.SUCCESS, 3.0, true)

	# 三只幽灵在厂房前漂浮。
	var ghost_tints: Array[Color] = [UIPalette.GLOW_CYAN, UIPalette.ACCENT_LIGHT, UIPalette.PRIMARY_LIGHT]
	for i in 3:
		var bob := sin(phase * 1.25 + float(i) * 1.7) * h * 0.018
		var center := Vector2(w * (0.24 + float(i) * 0.19), h * (0.60 + float(i % 2) * 0.11) + bob)
		_draw_ghost(ci, center, minf(w, h) * (0.045 + float(i) * 0.008), ghost_tints[i], phase)

	# 底部霓虹收边。
	ci.draw_rect(Rect2(0.0, h - 3.0, w, 3.0), Color(UIPalette.PRIMARY.r, UIPalette.PRIMARY.g, UIPalette.PRIMARY.b, 0.8), true)

## 全屏背景：极淡的废弃工厂远景 + 雾带，不能压住界面文字。
## @param ci 目标控件。
## @param canvas_size 控件尺寸。
## @param phase 动画相位。
static func _draw_backdrop(ci: CanvasItem, canvas_size: Vector2, phase: float) -> void:
	var w := canvas_size.x
	var h := canvas_size.y
	var silhouette := Color(UIPalette.BG_RAISED.r, UIPalette.BG_RAISED.g, UIPalette.BG_RAISED.b, 0.30)
	var trim := Color(UIPalette.PRIMARY_LIGHT.r, UIPalette.PRIMARY_LIGHT.g, UIPalette.PRIMARY_LIGHT.b, 0.14)

	# 远景厂房主体，集中在画面下三分之一。
	var base_y := h * 0.70
	_draw_factory_block(ci, Rect2(0.0, base_y, w, h * 0.22), silhouette, trim, 5, phase, 0.22)

	# 零星亮着的窗格。
	for i in WINDOW_COUNT:
		var col := i % 17
		var row := i / 17
		var wx := w * (0.04 + float(col) * 0.056)
		var wy := base_y + h * (0.035 + float(row) * 0.075)
		var flicker := 0.55 + 0.45 * sin(phase * 0.8 + _rand(i, 9.0) * TAU)
		var lit := _rand(i, 7.0) > 0.45
		if lit:
			ci.draw_rect(Rect2(wx, wy, w * 0.022, h * 0.026), Color(UIPalette.ACCENT.r, UIPalette.ACCENT.g, UIPalette.ACCENT.b, 0.13 * flicker), true)

	# 横向雾带，让剪影与上层 UI 之间有一层缓冲。
	for band in 5:
		var t := float(band) / 5.0
		var fy := base_y - h * 0.10 + t * h * 0.14
		var fog := Color(UIPalette.BG_GRADIENT_TOP.r, UIPalette.BG_GRADIENT_TOP.g, UIPalette.BG_GRADIENT_TOP.b, 0.045 * (1.0 - t))
		ci.draw_rect(Rect2(0.0, fy, w, h * 0.035), fog, true)

	# 地面线与稀疏透视网格。
	ci.draw_line(Vector2(0.0, base_y + h * 0.22), Vector2(w, base_y + h * 0.22), Color(UIPalette.PRIMARY.r, UIPalette.PRIMARY.g, UIPalette.PRIMARY.b, 0.16), 2.0)
	var spacing := maxf(w / 16.0, 32.0)
	var gx := -spacing
	while gx <= w + spacing:
		ci.draw_line(Vector2(w * 0.5 + (gx - w * 0.5) * 0.35, base_y + h * 0.22), Vector2(gx, h), Color(UIPalette.BORDER.r, UIPalette.BORDER.g, UIPalette.BORDER.b, 0.10), 1.0)
		gx += spacing

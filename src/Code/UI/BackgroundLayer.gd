class_name BackgroundLayer
extends Control

## 背景层。铺底色 + 若干柔和主色光斑，并内嵌一个 ArtPlaceholder 作为背景图位。
## 主菜单与关卡选择共用；美术资源到位后把路径填到 background_art_path 即可替换占位框。

## 光斑的随机分布种子，保证每次运行的布局一致。
const GLOW_SEED: int = 20260903
## 光斑漂移的基础速度（像素/秒）。
const GLOW_DRIFT_SPEED: float = 18.0
## 光斑漂移的最大偏移（像素）。
const GLOW_DRIFT_RANGE: float = 60.0
## 背景图占位与底色之间的层级差。
const ART_LAYER_OFFSET: int = 0

## 背景底色。
@export var base_color: Color = UIPalette.BG_DEEP
## 主色光晕颜色。
@export var glow_color: Color = UIPalette.PRIMARY
## 背景图占位组件。
@export var art_placeholder: ArtPlaceholder = null
## 是否启用缓慢流动的光斑。
@export var animate_glow: bool = true
## 光斑数量。
@export var glow_count: int = 5
## 背景图资源路径，留空表示等待美术。
@export var background_art_path: String = ""
## 光斑整体强度倍率，0~1。
@export_range(0.0, 1.0, 0.05) var glow_intensity: float = 0.35

var _phase: float = 0.0
var _spots: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -10
	_build_spots()
	if art_placeholder == null:
		# 场景里若已预置占位组件则直接认领，避免出现两个背景图位。
		for child in get_children():
			if child is ArtPlaceholder:
				art_placeholder = child
				break
	if art_placeholder == null:
		# 代码直接实例化时补建占位组件，保证背景图位始终存在。
		art_placeholder = ArtPlaceholder.new()
		art_placeholder.name = "ArtPlaceholder"
		add_child(art_placeholder)
	art_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if art_placeholder != null:
		art_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_placeholder.label_at_bottom_right = true
		if background_art_path != "":
			art_placeholder.SetArt(background_art_path)
	set_process(animate_glow)
	resized.connect(queue_redraw)

## 设定背景图资源路径；路径为空时退回占位框显示。
## @param path 背景图资源路径，空字符串表示尚未出图。
func SetArt(path: String) -> void:
	background_art_path = path
	if art_placeholder == null:
		return
	if path == "":
		art_placeholder.art_path = ""
		art_placeholder.ReloadArt()
		return
	art_placeholder.SetArt(path)

## 设定光斑强度。
## @param value 强度倍率，0~1。
func SetGlowIntensity(value: float) -> void:
	glow_intensity = clampf(value, 0.0, 1.0)
	queue_redraw()

## 取得内嵌的背景图占位组件。
## @return 占位组件；不存在时返回 null。
func GetArtPlaceholder() -> ArtPlaceholder:
	return art_placeholder

func _process(delta: float) -> void:
	if not animate_glow:
		return
	_phase += delta * GLOW_DRIFT_SPEED
	queue_redraw()

## 生成光斑的基础分布。
func _build_spots() -> void:
	_spots.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = GLOW_SEED
	for i in maxi(0, glow_count):
		_spots.append({
			"anchor": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(0.12, 0.26),
			"speed": rng.randf_range(0.4, 1.0),
			"phase": rng.randf_range(0.0, TAU),
		})

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), base_color, true)
	for spot in _spots:
		var anchor: Vector2 = spot["anchor"]
		var radius: float = spot["radius"]
		var speed: float = spot["speed"]
		var offset_phase: float = spot["phase"]
		var drift := Vector2(
			sin(_phase * speed + offset_phase),
			cos(_phase * speed * 0.7 + offset_phase)
		) * GLOW_DRIFT_RANGE
		var center := anchor * size + drift
		var spot_radius: float = maxf(size.x, size.y) * radius
		var alpha: float = glow_intensity * 0.35
		draw_circle(center, spot_radius, Color(glow_color.r, glow_color.g, glow_color.b, alpha))
		draw_circle(center, spot_radius * 0.55, Color(glow_color.r, glow_color.g, glow_color.b, alpha * 0.8))

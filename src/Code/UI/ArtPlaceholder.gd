class_name ArtPlaceholder
extends Control

## 美术位组件。优先级：art_path 指向的真实纹理 > procedural_art 程序化图案 > 虚线框占位。
## 界面上的实例由 BackgroundLayer / StartMenu 指定程序化类别，因此默认不再出现「待补图」文字；
## 美术资源到位后填 art_path 即可无缝替换，程序化图案只作兜底。
## 直接 new 出来的裸实例仍走虚线框模式，供组件自测使用。

## 占位框默认描边色（主色系，低不透明度）。
const DEFAULT_BORDER_COLOR: Color = Color(0.486, 0.361, 1.0, 0.45)
## 占位框默认填充色（主色系，极低不透明度）。
const DEFAULT_FILL_COLOR: Color = Color(0.486, 0.361, 1.0, 0.05)
## 标签文字字号。
const LABEL_FONT_SIZE: int = 16
## 虚线段长度（像素）。
const DASH_LENGTH: float = 12.0
## 虚线间隔（像素）。
const DASH_GAP: float = 8.0
## 标签贴边时的边距（像素）。
const LABEL_MARGIN: float = 16.0

## 占位图的说明文字，例如「背景图 · 废弃工厂夜景」。
@export var label_text: String = "背景图"
## 占位框的描边色。
@export var border_color: Color = DEFAULT_BORDER_COLOR
## 占位框的填充色。
@export var fill_color: Color = DEFAULT_FILL_COLOR
## 是否显示虚线边框。
@export var show_border: bool = true
## 标签相对占位框中心的偏移量。背景层用它把说明文字挪到角落，避免压住界面内容。
@export var label_offset: Vector2 = Vector2.ZERO
## 是否把标签贴到占位框右下角。铺满全屏的背景图位用它避免文字压住界面内容。
@export var label_at_bottom_right: bool = false
## 美术资源到位后要替换成的场景或纹理路径，留空表示暂无。
@export var art_path: String = ""
## 无真实素材时使用的程序化图案：none 裸占位框、key_art 主视觉、backdrop 全屏背景。
@export var procedural_art: StringName = &"none"
## 程序化图案是否启用缓慢动画（烟雾、幽灵漂浮、灯光闪烁）。
@export var animate_procedural: bool = true

var _texture: Texture2D = null
var _art_node: Node = null
var _phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	ReloadArt()
	_refresh_animation()

## 指定程序化图案类别并立即重绘。
## @param kind FactoryArt.KIND_KEY_ART / KIND_BACKDROP，或 &"none" 退回裸占位框。
func SetProceduralArt(kind: StringName) -> void:
	procedural_art = kind
	_refresh_animation()
	queue_redraw()

## 当前是否仍显示虚线框与占位文字（既无真实素材、也无程序化图案）。
## @return 显示裸占位框时返回 true。
func IsShowingPlaceholderFrame() -> bool:
	return _texture == null and not FactoryArt.IsValidKind(procedural_art)

## 只在程序化图案生效时开启逐帧重绘，避免静态界面白耗 CPU。
func _refresh_animation() -> void:
	set_process(animate_procedural and _texture == null and FactoryArt.IsValidKind(procedural_art))

func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()

## 设置占位说明文字。
## @param text 显示在占位框中央的文字。
func SetLabel(text: String) -> void:
	label_text = text
	queue_redraw()

## 指定美术资源路径并立即尝试加载。
## @param path 资源路径（res:// 下的纹理或场景），留空表示暂无资源。
func SetArt(path: String) -> void:
	art_path = path
	ReloadArt()

## 重新加载 art_path 指向的资源。
## 支持直接纹理（Texture2D），也支持内含 TextureRect 的场景（PackedScene）。
func ReloadArt() -> void:
	_clear_art()
	if art_path != "" and ResourceLoader.exists(art_path):
		var res := ResourceLoader.load(art_path)
		if res is Texture2D:
			_texture = res
		elif res is PackedScene:
			var instance := (res as PackedScene).instantiate()
			if instance is TextureRect:
				_texture = (instance as TextureRect).texture
			else:
				_art_node = instance
				add_child(instance)
				instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	_refresh_animation()
	queue_redraw()

## 清空已加载的美术资源。
func _clear_art() -> void:
	_texture = null
	if _art_node != null:
		remove_child(_art_node)
		_art_node.queue_free()
		_art_node = null

## 是否已经拿到真实美术资源。
## @return 有可用纹理时返回 true。
func HasArt() -> bool:
	return _texture != null

## 当前已加载的纹理。
## @return 纹理；没有则返回 null。
func GetArt() -> Texture2D:
	return _texture

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if _texture != null:
		_draw_texture_fitted(_texture, rect)
		return
	if FactoryArt.IsValidKind(procedural_art):
		FactoryArt.Draw(self, procedural_art, size, _phase)
		return
	draw_rect(rect, fill_color, true)
	if show_border:
		_draw_dashed_rect(rect, border_color)
	_draw_label()

## 按比例把纹理完整画进矩形，保持原始宽高比。
## @param texture 目标纹理。
## @param rect 目标区域。
func _draw_texture_fitted(texture: Texture2D, rect: Rect2) -> void:
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale_factor: float = minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
	var draw_size := tex_size * scale_factor
	var draw_pos := rect.position + (rect.size - draw_size) * 0.5
	draw_texture_rect(texture, Rect2(draw_pos, draw_size), false)

## 画虚线矩形边框。
## @param rect 边框区域。
## @param color 描边色。
func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var width := maxf(size.x, 1.0)
	var height := maxf(size.y, 1.0)
	_dashed_line(Vector2(0.0, 0.0), Vector2(width, 0.0), color)
	_dashed_line(Vector2(width, 0.0), Vector2(width, height), color)
	_dashed_line(Vector2(width, height), Vector2(0.0, height), color)
	_dashed_line(Vector2(0.0, height), Vector2(0.0, 0.0), color)

## 画一条虚线。
## @param from 起点。
## @param to 终点。
## @param color 描边色。
func _dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var delta := to - from
	var length := delta.length()
	if length <= 0.001:
		return
	var dir := delta / length
	var travelled := 0.0
	while travelled < length:
		var dash_end: float = minf(travelled + DASH_LENGTH, length)
		draw_line(from + dir * travelled, from + dir * dash_end, color, 2.0)
		travelled += DASH_LENGTH + DASH_GAP

## 在占位框中央画说明文字。
func _draw_label() -> void:
	if label_text == "":
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var pos: Vector2
	if label_at_bottom_right:
		# 贴右下角：留出 16 像素边距。
		pos = Vector2(size.x - text_size.x - LABEL_MARGIN, size.y - text_size.y - LABEL_MARGIN)
	else:
		pos = Vector2((size.x - text_size.x) * 0.5, (size.y + text_size.y * 0.5) * 0.5) + label_offset
	draw_string(font, pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, UIPalette.TEXT_SECONDARY)

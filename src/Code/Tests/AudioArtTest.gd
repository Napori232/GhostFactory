extends Node

## 下周计划 §6-6 / §6-7 验收测试：程序化美术不再显示占位框，四个基础音效与事件音真实可用。
## 运行：Godot --headless --path <src> res://Code/Tests/AudioArtTest.tscn

const MENU_SCENE: String = "res://Code/Entities/StartMenu/StartMenu.tscn"
const SELECT_SCENE: String = "res://Code/Entities/LevelSelect/LevelSelect.tscn"
const SETTINGS_SCENE: String = "res://Code/Entities/Setting/SettingPanel.tscn"

var _checks: int = 0
var _failures: int = 0

func _ready() -> void:
	await get_tree().process_frame
	_test_sfx_library()
	_test_ambient()
	await _test_sfx_playback()
	await _test_procedural_art()
	await _test_ui_art()
	print("---- 结果：%d 项断言，%d 项失败" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## 记录一条断言。
## @param condition 断言条件。
## @param label 断言说明。
func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
	else:
		_failures += 1
		print("FAIL: %s" % label)
		push_error("FAIL: %s" % label)

## 四个基础音必須齐全，且每个都是合法、非静音、不削波的 16-bit 单声道流。
func _test_sfx_library() -> void:
	var required: Array[StringName] = [
		GameSfx.ID_PLACE, GameSfx.ID_PICKUP, GameSfx.ID_PROCESS, GameSfx.ID_DELIVER
	]
	for id in required:
		_check(GameSfx.SFX_IDS.has(id), "基础音 %s 已登记" % id)
	for id in GameSfx.SFX_IDS:
		var stream := GameSfx.Get(id)
		_check(stream != null, "%s 可生成音频流" % id)
		if stream == null:
			continue
		_check(stream is AudioStreamWAV, "%s 为 AudioStreamWAV" % id)
		_check(stream.format == AudioStreamWAV.FORMAT_16_BITS, "%s 为 16-bit PCM" % id)
		_check(stream.mix_rate == GameSfx.MIX_RATE, "%s 采样率正确" % id)
		_check(not stream.stereo, "%s 为单声道" % id)
		_check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s 不循环" % id)
		var frame_count := stream.data.size() / 2
		_check(frame_count > 0 and stream.data.size() % 2 == 0, "%s PCM 字节数合法" % id)
		var length := stream.get_length()
		_check(length > 0.04 and length < 1.2, "%s 时长合理，实际 %.3fs" % [id, length])
		var peak := _peak_of(stream)
		_check(peak > 0.01, "%s 非静音，峰值 %.3f" % [id, peak])
		_check(peak <= 0.98, "%s 未削波，峰值 %.3f" % [id, peak])
	_check(GameSfx.Get(GameSfx.ID_PLACE) == GameSfx.Get(GameSfx.ID_PLACE), "同一音效复用缓存")
	_check(GameSfx.Get(&"not_a_sfx") == null, "未知音效 id 返回 null")

## 读取 16-bit PCM 的归一化峰值。
## @param stream 目标音频流。
## @return 0.0~1.0 的峰值。
func _peak_of(stream: AudioStreamWAV) -> float:
	var peak := 0.0
	var frames := stream.data.size() / 2
	for i in frames:
		var sample := float(stream.data.decode_s16(i * 2)) / 32767.0
		peak = maxf(peak, absf(sample))
	return peak

## 环境底噪必须整段循环且长度与循环点一致。
func _test_ambient() -> void:
	var ambient := GameSfx.GetAmbient()
	_check(ambient != null, "工厂环境底噪可生成")
	if ambient == null:
		return
	_check(ambient.loop_mode == AudioStreamWAV.LOOP_FORWARD, "环境底噪循环播放")
	_check(ambient.loop_begin == 0, "环境底噪从头循环")
	_check(ambient.loop_end == ambient.data.size() / 2, "环境底噪循环到末帧")
	_check(absf(ambient.get_length() - GameSfx.AMBIENT_SECONDS) < 0.02, "环境底噪时长 %.2fs" % ambient.get_length())
	var ambient_peak := _peak_of(ambient)
	_check(ambient_peak > 0.01 and ambient_peak < 0.5, "环境底噪音量适中，峰值 %.3f" % ambient_peak)

## 音效播放入口能真正挂上播放器，并遵守最小间隔节流。
func _test_sfx_playback() -> void:
	_check(Util.has_method("PlayGameSfx"), "Util 提供 PlayGameSfx")
	_check(SignalBus.has_signal("ItemProcessed"), "SignalBus 新增 ItemProcessed 信号")
	var players: Array[AudioStreamPlayer] = []
	for id in [GameSfx.ID_PLACE, GameSfx.ID_PICKUP, GameSfx.ID_PROCESS, GameSfx.ID_DELIVER]:
		var player := Util.PlayGameSfx(id)
		_check(player != null and player.stream == GameSfx.Get(id), "%s 可播放" % id)
		if player != null:
			players.append(player)
	_check(Util.PlayGameSfx(GameSfx.ID_PLACE) == null, "同一音效短时间内被节流")
	for player in players:
		player.queue_free()

	# 四个基础音必须真的由玩法事件触发：等节流窗口过去后发信号，
	# 紧接着手动播同一 id 会被节流，说明信号链路已经播过一次。
	await get_tree().create_timer(0.12).timeout
	SignalBus.GhostPlaced.emit(self)
	_check(Util.PlayGameSfx(GameSfx.ID_PLACE) == null, "GhostPlaced 事件自动播放放置音")
	SignalBus.SpiritPicked.emit(1)
	_check(Util.PlayGameSfx(GameSfx.ID_PICKUP) == null, "SpiritPicked 事件自动播放拾取音")
	SignalBus.ItemProcessed.emit(&"Offer")
	_check(Util.PlayGameSfx(GameSfx.ID_PROCESS) == null, "ItemProcessed 事件自动播放加工音")
	SignalBus.ItemDelivered.emit("Offer", self)
	_check(Util.PlayGameSfx(GameSfx.ID_DELIVER) == null, "ItemDelivered 事件自动播放交付音")

## 占位组件：裸实例仍可自测，指定程序化图案后不再显示虚线框与占位文字。
func _test_procedural_art() -> void:
	_check(FactoryArt.IsValidKind(FactoryArt.KIND_KEY_ART), "主视觉类别有效")
	_check(FactoryArt.IsValidKind(FactoryArt.KIND_BACKDROP), "背景类别有效")
	_check(not FactoryArt.IsValidKind(&"none"), "none 不是程序化图案")
	var placeholder := ArtPlaceholder.new()
	placeholder.size = Vector2(320, 240)
	add_child(placeholder)
	_check(placeholder.IsShowingPlaceholderFrame(), "裸实例仍显示占位框（组件自测用）")
	placeholder.SetProceduralArt(FactoryArt.KIND_KEY_ART)
	await get_tree().process_frame
	_check(not placeholder.IsShowingPlaceholderFrame(), "主视觉模式不再显示占位框")
	_check(placeholder.procedural_art == FactoryArt.KIND_KEY_ART, "主视觉类别已写入")
	placeholder.SetProceduralArt(FactoryArt.KIND_BACKDROP)
	_check(not placeholder.IsShowingPlaceholderFrame(), "背景模式不再显示占位框")
	_check(not placeholder.HasArt(), "程序化图案不冒充真实素材")
	placeholder.SetProceduralArt(&"none")
	_check(placeholder.IsShowingPlaceholderFrame(), "可退回裸占位框")
	placeholder.queue_free()

## 三套界面 + 主菜单主视觉都接上程序化图案，界面上不再有「待补图」文字。
func _test_ui_art() -> void:
	var layer := BackgroundLayer.new()
	layer.size = Vector2(1280, 720)
	add_child(layer)
	await get_tree().process_frame
	var backdrop := layer.GetArtPlaceholder()
	_check(backdrop != null, "背景层内嵌美术位")
	if backdrop != null:
		_check(backdrop.procedural_art == FactoryArt.KIND_BACKDROP, "背景层自动使用程序化背景")
		_check(not backdrop.IsShowingPlaceholderFrame(), "背景层不显示占位框")
	layer.queue_free()

	var menu := _instantiate(MENU_SCENE, "主菜单")
	if menu != null:
		var key_art := menu.get_node_or_null("%KeyArt") as ArtPlaceholder
		_check(key_art != null, "主菜单含主视觉位")
		if key_art != null:
			_check(key_art.procedural_art == FactoryArt.KIND_KEY_ART, "主视觉使用工厂剖面图")
			_check(not key_art.IsShowingPlaceholderFrame(), "主视觉不显示占位框")
			_check(key_art.label_text == ExportSettings.ui_key_art_label, "占位说明保留为元数据，但程序化模式不再绘制它")
		var menu_bg := menu.get_node_or_null("%Background") as BackgroundLayer
		if menu_bg != null and menu_bg.GetArtPlaceholder() != null:
			_check(menu_bg.GetArtPlaceholder().procedural_art == FactoryArt.KIND_BACKDROP, "主菜单背景使用程序化远景")
		menu.queue_free()

	for entry in [[SELECT_SCENE, "关卡选择"], [SETTINGS_SCENE, "设置面板"]]:
		var panel := _instantiate(String(entry[0]), String(entry[1]))
		if panel == null:
			continue
		var bg := panel.get_node_or_null("%Background") as BackgroundLayer
		_check(bg != null and bg.GetArtPlaceholder() != null, "%s 背景层已装配" % entry[1])
		if bg != null and bg.GetArtPlaceholder() != null:
			_check(bg.GetArtPlaceholder().procedural_art == FactoryArt.KIND_BACKDROP, "%s 背景使用程序化远景" % entry[1])
			_check(not bg.GetArtPlaceholder().IsShowingPlaceholderFrame(), "%s 不显示占位框" % entry[1])
		panel.queue_free()
	await get_tree().process_frame

## 实例化一个界面场景。
## @param path 场景路径。
## @param label 断言用的名称。
## @return 实例节点；加载失败返回 null。
func _instantiate(path: String, label: String) -> Node:
	var packed := load(path) as PackedScene
	_check(packed != null, "%s 场景可加载" % label)
	if packed == null:
		return null
	var instance := packed.instantiate()
	add_child(instance)
	return instance

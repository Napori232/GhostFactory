extends Node

## 通用工具集合：定时器、补间、音效播放、格式化等。
## 全部为无状态或自持状态的辅助函数，不依赖具体实体。

const BGM_CROSSFADE_DURATION: float = 2.5

var _bgm_player: AudioStreamPlayer = null
var _bgm_tracks: Dictionary = {}
var _bgm_tweens: Dictionary = {}

var _audio_initialized: bool = false
var _audio_volumes: Dictionary = {}
var _audio_buses: Dictionary = {}
var _audio_base_db: Dictionary = {}

func _ready() -> void:
	call_deferred("_start_game_audio")

func _start_game_audio() -> void:
	_initialize_audio_settings()

## 初始化并恢复独立音量设置；无参数，可重复调用且不会重置总线基准音量。
func InitializeAudioSettings() -> void:
	_initialize_audio_settings()

## 读取音量比例。
## @param channel 类别为 master 总音量、music 音乐、sfx 音效、dialogue 对白或 ambience 环境。
## @return 0.0-1.0 的线性音量比例；未知类别返回 1.0。
func GetAudioVolume(channel: StringName) -> float:
	_initialize_audio_settings()
	return float(_audio_volumes.get(channel, 1.0))

## 调整音量、应用音频总线并独立持久化，同时发送音量变化通知。
## @param channel 类别为 master 总音量、music 音乐、sfx 音效、dialogue 对白或 ambience 环境，未知类别忽略。
## @param volume 有限的线性音量比例，限制到 0.0-1.0，0 表示静音。
func SetAudioVolume(channel: StringName, volume: float) -> void:
	_initialize_audio_settings()
	if not _audio_volumes.has(channel) or not is_finite(volume):
		return
	_audio_volumes[channel] = clampf(volume, 0.0, 1.0)
	_apply_audio_volume(channel)
	var config := ConfigFile.new()
	for audio_channel in _audio_volumes:
		config.set_value("volume", String(audio_channel), _audio_volumes[audio_channel])
	var error := config.save(ExportSettings.audio_settings_path)
	if error != OK:
		push_warning("音量设置保存失败，错误码：%d" % error)
	SignalBus.AudioVolumeChanged.emit(channel, _audio_volumes[channel])

func _initialize_audio_settings() -> void:
	if _audio_initialized:
		return
	_audio_initialized = true
	_audio_volumes = {
		&"master": ExportSettings.audio_master_volume,
		&"music": ExportSettings.audio_music_volume,
		&"sfx": ExportSettings.audio_sfx_volume,
		&"dialogue": ExportSettings.audio_dialogue_volume,
		&"ambience": ExportSettings.audio_ambience_volume,
	}
	_audio_buses = {
		&"master": ExportSettings.audio_master_bus,
		&"music": ExportSettings.audio_music_bus,
		&"sfx": ExportSettings.audio_sfx_bus,
		&"dialogue": ExportSettings.audio_dialogue_bus,
		&"ambience": ExportSettings.audio_ambience_bus,
	}
	SignalBus.AudioVolumeChangeRequested.connect(SetAudioVolume)
	var config := ConfigFile.new()
	var loaded := config.load(ExportSettings.audio_settings_path) == OK
	for channel in _audio_volumes:
		var bus_index := AudioServer.get_bus_index(_audio_buses[channel])
		if bus_index >= 0:
			_audio_base_db[channel] = AudioServer.get_bus_volume_db(bus_index)
		else:
			push_warning("音量设置找不到音频总线：%s" % _audio_buses[channel])
		if loaded:
			var saved_volume: Variant = config.get_value("volume", String(channel), _audio_volumes[channel])
			if (saved_volume is float or saved_volume is int) and is_finite(float(saved_volume)):
				_audio_volumes[channel] = clampf(float(saved_volume), 0.0, 1.0)
		_apply_audio_volume(channel)
		SignalBus.AudioVolumeChanged.emit(channel, _audio_volumes[channel])

func _apply_audio_volume(channel: StringName) -> void:
	var bus_index := AudioServer.get_bus_index(_audio_buses[channel])
	if bus_index < 0 or not _audio_base_db.has(channel):
		return
	var volume: float = _audio_volumes[channel]
	AudioServer.set_bus_mute(bus_index, volume == 0.0)
	if volume > 0.0:
		AudioServer.set_bus_volume_db(bus_index, float(_audio_base_db[channel]) + linear_to_db(volume))

## 切换背景音乐，交叉淡入。
## @param music 要播放的音频流
## @param loop 是否循环播放
func SwitchBgm(music: AudioStream, loop: bool = true) -> void:
	if music == null:
		return
	var next_player: AudioStreamPlayer = null
	for track_player: AudioStreamPlayer in _bgm_tracks:
		if _bgm_tracks[track_player] == music and track_player.playing:
			next_player = track_player
			break
	if next_player == null:
		next_player = AudioStreamPlayer.new()
		next_player.process_mode = Node.PROCESS_MODE_ALWAYS
		next_player.bus = ExportSettings.audio_music_bus
		next_player.volume_linear = 0.0
		next_player.stream = music
		add_child(next_player)
		_bgm_tracks[next_player] = music
	next_player.play()
	_bgm_player = next_player
	for track_player: AudioStreamPlayer in _bgm_tracks:
		var target_volume: float = db_to_linear(ExportSettings.audio_master_volume) if track_player == next_player else 0.0
		_fade_bgm(track_player, target_volume)

func _fade_bgm(player: AudioStreamPlayer, target_volume: float) -> void:
	if _bgm_tweens.has(player):
		var previous_tween: Tween = _bgm_tweens[player]
		previous_tween.kill()
	var tween: Tween = player.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_bgm_tweens[player] = tween
	tween.tween_property(player, "volume_linear", target_volume, BGM_CROSSFADE_DURATION)

## 创建一次性计时器。
## @param time 等待秒数
## @param callback 超时后触发的回调
## @return 创建的计时器，可用于提前停止
func setTime(time: float, callback: Callable) -> SceneTreeTimer:
	var temp := get_tree().create_timer(time)
	temp.timeout.connect(callback, CONNECT_ONE_SHOT)
	return temp

## setTime 的 snake_case 兼容别名。
## @param time 等待秒数
## @param callback 超时后触发的回调
## @return 创建的计时器
func set_time(time: float, callback: Callable) -> SceneTreeTimer:
	return setTime(time, callback)

## 连接 Area2D 的左键点击事件。
## @param area2d 目标 Area2D
## @param callback 点击时触发的回调
func Area2dConnectClick(area2d: Area2D, callback: Callable) -> void:
	area2d.input_event.connect(func(obj, event, id):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				callback.call()
	)

## 连接 Area2D 的左键松开事件。
## @param area2d 目标 Area2D
## @param callback 松开时触发的回调
func Area2dConnectRelease(area2d: Area2D, callback: Callable) -> void:
	area2d.input_event.connect(func(_viewport, event, _shape_idx):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				callback.call()
	)

## 修改节点的贴图。
## @param node 目标节点
## @param new_texture 新贴图
func SetNodeTexture(node: Node, new_texture: Texture2D) -> void:
	if node and "texture" in node:
		node.texture = new_texture

## 先快后慢的缓动补间。
## @param obj 目标对象
## @param prop 要变化的属性名
## @param value 目标值
## @param time 持续秒数
## @param callback 补间结束时触发的回调
## @return 补间对象引用
func TweenFastToSlow(obj, prop: String, value, time, callback = func(): pass):
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(obj, prop, value, time)
	tween.finished.connect(callback)
	return tween

## 先慢后快的缓动补间。
## @param obj 目标对象
## @param prop 要变化的属性名
## @param value 目标值
## @param time 持续秒数
## @param callback 补间结束时触发的回调
## @return 补间对象引用
func TweenSlowToFast(obj, prop: String, value, time, callback = func(): pass):
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(obj, prop, value, time)
	tween.finished.connect(callback)
	return tween

## 大数字简洁格式化。K 之前显示普通数字，之后按千进制缩写为 K、M、B、T。
## @param num 待格式化的数值
## @return 格式化后的字符串
func FormatNumber(num: float) -> String:
	var suffixes := ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp"]
	var value := num
	var divisor := 1_000.0
	if value < divisor:
		if value == floor(value):
			return str(int(value))
		return str(value)
	var idx := 0
	while value >= divisor * 1000.0 and idx < suffixes.size() - 1:
		divisor *= 1000.0
		idx += 1
	var result := value / divisor
	if result == floor(result):
		return "%d%s" % [int(result), suffixes[idx]]
	var s := "%.1f" % result
	if s.ends_with(".0"):
		s = s.left(s.length() - 2)
	return s + suffixes[idx]

## 播放音效辅助函数，自动挂接到对应总线并在播放完毕后释放。
## @param stream 要播放的音频资源
## @param bus_name 总线名称
## @param volume_db 音量分贝调节
## @param pitch 音调缩放
## @return 创建的 AudioStreamPlayer 实例；stream 为空时返回 null
func PlaySFX(stream: AudioStream, bus_name: StringName = &"SFX", volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	if not stream:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus_name
	player.volume_db = volume_db
	player.pitch_scale = pitch
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player

## 在 2D 世界坐标播放音效，播放完毕后自动释放。
## @param stream 要播放的音频资源
## @param global_pos 世界坐标
## @param bus_name 总线名称
## @param volume_db 音量分贝调节
## @param pitch 音调缩放
## @return 创建的 AudioStreamPlayer2D 实例；stream 为空时返回 null
func PlaySFX2D(stream: AudioStream, global_pos: Vector2, bus_name: StringName = &"SFX", volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer2D:
	if not stream:
		return null
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = bus_name
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.global_position = global_pos
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player

## 模拟死亡：切断目标节点的逻辑心跳、渲染与碰撞。
## @param target_node 目标节点
func FakeDeath(target_node: Node) -> void:
	if not is_instance_valid(target_node):
		return
	target_node.process_mode = Node.PROCESS_MODE_DISABLED
	if target_node is CanvasItem:
		target_node.visible = false
	if target_node is Control:
		target_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_all_collisions(target_node, false)

func _set_all_collisions(root_node: Node, enabled: bool) -> void:
	for child in root_node.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", !enabled)
		if child.get_child_count() > 0:
			_set_all_collisions(child, enabled)

## 恢复被 FakeDeath 处理的节点。
## @param target_node 目标节点
func Revive(target_node: Node) -> void:
	if not is_instance_valid(target_node):
		return
	if target_node is CanvasItem:
		target_node.visible = true
	if target_node is Control:
		target_node.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_all_collisions(target_node, true)
	target_node.process_mode = Node.PROCESS_MODE_INHERIT

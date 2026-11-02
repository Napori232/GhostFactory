extends Node

## 全局可调参数出口。所有实体的数值型参数导出到此处，便于在编辑器中统一调整。
## 新增参数时按功能分组（@export_group），并在属性说明里写清单位与取值含义。

@export_group("Audio", "audio_")
## 音频设置存档路径。
@export var audio_settings_path: String = "user://audio_settings.cfg"
## 主音量、音乐、音效、对白、环境音的初始线性比例。
@export_range(0.0, 1.0, 0.05) var audio_master_volume: float = 1.0
@export_range(0.0, 1.0, 0.05) var audio_music_volume: float = 1.0
@export_range(0.0, 1.0, 0.05) var audio_sfx_volume: float = 1.0
@export_range(0.0, 1.0, 0.05) var audio_dialogue_volume: float = 1.0
@export_range(0.0, 1.0, 0.05) var audio_ambience_volume: float = 1.0
## 对应的音频总线名称，需与 default_bus_layout.tres 中的总线一致。
@export var audio_master_bus: StringName = &"Master"
@export var audio_music_bus: StringName = &"Music"
@export var audio_sfx_bus: StringName = &"SFX"
@export var audio_dialogue_bus: StringName = &"Dialogue"
@export var audio_ambience_bus: StringName = &"Ambience"

@export_group("Debug", "debug_")
## 是否显示调试面板。
@export var debug_panel_enabled: bool = false

@export_group("Interaction Dot", "interaction_dot_")
## 是否显示可交互实体中心的提示圆点。
@export var interaction_dot_enabled: bool = true
## 圆点颜色与半径，单位为世界像素。
@export var interaction_dot_color: Color = Color(1.0, 0.96, 0.85, 0.65)
@export_range(1.0, 32.0, 0.5) var interaction_dot_radius: float = 15.0

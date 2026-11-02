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

@export_group("Save", "save_")
## 完整存档文件路径。
@export var save_game_path: String = "user://savegame.cfg"
## 存档版本号，读入时用于迁移。
@export var save_version: int = 1

@export_group("Level", "level_")
## 关卡数据资源目录，存放 Level%02d.tres。
@export var levels_directory: String = "res://Data/Levels"
## 关卡数据文件命名模板，%02d 为关卡编号。
@export var level_file_template: String = "Level%02d.tres"
## Demo 关卡总数。
@export_range(1, 20, 1) var level_count: int = 3
## 结算三轴的星级阈值，占位数值，玩法实装后按真实评分调整。
@export var star_threshold_efficiency: float = 1.0
@export var star_threshold_manual: float = 1.0
@export var star_threshold_space: float = 1.0
## 结算面板三轴的占位分数，玩法未实现时写死显示。
@export var placeholder_score_efficiency: int = 0
@export var placeholder_score_manual: int = 0
@export var placeholder_score_space: int = 0
## 关卡内模拟结算按钮是否显示，玩法未实现时用于验证结算流程。
@export var debug_level_simulate_enabled: bool = true

@export_group("Scene", "scene_")
## 主菜单场景路径。
@export var scene_menu: String = "res://Code/Entities/StartMenu/StartMenu.tscn"
## 关卡选择场景路径。
@export var scene_level_select: String = "res://Code/Entities/LevelSelect/LevelSelect.tscn"
## 关卡场景路径。
@export var scene_level: String = "res://Code/Entities/Level/Level.tscn"
## 设置场景路径。
@export var scene_settings: String = "res://Code/Entities/Setting/SettingPanel.tscn"

@export_group("Debug", "debug_")
## 是否显示调试面板。
@export var debug_panel_enabled: bool = false

@export_group("Interaction Dot", "interaction_dot_")
## 是否显示可交互实体中心的提示圆点。
@export var interaction_dot_enabled: bool = true
## 圆点颜色与半径，单位为世界像素。
@export var interaction_dot_color: Color = Color(1.0, 0.96, 0.85, 0.65)
@export_range(1.0, 32.0, 0.5) var interaction_dot_radius: float = 15.0

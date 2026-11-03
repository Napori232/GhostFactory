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

@export_group("Simulation", "sim_")
## 逻辑 tick 频率（Hz）。
@export var sim_tick_rate: float = 20.0
## 物品步进间隔（秒）。
@export var sim_item_step_interval: float = 0.3
## 每段线的容量。
@export var sim_line_capacity: int = 3
## 同格堆叠压缩阈值。
@export var sim_stack_threshold: int = 5
## 推挤链上每只不倒翁鬼的单次产鬼能。
@export var sim_tumbler_spirit: int = 3
## 加工鬼吞吐速率减半（共鸣代价）。
@export var sim_processing_rate_halved: float = 0.5
## 镜鬼复制品产出比例。
@export var sim_mirror_output_scale: float = 0.5
## 镜鬼复制品寿命（秒）。
@export var sim_mirror_lifetime: float = 8.0
## 收容鬼处理一个垃圾的耗时（秒）。
@export var sim_contain_interval: float = 2.0
## 收容鬼每吃一个垃圾返还的鬼能。
@export var sim_contain_refund: int = 1
## 长舌鬼舌头节拍：伸出。
@export var sim_tongue_extend: float = 0.4
## 长舌鬼舌头节拍：停留。
@export var sim_tongue_hold: float = 0.3
## 长舌鬼舌头节拍：收回。
@export var sim_tongue_retract: float = 0.4
## 长舌鬼舌头节拍：间歇。
@export var sim_tongue_rest: float = 0.9
## 采集区掉落速率的面积指数，边际递减。
@export var sim_area_exponent: float = 0.5

@export_group("UI", "ui_")
## 背景图资源路径，留空表示等待美术出图。
@export var ui_background_art: String = ""
## 主视觉图资源路径，留空表示等待美术出图。
@export var ui_key_art: String = ""
## 主视觉占位组件的说明文字。
@export var ui_key_art_label: String = "主视觉 · 工厂剖面图"
## 背景占位组件的说明文字。
@export var ui_background_label: String = "背景图 · 废弃工厂"
## 背景光斑强度 0~1。
@export_range(0.0, 1.0, 0.05) var ui_glow_intensity: float = 0.35
## 按钮弹跳缩放的目标值。
@export var ui_pop_scale: float = 1.06
## 飘字上升距离（像素）。
@export var ui_feedback_rise: float = 48.0
## 飘字存活时长（秒）。
@export var ui_feedback_duration: float = 0.9

@export_group("Tutorial", "tutorial_")
## 教程步骤数据路径。
@export var tutorial_steps_path: String = "res://Data/Tutorial/tutorial_steps.tres"
## 是否在第 1 关自动触发教程。
@export var tutorial_enabled: bool = true
## 教程遮罩的不透明度。
@export_range(0.0, 1.0, 0.05) var tutorial_mask_alpha: float = 0.72
## 教程气泡与目标的间距（像素）。
@export var tutorial_bubble_gap: float = 18.0
## 高亮呼吸的缩放幅度。
@export var tutorial_highlight_pulse: float = 0.04

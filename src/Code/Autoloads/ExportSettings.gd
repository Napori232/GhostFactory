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
## Demo 关卡总数。
@export_range(1, 20, 1) var level_count: int = 4
## 结算三轴的星级阈值，占位数值，玩法实装后按真实评分调整。
@export var star_threshold_efficiency: float = 1.0
@export var star_threshold_manual: float = 1.0
@export var star_threshold_space: float = 1.0
## 关卡内模拟结算按钮是否显示，玩法未实现时用于验证结算流程。
@export var debug_level_simulate_enabled: bool = true

@export_group("Scene", "scene_")
## 主菜单场景路径。
@export var scene_menu: String = "res://Code/Entities/StartMenu/StartMenu.tscn"
## 关卡选择场景路径。
@export var scene_level_select: String = "res://Code/Entities/LevelSelect/LevelSelect.tscn"
## 关卡场景路径。关卡玩法层待重建，重建后此路径生效。
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
## 格子边长（像素）。
@export var sim_cell_size: int = 64
## 鬼移动一格所需时间（秒）。
@export_range(0.05, 2.0, 0.05) var sim_ghost_move_interval: float = 0.3
## 采集鬼搜索一步所需时间（秒）。
@export_range(0.05, 2.0, 0.05) var sim_search_step_interval: float = 0.1
## 采集鬼拾取一件掉落物所需时间（秒）。
@export_range(0.05, 5.0, 0.05) var sim_pickup_interval: float = 0.5
## 生产鬼生产周期（秒）。
@export_range(0.1, 10.0, 0.1) var sim_producer_cycle: float = 2.0
## 生产鬼单次产量。
@export_range(1, 10, 1) var sim_producer_output: int = 1
## 生产鬼输出缓冲容量。
@export_range(0, 20, 1) var sim_producer_buffer: int = 3
## 采集鬼输出缓冲容量。
@export_range(0, 20, 1) var sim_collector_buffer: int = 3
## 运输鬼输入缓冲容量。
@export_range(0, 20, 1) var sim_transporter_input_buffer: int = 1
## 运输鬼输出缓冲容量。
@export_range(0, 20, 1) var sim_transporter_output_buffer: int = 1
## 处理鬼输入缓冲容量。
@export_range(0, 20, 1) var sim_processor_input_buffer: int = 2
## 处理鬼输出缓冲容量。
@export_range(0, 20, 1) var sim_processor_output_buffer: int = 2
## 处理鬼损耗率，差额部分转为杂质。
@export_range(0.0, 1.0, 0.05) var sim_processor_impurity_rate: float = 0.25
## 处理鬼再处理（杂质回收）耗时（秒）。
@export_range(0.1, 10.0, 0.1) var sim_processor_recycle_interval: float = 1.6
## 缺料等待多久判定为故障（秒）。
@export_range(1.0, 60.0, 1.0) var sim_fault_timeout: float = 5.0

@export_group("Build", "build_")
## 每关开局赠送的初始鬼能。够玩家盖出第一条产线且有余量。
@export var build_start_spirit: int = 30
## 拆除鬼时是否全额退还鬼能。
@export var build_refund_on_remove: bool = true

@export_group("Simulation Ext", "sim_")
## 采集鬼拾取一件掉落物的基础耗时，单位：秒；搜索区超软上限会按比例变慢。
@export_range(0.05, 5.0, 0.05) var sim_collector_interval: float = 0.5
## 处理鬼单次加工耗时，单位：秒。
@export_range(0.1, 10.0, 0.1) var sim_processor_cycle: float = 1.2
## 运输鬼搬运一格的基础耗时，单位：秒。
@export_range(0.05, 2.0, 0.05) var sim_transporter_interval: float = 0.3

## 推舌鬼出舌周期：每 2.0 s 尝试把前方一格推开（Docs/Ghosts.md 推舌鬼）。
@export_range(0.2, 20.0, 0.1) var sim_pusher_cycle: float = 2.0
## 采集搜索区软上限，单位：格；每超 1 格拾取步进 +10%（GameDesign §13）。
@export_range(1, 100, 1) var sim_search_soft_cap: int = 9

@export_group("View3D", "view_")
## 正交相机俯仰角，单位：度；固定 -45，不参与玩法判定。
@export var view_pitch_degrees: float = -45.0
## 三档缩放的正交视野高度，单位：格。
@export var view_zoom_sizes: Array[float] = [8.0, 12.0, 16.0]
## 相机旋转补间时长，单位：秒。
@export_range(0.0, 2.0, 0.05) var view_rotate_duration: float = 0.2
## 相机缩放补间时长，单位：秒。
@export_range(0.0, 2.0, 0.05) var view_zoom_duration: float = 0.15
## 相机平移补间时长，单位：秒。
@export_range(0.0, 2.0, 0.05) var view_pan_duration: float = 0.1
## 鬼与障碍墙的模型高度上限，单位：格；防止斜俯视下遮死地面。
@export_range(0.2, 3.0, 0.1) var view_model_height_max: float = 1.0
## X-Ray 开启时鬼模型的透明度，0~1。
@export_range(0.05, 1.0, 0.05) var view_xray_alpha: float = 0.35

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
## 呼吸缩放的相对幅度，0.03 表示上下浮动 3%。
@export_range(0.0, 0.2, 0.005) var ui_breathe_amplitude: float = 0.03
## 呼吸缩放的单次周期（秒）。
@export_range(0.4, 10.0, 0.1) var ui_breathe_period: float = 2.4
## 左右摇摆的角度幅度（度）。
@export_range(0.0, 20.0, 0.5) var ui_sway_angle_deg: float = 3.0
## 左右摇摆的单次周期（秒）。
@export_range(0.4, 10.0, 0.1) var ui_sway_period: float = 3.2
## 悬停时放大到的倍数。
@export_range(1.0, 1.5, 0.01) var ui_hover_scale: float = 1.05
## 按下时缩小到的倍数。
@export_range(0.5, 1.0, 0.01) var ui_press_scale: float = 0.96
## 悬停与按下反馈的过渡时长（秒）。
@export_range(0.04, 0.6, 0.02) var ui_hover_duration: float = 0.16
## 列表项依次入场的间隔（秒）。
@export_range(0.0, 0.5, 0.01) var ui_stagger_interval: float = 0.06
## 装饰元素上下浮动的距离（像素）。
@export_range(0.0, 30.0, 0.5) var ui_float_distance: float = 6.0

@export_group("Tutorial", "tutorial_")
## 教程步骤数据路径。教程层待重建，重建后此路径生效。
@export var tutorial_steps_path: String = "res://Data/Tutorial/tutorial_steps.tres"
## 是否在第 1 关自动触发教程。
@export var tutorial_enabled: bool = true
## 教程遮罩的不透明度。
@export_range(0.0, 1.0, 0.05) var tutorial_mask_alpha: float = 0.72
## 教程气泡与目标的间距（像素）。
@export var tutorial_bubble_gap: float = 18.0
## 高亮呼吸的缩放幅度。
@export var tutorial_highlight_pulse: float = 0.04

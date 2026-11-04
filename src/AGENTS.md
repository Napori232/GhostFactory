# 代码组开发规范

本文件适用于仓库内的 Godot 项目 `src/`。下文的 `res://` 指 `src/`，因此 `res://Code/` 对应 `src/Code/`。
ai在分析代码之前，先看看代码索引，按需了解代码的组织结构和文件关系。

## 一、权限边界与文件操作

- 开发者和 AI 编码助手仅可修改 `res://Code/` 下的代码与场景文件。维护本文件及仓库级 AI 指令文件是此规则的明确例外；其他例外须由任务明确授权。
- `res://Code/` 外的文件（包括美术、音频和第三方插件）只可查看和引用，不得修改原始内容。程序不得引用 `res://Assets/WIP/` 中的内容；若实际素材目录名称不同，也不得引用对应的 WIP 美术目录。
- 未经明确授权，不得修改 `project.godot`、`.godot/` 缓存及全局物理、渲染等底层配置。
- 提交 `.tscn` 或 `.gd` 前，核对外部依赖、资源路径与导入状态，避免缺失依赖或断链。

## 二、架构与目录

`res://Code/` 按树状实体自治组织：

```text
Code/
├── Autoloads/          # 全局单例、常量、信号总线和数据
├── Common/             # 可复用类、基类和组件
└── Entities/           # 业务场景与功能模块
    └── Player/         # 每个实体或功能独立成目录
        ├── Player.tscn
        ├── Player.gd
        └── PlayerState.gd
```

- `Entities/` 自顶向下嵌套；每个实体或功能拥有独立目录，并尽量在各自目录内开发。目录使用 PascalCase。
- 开发组件或功能前，先检索 `Autoloads/` 和 `Common/` 中已有的常量、数据、工具和组件，优先复用。
- 原则上不删除或破坏 `Autoloads/`、`Common/` 的既有接口。需要通用能力时以兼容的增量扩展为主，并检查现有调用方。

## 三、GDScript 命名与文档

- 可供脚本外部调用的公共方法使用 PascalCase，如 `ApplyDamage`；每个公共方法上方须有 `##` 文档注释，说明用途、参数含义与传参规范，有返回值时说明返回值。
- 仅供脚本内部调用的方法使用下划线加 snake_case，如 `_update_internal_state`。Godot 引擎回调（如 `_ready`、`_process`）遵循引擎名称。
- 常量使用全大写下划线，如 `MAX_SPEED`；定义前先检查 `Autoloads/` 中是否已有相同含义的常量或数据字典。
- `Autoloads/SignalBus.gd` 中的全局信号使用 PascalCase。每个信号上方须有 `##` 文档注释，说明触发时机和各参数含义。

## 四、实体生命周期与存档

- 需要持久化状态的 Entity 提供 `ExportSaveData() -> Dictionary` 和 `LoadSaveData(data: Dictionary) -> void`，并按公共方法规则写 `##` 文档注释。
- `_init()` 必须能无参安全调用，或为所有外部参数提供安全默认值；不得强制依赖非空外部上下文。
- 外部依赖和节点引用在 `@onready`、`_ready()` 或 `LoadSaveData()` 中建立，确保实体可安全实例化与还原。加载数据时注意节点就绪时机。

## 五、场景、UI 与输入

- 尽量在 `.tscn` 场景树中预置节点，并通过 `@onready` 引用；不要在脚本中用大量 `new()` 动态构造复杂节点树。
- 鼠标点击区域使用无纹理 `TextureButton` 或透明遮罩 `Button`。Sprite2D 的悬停或进入检测使用其下的 `Area2D`，并正确配置 `CollisionShape2D`。
- Control UI 配置锚点预设与容器布局，验证不同窗口分辨率；避免任意绝对像素定位。

## 六、类别
- 在 `Common/`中声明通用类别的时候,用class_name关键词命名

## 七、场景入口
- `res://Code/Entities/StartMenu/StartMenu.tscn` 是启动主场景；替换主场景时须同步修改 `project.godot` 的 `run/main_scene`。

## 八、参数
- 实体参数都要导出到ExportSettings.gd中,方便我修改调整

## 九、通信
- 实体之间的通信要使用信号总线(signalbus),来达到解耦的目的,实体状态变化的时候,都最好通过信号总线发送信号来通知其他实体,而不是直接调用其他实体的方法.

- Godot 可执行文件路径：`D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`

## 十、代码索引（AI 按需阅读入口）

### 10.1 阅读方法与维护规则

- 本章是 AI 阅读代码的入口索引。分析任何需求前，先在本章检索相关条目，再按需打开对应文件。
- 新增或移动文件后，必须同步更新本章索引；索引条目须包含文件路径与一句职责说明。
- 索引只描述「文件是什么、在哪」，不写实现细节；实现细节留在代码注释里。

### 10.2 启动、全局基础与参数

| 文件 | 职责 |
| --- | --- |
| `Code/Autoloads/GlobalValue.gd` | 全局常量（重力）、应用暂停/失焦同步与待进入关卡记录 |
| `Code/Autoloads/SignalBus.gd` | 全局信号总线，实体间解耦通信的唯一入口 |
| `Code/Autoloads/Util.gd` | 通用工具：定时器、补间、音效播放、格式化等 |
| `Code/Autoloads/ExportSettings.gd` | 全局可调参数出口，实体数值一律在此导出 |
| `Code/Autoloads/ExportSettings.tscn` | 参数单例的实例化场景，作为 autoload 挂载 |
| `Code/Autoloads/SaveManager.gd` | 存档单例：进度、解锁、设置的持久化与读写 |

### 10.3 通用组件与基类

| 文件 | 职责 |
| --- | --- |
| `Code/Common/State.gd` | 状态基类：进入/退出/更新生命周期与迁移信号 |
| `Code/Common/StateMachine.gd` | 状态机：状态注册、切换与分发 |
| `Code/Common/GameInputControl.gd` | 输入控制组件基类 |
| `Code/Common/InteractionDot.gd` | 实体交互提示圆点组件 |
| `Code/Common/TouchActionButton.gd` | 移动端虚拟触控动作按钮 |
| `Code/Common/SceneRouter.gd` | 场景路由：跨场景跳转的唯一入口 |
| `Code/Common/StarRating.gd` | 结算星级计算（当前为占位阈值） |
| `Code/Common/GhostTag.gd` | 端口标签词表：SPIRIT / OFFER / IMPURITY 物料标签与 HAUL / GROUND 动作标签；连线合法性校验 |
| `Code/Common/FormData.gd` | 形态数据：鬼能 / 贡品 / 杂质 |
| `Code/Common/RecipeData.gd` | 配方数据：形态转换关系、产出率与加工耗时 |
| `Code/Common/GridUtil.gd` | 网格几何工具：格子换算、路径生成、占位重叠检测 |
| `Code/Common/UIPalette.gd` | UI 23 色板与全局主题生成：深靛蓝底、玻璃面板、霓虹描边、暖橙点缀 |
| `Code/Common/UIEffects.gd` | UI 动效库：缩放弹跳、淡入淡出、粒子迸发、数字滚动、呼吸、左右摇摆、悬浮、辉光脉冲、悬停与按下反馈 |
| `Code/Common/ResourceUtil.gd` | 资源属性读取工具：统一处理 Object.get 与 Dictionary.get 的差异 |
| `Code/UI/BackgroundLayer.gd` | 背景层：竖向渐变底、蓝图网格、漂移呼吸光斑与暗角 |
| `Code/UI/BackgroundLayer.tscn` | 背景层场景，供主菜单、关卡选择与关卡场景复用 |
| `Code/UI/ArtPlaceholder.gd` | 美术占位框：资源未就位时显示虚线框与标签 |
| `Code/UI/UIFeedback.gd` | 界面反馈：飘字与提示条 |

### 10.4 业务实体

| 文件 | 职责 |
| --- | --- |
| `Code/Entities/StartMenu/StartMenu.tscn` | 启动主场景 |
| `Code/Entities/StartMenu/StartMenu.gd` | 主菜单逻辑与新游戏入口 |
| `Code/Entities/LevelSelect/LevelSelect.tscn` | 关卡选择界面：关卡卡片、解锁态与最佳星级 |
| `Code/Entities/LevelSelect/LevelSelect.gd` | 关卡列表构建与解锁状态刷新 |
| `Code/Entities/Setting/SettingPanel.tscn` | 设置面板：音量、开关、画质与重置进度 |
| `Code/Entities/Setting/SettingPanel.gd` | 设置项读写、音量实时应用与二次确认流程 |
| `Code/Tests/SaveManagerRoundTrip.tscn` | 存档与形态/配方资源的 headless 往返测试 |
| `Code/Tests/UiFlowTest.tscn` | UI 流程的 headless 测试 |

> **待重建**（v10 玩法层）：`Entities/Board/`（网格、鬼组件、掉落物、线路、运行时）、`Entities/Level/`（关卡流程、目标、计时、结算）、`Entities/Tutorial/`（新手教程与聚光灯）、`Common/GhostData.gd`、`Common/LevelData.gd`。

### 10.5 资源目录约定

| 目录 | 内容 |
| --- | --- |
| `res://Art/` | 美术资源；`New/` 当前使用，`Archived/` 历史归档，`AI/` AI 生成素材 |
| `res://Music/` | 音频资源；`bgm/` 背景音乐，`SFX/` 音效 |
| `res://CopyWriting/` | 剧情与文案文本 |
| `res://Data/` | 表格与配置数据 |
| `res://Docs/GameDesign.md` | 策划案 v10：鬼的种类/触发/可动性、鬼能经济、采集、空间、关卡、存档与系统数值的事实来源 |
| `res://Docs/Ghosts.md` | 鬼总表：每只鬼的种类、触发方式、端口、几何占位、数值、故障条件与涌现案例 |
| `res://Docs/LevelDesign.md` | Demo 三关设计：地图、预置设施、目标、吞吐与空间核对 |
| `res://Docs/PhysicsLayer.md` | 物理层说明：涌现模型、端口标签职责、意图与结算、代码目标形态与迁移顺序 |
| `res://../tools/` | 仓库级离线工具（切图打包、图块归一化等），不参与运行时 |
| `res://addons/` | 第三方插件：Godot AI（MCP）、Phantom Camera；不得修改其内容 |

### 10.6 跨模块主链与修改前检查

- 修改 `Autoloads/`、`Common/` 的公共接口前，先检索 `Entities/` 下的调用方，确认改动向后兼容。
- 新增实体时：目录放在 `Entities/` 下，脚本以 `class_name` 或场景内挂载方式接入，跨实体通信走 `SignalBus`。
- 提交前自检：`.tscn` 依赖的资源是否存在、`res://` 路径大小写是否正确、导出参数是否落在 `ExportSettings.gd`。

# 鬼工厂 · 完整实现计划书（交由 AI Agent 执行，含 3D）

> 面向执行者：另一个 AI agent 或开发者。**目标是：拿着这个仓库 + 这份文档，能直接搓出能交差的可玩游戏。**
> 本文件是**可执行规格**，不是设想。每条规则都有出处（`res://Docs/` 原文），每个数字都可核对。
> 事实来源优先级：`res://Docs/GameDesign.md` > `Ghosts.md` > `LevelDesign.md` > `PhysicsLayer.md` > 本文件。
> **本文件与 Docs 冲突时，以 Docs 为准，并回报差异，不要自行改写 Docs。**

---

## 0. 执行摘要

Demo 目标 = 一个**能在课堂上打开就玩**的 3D 版本《鬼工厂》。范围锁定在《第 8 周开发文档》「下周计划」的第 1、2 项，但**包含 3D 表现层**（斜俯视八向旋转相机 + 网格地台 + 3D 拾取），因为课程演示要看的就是这个效果。

交付物 = 三个可通关的关卡 + 一个 3D 关卡场景：

1. **玩法层**：机关基类 + 输入/输出端口 + 物理行为 —— 关卡 1 的「生产 → 交付」单链真的能跑通。
2. **数据层**：`LevelData` 与三关 `.tres`，关卡 1/2/3 各自可通关。
3. **表现层**：斜俯视 3D 场景，正交相机俯仰 45°、八向 45° 吸附旋转、三档缩放、地台格线、可放置区高亮、3D 拾取与 X-Ray 透视。

**明确排除**（避免 agent 摊大饼）：推动链涌现案例（守财/吊死/推舌/贪食鬼）、教程聚光灯、存档 UI 重做、正式美术资源（用几何体占位即可）。

**关键工程前提（务必先理解，否则会走弯路）**：
- `src/` 当前是**纯 2D 工程**（`Code/` 与所有 `.tscn` 里 `Node3D`/`Camera3D`/`MeshInstance3D`/`CharacterBody3D` **零命中**），`GridUtil` 用 2D `Vector2` + `CELL_SIZE=64` 做像素换算。
- 因此本次**新增 3D 子系统**，而不是「改造已有的 3D」。3D 是**表现层**：逻辑世界仍是**单层平面网格**（`GameDesign.md` §5.7）。
- **规则层必须与表现层解耦**：所有判定（占格、寻路、掉落、评分）只认 `Vector2i` 格坐标；3D 场景只负责「把格坐标画出来 + 把鼠标点转回格坐标」。这样 3D 出问题不会污染玩法判定。

---

## 1.0 开工指引（拿到仓库后第一件事照这个做）

> 如果你（执行 agent）只有十分钟，读完这一节就能开始写代码。

### 第一步：确认环境（5 分钟）

```bash
cd /d/GhostFactory/src
GODOT="/d/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
timeout 120 "$GODOT" --headless --path . --quit-after 60
```
看到正常退出（无报错）即可继续。

### 第二步：跑通现有测试，拿到基线（5 分钟）

```bash
for t in SaveManagerRoundTrip UiFlowTest UiPolishTest; do
  echo "=== $t ==="
  timeout 120 "$GODOT" --headless --path . "res://Code/Tests/$t.tscn" --quit-after 300
done
```
**这 3 个必须全绿**。它们是你改动后的守门员，任何时候跑挂了说明你改坏了东西。

### 第三步：按阶段推进，每个阶段一个提交

| 阶段 | 大概产出 | 提交前必须过 |
| --- | --- | --- |
| 0 | 目录骨架 | 冒烟 + 3 测试全绿 |
| 1 | `GhostData` / `BoardPortDef` / `LevelData` + 4 鬼 + 3 关 `.tres` | 新增 `LevelDataLoadTest` + 3 测试全绿 |
| 2 | 棋盘、放置、掉落物 | 新增 `BoardPlacementTest` + 3 测试全绿 |
| 3 | **生产鬼行为 + 关卡 1 可通关** | 新增 `Level01PlaythroughTest` / `ManualCountTest` / `FaultTest` + 3 测试全绿 |
| 4 | 采集/运输/处理 + 关卡 2、3 | 新增 `Level02PlaythroughTest` / `Level03PlaythroughTest` / `ConnectionRuleTest` + 3 测试全绿 |
| 5 | **3D 表现层** | 新增 `Level3DSceneTest` + 3 测试全绿 + 手动验收 6 条 |
| 6 | 收尾（索引、说明、复核） | 全部测试全绿 |

### 第四步：卡住了怎么办

| 症状 | 处理 |
| --- | --- |
| 不知道某个规则 | 回到 `res://Docs/` 找原文，**不要自己发明规则**；找不到就在提交说明里列为「待少主裁决」 |
| 想用旧原型 | `git show 80787b2:src/Code/Entities/Board/GhostComponent.gd` **只看**，不恢复 |
| 测试挂了自己没改坏 | 先 `git stash` 验证基线，再逐条恢复 |
| 需要改 `project.godot` / `Docs/` | **停下来，在提交说明里写清要改什么、为什么，等少主授权**。可用绕开方案优先（如 §5.9.8 用 `_unhandled_input` 读 keycode 绕开 `[input]` 段） |
| 3D 效果不对 | 检查 §5.9.1 坐标约定（y 取负）、§5.9.3 相机参数（ORTHOGONAL / -45°） |

### 第五步：完成的定义

**能交差 = 下面全部成立**：

- [ ] 关卡 1 能在 3D 场景里从头玩到通关（放鬼 → 等掉落 → 拾取 → 交付 → 结算出星级）
- [ ] 关卡 2、关卡 3 各自可通关（脚本化测试证明）
- [ ] 3D 效果成立：斜俯视 45°、Q/E 八向旋转吸附、三档缩放、格线地台、可建区高亮、点得中鬼、遮挡与 X-Ray
- [ ] 3 个原有测试 + 全部新增测试全绿
- [ ] `AGENTS.md` §10 索引已更新
- [ ] 提交信息中文，说明含：改了哪些文件、5 处设计定稿、**D4 关卡 2 目标形态待少主裁决**

---

## 1. 开工前必读（15 分钟）

按顺序读完这 4 份，**不要跳过**——本计划书的每条实现规则都出自其中：

| 顺序 | 文件 | 读什么 | 行数 |
| --- | --- | --- | --- |
| 1 | `res://Docs/GameDesign.md` | §4.1 四大类定义、§4.2 基础鬼行为、§5 空间规则、§7 评分三轴、§8 物理层、§13 系统数值 | 677 |
| 2 | `res://Docs/Ghosts.md` | 鬼总表（当前只列规划中鬼，基础四类在 GameDesign §4.2） | 24 |
| 3 | `res://Docs/LevelDesign.md` | 关卡 1/2/3 地图、预置设施、目标、吞吐与空间核对 | 296 |
| 4 | `res://Docs/PhysicsLayer.md` | §2 端口标签职责、§3 意图与结算、§4 代码目标形态、§6 迁移顺序 | 301 |

再读 `res://AGENTS.md`（141 行，硬性规约，违反会被 review 打回）。

### 1.1 环境事实（已核实，照抄即可）

- Godot 可执行：`D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- 项目根：`D:\GhostFactory\src`（`res://` 即此目录）
- 主场景：`res://Code/Entities/StartMenu/StartMenu.tscn`
- 已存在的 autoload：`Util`、`SignalBus`、`GlobalValue`、`ExportSettings`、`SaveManager`（另有 `PhantomCameraManager`、`_mcp_game_helper`）
- 渲染：`gl_compatibility`，窗口 `mode=3`（最大化）
- 现有 headless 测试（**当前全绿**，改动后必须仍然全绿）：
  - `Code/Tests/SaveManagerRoundTrip.tscn`
  - `Code/Tests/UiFlowTest.tscn`
  - `Code/Tests/UiPolishTest.tscn`
- 头less 运行命令模板（**Windows + bash**，用 MSYS 路径前缀）：

```bash
cd /d/GhostFactory/src
GODOT="/d/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
timeout 120 "$GODOT" --headless --path . --quit-after 60            # 启动冒烟
timeout 120 "$GODOT" --headless --path . res://Code/Tests/UiFlowTest.tscn --quit-after 300
```

> `--quit-after N` 的 N 是**帧数**不是秒（60 ≈ 1 秒）。

### 1.2 现成资产（**先复用，不要重写**）

| 资产 | 位置 | 能干什么 |
| --- | --- | --- |
| `GridUtil` | `Code/Common/GridUtil.gd` | `CellToWorld` / `WorldToCell` / `Neighbors4` / `Manhattan` / `NormalizeFootprint` / `FootprintBounds` / `Translate` / `Overlap` / `PathL` / `ToCellArray` / `InBounds`。**占位重叠检测与寻路已有实现，直接用。** |
| `GhostTag` | `Code/Common/GhostTag.gd` | 物料标签 `SPIRIT`/`OFFER`/`IMPURITY`；动作标签 `HAUL`/`GROUND`；`CanConnect(output_tags, input_tags) -> bool`（**只认物料标签**，动作标签不参与连线判定） |
| `FormData` | `Code/Common/FormData.gd` | 形态资源基类：`id` / `display_name` / `letter` / `color` / `deliverable` |
| `RecipeData` | `Code/Common/RecipeData.gd` | 配方资源基类：`id` / `from_form` / `to_form` / `yield_rate` / `cycle_time` |
| `StarRating` | `Code/Common/StarRating.gd` | `CalculateStars(efficiency, manual, space) -> int`；`ToText(stars) -> String` |
| `SignalBus` | `Code/Autoloads/SignalBus.gd` | 已含 `GhostPlaced` / `GhostRemoved` / `GhostStateChanged` / `GhostFaulted` / `SpiritProduced` / `SpiritDropped` / `SpiritPicked` / `OfferScored(delivered, goal)` / `ItemDelivered(form, terminal)` / `BufferStateChanged` / `LineCreated` / `LineBlocked` / `LevelTimerTick` / `LevelStarted` / `LevelCompleted` / `LevelFailed` —— **本次几乎不需要新增信号，先查这张表** |
| `ExportSettings` | `Code/Autoloads/ExportSettings.gd` | 80 个 `@export` 参数，分组 `Audio` / `Save` / `Level` / `Scene` / `Debug` / `Interaction Dot`。**新增数值参数一律加在这里**（AGENTS.md §八） |
| 形态资源 | `res://Data/Forms/` | `Spirit.tres`、`Offer.tres`、`Impurity.tres`（`FormData` 实例） |
| 配方资源 | `res://Data/Recipes/` | `SpiritToOffer.tres` 等（`RecipeData` 实例） |

### 1.3 旧原型可考古，但**不要直接搬**

Git 提交 `80787b2`（旧 v10 玩法层原型）含 `GhostData.gd`、`LevelData.gd`、`Entities/Board/` 下 Board / Ghost / DroppedItem / Connection / Port / Field / LineGhost / Obstacle / Terminal 等组件。

**允许**：用 `git show 80787b2:src/Code/Common/GhostData.gd` 查字段命名习惯与序列化方式，抄思路。
**禁止**：`git checkout 80787b2 -- ...` 整体恢复。旧逻辑基于已废弃的策划版本，直接搬会与当前 Docs 冲突，且会覆盖工作区未提交的文档改动。

---

## 2. 硬性规约（AGENTS.md，不可违反）

1. **只能改 `res://Code/` 下的 `.gd` / `.tscn`。** `res://Data/`、`res://Docs/`、`res://project.godot`、`res://addons/`、`res://Art/` 一律只读。改 `project.godot` 需明确授权。
2. 公共方法 **PascalCase**（`ApplyDamage`），且**每个公共方法上方必须有 `##` 文档注释**（用途、参数含义、传参规范、有返回值则说明返回值）。内部方法 `_snake_case`。常量 `ALL_CAPS`。
3. `Common/` 下的通用类用 `class_name` 声明（AGENTS.md §六）。类名 = 文件名。
4. **实体参数全部导出到 `ExportSettings.gd`**（AGENTS.md §八），并用 `@export_group` 分组，属性说明写清单位与取值含义。
5. **跨实体通信走 `SignalBus`**，不要直接调用别的实体的方法（AGENTS.md §九）。
6. **尽量在 `.tscn` 里预置节点 + `@onready` 引用**，不要在脚本里 `new()` 造复杂节点树（AGENTS.md §五）。
7. 目录 PascalCase；`Entities/` 下每个实体独立目录。
8. 需要持久化的实体提供 `ExportSaveData() -> Dictionary` / `LoadSaveData(data: Dictionary) -> void`。
9. **每阶段提交前必须跑 headless 测试全绿**；提交信息用中文。
10. 新增/移动文件后**必须同步更新 `AGENTS.md` §10 代码索引**。
11. 注释与文档字符串一律中文。

---

## 3. 设计缺口：本计划已替你定死的 5 处

Docs 里有 5 处矛盾或缺口。**不要让执行 agent 自己猜**——下面已给出定稿，agent 按此实现即可，同时**把这 5 条作为「需少主确认」的 diff 回报**。

### D1. 端口标签口径统一（阻塞级）

- **矛盾**：`PhysicsLayer.md` §2.2 的例子用动作标签连线（`ACTION=HAUL` → `RECEPTACLE=HAUL`）；但 `GhostTag.CanConnect()` 实际实现**只认物料标签**，动作标签一律跳过。
- **定稿**：**连线合法性一律以物料标签为准**（`SPIRIT` / `OFFER` / `IMPURITY`）。`HAUL` / `GROUND` 保留为语义标记，**不参与连线判定**，仅用于 UI 提示与日志。
- **回报给少主的文档改动**：`PhysicsLayer.md` §2.2 的示例改为物料标签（例如「生产鬼输出 `SPIRIT` → 运输鬼输入接受 `SPIRIT`」）。

### D2. 采集鬼从地面取物的输出端口标签（阻塞级）

- **缺口**：`GameDesign.md` §4.2 写采集鬼「输入端口 0 / 输出端口 1」，但没说输出端口**携带什么物料标签**；而 `CanConnect` 靠标签判定，标签不定则采集鬼**永远连不上运输鬼**。
- **定稿**：采集鬼输出端口的物料标签 = **它当前缓冲里实际持有的物料标签集合**（空缓冲时为空集合，连线禁止）。连接判定时检查「运输鬼输入端口的物料集合 ∩ 采集鬼输出端口的物料集合 ≠ ∅」。
- 实现上：采集鬼的输出端口不写死标签，每帧根据缓冲内容计算；`GhostData` 里该端口的标签字段留空并注明「动态」。

### D3. 生产鬼「输出端口 0」与「输出区」的自相矛盾（阻塞级）

- **矛盾**：`GameDesign.md` §4.2 生产鬼一行写「输出端口 0」，但同节又写「四邻无空格则产出进入自己的输出区」，§5 也提到产出需要落点。
- **定稿**：生产鬼**没有连线输出端口**（0 个），产出走**掉落机制**：产物出现在生产鬼**四邻空格**中（掉落物实体）。「输出区」= 生产鬼自身缓冲（上限见 §13 数值表）。若四邻无可落空格且缓冲已满 → **故障**（进 `FAULT` 状态，触发 `GhostFaulted` 信号）。
- 因此：**关卡 1 的「生产 → 交付」单链不需要任何连线**——玩家放置生产鬼，等掉落物出现在四邻空格，手动拾取后走到交付口交付。这与 `LevelDesign.md` 关卡 1 的「玩家要做的事」完全一致（该关只有生产鬼 + 交付口，无运输鬼）。

### D4. 关卡 2 目标不可达（阻塞级，需要少主拍板）

- **矛盾**：`LevelDesign.md` 关卡 2 写「可用鬼：生产鬼 / 采集鬼 / 运输鬼」，目标形态是**贡品（Offer）**，交付口 `accepted_form=Offer`；但 `Offer` 只能由**处理鬼**经 `SpiritToOffer` 配方产出，而关卡 2 的可用鬼里**没有处理鬼**。该关按现配置**无解**。
- **定稿（本次实现按此做）**：**关卡 2 的目标形态改为 `Spirit`（鬼能）**，交付口 `accepted_form` 同步改为 `Spirit`，目标数从 72 改为 **72 个鬼能**（数量不变，仅形态修正）。
  - 理由：关卡 2 的教学目标是「采集与运输」（关卡 3 才引入加工），鬼能形态不需要处理鬼即可产出，配置自洽。
  - 吞吐核对随之修正：`LevelDesign.md` 关卡 2 的吞吐核对写的是「采集 1.05/s → 120 s × 1.05 ≈ 126 个，目标 72 ≈ 69 s」——这组数字本来就按**鬼能**算的（不是贡品），改形态后**原数字全部仍然成立**，无需重算。**这是支持本次修正的最强证据。**
- **回报给少主**：这是**策划语义改动**（关卡 2 从「交付贡品」变成「交付鬼能」），少主可能有别的意图（例如把关卡 2 目标留给关卡 3）。实现按上面定稿走，但在提交说明里显著标注此项，等少主裁决后可能需要回改。

### D5. 关卡 1 三星「零容错」与推动链量化规则（严重，需少主确认）

- **问题 A（关卡 1 三星阈值）**：`LevelDesign.md` 关卡 1 目标 30 个鬼能，2★ 要求 ≤ 60 s；玩家手动拾取 + 交付 30 次，若「拾取」与「交付」各算一次点击，则 ≥ 60 次点击，与时间阈值叠加后三星极易落空。
- **定稿**：**「点击次数」只统计交付动作**（每次向交付口交付 1 个计 1 次），不统计拾取、不统计移动、不统计放置。关卡 1 的手动次数阈值沿用文档既有值，交付次数上限 = **40 次**（30 次必需 + 10 次容错）。点击计数通过 `SignalBus.ItemDelivered` 累计。
- **问题 B（推动链量化）**：`Ghosts.md` 里守财鬼 / 吊死鬼 / 推舌鬼 / 贪食鬼全标「规划中」，只有一句行为描述，没有可编码的数值。
- **定稿**：**推动链整体推迟到本次范围之外**（§0 已明确排除）。但把可编码的量化规则先行写死，供后续直接实现，避免再次返工：

| 项 | 规则 |
| --- | --- |
| 触发 | 柔体被动鬼被推后**立即**触发自身反应（`Ghosts.md` §8.3：链上每被推动一次就发生一次该鬼自己的反应） |
| 推力方向 | 按**世界四邻**定义，与相机朝向无关（`GameDesign.md` §8.5） |
| 刚体 | 链上的**止点**：推力到刚体为止，刚体不动 |
| 链长 | 不是参数，是玩家摆出来的几何结果；接不上就断 |
| 位移粒度 | 位移仍以**一格**落地，动画负责把这一格铺顺（`GameDesign.md` §8.5） |
| 遮挡 | **不阻断联动**，被挡住的鬼照常参与结算（`GameDesign.md` §8.5） |
| 推舌鬼 | 每 **2.0 s** 舌头伸出抓住相邻格目标，缩回时把它**拉近并推出**（`Ghosts.md`） |
| 吊死鬼 | 被推动后自动**荡回**，把力传给下一格（`Ghosts.md`） |
| 守财鬼 | 被推动时**掉落鬼能**——永动机引擎核心件（`Ghosts.md`） |
| 贪食鬼 | 把相邻格掉落物**吸入自身输出缓冲**，只能吸四邻（`Ghosts.md`） |

---

## 4. 目标架构

```text
src/Code/
├── Common/                          # 通用类（class_name 声明）
│   ├── GhostData.gd          [新建] 鬼的数据定义（Resource）
│   ├── LevelData.gd          [新建] 关卡的数据定义（Resource）
│   ├── BoardPortDef.gd       [新建] 端口定义（Resource）
│   └── GridUtil.gd           [已有] 不改
├── Entities/
│   ├── Board/                 [新建目录] 棋盘运行时
│   │   ├── Board.tscn / .gd          棋盘根：网格、格子占用、拖放交互
│   │   ├── BoardGrid.gd              格子状态：占用、掉落物、设施
│   │   ├── GhostInstance.gd          单只鬼的运行时实例（贴 .tres）
│   │   ├── GhostBehavior.gd          鬼行为基类（虚拟方法）
│   │   ├── DroppedItem.gd            掉落物实体
│   │   ├── BoardRunner.gd            全局时序驱动（tick / 意图收集 / 结算）
│   │   └── ...                       按需再加
│   ├── Level/                  [新建目录] 关卡流程
│   │   ├── Level.tscn / .gd          关卡根：装配棋盘 + HUD + 结算
│   │   ├── LevelGoal.gd              目标判定（goal_form / 目标数 / 星级）
│   │   └── LevelHud.tscn / .gd       鬼能、进度、计时
│   └── ...
└── Data/                       [只读既有；新建资源目录]
    ├── Ghosts/                 [新建] 鬼的 .tres
    └── Levels/                 [新建] 关卡的 .tres
```

> ⚠️ `res://Data/` 在 AGENTS.md 的只读范围之外？**不是**——AGENTS.md §一写的是「`res://Code/` 外的文件只可查看和引用，不得修改原始内容」。**新建** `Data/Ghosts/` 与 `Data/Levels/` 属于新增而非修改既有内容，但如果 reviewer 认为超范围，可改为在 `res://Code/Entities/Board/` 下建 `Resources/` 目录存放 `.tres`。**默认按新建 `res://Data/Ghosts/` 与 `res://Data/Levels/` 执行，并在提交说明里点明这一判断。**

---

## 5. 数据模型（先做这层，它是后面所有代码的地基）

### 5.1 `GhostData`（`Code/Common/GhostData.gd`，Resource，`class_name GhostData`）

承载一只鬼的**静态配置**。字段取自 `GameDesign.md` §4.1/§4.2 与 `Ghosts.md` 鬼总表的列：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id: StringName` | 资源内唯一 id，如 `&"producer"` |
| `display_name: String` | 中文名 |
| `category: StringName` | 四大类之一：`PRODUCTION` / `COLLECTION` / `TRANSPORT` / `PROCESSING`（**仅分类与 UI 用，不参与判定**，`Ghosts.md` 明说「大类一列只给玩家和关卡设计读」） |
| `trigger_type: StringName` | `PASSIVE` / `AUTO` / `MANUAL` |
| `movability: StringName` | `RIGID` / `SOFT`（刚体 / 柔体） |
| `footprint: Array[Vector2i]` | 占位格集合，相对本体原点。`GridUtil.NormalizeFootprint` 可用来规整 |
| `ports: Array[BoardPortDef]` | 端口定义（见 5.2） |
| `cost: int` | 造价（鬼能） |
| `cycle_time: float` | 自动行为周期（秒）。生产鬼 = 2.0（§13） |
| `buffer_capacity: int` | 缓冲上限 |
| `search_area: Array[Vector2i]` | 搜索区（采集鬼用）；空 = 全图 |
| `is_manual: bool` | 是否需要手动操作（`Ghosts.md` 鬼总表的「手动」列） |
| `recipe_id: String` | 关联的配方资源 id（处理鬼用） |

**公共方法**（每个都要 `##` 注释）：

- `GetPortDef(port_id: StringName) -> BoardPortDef`
- `HasPortInDirection(dir: Vector2i) -> bool`
- `GetFootprintAt(origin: Vector2i) -> Array[Vector2i]`（= `GridUtil.Translate(footprint, origin)`）

### 5.2 `BoardPortDef`（`Code/Common/BoardPortDef.gd`，Resource，`class_name BoardPortDef`）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id: StringName` | 端口 id |
| `direction: Vector2i` | 端口朝向（`GridUtil.Neighbors4` 的方向之一） |
| `accepts: Array[StringName]` | **接受的物料标签**集合（`GhostTag.SPIRIT` / `OFFER` / `IMPURITY`）。判定用这个 |
| `produces: Array[StringName]` | **可送出的物料标签**集合。生产鬼 = 空；采集鬼 = 空 + 运行时动态计算（见 D2） |
| `buffer_size: int` | 该端口的线路缓冲上限 |

**关键**：连线判定用 `GhostTag.CanConnect(output.produces, input.accepts)`。**动作标签 `HAUL`/`GROUND` 不写进这两个字段**（会污染 `CanConnect` 的物料判定）。

### 5.3 `LevelData`（`Code/Common/LevelData.gd`，Resource，`class_name LevelData`）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id: int` | 关卡序号，从 1 开始 |
| `display_name: String` | 关卡名 |
| `grid_size: Vector2i` | 网格尺寸（关卡 1 = 10×8，见 `LevelDesign.md`） |
| `time_limit: float` | 时限秒（关卡 1 = 90） |
| `goal_form: String` | 目标物料 id（关卡 1 = `Spirit`，关卡 2 = `Spirit` 见 D4，关卡 3 = `Offer`） |
| `goal_amount: int` | 目标数量（关卡 1 = 30，关卡 2 = 72，关卡 3 = 55） |
| `start_spirit: int` | 开局鬼能（关卡 1 = 30） |
| `placeable_cells: Array[Vector2i]` | 可建造区（关卡 1 起始 18 格） |
| `obstacle_cells: Array[Vector2i]` | 障碍格（关卡 1 = 3 格：`(4,1) (5,1) (6,1)`） |
| `preplaced_ghosts: Array[GhostPlacement]` | 预置鬼（关卡 1 无） |
| `preplaced_facilities: Array[FacilityPlacement]` | 预置设施（关卡 1 = 交付口 1 个于 `(8,4)`） |
| `allowed_ghost_ids: Array[StringName]` | 本关可用鬼的白名单 |
| `star_thresholds: StarThresholds` | 三轴阈值（效率 / 手动 / 空间） |

### 5.4 设施（交付口 / 仓库口）

`GameDesign.md` §4.8 定义，二者**不是鬼**，独立成类：

| 设施 | 行为 |
| --- | --- |
| 交付口 | 玩家把物品送进它 → 检验形态是否符合 `accepted_form` → 符合则计分，不符则转杂质 |
| 仓库口 | 接收物品转成建造货币 |

### 5.5 关卡 1 资源（必须真的能通关）

`res://Data/Levels/Level01.tres`：

- `grid_size = (10, 8)`
- `time_limit = 90`，`goal_form = "Spirit"`，`goal_amount = 30`，`start_spirit = 30`
- `placeable_cells` = 第 2~7 列、第 3~5 行（共 18 格，见 `LevelDesign.md` 关卡 1）
- `obstacle_cells` = `[(4,1),(5,1),(6,1)]`
- `preplaced_facilities` = 交付口 1 个，位置 `(8,4)`，`accepted_form = "Spirit"`
- `allowed_ghost_ids` = `[&"producer"]`（只有生产鬼）
- 产能核对：生产鬼 2.0 s/个 → 30 个需 60 s，落在 90 s 时限内 ✓

---

## 5.9 3D 表现层规格（本次必做）

逻辑规则做完只是「能算」，3D 做完才是「能交差」。这一节是 3D 的完整施工图。

### 5.9.1 世界坐标约定

逻辑世界是**单层平面网格**（`GameDesign.md` §5.7（单层平面）：只有地面，没有楼层，模型高度不参与任何判定）。3D 里把它放在 `y = 0` 的 XZ 平面上：

| 逻辑 | 3D |
| --- | --- |
| 格坐标 `(x, y)`（`Vector2i`，y 向北为正） | 世界坐标 `(x * CELL, 0, -y * CELL)`，**y 轴取负**因为 Godot +Z 朝南 |
| `CELL` | **1.0 世界单位**（`GameDesign.md` §13：1 格 = 1 世界单位），地台格线每格 1 单位 |
| 高度 | 鬼模型向上为 `+Y`；模型高度**不参与判定**（§5.4） |

新增 `Code/Common/Grid3D.gd`（`class_name Grid3D`）只放坐标换算，不含任何逻辑：

- `static func CellToWorld3D(cell: Vector2i) -> Vector3`
- `static func World3DToCell(pos: Vector3) -> Vector2i`
- `const CELL := 1.0`

> ⚠️ `GridUtil` 是 2D 像素系（`CELL_SIZE=64`），**不要混用**。3D 全程走 `Grid3D`。

### 5.9.2 场景树（`Level3D.tscn`）

按 AGENTS.md §五，节点**尽量在 .tscn 里预置**，脚本里只做引用与逻辑：

```text
Level3D (Node3D)                       ← Level.gd
├── World (Node3D)
│   ├── GridFloor (MeshInstance3D)     ← BoxMesh 铺满网格，材质含格线纹理
│   ├── CellMarkers (Node3D)           ← 预置每格的薄 BoxMesh，占位/可建/障碍靠材质区分
│   ├── Ghosts (Node3D)                ← 每只鬼一个 Node3D 实例
│   ├── Items (Node3D)                 ← 掉落物 Node3D 实例
│   └── Facilities (Node3D)            ← 交付口 / 仓库口
├── CameraRig (Node3D)                 ← CameraRig.gd
│   └── Camera3D                       ← 正交投影
├── UILayer (CanvasLayer)
│   ├── HUD                            ← 鬼能、目标进度、计时
│   ├── GhostBar                       ← 可用鬼牌栏（2D UI）
│   └── ResultPanel                    ← 结算
```

### 5.9.3 相机（`Camera3D.gd` 挂在 `CameraRig`）

照抄 `GameDesign.md` §5.4 与 §8.5：

| 参数 | 值 | 出处 |
| --- | --- | --- |
| 类型 | **正交相机**（`projection = ORTHOGONAL`） | §5.4 |
| 俯仰角 | **45°** 俯视（`rotation_degrees.x = -45`） | §5.4 / §8.5 |
| 偏航角 | **八向 45° 吸附**，默认 0° | §5.4 / §8.5 |
| 缩放 | **三档视野：8 / 12 / 16 格高**（相机 `size` 按格数换算，1 格 = 1 单位） | §5.4 |
| 旋转手感 | 按住拖拽 → 释放时**吸附**到最近的 45° | §5.4 / §8.5 |
| 初始朝向 | 每关预设，保证**交付口与可放置区一眼同屏** | §5.4 |
| 平移 | 限制在**地台边界内** | §5.4 |
| 朝向提示 | 界面常驻**八向罗盘**，标出当前方位与世界北 | §5.4 |

**偏航与世界方位的关系**：`GameDesign.md` §5.4 明确「相机偏转与落子方向同步补偿，逻辑方位不随相机转」——即**逻辑坐标永远不变**，只是相机绕场景转，所以**不需要任何坐标补偿代码**（这正是把逻辑层做成 `Vector2i` 的好处）。旋转只改 `CameraRig` 的 `rotation_degrees.y`。

**硬约束（§5.4）**：**视角不进玩法** —— 旋转 / 缩放 / 平移**不改变**任何格坐标、连线、搜索区、掉落分布、联动结果；不暂停游戏、不消耗关卡时间、不产生任何游戏事件。实现时相机节点**只能写自己的 transform**，绝不能回调玩法层。

**关键**：偏航吸附后，`World3DToCell` 必须仍然正确——所以换算要**用相机的逆变换**，不能直接用世界坐标取整。两种做法都可行，推荐第二种：

```gdscript
# 做法 A：直接用世界坐标（相机不绕场景转时成立）
# 做法 B（推荐）：把射线打到 y=0 平面，再取整
static func World3DToCell(pos: Vector3) -> Vector2i:
    return Vector2i(floori(pos.x), floori(-pos.z))
```
因为相机是**绕场景中心旋转**的，格子本身仍在 XZ 平面按轴对齐，所以射线打到 `y=0` 平面后取整就是格子 —— 与相机朝向无关。

### 5.9.4 拾取（`Picker3D.gd`）

玩家点击要能落到具体格子：

1. `Camera3D.project_ray_origin(mouse)` / `project_ray_normal(mouse)` 得到射线。
2. 用 `Plane(Vector3.UP, 0).intersects_ray(origin, normal)` 求与 `y=0` 平面的交点。
3. 交点 → `Grid3D.World3DToCell()` → 格坐标。
4. 若该格无鬼但鬼有高度/宽度，用 `Area3D` + `input_event` 做精确命中（`CollisionShape3D` 立方体）作为**第二优先级**：先精确命中实体，命中失败再落回平面取整。

> 两种都要实现：**平面取整**负责选空格子（放置预览）、**Area3D 命中**负责选中已有的鬼（拆除/查看）。只做前者会导致点不中已有鬼。

### 5.9.5 地台与占位可视化（`GridFloor.gd` / `CellMarker`）

- `GridFloor`：`BoxMesh`，尺寸 = `(grid_size.x * 1.0, 0.1, grid_size.y * 1.0)`，放在 `y = -0.05`。材质用 `StandardMaterial3D` + `uv1_scale = grid_size`，配一张程序化生成的格线纹理（`GradientTexture2D` 或直接用 `ImageTexture` 画线），使格线与格子对齐。
- 每格一个 `CellMarker`：`BoxMesh` 尺寸 `(0.9, 0.02, 0.9)`，`y = 0.01`。颜色按状态分：
  - 可放置区（`placeable_cells`）：**低饱和蓝**，hover 时提亮
  - 障碍格（`obstacle_cells`）：**深灰**
  - 已有鬼 / 设施占用：**隐藏**
  - 放置预览：**亮绿**（合法）/ **红**（非法，`GridUtil.Overlap` 判定失败时）
- 格子数量 = 关卡 10×8 = 80 个 `CellMarker`，**在 .tscn 里预置 80 个太笨重**——允许在 `BoardGrid.gd` 里按 `grid_size` 动态生成 `CellMarker`（这是「简单重复网格」，不属于 AGENTS.md §五要预置的「复杂节点树」）。用 `MultiMeshInstance3D` 更省。

### 5.9.6 鬼与掉落物的 3D 占位

无美术资源，用几何体占位：

| 对象 | 表现 |
| --- | --- |
| 鬼 | `MeshInstance3D` + `BoxMesh`（尺寸约 `0.8 × 0.8 × 0.8`），材质颜色取 `GhostData` 的 `color`；顶部挂一个 `Label3D` 显示中文名（`billboard = BaseMaterial3D.BILLBOARD_ENABLED`） |
| 掉落物 | 小 `SphereMesh` 或 `BoxMesh`（`0.3`），颜色按物料（鬼能=青、贡品=金、杂质=暗紫） |
| 交付口 / 仓库口 | `BoxMesh` 底座 + `Label3D` 标字 |

`Label3D` 用于悬浮文字；`Billboard` 只给文字与图标用，**不要给整个模型用**（会破坏「模型高度不参与判定」的视觉直觉）。

### 5.9.7 遮挡与 X-Ray

`GameDesign.md` §5.6（遮挡与可读性）与 §8.5 要求：**高模型挡住后面的格线**（要有立体感），同时玩家能看清被挡内容。

`GameDesign.md` §5.6 给了五条手段，照抄实现：

| 手段 | 实现 |
| --- | --- |
| **八向旋转（主手段）** | 转相机到能看清的一侧 → Q/E 或右键拖拽 |
| **建筑高度上限** | 所有鬼模型与障碍墙 **≤ 1 格高**，禁止高墙整片遮住地面 → 占位体高度不要超过 1.0 单位 |
| **选中描边** | 被选中 / 悬停的鬼显示轮廓，即使被挡住也能看到位置与形状 → 用 `MeshInstance3D` 的 `outline`（`StandardMaterial3D` 的 `grow` + `rim`），或加一层放大的透明外壳 |
| **拾取规则** | **只命中最前面的可见实体**；被完全遮挡的实体不能点，需转视角或用透视查看 → 拾取按距离/深度排序，只取最近命中的 |
| **透视查看（X-Ray）** | **建筑半透**，但地面格线、连线、端口、掉落物**保持不透明** → 只给鬼的材质设 `transparency = ALPHA` + `alpha ≈ 0.35`，地台与掉落物不透明 |
| **状态浮标** | 状态与故障标记始终朝向玩家 → 用 `Label3D` + `billboard = BILLBOARD_ENABLED` |

**硬约束**：**遮挡只影响可见性与点选，不影响逻辑**（§5.6 末句）。被挡住的鬼照常运行、照常掉落、照常进故障——3D 表现层**不得**因为画面遮挡而阻止任何结算。

### 5.9.8 相机操作与快捷键

`GameDesign.md` §5.5（操作优先级）给出（相机 → 选中 → 放置 → 拆除），照此实现输入映射：

| 输入 | 行为 |
| --- | --- |
| **右键拖拽 / 中键拖拽** | 视角旋转（松手吸附 45°）——**优先级最高** |
| **滚轮** | 三档缩放（8 / 12 / 16 格高） |
| 左键拖拽（从鬼牌栏拖出） | 放置鬼 |
| 左键点击鬼本体 | 切换状态 |
| 左键拖拽掉落物 | 手动拾取 |
| `Delete` / 工具栏按钮 | 拆除选中的鬼 |
| `Q` / `E` | 相机偏航 -45° / +45°（八向吸附，键盘替代品） |
| `X` | 切换 X-Ray |

> 以上顺序照抄 `GameDesign.md` §5.5 的操作优先级表（视角 → 接线 → 范围手柄 → 放置 → 切换状态 → 拾取 → 拆除）。**实现输入判定时严格按这个顺序判定**，否则会出现「想拖视角却放下了鬼」。

> ⚠️ **输入映射要加到 `project.godot`**——但 AGENTS.md §一规定 `project.godot` 需明确授权。**处理办法**：在提交说明里单独列出「需在 `project.godot` 的 `[input]` 段新增 Q/E/W/S/X 五个 action，请少主确认」，或改用代码内 `_unhandled_input` 直接读 `InputEventKey` 的 `keycode`（**推荐**，绕开 `project.godot` 改动需求）。

### 5.9.9 3D 阶段的验收

- 新测试 `Level3DSceneTest.tscn`（headless）：实例化 `Level3D.tscn`，断言：场景能加载；`Grid3D.CellToWorld3D` 与 `World3DToCell` 互为逆运算（遍历全部格子断言往返一致）；相机的 `projection` 是 ORTHOGONAL、`rotation_degrees.x == -45`；偏航吸附函数对任意输入角返回 45° 的整数倍。
- 手动验收清单（写进提交说明，交由少主在编辑器里确认）：
  1. 打开关卡 1，看到斜俯视地台与格线
  2. `Q`/`E` 旋转，视角 45° 吸附，画面不抖
  3. 滚轮缩放三档
  4. 放一只生产鬼，它有实体、有阴影、能被遮挡
  5. 掉落物出现并可拾取，能送进交付口
  6. 达成 30 个 → 结算面板出星级

---

## 6. 实现阶段（严格按序，每阶段独立可提交）

### 阶段 0：脚手架与回归基线（不改功能）

**目标**：确认 headless 环境能跑，且现有 3 个测试是绿的。

1. 跑一次启动冒烟 + 3 个测试，记录基线输出。
2. 新建空目录 `Code/Entities/Board/`、`Code/Entities/Level/`、`Code/Data/Ghosts/`、`Code/Data/Levels/`（若决定资源放 `Data/` 则不建 `Code/Data/`）。
3. **提交**：`chore: 建立玩法层目录骨架`（中文提交信息）。

**验收**：基线测试全绿，仓库里除新增空目录外无任何改动。

---

### 阶段 1：数据模型（无行为，纯资源）

**产出**：`GhostData.gd`、`BoardPortDef.gd`、`LevelData.gd` + 关卡 1/2/3 的 `.tres` + 生产/采集/运输/处理四只基础鬼的 `.tres`。

**四类基础鬼的参数**（取自 `GameDesign.md` §4.2 与 §13 数值表）：

| 大类 | 触发 | 可动性 | 输入端口 | 输出端口 | 关键数值 |
| --- | --- | --- | --- | --- | --- |
| 生产鬼 | 自动 | 刚体 | 0 | 0（走掉落） | 周期 **2.0 s**，缓冲 3，产出鬼能 |
| 采集鬼 | 自动 | 柔体 | 0 | 1（动态物料标签，见 D2） | 搜索区 = 四邻 DFS，拾取间隔 **0.5 s**，采集步进 **0.1 s/格**，缓冲 3 |
| 运输鬼 | 自动 | 柔体 | 1 | 1 | 移动 **0.3 s/格**，输入缓冲 1，输出缓冲 1 |
| 处理鬼 | 自动 | 柔体 | 1 | 1 | 周期 **1.2 s**，输入缓冲 2，输出缓冲 2，损耗 **25%**，再处理间隔 **1.6 s** |

**动作**：按 §5.1 / §5.2 建类与资源；`res://Data/Forms/Spirit.tres` 等**直接复用**，不要新建同名资源。

**验收**：
- 新增一个 headless 测试 `Code/Tests/LevelDataLoadTest.tscn`，断言：三关 `.tres` 均可 `load()`；关卡 1 的 `goal_amount == 30`、`allowed_ghost_ids` 含 `producer`；四只基础鬼 `.tres` 的 `category` / `ports` / `cycle_time` 与上表一致。
- 现有 3 个测试仍全绿。

---

### 阶段 2：棋盘骨架（网格 + 放置 + 掉落，不做行为）

**产出**：`Board.tscn/.gd`、`BoardGrid.gd`、`GhostInstance.gd`、`DroppedItem.gd`。

**要求**：
- `Board` 持有 `grid_size`、格子占用表、掉落物表。
- 放置校验：目标格 `GridUtil.InBounds` + 不在 `obstacle_cells` + 不在已占用格 + 落位后 `GridUtil.Overlap` 与既有占位无交叠。
- 掉落物：占用一格，携带 `form` 与 `amount`。
- 玩家交互：放置（从鬼牌栏拖到格子）、拆除、拾取掉落物。拖放用 `Area2D` + `@onready`，符合 AGENTS.md §五。

**验收**：新测试 `BoardPlacementTest.tscn` 断言：合法位可放置；落在障碍格失败；与既有鬼占位交叠失败；`GridUtil.Overlap` 返回空。

---

### 阶段 3：生产鬼行为 + 关卡 1 单链跑通（**本次的核心交付**）

**产出**：`GhostBehavior.gd`（基类）+ 生产鬼行为、`BoardRunner.gd`（时序）、`Level.tscn/.gd`、`LevelHud`、`LevelGoal`。

**时序模型**（`PhysicsLayer.md` §3 的意图结算简化为单鬼版）：
1. `BoardRunner` 按固定 tick 推进；所有速度类参数从 `ExportSettings.gd` 读，不写死在脚本里。
2. 每 tick：收集每只鬼的**意图** → 按优先级/距离/放置顺序仲裁 → 执行。
3. 生产鬼每 `cycle_time` 产生一个意图「产出 1 个鬼能」；执行时找四邻空格放 `DroppedItem`，放不下则进自身缓冲；缓冲满 → `FAULT` 状态 + `SignalBus.GhostFaulted`。
4. 掉落物出现 → `SignalBus.SpiritDropped(cell, amount)`；玩家拾取 → `SignalBus.SpiritPicked(amount)`；鬼能入池 → `SignalBus.SpiritChanged(spirit)`。
5. 玩家把物品交给交付口 → 校验 `accepted_form` → 计数 → `SignalBus.ItemDelivered(form, terminal)` + `SignalBus.OfferScored(delivered, goal)`。
6. `delivered >= goal_amount` → 关卡完成 → `SignalBus.LevelCompleted(level_id, stars)`。

**星级**：用 `StarRating.CalculateStars(efficiency, manual, space)`，三轴取值来自 `LevelData.star_thresholds`。`StarRating` 当前是占位阈值，实现前先读它的实际算法，必要时**只加 `LevelData` 侧的阈值数据**，不改 `StarRating` 的公共接口（AGENTS.md §二：优先兼容增量）。

**验收（硬指标，必须全部通过）**：
- 新测试 `Level01PlaythroughTest.tscn`：**脚本化跑通关卡 1**——放 2 只生产鬼 → 推进 tick 直到产出 30 个鬼能 → 交付 30 次 → 断言 `LevelCompleted` 被触发、`stars >= 1`、总耗时 < 90 s。
- 新测试 `ManualCountTest.tscn`：断言手动次数只统计交付动作（拾取/移动/放置不计数），30 次交付后计数 == 30。
- 新测试 `FaultTest.tscn`：把生产鬼放在角落使四邻全满且缓冲满 → 断言进入 `FAULT` 且 `GhostFaulted` 发出。
- 现有 3 个测试仍全绿。

---

### 阶段 4：采集 / 运输 / 处理三类行为 + 关卡 2、3

**产出**：采集鬼行为（DFS 搜索 + 拾取）、运输鬼行为（沿线路搬运 + 背压）、处理鬼行为（配方加工 + 损耗 + 再处理）、连线层 `ConnectionLayer`。

**要求**：
- 采集鬼搜索用 `GridUtil.Neighbors4` 做 DFS，搜索区来自 `GhostData.search_area`，步进 **0.1 s/格**。
- 运输鬼：输出端口 → 输入端口，用 `GridUtil.PathL` 生成正交折线路径，移动 **0.3 s/格**；目标缓冲满 → 背压停止 → `SignalBus.BufferStateChanged`。
- 处理鬼：按 `recipe_id` 取 `RecipeData`，`cycle_time` 后产出 `to_form`，产出率 `yield_rate`，损耗部分转 `Impurity` 并发出 `SignalBus.ImpurityCreated(cell)`。
- 连线合法性用 `GhostTag.CanConnect`（只认物料标签）。

**关卡 2 按 D4 修正**（目标形态改 `Spirit`，交付口 `accepted_form` 改 `Spirit`，数量 72 不变）。
**关卡 3** 保持 `goal_form = Offer`、`goal_amount = 55`，且 `LevelDesign.md` 明确其交付口接受 `Offer`——关卡 3 的可用鬼含处理鬼，配置自洽。

**验收**：
- `Level02PlaythroughTest.tscn`：脚本化跑通关卡 2（生产 + 采集 + 运输链），断言达成 72 个目标。
- `Level03PlaythroughTest.tscn`：脚本化跑通关卡 3（加处理鬼），断言达成 55 个贡品。
- `ConnectionRuleTest.tscn`：断言 `SPIRIT` 输出 → `SPIRIT` 输入可连；`SPIRIT` 输出 → 仅接受 `OFFER` 的输入**不可连**；动作标签不影响判定。

---

### 阶段 5：3D 表现层（**交差靠这步**）

**产出**：`Code/Common/Grid3D.gd`、`Code/Entities/Level/Level3D.tscn/.gd`、`CameraRig.gd`、`Picker3D.gd`、`GridFloor.gd`、3D 鬼与掉落物占位。

**做法**：**先跑通最小可看版本**——地台 + 一个相机 + 能放一只鬼——再逐步加细节。别一上来就做完整美术。

顺序：
1. `Grid3D` 坐标换算 + `Level3D.tscn` 场景树（World / GridFloor / CameraRig / UILayer）。
2. 正交相机 + 45° 俯视 + Q/E 八向吸附 + 三档缩放。**先能转起来**。
3. `GridFloor` 格线（程序化纹理，对齐格子）+ `CellMarker` 高亮可建区/障碍格。
4. 3D 拾取（平面取整 + Area3D 命中两条路径）+ 放置预览（绿/红）。
5. 鬼与掉落物占位（几何体 + `Label3D` 名字）+ 阴影与遮挡。
6. HUD 与结算面板（2D `CanvasLayer` 叠在 3D 上）。
7. X-Ray 开关。

**验收**：§5.9.9 的 headless 测试 + 手动验收清单 6 条全部通过。

---

### 阶段 6：收尾

1. 更新 `res://AGENTS.md` §10.3 / §10.4 代码索引（新增文件全部登记）。
2. 在提交说明里汇总：5 处设计缺口的定稿与**需要少主裁决的 D4**（关卡 2 目标形态）。
3. 全部测试跑一遍，记录通过数。
4. `git status` 确认没有误改 `res://Docs/`、`project.godot`、`res://addons/`。

---

## 7. 给执行 agent 的硬性检查清单

每阶段提交前逐条打勾：

- [ ] 改的文件全部在 `res://Code/` 内（新建 `res://Data/` 资源除外，且已在提交说明声明）
- [ ] `project.godot` 未被修改
- [ ] 所有新公共方法有 `##` 文档注释，方法名 PascalCase
- [ ] 所有新数值参数在 `ExportSettings.gd` 里 `@export`，带 `@export_group` 与单位说明
- [ ] 跨实体通信全部走 `SignalBus`，没有直接调用别的实体的方法
- [ ] `.tscn` 里的 `res://` 路径大小写正确、无断链
- [ ] headless 冒烟 + 全部测试全绿（**含原有 3 个**）
- [ ] `AGENTS.md` §10 索引已同步
- [ ] 提交信息中文，说明里写清本阶段新增/修改了哪些文件

---

## 8. 风险与已知坑

| 风险 | 说明 | 应对 |
| --- | --- | --- |
| **2D / 3D 路线冲突** | Docs 描述 3D 八向相机，工程是纯 2D | 本次**新增** 3D 表现层（阶段 5）；规则层全程只认 `Vector2i`，表现层只做坐标换算，互不污染 |
| **`ExportSettings` 是 `.tscn` autoload** | `ExportSettings="*res://Code/Autoloads/ExportSettings.tscn"` | 改参数要同时确认 `.tscn` 里挂了 `ExportSettings.gd`；新增 `@export` 默认值即可生效，不需改 `.tscn` |
| **`SignalBus` 已有 31 个信号** | 极易重复造轮子 | 实现前先 `grep -n "^signal" Code/Autoloads/SignalBus.gd`，缺的才加 |
| **`CanConnect` 忽略动作标签** | 写了 `HAUL` 也不参与判定 | 一律只填物料标签 |
| **`GridUtil` 是 2D 像素坐标** | `CELL_SIZE = 64`，`CellToWorld` 返回 `Vector2` | 规则层只用 `Vector2i` 格坐标；像素换算只在表现层用 |
| **关卡 2 语义待裁决** | D4 改了策划意图 | 按定稿实现，提交说明显著标注，等少主拍板 |
| **旧原型诱惑** | `80787b2` 有完整 Board 实现 | 只看思路不整体恢复；整体恢复会覆盖工作区未提交的 Docs 改动 |
| **工作区脏** | 当前 `git status` 有 4 个 `M` 的 Docs + 未跟踪 `.workbuddy/` | **不要 `git checkout`/`reset`/`clean`**；只提交自己新增/修改的 `Code/` 文件 |

---

## 9. 附录 A：关键数字速查（全部有出处）

**系统数值**（`GameDesign.md` §13）
生产周期 2.0 s｜采集步进 0.1 s/格｜拾取间隔 0.5 s｜运输 0.3 s/格｜处理周期 1.2 s｜再处理间隔 1.6 s｜加工损耗 25%｜堆叠压缩阈值 5

**关卡 1**（`LevelDesign.md`）：10×8 网格｜时限 90 s｜目标 30 个鬼能｜开局鬼能 30｜起始 18 格可建｜障碍 3 格｜交付口 1 个于 `(8,4)`｜仅生产鬼｜2★ ≤ 60 s

**关卡 2**：目标 72（原写贡品，按 D4 改鬼能）｜仅生产/采集/运输

**关卡 3**：目标 55 个贡品｜含处理鬼

**星级**：`StarRating.CalculateStars(efficiency, manual, space) -> int`（三轴 0~1，越大越好）

---

## 10. 附录 B：本文档已核对的事实清单

以下均为**实测**结论，执行时可直接依赖：

- `src/` 全部代码为 2D；`grep -rl "Node3D|Camera3D|MeshInstance3D|CharacterBody3D"` 在 `Code/` 与 `.tscn` 中**零命中**
- `project.godot`：主场景 `StartMenu.tscn`；7 个 autoload；渲染 `gl_compatibility`；窗口 `mode=3`
- `Data/` 下仅 `Forms/`（3 个 `.tres`）与 `Recipes/`，**无** `Ghosts/`、`Levels/` 子目录 → 需新建
- `Code/Entities/` 下 `Board/`、`Level/`、`Tutorial/` **为空目录**（仅 `.gitkeep`）→ 正好是本次要填的位置
- 现有 headless 测试 3 个，当前全绿
- `GhostTag` 物料标签 3 个 + 动作标签 2 个，`CanConnect` 实现只认物料
- `GridUtil` 13 个公开静态函数，含 `Overlap` 与 `PathL`（占位检测、寻路已就绪）
- `ExportSettings.gd` 有 80 个 `@export`，分 6 组
- `SignalBus.gd` 有 31 个信号，覆盖本次需要的绝大多数
- 远端 `origin/master` 的 `Docs/Ghosts.md`（133 行）含**旧版四类基础鬼的完整规格**（造价 / 占位 / 端口 / 数值 / 故障条件），本地 24 行版已按 v12 精简 → **如需基础鬼的历史数值，`git show origin/master:src/Docs/Ghosts.md` 可查，但以当前 Docs 为准**
- 上传的《第 8 周开发文档》文件名与正文周次不一致（正文实为**第 6 周**开发文档，基线 `66a4e83`）；其「下周计划」第 1、2 项即本计划书 §0 的范围锚点

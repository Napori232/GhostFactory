# AGENTS.md · 给后续开发者 / AI 的工程约定

> 本文件只讲「怎么改不坏事」。设计口径看 `GameDesign.md`，
> 架构与不变量看 `docs/ARCHITECTURE.md`，加内容看 `docs/CONTENT_GUIDE.md`。

## 1. 先跑这个

```powershell
# 一键：先 --import 注册全局类，再跑无头测试
tools\test.cmd D:\path\to\Godot_v4.7.2-stable_win64_console.exe

# 或手动两步（改过 class_name 脚本后必须重新 import）
Godot --headless --path . --import
Godot --headless --path . res://Code/Tests/TestRunner.tscn

# 无头冒烟：自动放机关 / 插晶 / 跑 7 秒
Godot --headless --path . -- --dev-smoke

# 端到端验证拖动输入（窗口模式）
Godot --path . -- --dev-input

# 渲染截图（intro / play / duo / clear / armor / swapper / boss / wave / victory / tutorial / help / resonance）
Godot --path . -- --dev-shot

# 第三夜（大地图）/ 内容陈列 / 庞然大物
Godot --path . -- --dev-shot3
Godot --path . -- --dev-gallery
Godot --path . -- --dev-behemoth

# 玩家视角验收
Godot --path . -- --dev-select
Godot --path . -- --dev-held
Godot --path . -- --dev-eye
Godot --path . -- --dev-click-card

# 机械联动 / 鬼晶手感
Godot --path . -- --dev-link
Godot --path . -- --dev-crystal

# 新手引导与帮助面板
Godot --path . -- --dev-tutorial
Godot --path . -- --dev-tutorial-flow
Godot --path . -- --dev-help

# 机器共振截图
Godot --path . -- --dev-resonance

# 第二夜（走廊）截图
Godot --path . -- --level=02 --dev-shot2
```

任何改动提交前，`TestRunner` 必须是 **0 失败**。改公式就补断言。

## 2. 分层纪律

- **`Code/Core` 里不许出现 `Node`、`Control`、`Node3D`、`get_node`、`await` 场景树。**
  需要通知表现层 → 往 `SimEvents` 加信号。
- **`Code/Game` / `Code/UI` 不许改 `Sim` 的规则状态。**
  它们只能调 `Sim` 的公开方法（Build / RemoveAt / PickCrystal / …）并读取公开字段。
- **数据只放 `Data/`。** 代码里的数字只允许是「安全默认值」兜底，
  不许出现「这个关卡就该是 80 预算」这类硬编码。

## 3. 命名与风格

- `class_name` 用 PascalCase：`SimGhost`、`WorldView`、`ResonanceGauge`。
- 公开方法 PascalCase（`SetPaused`、`EnvelopeAt`），内部方法 / 变量 snake_case（`_tick_enemies`）。
- 信号 PascalCase（`GhostPulse`、`RunFailed`）。
- 常量 `UPPER_SNAKE_CASE`。
- 每个公开方法上方写 `##` 文档注释：用途、参数含义、返回值。
- 中文注释可以，但**标识符、数据键名一律英文**。

## 4. 不变量（违反会静默坏档 / 坏状态）

1. `Sim.cells` 是格子占用的唯一真相；建 / 拆 / 拿 / 放 / 插 / 取都要同步它。
   **例外**：骑在传送带上的鬼晶不写 `cells`（带子占着那一格），它由 `SimCrystal.ride_belt` 表达。
2. `SimCrystal.slotted_in` 与 `SimMechanism.crystal_id` 必须成对更新；
   删除机关时要把槽里的晶落到地上，否则会丢晶。
3. 鬼晶的位置三态互斥：地上（`cell`）/ 槽里（`slotted_in`）/ 带面（`ride_belt`）。
   搬运时必须一起改，否则会出现「一颗晶在两个地方」。
4. 快照 / 恢复必须保留实体 `id`，否则插槽引用会断；传送带要连 `items` 一起恢复。
5. 视图在 `WorldRestored` 后必须全量重建；不要试图增量修复。
6. `outlaw_cells` / `outlaw_count` 是缓存：建 / 拆 / 挪 / 扩地之后必须调 `_recount_outlaws()`。
7. 波次威胁只有一份口径：HUD 的「有效 HP」与 `BalanceAudit` 都走 `WaveMath.Threat()`。
8. 手持鬼晶只显示在 HUD 的 `HeldSlot`；不要在相机/世界里再挂一个「手」的 3D 图标。
9. 实体被拆 / 被魅啃掉 / 被回溯后，`Main` 必须清掉选中格与信息面板。
10. **鬼与鬼的物理联动**：冲量只走 `pending_impulse`（下一 tick 生效），`strike_pending` 每 tick 只结算一次；
    `Sim.links` 是派生数据，每 tick 重算，不进存档。
11. 测试不要写 `user://`（本机可能不可写）；临时文件放 `res://.godot/` 下。

## 5. 性能边界

- 逻辑 20 Hz；热力图 5 Hz；不要在每个 `_process` 里重算场。
- 实体节点数量很小（几十个），结构变化时全量重建是可接受的。
- 新增每帧计算前，先想清楚是否能用「事件 + 缓存」。

## 6. 加东西的路径

| 想加 | 正确做法 |
|---|---|
| 新鬼（同类型阈值） | 只加 `Data/ghosts/*.json` + `Data/content.json` 一行 |
| 新鬼（双支撑 / 脉冲触发） | 直接改 `kind` 字段（`multi` / `relay`），不用写代码 |
| 新机关（已有 effect） | 只加 `Data/mechanisms/*.json`（push / crank / tune / amp / reach） |
| 新传送带 / 搬运装置 | 只加 `Data/belts/*.json`、`Data/swappers/*.json` |
| 新关卡 / 波次 | 只加 `Data/levels/*.json`，`next_level` 指过来，再把 id 加进 `content.json` 的 `levels` |
| 新夜规 | 只加 `Data/modifiers.json` 条目 |
| 新阈值类型 | 改 `SimGhost`（加 kind）+ `Sim._tick_ghosts`，补测试 |
| 新鬼与鬼联动 | 在 `SimGhost` 加触发量 + `Sim._compute_brace_supports` / `_resolve_strike` 结算，补测试 |
| 新机关作用方式 | 改 `SimMechanism` + `Sim._tick_ghosts` 的参数改写段，补测试 |
| 新物流形态 | 新建 `Code/Core/Sim*.gd` + `Sim` 的 tick / Build 分支，补测试 |
| 新视图 | 新建 `Code/Game/Views/*View.gd`，在 `WorldView` 里注册，不改 Core |
| 新 UI 面板 | 改 `Hud.gd`，数据从 `Sim` 公开字段读 |
| 新相机模式 | 改 `CameraRig`，方向计算抽成 static 纯函数并补测试 |
| 新数值口径 | 只改 `WaveMath`，HUD / 审计 / 测试自动跟上 |

## 7. 已废弃 / 别碰

- `ghost-factory/`：最初的空骨架，已被 `.gdignore` 排除（原因见其 `SUPERSEDED.md`）。
- `_acl-recovery/`、`_newtest/`、`_wtest.txt`：本机排查沙箱权限留下的临时物，可删。
- `Core/SimGrid.gd`（如果还存在）：误建的空占位，真正实现在 `Code/Core/SimGrid.gd`。

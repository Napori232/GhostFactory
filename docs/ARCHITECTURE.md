# 架构

> 目标不是「能跑就行」，而是**稳定、可移植、可长期维护**。
> 三条硬约束：规则可无头测试；内容不写死在代码里；表现层可整体替换。

---

## 1. 分层与依赖方向

```
            Data/*.json
                │  只读
                ▼
     ┌──────────────────────┐
     │  Code/Core           │  纯 GDScript（RefCounted）
     │  Sim / SimGhost /    │  不 import 任何 Node / 渲染 / 场景
     │  SimField / ...      │  固定 dt 推进，可 headless
     └──────────┬───────────┘
                │ SimEvents（信号）+ 只读状态
                ▼
     ┌──────────────────────┐
     │  Code/Game / Code/UI │  Node3D / Control
     │  Main / WorldView /  │  只同步与表现，不改规则
     │  Hud / HeatmapView   │
     └──────────────────────┘
```

依赖是**单向**的：`Game/UI → Core`，Core 不知道节点存在。
唯一让 Core 触碰文件系统的地方是 `GameData`（只读 JSON）。

这条边界带来两个实际好处：

1. `Code/Core` 可以整体拷到另一个工程（甚至非 Godot 的运行时）而不带渲染包袱。
2. 所有玩法规则都能在 `--headless` 下用固定时间步测试，不受帧率与物理引擎影响。

---

## 2. 一 tick 做什么（顺序是刻意的）

`Sim.Step(dt)`，`dt = 1 / tick_rate`（默认 20 Hz）：

| 顺序 | 阶段 | 为什么在这个位置 |
|---|---|---|
| 1 | 搬运（搬运手 / 装卸臂）：把充能晶换进缺电机关 | 换进来的晶要能供本 tick 的机关使用 |
| 2 | 传送带：把带面最前面的晶往前送一格 | 先送料、再上料；带面上的晶本 tick 也能被脉冲充能 |
| 3 | 机关：判定是否发力、按周期扣鬼能 | 力必须先于鬼的姿态积分 |
| 4 | 鬼：接力脉冲落地 → 机关改参数 → 汇总力矩/支撑数 → 积分倾角 → 过阈值 → 发脉冲 | 脉冲在这里产生 |
| 5 | 重建脉冲场 | 用本 tick 的「立正 / 相位 / 改后参数」重建，供伤害使用 |
| 6 | 魅：移动 → 采样场 → 掉血 / 越线抹杀 / 啃越界造物 / 抵达 | 保证「刚立正的那一拍」就能打到 |
| 7 | 波次：倒计时、刷怪（含鬼屋激增）、清波、扩地、全清 | 刷出来的怪下一 tick 才参与伤害 |
| 8 | 热力图缓存（5 Hz） | 纯展示数据，低频刷新省 CPU |

暂停时 `Step` 直接返回；建造 / 拆除走的是独立入口，所以**暂停中仍可改装置**。

---

## 3. 核心模型

### 3.1 鬼：单自由度倒立摆

`SimGhost.angle` 是判定用的唯一状态，不是动画：

```
θ̈ = (τ_gravity + τ_push) / I − damping · θ̇

θ < rest_angle :  τ_gravity = gravity · (0.12 + sin θ)   // 立正附近不稳定，必倒
θ ≥ rest_angle :  τ_gravity = −(θ − rest_angle) · stop_stiffness  // 脚撑接住
```

- `rest_angle`：翘脚姿态（没人顶就停在这）。
- `stand_angle`：判定「立正」的阈值；`hysteresis` 防止在临界点抖动。
- `τ_push`：机关给的力矩，负值压脚、正值推身。

**阈值来自积分结果，不是脚本触发。** 推得不够、推错地方、电不够，鬼都不会立正。

### 3.2 接触：顶脚 vs 推身

机关头部位置 `HeadWorld()` 与鬼的两个受力点比较：

| 命中 | 力矩符号 | 后果 |
|---|---|---|
| 翘起那只脚（`FootWorld`，半径小） | 负 | 压回立正 |
| 身体（`BodyWorld`） | 正 × `topple_factor` | 推倒 |

所以「放歪了」不是无操作，而是**帮倒忙**——这是设计里「相对位置是题面」的实现。

### 3.3 脉冲场

每个立正的鬼是一个波源：`(pos, period, phase, amplitude, range)`。

```
在点 p：
  衰减      a = amplitude · (1 − d / range)          // d ≥ range 归零
  传播延迟  φ = phase − 2π · d / (speed · period)     // speed 默认 6 格/秒
  同周期    复数相量求和：S = Σ a·e^{iφ}              // 反相即抵消
  异周期    sqrt(Σ|S_f|²)                             // 不锁相，按能量叠加
```

这直接实现了设计要的三件事，且**没有任何组合规则表**：

- 同频同相 → 振幅叠加；
- 同频差半拍 → 互相抵消（「明明都在拼命，机器却不动」）；
- 异频 → 平均功率远低于同相（拍频）。

**相位从哪来：** 鬼立正时把相位对齐全场时钟（`fmod(now, period) / period * TAU`），
之后每一 tick 都从**绝对时钟**重算，而不是自己累加。这样不同时间立正的同周期鬼
也会落在同一拍上；两点之间的相位差只来自位置与传播延迟。
这样玩家调的是「摆哪」，不是「按哪个瞬间」，热力图才是稳定的、可推演的。

热力图显示的是**一个周期内的峰值包络**（`SimField.EnvelopeAt`），按格缓存。

### 3.4 伤害：两条线

```
env = 该点的合成振幅
env ≥ clear_line  → 立即抹杀（by_clear = true，对应「一拱全爆」；无视护甲）
env ≥ damage_line → 每秒伤害 = (env − damage_line) · dps_scale · armor
```

默认 `damage_line = 0.25`、`clear_line = 1.45`、`dps_scale = 60`。
单只鬼的峰值是 1.0（到不了清场线）；两只同相叠到 1.5 以上就能越线。
`armor` 只减免持续伤害，不减免清场抹杀——这是「甲魅」逼玩家去摆清场线的机制。

### 3.5 波次

`SimWaves` 不碰实体，只产出指令数组：

```
{"op":"wave_start"} / {"op":"spawn", pos, hp, speed}
{"op":"wave_clear"} / {"op":"all_clear"}
```

状态机：`PREP → SPAWNING → ACTIVE → (下一波) PREP …`。
`ACTIVE` 阶段只有「场上魅数量为 0」才清波，所以刷怪那一 tick 不会被误判。

### 3.6 自动化物流

`SimSwapper` 有两种形态，共用同一套建造 / 拆退 / 快照 / 视图管路：

**`source = "ground"`（搬运手）**：每 `swap_period` 秒，找服务半径内最缺电的机关，
把附近地上最近的、存量 ≥ 1 + `drain` 的鬼晶换进去；旧晶落回原格，抽走 `drain`。

**`source = "belt"`（装卸臂）**：有朝向，每 `swap_period` 秒做一个动作（优先级）：

1. **交换**：槽里是空晶 → 挪到背后的带子 / 附近空地，同时从正前方带（其次地面）取充能晶塞回槽；
2. **上料**：空槽 → 从正前方带（其次地面）取充能晶；
3. **卸料**：带面上的空晶 → 卸到附近空地；
4. **装带**：地面的充能晶 → 放上「和自己同向走」的带子。

「交换」一次完成两件事，所以机关不会因为换料而断电——这是自持产线的基础。
方向规则（正前方 = 来料、背后 = 回程、同向 = 去程）让「去程 / 回程两条带」成为可读的布局题。

### 3.6.1 传送带

`SimBelt` 占 1 格、有朝向与速度。每 `1/speed` 秒把 `items[0]` 往前送一格：

- 前方空地 → 落地（写进 `cells`）；
- 前方有空位的带子 → 交给它（`Accept()` 会把它的 `move_timer` 归零，防止同一 tick 连跳两格）；
- 前方空槽机关且晶有电 → 直接插进去（计入 `belt_deliveries`）；
- 其它情况 → 原地等（堵带）。

**带面上的鬼晶**：`cell` 记成带子所在格、`ride_belt = belt.id`，但**不写进 `cells`**。
它是场上的容器，所以能被脉冲充能；玩家也能从带面上拿走最前面那颗。

### 3.7 回溯

- **快照时机**：`Setup`（开局）与每次 `wave_clear`（波次边界）。
- **快照内容**：鬼 / 机关 / 鬼晶 / 插槽引用 / 预算 / 已解锁 / 抵达计数 / 波次游标 / 统计 / 共振蓄能与冷却。
- **恢复**：清空实体 → 按原 id 重建 → 重建占用表与插槽引用 → 波次回到该波准备阶段。
- **不恢复**：已解锁内容（设计 v14.5 明确解锁永久保留）。

失败时先进入 `FAILED`（世界冻结、面板可读），玩家点「回溯」才真正回滚——
比瞬间回滚更容易看懂「刚才发生了什么」。

---

### 3.8 关卡与会话

- `GameSession.current_level` 是进程内的静态变量，决定 `Main` 载入哪份 `Data/levels/*.json`。
- 启动时优先读 `--level=XX`（调试），否则读存档里的 `current_level`，都无效则回落到 `01`。
- 通关时 HUD 读取当前关卡的 `next_level`：有就显示「下一夜 · 名字」，点击后
  写入存档的 `current_level` 并 `reload_current_scene()`；没有就显示「再守一夜」。
- 关卡之间不继承布局；每夜有自己的预算 / 图纸 / 场地 / 波次。跨夜继承的是
  **玩家学到的规律**，不是数值——这是刻意的，避免滚雪球。
- **夜规**（`Data/modifiers.json`）由 `LevelModifier.Apply()` 在 `Main` 里改关卡字典
  （预算 / 准备时间 / 禁用图纸），改完再交给 `Sim.Setup`；模拟层完全不知道夜规存在。
  「换约束重打」在 `GameSession.modifier_id` 上轮换并重载场景，进入下一夜时清空。
  「从第一夜开始」把 `current_level` 设回 `01` 并清空夜规，同时写回存档。

### 3.9 新手引导

- **控制器在 `Main`**：4 步状态机（建机关 → 插晶 → 看到脉冲 → 清掉第一波），监听
  `Built` / `CrystalInserted` / `GhostPulse` / `WaveCleared(0)` 前进。
- **显示层只显示**：`Hud.ShowTutorialStep()` 画左上角卡片并高亮建造按钮；
  `WorldView.ShowCellMarker()` 在“鬼脚边 / 充能晶”格子上放脉动环。
- **持久化**：完成或跳过后写 `tutorial_done = true`；帮助面板的「重看新手引导」可强制重开。
- 它不进入 `Sim`，也不改任何规则——引导只是把玩家的视线带到已经存在的交互上。

### 3.10 机器共振

- 每 tick 汇总本 tick 所有 `GhostPulse` 的振幅、次数与质心（`_pulse_tick_sum` / `_pulse_tick_count`）。
- 若同一 tick 有 ≥2 只鬼、振幅总和 ≥ `resonance_threshold`，且冷却已过：
  - 在质心周围 `resonance_radius` 内造成 `resonance_damage × 振幅总和 × 距离衰减` 的伤害（**无视护甲**）；
  - 给所有地上可充能鬼晶 +`resonance_charge_amount`；
  - `ResonanceBurst` 事件 → HUD 横幅/闪光/慢动作、WorldView 金环、Sfx 低频和弦。
- `resonance_charge` 是 0..1 的蓄能，给 HUD 实时读；没有脉冲的 tick 按 `resonance_decay` 衰减。
- 快照保留 `resonance_charge` 与 `resonance_ready_at`，失败回溯不会白嫖一次爆发。

### 3.11 鬼的三种阈值形态

`SimGhost.kind` 决定「怎样才算到阈值」：

| kind | 判定 | 状态 |
|---|---|---|
| `tilt` | `angle <= stand_angle`（带迟滞） | 倒立摆积分 |
| `multi` | 同上，且本 tick 顶住它的机关数 ≥ `contacts_required` | 倒立摆积分 + 支撑计数 |
| `relay` | 不靠倾角：被别的脉冲扫到 → 排一次 `delay` 秒后的发射 → 进冷却 | `relay_due` / `relay_active` |

- **支撑计数**由 `Sim._tick_ghosts` 在同一个汇总循环里数，`Step()` 只负责「够不够」的判定；
- **接力鬼**的发射队列在下一 tick 开头统一 flush，并且只 flush「这一 tick 开始时已到点」的那批，
  所以链式接力每 tick 只传一跳，不会递归爆栈；`relay_active > 0` 时它作为同相波源进入场。

### 3.12 机关的四种 effect

`SimMechanism.effect`（数据驱动）：

| effect | 在 `_tick_ghosts` 里做什么 |
|---|---|
| `push` | 头部命中脚 → 负力矩；命中身体 → 正力矩 × `topple_factor` |
| `crank` | 计算鬼的脚到「长撬线段」的距离，线段内都算顶到（可同时顶多只） |
| `tune` | 对半径内鬼写 `period_override = target_period` |
| `amp` | 对半径内鬼累加 `amp_mult`（封顶 `effect_amp_cap`） |
| `reach` | 对半径内鬼累加 `range_mult`（封顶 `effect_range_cap`） |

改参数的三种每 tick 先清空、再由**有电的**机关重新写入。因此：
失电 → 参数立刻还原 → 场立刻塌。这就是「改鬼的机关自己也要喂」的机制表达。

`SimGhost.EffPeriod()` / `EffAmplitude()` / `EffRange()` 是唯一的读取入口，
场的重建、充能半径、接力触发半径都用它们，避免出现两套口径。

### 3.13 大地图：领地、越界、鬼屋激增

- `SimGrid.build_rect` 是领地；`Sim.ExpandTerritory(rings)` 每次向外扩一圈，
  并广播 `TerritoryExpanded(rect, annexed)`（视图重建边界、相机重算平移范围、HUD 提示）。
- `Sim.CanBuildAt(cell)`：领地内永远可以；领地外要看关卡的 `allow_outlaw`。
- `Sim._recount_outlaws()` 扫一遍 `cells`，把领地外的**造物**（鬼 / 机关 / 带 / 臂）记成 `outlaw_cells`；
  鬼晶不算造物。
- `Sim.WavePressureBonus()` = `round(outlaw_count × outlaw_pressure)`，作为 `SimWaves.Step` 的 `bonus`，
  每个刷怪组多刷这么多。
- `Sim._tick_enemies` 会先给每只魅找 `aggro_radius` 内最近的越界造物；找到就走向它、啃
  `outlaw_attack_time` 秒后 `_raze_outlaw()`：拆掉造物（不退钱）、魅同归于尽、`OutlawRazed` 广播。
- 扩地时新圈进来的越界造物自动合法化（`annexed`），从 `outlaw_cells` 里消失。

### 3.14 相机、选择与拆除

**双视角**（`CameraRig`）：

| 模式 | 行走 | 观察 | 说明 |
|---|---|---|---|
| `BUILD` | WASD 平移、Q/E 旋转、滚轮 5 档缩放 | 斜俯视 52° | W 朝「镜头看的方向」（`PanDelta()` 唯一口径） |
| `EYE` | WASD 自由移动、Q/E 升降、Shift 加速 | **右键拖动**观察、pitch ±72° | 站到机关之间平视；不建造、不拾取 |

- `CameraRig.PanDelta(yaw, input)` 与 `EyeDir(yaw, pitch)` 是纯函数，测试直接断言方向；
- 幽灵视角用**右键拖动**观察（不捕获鼠标，HUD 仍可点）；`Tab` / `V` / `Esc` 或顶栏按钮返回；
- 两种模式都不暂停世界；进入 EYE 时隐藏建造栏 / 右侧面板 / 提示条，只留顶栏与一条操作提示。

**选择 / 拆除**（`Main` + `Hud`）：

- 左键点实体 → `Main._select_cell()`：`WorldView.SetSelection()` 画脉动青环，`Hud.ShowInspector(cell)` 弹数值面板；
- `Delete` / 面板「拆除」→ `Sim.RemoveAt(cell)`，全额退款；拆机关/带子时槽里/带面上的晶落到地上；
- 结构变化（`Built` / `Removed` / `Moved`）后，`Main` 会校验选中格是否还有东西，没有就清掉；
- 面板里的数值每帧只在该面板可见时刷新（`Hud.Refresh` → `_refresh_inspector`）。

**手持鬼晶**：不再有挂在相机前的 3D 图标（曾经放下后不刷新、还会和建造栏打架）。
手持状态只显示在 `HeldSlot`（建造栏左侧的 HUD 槽位）；空手整条隐藏。

### 3.15 鬼与鬼的物理联动

`SimGhost` 新增三种触发形态（数据字段 `kind`）：

| kind | 触发量 | 输出 |
|---|---|---|
| `topple` | 角度 ≥ `topple.topple_angle` | `strike_pending` + 冲击脉冲，砸向邻格 |
| `brace` | `support_load > 0` | 承重时按周期脉冲；同时给邻鬼一个支撑 |
| `oscillate` | `|angular_velocity| ≥ oscillate.trigger_speed` | `strike_pending` + 冲击脉冲 |

**结算顺序**（`Sim._tick_ghosts`）：

1. `_compute_brace_supports()` 先算撑鬼的支撑关系：
   - 撑鬼站着时，邻鬼的 `LeanDir` 正指向它 → 邻鬼多一个支撑；
   - 给邻鬼一个压脚的负力矩，给撑鬼自己 `support_load × support_weight` 的倾覆力矩；
   - 写 `Sim.links`（视图画连杆）。
2. 机关力矩 / 支撑数合并，所有鬼 `Step`（`pending_impulse` 在这里进角速度）。
3. `Step` 可能设置 `strike_pending`（倒下、倾倒过阈值、摆速过阈值）。
4. `TickTimers` 后统一结算所有 `strike_pending`：`_resolve_strike()` 找倒向的那一格；
   目标鬼的脚朝它 → 负冲量，背对它 → 正冲量；`pulse_on_strike` 同时发冲击脉冲。
5. `_resolve_resonance`（冲击脉冲也参与共振与充能）。

**不能破坏的**：

- 冲量必须通过 `pending_impulse` 在**下一 tick** 施加，保证与遍历顺序无关；
- 砸击只结算一次、带冷却；不要在同一 tick 递归传整条链；
- `Sim.links` 是派生数据，每 tick 重算，不要当存档状态；
- 撑鬼的支撑是「邻鬼倒向它」的几何关系，不是任意相邻都算。

**数据字段**（`Data/ghosts/*.json`）：

- `link.strike_torque`（默认 1.0；0 = 不砸）、`link.cooldown`、`link.pulse_on_strike`；
- `link.support_capacity`、`link.support_weight`（撑鬼）；
- `topple.topple_angle` / `topple.rearm_angle`（锤鬼）；
- `oscillate.trigger_speed` / `oscillate.cooldown`（摆锤鬼）。

---

## 4. 事件与视图

`SimEvents` 是唯一出口。视图**只**通过它做结构变化与特效：

| 事件 | 视图反应 |
|---|---|
| `Built` / `Removed` / `Moved` / `WorldRestored` | 全量重建实体节点（数量很小，简单可靠） |
| `EnemySpawned` / `EnemyKilled` / `EnemyBreached` | 增删魅节点 + 爆发环 |
| `GhostPulse` | 在鬼的位置播一个扩散环（射程可视化） |
| `ResonanceBurst` | 金色大环 + 横幅 + 闪光 + 镜头震动（机器共振） |
| `GhostStood` / `GhostFell` | 立正反馈 / 状态环 |
| `CrystalChanged` / `CrystalInserted` / `CrystalEjected` / `SwapperWorked` | 刷新表现 |
| `BeltDelivered` | 带面微光 / 物流节拍（当前用于表现与调试） |
| `TerritoryExpanded` | 重建领地边界、重算相机平移范围、HUD 提示「扩地 + 收编」 |
| `OutlawRazed` | HUD 提示「一处越界造物被魅拆了」 |
| `WaveStarted` / `WaveCleared` / `RunFailed` / `RunCleared` | HUD 提示与结算 |

每帧视图从 `sim.ghosts[id]` 等处**读**状态同步位置与姿态；
视图从不写入 `Sim` 的规则状态。

同一层里还有两个纯表现订阅者：

- `Sfx`：收到 `GhostPulse` / `GhostStood` / `EnemyKilled` / `RunFailed` 等事件时播放
  启动时合成好的 PCM 音效，不接触规则。
- `CameraRig.Shake()`：在漏怪、清场、失败时给一点镜头震动，同样只影响观感。

---

## 5. 数据与扩展点

| 想加什么 | 改哪里 | 要不要写代码 |
|---|---|---|
| 一只新鬼（同一种阈值类型） | `Data/ghosts/*.json` + `content.json` | 不用（换倾角 / 周期 / 振幅 / 颜色 / kind） |
| 一种新机关（已有 effect） | `Data/mechanisms/*.json` + `content.json` | 不用（换力、射程、耗能、target_period、mult） |
| 一种新传送带 / 装卸装置 | `Data/belts/*.json`、`Data/swappers/*.json` + `content.json` | 不用 |
| 新关卡 / 新波次 / 新提示 | `Data/levels/*.json` + `content.json` 的 `levels` | 不用 |
| 新的阈值**类型**（如质量差、接触时长） | `SimGhost`（加 kind）+ `Sim._tick_ghosts` | 要 |
| 新的机关**作用方式**（拉、夹、变压器） | `SimMechanism` + `Sim._tick_ghosts` 的参数改写段 | 要 |
| 新的敌人行为 | `SimEnemy` + `Sim._tick_enemies` | 要 |
| 新的物流形态（分流器、机械臂） | 新的 `Sim*` + `Sim` 的 tick 与 Build 分支 | 要 |
| 新的波次读数 / 威胁口径 | 改 `WaveMath`，HUD 与 `BalanceAudit` 自动跟上 | 要（只改一处） |
| 新的开始界面 / 面板 | 改 `Hud.gd`；夜卡从 `GameData.LevelIds()` 生成 | 不用改 Core |

扩展时优先**加数据字段**，不要加全局分支；新判定类型也应保持「一条阈值 + 一个产出」的形状。

---

## 6. 不变量（改代码时请守住）

1. **`Sim.cells` 是占用的唯一真相**；任何实体创建 / 移动 / 删除都必须同步它。
   **例外**：骑在传送带上的鬼晶不写 `cells`——带子本身占着那一格。
2. **`SimCrystal` 的位置三态互斥**：地上（`cell` 有效）/ 槽里（`slotted_in >= 0`）/ 带面（`ride_belt >= 0`）。
   任何搬运都要同时维护 `cell`、`slotted_in`、`ride_belt`，否则会出现「一颗晶在两个地方」。
3. **Core 不引用节点**。需要表现时发事件，不要 `get_node`。
4. **玩法数值只放 `Data/`**；代码里只允许「安全默认值」兜底。
5. **一切随机必须来自显式 RNG / 数据**，不要用 `randf()` 破坏可复现性。
6. **测试必须在无头环境跑通**，且不依赖 `user://`（用 `res://.godot/` 下的临时路径）。
7. **越界计数是缓存**：`outlaw_cells` / `outlaw_count` 由 `_recount_outlaws()` 从 `cells` 重算；
   建造 / 拆除 / 挪位 / 扩地之后必须调用它。
8. **威胁口径只有一份**：HUD 的「有效 HP」与 `BalanceAudit` 都走 `WaveMath.Threat()`；
   不要在 UI 里另写一套公式。
9. **手持晶只存在于 HUD**：不要在相机/世界里再挂一个「手」的 3D 图标；
   世界里的 `CrystalView` 只表示场上实体。
10. **选中格失效要清掉**：实体被拆 / 被魅啃掉 / 被回溯之后，`Main` 必须清选择与面板。
11. **鬼的物理联动**：冲量只走 `pending_impulse`（下一 tick 生效）；`strike_pending` 每 tick 只结算一次；
    `Sim.links` 是派生数据，每 tick 重算，不进存档。
12. 结构变化后跑一遍 `TestRunner`；改公式时补一条对应断言。

---

## 7. 测试策略

`Code/Tests/TestRunner.gd` 是一个自包含的迷你测试框架（无插件依赖），
`Godot --headless --path . res://Code/Tests/TestRunner.tscn`，失败退出码 1。

| 组 | 覆盖 |
|---|---|
| 内容数据 | JSON 齐全、关卡引用的定义都存在、波次字段完整、`content.json` 目录自洽 |
| 脉冲场 | 单源衰减、同相相加、反相抵消、异频能量叠加、边界归零 |
| 鬼 | 无人施力保持翘脚、被顶立正、立正即发脉冲、按周期续发、推身倒下 |
| 机关 | 每次发力扣 1 单位、耗尽停摆 |
| 充能 | 最近空晶、槽内不充、带面上的晶能充 |
| 建造 | 越界 / 占用 / 未知类型 / 未解锁 / 预算不足 / 全额退款 |
| 调场 | 鬼 / 机关 / 带子 / 装置整体挪位、旧格释放、插槽鬼晶跟随、非法目标拒绝 |
| 搬运 | 拿起 / 手满 / 放下 / 插入 / 空晶拒插 / 取出 |
| 自动化 | 搬运手把充能晶换进缺电机关、抽走 1 单位、旧晶落地、没电后再换 |
| 传送带 | 一格一秒推进、交给下一条带、尽头落地、带面晶被脉冲充能、玩家可拿 |
| 装卸臂 | 带面 → 机关（抽 1 单位）→ 空晶换出到地面 / 带面；朝向规则（背后放空晶、同向才上货） |
| 改鬼机关 | 节拍改写周期后同相叠加越线、共鸣腔放大振幅、传声筒延长射程 |
| 长撬 | 一根撬杆同时顶住两只鬼的脚 |
| 锚鬼 | 单支撑不立正、补第二支撑才立正 |
| 接力鬼 | 被脉冲扫到后延迟发射、进入冷却、链式传给下一只、活跃窗口内是波源 |
| 越界 | 领地外可建、计数、鬼屋压力、魅来拆、拆后同归于尽、无越界规则的关卡仍然拒绝 |
| 领地 | 扩圈、边界增长、越界造物被收编、事件广播 |
| 物流快照 | 带子 / 带面晶 / 越界 / 领地一起回溯 |
| 庞然大物 | 参考机器自持 60 秒：所有机关有电、带子 100+ 次搬运、清场线覆盖 80+ 格、厚甲魅王被一发抹掉 |
| 波次 | 准备倒计时、按间隔刷怪、弧段分布、击杀前不清波、清波 + 全清 |
| 节拍 | 不同时间立正的同周期鬼，相位会对齐到同一节拍 |
| 甲魅 | 护甲减免持续伤害，但清场线直接抹杀（无视护甲） |
| 魅王 | 抵达中央直接判负（不等 10 只）；清场线可秒杀；HUD 有血条 |
| 下一波预览 | 准备阶段能读到下一波的分组 / 来向 / 甲魅标记 / 鬼屋激增 |
| 关卡 | 第二夜（走廊）能载入并通过完整四波；第三夜四向小机器能走完六波；`next_level` 链与数据校验 |
| 夜间报告 | 从统计读出清场流 / 磨血流、零漏、手搬 / 自动物流 / 半自动、传送带流、越界者、收编者 |
| 夜规 | 应用预算 / 准备时间 / 禁用图纸；不改原关卡数据；奖励解锁也会被清掉 |
| 新手引导 | 默认档 `tutorial_done=false`；首次进入 4 步引导，完成后置真 |
| 机器共振 | 同 tick 振幅总和、阈值/冷却、范围伤害无视护甲、给地上晶充能 |
| 新图纸 | 摆臂鬼可建造；翘脚鬼 + 摆臂鬼同相叠加越过清场线 |
| 奖励 | 清波后预算入账、`unlock` 解锁新图纸、`expand` 扩地 |
| 失败回溯 | 满 10 只判负、回溯恢复预算 / 计数 / 清空魅 |
| 闭环 | 机关 → 鬼立正 → 脉冲 → 充能 |
| 实战 | 会换晶的脚本玩家能零漏守住第一波 |
| 一拱全爆 | 两只同相鬼中间越线，魅被直接抹杀 |
| 暂停 | 时钟冻结、仍可建造、恢复后继续 |
| 相机 | `PanDelta` 的 W/S/A/D 方向（W 朝向镜头看的方向）；`EyeDir` 的默认朝向与 pitch |
| 拆除 | 鬼可拆、全额退款、格子释放（`RemoveAt` 的 UI 入口） |
| 鬼的联动 | 锤鬼砸身体/脚的方向与冲量；撑鬼的支撑计数；锤 → 摆锤的速度触发 |
| 数值曲线 | 每夜波数、首波预算、预算不倒退、boss 波是威胁峰值、第三夜总预算放得下参考机器 |
| 存档 | 默认档、往返、v0 → 当前版本迁移 |

另外有一条**输入链**的端到端检查：`Godot --path . -- --dev-input` 会注入鼠标事件，
在窗口模式下实际走一遍「按住鬼 → 拖到另一格 → 松开」，并断言鬼的格子确实变了。
它不进 CI（需要渲染视口），但改动输入/拾取代码后应当跑一次。

窗口下的开发场景（不进 CI，用于人工验收）：

| 命令 | 检查什么 |
|---|---|
| `-- --dev-select` | 左键选中 → 面板出现 → Delete 拆除 → 预算 +10、鬼消失；再选中机关 |
| `-- --dev-held` | 拿起鬼晶时 HUD 槽位出现、放下后消失（`slot_visible=false`） |
| `-- --dev-eye` | 幽灵视角截图；按住 W 后离目标更近（`closer=4.03->1.49`） |
| `-- --dev-click-card` | 点「第二夜」卡片 → 重载 → `current_level=02`、`autostart=false`、开始界面关闭 |
| `-- --dev-link` | 锤鬼→摆锤、长撬+撑鬼→锚鬼；打印 `strikes / pend_pulses / brace_load / anchor_standing / links` |
| `-- --dev-crystal` | 按住晶拖到机关松手 → 插入；右键机关 → 取出到手上 |

---

## 8. 为什么不用刚体（Jolt）

设计要求「物理承重」。这里承重的是**力和阈值**，不是「必须用引擎刚体」：

- 用刚体做「单脚站立 → 被顶到立正」，会引入关节、接触、抖动、休眠等大量不可控因素；
- 判定阈值会变得难以复现，测试只能靠「跑一遍看看」；
- 移植与调参都会被物理引擎版本绑住。

所以鬼的姿态用**单自由度倒立摆**积分，接触用几何判定（脚 / 身两个受力点），
`push_torque = force × lever` 仍然来自数据。物理关系保留，数值确定、可测试、可调。

代价是：不能直接得到「多体碰撞、堆叠、倾倒」的涌现。
后续要做「连锁失稳 / 重心转移」时，应把它做成**另一个显式的多体模型**，
而不是把规则偷偷迁进刚体引擎。

---

## 9. 性能与开销

- 13×13（第三夜 23×23）网格、20 Hz 逻辑、5 Hz 热力图；单帧模拟远低于 1 ms（本机无压力测试，按结构估算）。
- 热力图每 0.2 s 采样 `width × height` 个点 × 少量波源，重建一张单通道贴图（23×23 = 529 点）。
- 越界目标查找只在 `_recount_outlaws()` 重建的 `outlaw_cells` 上做线性扫描，数量很小。
- 实体节点在结构变化时全量重建（几十个节点），换取实现简单与状态一致。
- 选中面板只在可见时每帧刷新；幽灵视角里跳过地面拾取与光标预览。
- 脉冲环用对象池 + 单个 shader 平面，不产生大量临时节点。
- 音效在启动时合成一次（12 个音，合计不到 2 秒 PCM），之后只复用
  `AudioStreamPlayer` 池；没有音频文件、没有运行时合成开销。

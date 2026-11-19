# 内容手册：怎么加鬼、加机关、加关卡

> 目标：**加内容不改代码**。所有玩法数值只在 `res://Data/` 下。
> 改完跑一遍 `TestRunner`；`GameData.Validate()` 会把缺字段 / 引用不到的定义直接报出来。

---

## 0. 目录约定

```
Data/
  game.json               全局调参
  content.json             建造栏顺序 + 关卡列表（新内容必须在这里登记）
  ghosts/<id>.json         鬼
  mechanisms/<id>.json     鬼能机关
  belts/<id>.json          传送带
  swappers/<id>.json       搬运手 / 装卸臂
  crystals/<id>.json       鬼晶
  levels/<id>.json         关卡
```

文件名必须等于 `id`（例：`ghosts/waver.json` 里 `"id": "waver"`）。
关卡通过 `unlocks` 声明本关允许的图纸；建造时按 `type_id` 找定义。
**新内容要同时加进 `Data/content.json`**，否则 HUD 建造栏里不会出现。

---

## 1. 鬼 `Data/ghosts/<id>.json`

```json
{
  "id": "waver",
  "name": "翘脚鬼",
  "proverb": "它只肯在站直的那一瞬干活。",
  "role": "被动 · 力阈值",
  "cost": 10,
  "geometry": {
    "body": [0.62, 1.02, 0.46],
    "color": "#79d4ff",
    "glow": "#c8f2ff"
  },
  "tilt": {
    "rest_angle": 0.58,
    "stand_angle": 0.13,
    "hysteresis": 0.10,
    "gravity": 5.6,
    "stop_stiffness": 9.0,
    "damping": 3.2,
    "inertia": 1.0
  },
  "contact": {
    "foot_offset": 0.42,
    "body_offset": 0.0,
    "foot_radius": 0.16,
    "body_radius": 0.30,
    "topple_factor": 1.25
  },
  "pulse": {
    "amplitude": 1.0,
    "period": 2.0,
    "range": 6.0,
    "charges_per_pulse": 1,
    "charge_amount": 2.0
  }
}
```

| 字段 | 含义 | 调它会发生什么 |
|---|---|---|
| `cost` | 预算造价 | 只影响建造 |
| `geometry` | 程序化模型尺寸与颜色 | 纯表现 |
| `geometry.style` | `lean`（图腾）或 `swing`（摆臂） | 纯表现；`swing` 会画立杆 + 配重 |
| `tilt.rest_angle` | 没人顶时停住的角度（翘脚） | 越大越「歪」、越难顶回 |
| `tilt.stand_angle` | 判定「立正」的阈值 | 越小越难触发 |
| `tilt.hysteresis` | 立正后掉出的迟滞带 | 越小越容易一抖就倒 |
| `tilt.gravity` | 失稳力矩 | 越大越难顶 |
| `tilt.stop_stiffness` | 脚撑刚度 | 越大翘脚姿态越硬 |
| `tilt.damping` / `inertia` | 阻尼 / 转动惯量 | 影响响应速度 |
| `contact.foot_offset` | 翘起那只脚离格子中心多远 | 决定机关要摆哪一格 |
| `contact.foot_radius` / `body_radius` | 两个受力点的判定半径 | 越大越容易顶到 |
| `contact.topple_factor` | 顶到身体时的放大系数 | 越大「放歪」惩罚越狠 |
| `pulse.amplitude` | 单只鬼的脉冲强度 | 直接进场的公式 |
| `pulse.period` | 固有周期（秒） | **相同周期才会相干干涉** |
| `pulse.range` | 射程（格） | 衰减到边缘归零 |
| `pulse.charges_per_pulse` | 一次脉冲给几颗晶充能 | 目前只认 1 |
| `pulse.charge_amount` | 一次充多少单位 | 和机关耗能一起决定闭环松紧 |

**新鬼的数值建议：** 先复制 `waver.json`，只改 `period`（比如 2.0 → 2.6）。

### 1.2 阈值形态：`kind`

| kind | 阈值 | 用在哪 | 额外字段 |
|---|---|---|---|
| `tilt`（默认） | 倾角 ≤ `stand_angle` 就立正 | 翘脚鬼 / 摆臂鬼 / 守夜钟 / 低鸣鬼 / 提灯鬼 | 无 |
| `multi` | 倾角够直**且**同时有 `contacts_required` 个支撑（机关 / 撑鬼）顶住脚 | 锚鬼 | `tilt.contacts_required` |
| `relay` | 不站；被别的脉冲扫到时迟 `delay` 秒再发一次，然后进 `cooldown` 冷却 | 接力鬼 | `relay.delay` / `relay.cooldown` |
| `topple` | 角度 ≥ `topple_angle`（被推倒）才触发；砸向邻格 | 锤鬼 | `topple.*` / `link.strike_torque` |
| `brace` | 不靠角度触发；`support_load > 0`（撑着邻鬼）时才按周期发脉冲 | 撑鬼 | `link.support_capacity` / `link.support_weight` |
| `oscillate` | `abs(角速度) ≥ trigger_speed` 才触发；不站也不倒 | 摆锤鬼 | `oscillate.trigger_speed` / `oscillate.cooldown` |

**接力鬼**不需要机关，但它只会被同场地的脉冲触发：它充当「波源中继」，摆法决定清场区能推多远。链式接力每 tick 只传一跳，不会在同一帧里无限递归。

**锚鬼**需要「两个支撑」这一条是真的数支撑：长撬（`crank`）算一个、顶足机关算一个、**撑鬼也算一个**；一根撬杆顶两只鬼时，两只各算一个支撑。

**锤鬼**要顶在它**背后**（朝它身体推）才会倒；它倒向哪一格，就砸哪一格，砸完回弹。砸到目标鬼的脚 → 帮它立正；砸到身体 → 把它推倒。

**撑鬼**要放在「被撑的鬼倒向的一侧」：邻鬼的 `facing` 指向撑鬼，才算撑住。撑鬼自己会被承重拉倒；超载就会失去支撑。

**摆锤鬼**不会自己动：它要挨一下（锤鬼砸、别的鬼倒下砸到它），才会荡起来；`|ω|` 过阈值才发脉冲。

### 1.2.1 鬼与鬼的物理层（所有 kind 通用）

- **倒下砸邻格**：`link.strike_torque`（默认 1.0，0 = 不砸）；砸脚 = 负冲量，砸身 = 正冲量；
- **支撑**：撑鬼的支撑计入邻鬼的 `contacts_required`，并在视图里画一条连杆；
- **连锁**：被砸的鬼可能倒下，再砸下一只；冲量下一 tick 才生效，保证确定性；
- **冷却**：`link.cooldown` 防止同一只鬼每 tick 都砸。

做联动关卡时，先画一条「力」的路径：机关 → 锤鬼 → 摆锤 → 脉冲；或 锚鬼 ← 撑鬼 ← 自己的顶足机关。路径上的每一格都要能站人、朝向要对。

### 第二个例子：摆臂鬼（同频、近距、高振幅）

```json
{
  "id": "swing",
  "name": "摆臂鬼",
  "proverb": "它和邻居踩同一个拍子——摆在哪里，比摆几只更重要。",
  "cost": 14,
  "geometry": {
    "style": "swing",
    "body": [0.5, 1.28, 0.4],
    "color": "#ffb86b",
    "glow": "#ffe2b8"
  },
  "tilt": {
    "rest_angle": 0.72, "stand_angle": 0.11, "hysteresis": 0.09,
    "gravity": 4.6, "stop_stiffness": 7.5, "damping": 2.6, "inertia": 1.15
  },
  "contact": {
    "foot_offset": 0.40, "body_offset": 0.0,
    "foot_radius": 0.15, "body_radius": 0.26, "topple_factor": 1.1
  },
  "pulse": {
    "amplitude": 1.25, "period": 2.0, "range": 4.5,
    "charges_per_pulse": 1, "charge_amount": 2.0
  }
}
```

它和翘脚鬼**周期相同**，所以两只的脉冲会相干叠加：

- 摆在一起、到目标的距离接近 → 振幅相加，容易顶过清场线；
- 摆得让两束波到目标时差半个周期 → 互相抵消，热力图反而变冷。

这就是「加鬼不一定变强」的来源，不需要任何额外的规则表。
两只鬼摆在一起时，异频会得到「拍频」——功率忽高忽低，但不会互相抵消，
这是最容易让玩家**看见**干涉的教学方式。

> 想要全新的阈值类型（支撑点数、质量差、接触时长……），需要在
> `SimGhost.Configure` / `SimGhost.Step` / `Sim._tick_ghosts` 里加状态与判定；
> 仍然保持「一条阈值 + 一个产出」的形状，不要引入组合规则表。

---

## 2. 鬼能机关 `Data/mechanisms/<id>.json`

```json
{
  "id": "pusher",
  "name": "顶足机关",
  "proverb": "得电才肯顶。顶错了地方，它会把人推倒。",
  "role": "独立机关 · 把鬼能变成力",
  "cost": 6,
  "reach": 0.62,
  "force": 12.0,
  "lever": 0.45,
  "push_period": 2.0,
  "energy_per_push": 1.0,
  "head_radius": 0.22,
  "geometry": {
    "base": [0.78, 0.32, 0.78],
    "rod_radius": 0.085,
    "color": "#c9a06a",
    "slot_color": "#5be0c0"
  }
}
```

| 字段 | 含义 | 备注 |
|---|---|---|
| `reach` | 顶杆伸出多远（格） | 决定「要隔一格还是贴脸」 |
| `force` × `lever` | 施加的力矩 | 必须大于鬼的失稳力矩，否则顶不动 |
| `push_period` | 每多少秒扣 1 单位鬼能 | 与脉冲补给速度共同决定持续能力 |
| `energy_per_push` | 每次扣多少 | 目前为 1 |
| `head_radius` | 头部判定半径 | 与鬼的 `foot_radius` / `body_radius` 相加 |
| `geometry` | 纯表现 | |

**机关是「独立装置」**：它不属于某只鬼，一台机器可以顶到任何进入它头部的鬼。
这也是后续做「一根顶杆撑两只鬼」的基础。

### 2.2 作用方式：`effect`

| effect | 作用 | 关键字段 | 例子 |
|---|---|---|---|
| `push`（默认） | 顶住一只鬼的脚 / 身体 | `reach`、`force`、`lever`、`head_radius` | 顶足机关 |
| `crank` | 沿朝向的一条线段顶脚，可同时顶多只 | `reach`、`min_reach`、`head_radius` | 长撬机关 |
| `tune` | 把半径内鬼的周期改写成 `target_period` | `target_period`、`effect_radius` | 节拍机关 |
| `amp` | 放大半径内鬼的脉冲振幅 | `amplitude_mult`、`effect_radius` | 共鸣腔 |
| `reach` | 延长半径内鬼的射程 | `range_mult`、`effect_radius` | 传声筒 |

- 所有 effect 都吃同一个插槽与同一个耗能周期（`push_period` / `energy_per_push`）；
- `tune` / `amp` / `reach` **只在有电时生效**，失电立刻还原——所以「改鬼的机关」自己也要喂；
- 多个同类机关叠在同一只鬼身上会相加，但有 `game.json` 的 `effect_amp_cap`（默认 2.2）与 `effect_range_cap`（默认 2.4）封顶。

### 2.5 传送带 `Data/belts/<id>.json`

```json
{
  "id": "belt",
  "name": "传送带",
  "cost": 4,
  "speed": 1.0,
  "capacity": 1,
  "geometry": { "color": "#6d7f96", "stripe": "#a8e6ff" }
}
```

| 字段 | 含义 |
|---|---|
| `speed` | 每 1/speed 秒推进一格；`express` 是 2.2 |
| `capacity` | 带面能停几颗晶；`express` 是 2 |

**规则**：只往前送；前方是空地、另一条有空位的带子、或空槽机关才送得出去，否则堵住。
带面上的鬼晶**可以被脉冲充能**（它仍是场上的容器），但不占 `cells`。

### 2.6 装卸臂 `Data/swappers/arm.json`

```json
{
  "id": "arm",
  "source": "belt",
  "service_radius": 3.2,
  "crystal_radius": 2.6,
  "belt_radius": 2.1,
  "swap_period": 1.1,
  "drain": 1.0
}
```

有朝向（`facing`，建造时按 `R` 转）。每个 `swap_period` 做一个动作，优先级：

1. **交换**：槽里是空晶 → 挪到背后带 / 空地，同时从正前方带（其次地面）取充能晶塞回槽；
2. **上料**：空槽 → 从正前方带（其次地面）取充能晶；
3. **卸料**：带面上的空晶 → 卸到附近空地（让鬼去充）；
4. **装带**：地面的充能晶 → 放上「和自己同向走」的带子（去程带）。

每次搬运从被搬的晶里抽走 `drain`。摆反了方向它就不工作——这是刻意的。

---

## 3. 鬼晶 `Data/crystals/<id>.json`

```json
{
  "id": "crystal",
  "name": "鬼晶",
  "proverb": "装的是鬼能，壳留下。",
  "role": "容器 · 一次充能 1 单位",
  "cost": 3,
  "capacity": 5,
  "geometry": { "radius": 0.22, "height": 0.46, "color": "#4fe0c4" }
}
```

`capacity` 是单颗容器上限。容量越大，换晶频率越低；同时空地堆放的成本也越高（占格、造价）。

---

## 3.5 搬运手 `Data/swappers/<id>.json`
```json
{
  "id": "hand",
  "name": "搬运手",
  "proverb": "它不生产鬼能，只是把晶挪个地方——顺手抽走一点。",
  "role": "自动化 · 自动换晶",
  "cost": 8,
  "service_radius": 1.7,
  "crystal_radius": 2.6,
  "swap_period": 2.5,
  "drain": 1.0,
  "geometry": { "base": [0.66, 0.24, 0.66], "arm": 0.46, "color": "#8fb7c9", "claw_color": "#5be0c0" }
}
```

| 字段 | 含义 |
|---|---|
| `service_radius` | 机关离它多近才会被服务（格） |
| `crystal_radius` | 在地上找充能晶的半径（格） |
| `swap_period` | 两次换晶之间的间隔（秒） |
| `drain` | 每次搬运抽走的鬼能（损耗） |

**行为规则**（`Sim._tick_swappers`）：

1. 每 `swap_period` 秒，找 `service_radius` 内最缺电的机关（槽空或存量 < 1）。
2. 在 `crystal_radius` 内找最近的一颗「地上、存量 ≥ 1 + drain」的鬼晶。
3. 把它换进机关；槽里的空晶落到那颗晶原来的格子；没有空晶时旧格直接空出。
4. 搬运抽走 `drain` 单位——所以自动化永远比手搬更费能量。

它不会移动、不占机关槽、也不能被拖动。它让玩家从「每 10 秒手动换一次」里解放出来，
但要多花 8 预算和 1 格空间，并且持续损失鬼能。

---

## 3.9 夜规 `Data/modifiers.json`

```json
{
  "modifiers": [
    { "id": "tight", "name": "紧箍", "desc": "预算 -30%", "budget_mult": 0.7 },
    { "id": "solo", "name": "孤军", "desc": "没有搬运手，只能手搬", "disable": ["hand"] },
    { "id": "rush", "name": "催命", "desc": "准备时间 -40%", "prep_mult": 0.6 }
  ]
}
```

| 字段 | 含义 |
|---|---|
| `budget_mult` | 关卡预算倍率（默认 1） |
| `prep_mult` | 每波准备时间倍率（默认 1） |
| `disable` | 禁用的 `type_id` 列表；会同时从初始解锁和奖励解锁里移除 |

夜规只在 `LevelModifier.Apply()` 里改关卡数据（深拷贝，原 JSON 不动），改完照样交给
`Sim.Setup`——**模拟层不知道夜规存在**。结算面板的「换约束重打」会按列表顺序轮换，
HUD 标题会显示「第一夜 · 翘脚 · 紧箍」，副标题显示具体约束。

调试时可以直接带夜规进入：`Godot --path . -- --level=01 --modifier=tight`。

---

## 4. 关卡 `Data/levels/<id>.json`

```json
{
  "id": "01",
  "name": "第一夜 · 翘脚",
  "subtitle": "魅从四面来 · 守住中央",
  "next_level": "02",
  "grid": { "w": 13, "h": 13 },
  "buildable": { "x": 1, "y": 1, "w": 11, "h": 11 },
  "center_radius": 1.6,
  "spawn_radius": 8.0,
  "max_breaches": 10,
  "budget": 80,
  "unlocks": ["waver", "pusher", "crystal"],
  "initial": [
    { "kind": "ghost", "type": "waver", "cell": [3, 8], "facing": 0 }
  ],
  "initial_crystals": [
    { "cell": [5, 8], "charge": 5 },
    { "cell": [5, 6], "charge": 5 },
    { "cell": [3, 6], "charge": 0 }
  ],
  "hints": [
    { "when": "no_mechanism", "text": "把一台顶足机关摆到翘脚鬼翘起的那只脚边（R 键转朝向），它才顶得到。" }
  ],
  "waves": [
    {
      "prep": 30.0,
      "groups": [
        { "count": 2, "interval": 2.5, "center_deg": 180, "arc_deg": 0, "hp": 40, "speed": 0.50 }
      ]
    }
  ],
  "rewards": [ { "budget": 20 } ]
}
```

| 字段 | 含义 |
|---|---|
| `grid` | 场地格子数；格子中心以场地中心为原点 |
| `buildable` | 允许建造的矩形（格子坐标） |
| `center_radius` | 中央保护区半径（世界单位）；魅进入即计数 |
| `subtitle` | HUD 标题下的小字 |
| `next_level` | 通关后「下一夜」指向的关卡 id；空 = 到此为止 |
| `start_zoom` | 可选，开局相机档位（0 近 … 4 远）；宽场地用 2~3 |
| `spawn_radius` | 刷怪圆半径（世界单位） |
| `max_breaches` | 漏多少只判负 |
| `allow_outlaw` | 是否允许在领地外建造（第三夜 = true） |
| `expand_per_wave` | 每清一波领地向外扩几圈（第三夜 = 1） |
| `outlaw_pressure` | 每处越界造物给每个刷怪组多加多少只（第三夜 = 0.5，四舍五入） |
| `aggro_radius` | 魅在多大范围内会去啃越界造物 |
| `outlaw_attack_time` | 啃掉一处越界造物要多久（秒） |
| `budget` | 初始预算 |
| `unlocks` | 本关允许建造的 `type_id` |
| `initial` | 免费预置的建筑（`kind`: ghost / mechanism / crystal） |
| `initial_crystals` | 预置鬼晶与初始存量 |
| `hints` | 教程提示，按 `when` 条件取第一条匹配 |
| `waves` | 波次表，按顺序推进 |
| `rewards` | 每波清空后的奖励（预算 / `unlock` / `expand`） |

**越界与扩地**（只有 `allow_outlaw` 的关卡生效）：

- 领地内随便建；领地外也能建，但每一处鬼 / 机关 / 带子 / 臂都算「越界造物」（鬼晶不算）；
- 魅会优先走向仇恨半径内最近的越界造物，啃 `outlaw_attack_time` 秒后把它拆掉（不退款），自己也同归于尽；
- 每处越界造物让每个刷怪组多刷 `outlaw_pressure` 只（`round` 取整），HUD 显示「鬼屋激增 +N/组」；
- 每波奖励的 `expand`（没写就用关卡的 `expand_per_wave`）把领地向外扩；新圈进来的造物被**收编**，从此不再引鬼。

**内容目录** `Data/content.json`：

```json
{
  "levels": ["01", "02", "03"],
  "entries": [
    { "kind": "ghost", "id": "waver", "hotkey": "1" },
    { "kind": "belt", "id": "belt", "hotkey": "B" }
  ]
}
```

`entries` 的顺序就是 HUD 建造栏的顺序；`hotkey` 是可选的单字符，`Main` 会把它绑到键盘上。新增任何内容都要在这里加一行，`GameData.Validate()` 会检查引用的定义是否存在。

**多个关卡**：`next_level` 串成一条链（01 → 02）。通关时 HUD 直接把下一夜的名字写在按钮上，
点一下就把 `current_level` 写进存档并重载场景。新关卡只需要一个 JSON + 把上一关的
`next_level` 指过来；`GameData.Validate()` 会检查 `next_level` 是否存在。

**场地形状**：`buildable` 只是一个矩形，`grid` 可以更大——第二夜就是 15×9 的场地里
只给一条 13×3 的走廊。想让相机开局就装得下宽场地，设 `start_zoom: 2`。

**难度调参**：优先动 `prep`（准备时间）和 `budget`，最后才动 `hp` / `armor`。
第一夜现在按“先教会、再为难”调：预算 90、准备 35/30 秒、魅王 280 血 / 0.17 速；
第二夜保留走廊的空间压力。夜规只在此基础上加约束，不改基础数值。

**机器共振**（`Data/game.json`）：同一 tick 里 ≥2 只鬼、振幅总和 ≥ `resonance_threshold`
时触发一次范围爆发，伤害 `resonance_damage × 总和`，半径 `resonance_radius`，
冷却 `resonance_cooldown` 秒，没脉冲时蓄能按 `resonance_decay` 衰减，
并给地上可充能鬼晶 +`resonance_charge_amount`。阈值调低会让爆发更频繁；
先调 `resonance_damage`，再动阈值。

### 波次组

| 字段 | 含义 |
|---|---|
| `count` | 这一组刷几只 |
| `interval` | 组内间隔（秒） |
| `center_deg` | 刷怪弧的圆心角（0 = +X 东，90 = +Z 南，180 = -X 西，270 = -Z 北） |
| `arc_deg` | 弧宽；`0` = 单点；`360` = 均匀铺满一圈 |
| `hp` / `speed` | 单只魅的血量与速度（格/秒） |
| `armor` | 可选，普通脉冲伤害的系数（1 = 无减免，0.4 = 只吃 40%）；**清场线无视它** |
| `boss` | 可选，`true` = 魅王：HUD 显示血条，抵达中央直接判负 |
| `radius` | 可选，覆盖 `spawn_radius` |

`armor < 0.8` 的组会在 HUD 里标成「甲魅」，场地上的准备阶段信标变成琥珀色。
HUD 的「下一波」会自动拼出来向 + 种类 + 数量，所以**改了波次数据，预览会自己跟上**，
不需要另外维护一份预告文案。

常用组合：

| 想要的效果 | 写法 |
|---|---|
| 疾魅冲脸 | `speed: 0.95, hp: 22, armor: 1` |
| 厚魅磨血 | `hp: 150, speed: 0.35` |
| 甲魅逼清场线 | `hp: 130, speed: 0.4, armor: 0.4` |
| 四面均匀 | `arc_deg: 360` |
| 单路压境 | `arc_deg: 0, center_deg: 270`（北） |

奖励里的 `"unlock": "hand"` 会在清波后解锁搬运手（`Data/swappers/hand.json`）。
解锁是永久的，回溯不会收回。

### 魅王

`"boss": true` 的组会：

- 在 HUD 顶部显示血条（`魅王 HP / Max`）；
- 预览里标成「魅王」，场地信标变成金色大信标；
- **抵达中央直接判负**，不等累计 10 只。

一个关卡最好只放一个 boss 组，并且让它走一条玩家能用清场线覆盖的路线：
它的血厚、护甲高、速度慢，正常脉冲只能磨，清场线才是干脆的答案。

### 提示条件

目前支持五种 `when`：

| 值 | 触发条件 |
|---|---|
| `no_mechanism` | 场上还没有机关 |
| `no_power` | 有机关，但没有任何有电的鬼晶（槽内、地上或带面上） |
| `outlaw` | 有越界造物（只在 `allow_outlaw` 关卡出现） |
| `swing_available` | 已解锁摆臂鬼但还没造 |
| `resonance` | 两只以上鬼、共振蓄能到一半 |
| `default` | 其它情况（通常写「读热力图」类提示） |

---

## 4.5 自持产线怎么搭（第三夜参考流程）

一条能自己转的产线，最少需要三样东西：**鬼能泵**、**往返两条带**、**装卸臂**。

1. **鬼能泵**：两只低鸣鬼各配一台顶足机关。低鸣鬼一次给 2 颗晶各充 3 点，是最快的充能来源。
2. **往返两条带**：去程（`express`，朝向产线）把充好的晶送到机关；回程（`belt`，朝向鬼屋）把空晶送回来。两条带必须方向相反，否则会堵。
3. **装卸臂**：核心一侧的臂面朝去程带、背对回程带（这样它只吃来料、只把空晶放到回程）；鬼屋一侧的臂面朝去程带，负责把地面充好的晶送上带、把回程带的空晶卸到地上。
4. **两个晶轮换**：机关槽里那颗在用的时候不能被脉冲充能，所以每台机关至少需要「一颗在用 + 一颗在充」。
5. 先跑 `Test_Behemoth`（或 `--dev-behemoth`）确认你的产线数值能自持，再放进关卡。

**为什么不能只造一条带**：带子只往前，去程带送过去的空晶回不来；要么再铺一条回程带，要么让装卸臂把空晶卸到地上、再由另一只臂重新上带——后者就是「物流管理」这道题本身。

---

## 4.6 数值曲线怎么调（玩家能自己算）

所有「下一波」的读数只有一个口径，写在 `Code/Core/WaveMath.gd`：

```
有效 HP = Σ 数量 × 血量 ÷ 护甲 × (0.7 + 速度)
```

- HUD 的「下一波」、`BalanceAudit`、`Test_BalanceCurve` 都用它，改公式只改一处；
- 它不是伤害公式，只是给玩家做预算取舍的估算；玩家看到的「有效 HP」「清波奖励」「开波预算」可以直接对账。

调曲线的步骤：

1. 跑 `Test_BalanceCurve`（或 `BalanceAudit.Format()`）打印每波「有效 HP / 开波预算 / 奖励」；
2. 检查四条硬规则：
   - 第一波预算够起手（当前门槛 60）；
   - 开波预算只涨不跌；
   - **boss 波是本夜有效 HP 的峰值**；
   - 第三夜总预算 ≥ 参考机器成本（约 305）。
3. 如果某波有效 HP 跳得太高，先调 `count / hp / armor`，再调奖励；不要只加预算——
   预算加太多会让「摆什么」失去取舍。
4. 改完重跑 `Test_FullRun` / `Test_Level02` / `Test_Level03Run`，确认脚本玩家还能通关。

当前曲线见 `GameDesign.md` §17.1。第三夜的第四波是**有意的喘息波**，不要「修」成和前后一样重。

---

## 5. 关卡设计检查清单

1. **第一波的方向**要和预置鬼的位置对得上，否则教学关无解
   （有 `Test_WaveOneSurvives` 兜底：会换晶的脚本玩家必须能零漏守住第一波）。
2. **甲魅不能全波都是**：至少留一组普通/疾魅，否则玩家只能被迫摆清场线，
   失去了「覆盖 vs 叠加」的取舍；最好让甲魅走单路，逼玩家在准备阶段把它读出来。
3. **波次之间要换边**：同一方向连续来两波，玩家就不需要动布局了。
4. **预算**要刚好让玩家在「第二只鬼 / 第二台机关 / 更多晶」之间做一次取舍。
5. **清场线**要留出「两只同相才够」的空间：单只鬼峰值 1.0，清场线 1.45 左右。
6. 新波次的方向要逼玩家改布局，而不是加数量。
7. **大地图关**（`allow_outlaw`）：越界压力系数与扩地速度要一起调。扩张太快 = 没有风险，
   太慢 = 玩家永远在 5×5 里摆；第三夜目前是「每波 +1 圈、每处越界 +0.5 只/组」。
8. **改鬼机关**（tune / amp / reach）要么给足供能、要么放在玩家够得着的地方；
   它们失电会立刻还原参数，玩家会立刻看到「场塌了」。
9. **数值曲线**：改完波次先跑 `Test_BalanceCurve` 对账（首波预算、预算不倒退、boss 峰值、第三夜总预算）。
10. 改完数值先跑测试，再跑 `--dev-shot` / `--dev-shot3` / `--dev-behemoth` 看热力图与手感。

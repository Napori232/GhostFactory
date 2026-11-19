
===== USER #1 =====
The user changed the approval policy from "ask the user for approval" to "never ask the user for approval".

===== USER #2 =====
<goal_round>
Objective: "丰富鬼和鬼能机关。她应该是在一个大地图里不断拓展空间，超过这个空间的造物会被怪物集火，同时鬼屋数量激增。她本质上就一个大地图，但是需要不断的抵御。每过一个波次就会给一些新的鬼和成本、\n第二个她的机关应该是紧密相连的，需要传送带去做物流管理的一个机关的鬼能被用过之后不能再用只能等下一个鬼能就是需要这一份物流管理的和机关设计的，不然这个游戏没有意思了，填充着部分的内容，你要证明这个机关和鬼的内容的上限，就是根据这些乱七八糟的东西可以造出来一个精密的庞然大物，你设计的时候先实践一下行不行，然后有些鬼和机关的存在可以提高效率改动之前的鬼。\n就是让这个游戏变得好玩。\n好玩的点在于上限非常高的自由搭建\n搭完之后清怪的爽感\n新的鬼或者机关带来的尤米尔时刻。\n\n让这个游戏变得好玩，你可以设计新的内容，修改微量的系统再不是本味的情况下，我给你极高的权限，"
Round: 1/256

Continue working toward the objective in this same session. Treat the current workspace, tool results, and durable session state as authoritative; inspect them instead of assuming earlier narration is still current. Make concrete progress and verify the result. Before claiming completion, gather evidence that the whole objective is achieved, read the current goal, and mark it complete. If work remains, leave the goal active for the next round. Follow the configured goal-tool policy before reporting a blocker.
</goal_round>

===== USER #3 =====
<system-reminder>
The following workspace instructions may be relevant to your work. Use them as guidance when applicable. More specific instructions take precedence over broader ones. They do not override system, developer, or direct user instructions.

Instructions from: AGENTS.md

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
2. `SimCrystal.slotted_in` 与 `SimMechanism.crystal_id` 必须成对更新；
   删除机关时要把槽里的晶落到地上，否则会丢晶。
3. 快照 / 恢复必须保留实体 `id`，否则插槽引用会断。
4. 视图在 `WorldRestored` 后必须全量重建；不要试图增量修复。
5. 测试不要写 `user://`（本机可能不可写）；临时文件放 `res://.godot/` 下。

## 5. 性能边界

- 逻辑 20 Hz；热力图 5 Hz；不要在每个 `_process` 里重算场。
- 实体节点数量很小（几十个），结构变化时全量重建是可接受的。
- 新增每帧计算前，先想清楚是否能用「事件 + 缓存」。

## 6. 加东西的路径

| 想加 | 正确做法 |
|---|---|
| 新鬼（同类型阈值） | 只加 `Data/ghosts/*.json` |
| 新机关（同类型「顶」） | 只加 `Data/mechanisms/*.json` |
| 新搬运手（同类型换晶） | 只加 `Data/swappers/*.json` |
| 新关卡 / 波次 | 只加 `Data/levels/*.json`，并把上一关的 `next_level` 指过来 |
| 新夜规 | 只加 `Data/modifiers.json` 条目 |
| 新阈值类型 | 改 `SimGhost` + `Sim._tick_ghosts`，补测试 |
| 新机关作用方式 | 改 `SimMechanism` + `Sim._tick_mechanisms`，补测试 |
| 新视图 | 新建 `Code/Game/Views/*View.gd`，在 `WorldView` 里注册，不改 Core |
| 新 UI 面板 | 改 `Hud.gd`，数据从 `Sim` 公开字段读 |

## 7. 已废弃 / 别碰

- `ghost-factory/`：最初的空骨架，已被 `.gdignore` 排除（原因见其 `SUPERSEDED.md`）。
- `_acl-recovery/`、`_newtest/`、`_wtest.txt`：本机排查沙箱权限留下的临时物，可删。
- `Core/SimGrid.gd`（如果还存在）：误建的空占位，真正实现在 `Code/Core/SimGrid.gd`。

</system-reminder>

===== USER #4 =====
Current runtime context. This snapshot supersedes earlier runtime-context snapshots.

Current working directory: "D:\\GhostFactory_deep".

Current DSH file policy: danger-full-access. The DSH file sandbox does not restrict file modifications by available operations.

Approval prompts are disabled in this session: actions that require approval are rejected automatically — do not request sandbox escalation (do not set `sandbox_permissions`).

Current DeepSeek Harness implementation checkout: "C:\\Users\\Napori\\AppData\\Local\\Programs\\DeepSeek Harness\\resources\\app.asar\\dsh\\".

Current DeepSeek Harness Web GUI URL: "http://127.0.0.1:50212".

===== USER #5 =====
<system-reminder>
A skill is a reusable set of task-specific instructions. The following skills are available in this session:

<available_skills>
- `diagnose-windows-sandbox-acl`: Use on Windows for unexpected DSH sandbox access denials: workspace writes or listing fail, or an ordinarily readable path cannot be read. One bundled command inspects the path and every ancestor and repairs the ACL problems it proves in that same run. Expected confinement denials need no ACL repair.
- `lark-approval`: 飞书审批：查询和处理审批待办/已办/实例，搜索可发起审批定义、查看定义详情并发起原生审批实例。当用户要处理审批任务、查看审批实例、搜索或发起审批时使用。审批待办不是飞书任务；非审批类待办走 lark-task。不负责创建审批定义；三方审批定义不走原生提单。
- `lark-apps`: 妙搭（Spark/Miaoda）应用开发与托管：应用创建、本地全栈开发、云端生成迭代、创意设计（UI mockup / 可交互原型 / 线框图 / 落地页 / 仪表盘 / 幻灯片 deck / 视觉探索）、AI相关能力和飞书平台能力或者其他外部能力集成、日志/Trace/监控指标/PV/UV 查询、环境变量管理、应用协作者与协作权限设置、应用角色与成员管理、自动化触发器（定时/记录变更/Webhook/飞书审批）。当用户要开发/新建一个系统·工具·平台·应用，或要本地开发 / 云端开发 / 修改 / 部署 / 发布 / 上线 / 拿可分享链接，或用 HTML 做页面·网站·部署到妙搭，或要设计 / design / mockup / prototype / wireframe / 做 PPT / deck / 视觉探索，或提到妙搭/Spark/Miaoda（应用运行时域名形如 *.aiforce.cloud）、应用数据库、应用文件存储、开放 API Key、可见范围、应用协作者/开发权限、应用角色/角色成员、线上日志、接口请求量、错误量、延迟、访问量、环境变量、给妙搭应用配自动化...
- `lark-attendance`: 飞书考勤打卡：查询自己的考勤打卡记录
- `lark-base`: 飞书多维表格（Base）操作：建表、字段、记录、视图、统计、公式/lookup、表单、仪表盘、应用模式（BaseApp/AppMode 页面与组件）、Workspace 目录、workflow、角色权限、模板中心（多维表格模板分类/列表/搜索）；遇到 Base/多维表格/bitable、BaseApp/AppMode、/base/ 或 /app/ 链接时使用。BaseApp 不走 lark-apps；文件导入/导出转 lark-drive，认证/授权转 lark-shared。
- `lark-calendar`: 飞书日历：管理日历日程和会议室。查看/搜索日程、创建/更新日程、管理参会人、查询忙闲和推荐时段、预定会议室。当用户需要查看日程安排、创建/修改会议、查询/预定会议室时使用。不负责：查询过去的视频会议记录（走 lark-meeting）、待办任务（走 lark-task）。
- `lark-contact`: 飞书 / Lark 通讯录:按姓名 / 邮箱解析成 open_id,或按 open_id 反查姓名 / 部门 / 邮箱 / 联系方式 / 个人状态 / 签名,以及按关键词搜索当前用户可见的机器人 / 智能体(agent)。当用户提到一个名字要下一步发消息 / 排日程,或拿到 open_id 想查具体信息时使用。不负责部门树遍历、按部门列员工、组织架构图,这类需求走原生 OpenAPI。
- `lark-doc`: 飞书云文档（Docx / Wiki）内容操作：读取、创建、编辑文档，插入或下载图片附件，以及操作思维笔记。用户提供文档 URL/token（包括 doubao.com 的 /docx/、/wiki/）时使用；按 URL 路径/token 而非域名路由。文档内嵌资源按读取参考中的统一规则分流。独立评论操作走 lark-drive；随正文读取评论使用 docs +fetch。表格或 Base 内部数据操作不在本 skill。
- `lark-drive`: 飞书云空间（云盘/云存储）：管理 Drive 文件和文件夹，包含上传/下载、创建文件夹、复制/移动/删除、查看元数据、查询权限设置、评论/权限/订阅、标题、版本、飞书文档密级标签（secure labels）和本地文件导入。用户需要整理云盘目录、处理云空间资源 URL/token、判断链接类型/真实 token/标题，或导入 Word/Markdown/Excel/CSV/PPTX/.base 为 docx/sheet/bitable/slides 时使用；doubao.com 云空间 URL/token 也按资源路径和 token 路由，不回退 WebFetch。不负责：文档内容编辑（走 lark-doc）、表格/Base 表内数据操作（走 lark-sheets/lark-base）、知识空间节点/成员管理（走 lark-wiki）、原生 Markdown 文件读写/patch/diff（走 lark-markdown）。
- `lark-event`: Lark/Feishu real-time event listening / subscribing / consuming: stream events as NDJSON via `lark-cli event consume &lt;EventKey&gt;` (covers IM messages/reactions/chat changes, Approval status changes, Task updates, VC meeting started/joined/ended, Minutes generated, Whiteboard updated, etc.). Use for Lark bots, real-time message processing, long-running subscribers, streaming webhook/push handlers. Supports `--max-events` / `--timeout` bounded runs and a stderr ready-marker contract — designed f...
- `lark-im`: 飞书即时通讯：收发消息和管理群聊。发送和回复消息、搜索聊天记录、管理群聊成员、上传下载图片和文件、管理表情回复、发送应用内/短信/电话加急、发送和处理交互卡片（Interactive Card）、监听卡片按钮回调（card.action.trigger）。当用户需要发消息、查看或搜索聊天记录、下载聊天中的文件、查看群成员、搜索群、创建群聊或话题群、管理标记数据、管理 Feed 置顶（添加/移除/查询置顶会话）、管理标签数据、处理卡片回调时使用。
- `lark-mail`: 飞书邮箱：Use when user mentions 起草邮件、写邮件、草稿、发送/回复/转发邮件、查阅邮件、看邮件、搜索邮件、邮件文件夹、邮件标签、邮件联系人、监听新邮件、邮件收信规则等；use for mail/email intent only. Do not use for docs/sheets/calendar/auth setup/pure contact lookup/IM chat tasks.
- `lark-markdown`: 飞书 Markdown：查看、创建、上传、编辑和比较飞书中的原生 Markdown 文件。当用户要操作飞书 Markdown 文件，或比较其远端版本及本地草稿时使用。纯本地 Markdown 文件操作不触发本 skill。不负责将 Markdown 导入为飞书在线文档，也不负责文件搜索、权限、评论、移动、删除等云空间管理操作。
- `lark-meeting`: 飞书视频会议：查询会议记录与会议产物(纪要/逐字稿/妙记)、妙记搜索/上传/下载/编辑、机器人参与会议；查询进行中的会议、实时会议内容(发言/聊天/共享文档)问答(会上/会里)、发送会中聊天/表情；基于 meeting_id、meeting_no、event_id、note_id、minute_token、vc-node-id 或妙记 URL 查询相关信息。预约会议、忙闲和会议室管理走 lark-calendar。
- `lark-minutes`: 仅当用户或上游配置显式指定 lark-minutes 时使用，相关请求统一交由 lark-meeting 技能处理。
- `lark-note`: 仅当用户或上游配置显式指定 lark-note 时使用，相关请求统一交由 lark-meeting 技能处理。
- `lark-okr`: 飞书 OKR：管理目标与关键结果。查看和编辑 OKR 周期、目标、关键结果、对齐关系、量化指标和进展记录。当用户需要查看或创建 OKR、管理目标和关键结果、查看对齐关系时使用。不负责：待办任务管理（lark-task）、日程/会议安排（lark-calendar）、绩效评估
- `lark-openapi-explorer`: 飞书/Lark 原生 OpenAPI 探索：从官方文档库中挖掘未经 CLI 封装的原生 OpenAPI 接口。当用户的需求无法被现有 lark-* skill 或 lark-cli 已注册命令满足，需要查找并调用原生飞书 OpenAPI 时使用。
- `lark-shared`: Use for lark-cli setup/auth tasks: auth login/status/logout, user vs bot identity, business-domain permissions (--domain, including all/docs/drive), missing scopes, revoking authorization, or handling _notice JSON.
- `lark-sheets`: 飞书电子表格：创建和操作电子表格。支持工作表与行列结构（增删/合并/尺寸/隐藏/冻结/分组）、单元格读写（值/公式/样式/批注/单元格图片）、区域复制移动排序填充、查找替换、批量更新，图表、透视表、条件格式、筛选器与筛选视图、下拉列表、迷你图、浮动图片等对象的创建与维护，以及公式校验、历史版本回滚、本地 Excel/CSV 与飞书表格的导入导出。当用户需要创建或编辑表格、统计汇总与可视化、表格美化、公式计算（含 Excel 公式迁移）、金融/财务建模（DCF、三张表、预算、Sensitivity 等）时使用。多维表格（Base/bitable）请改用 lark-base；若用户是想按名称或关键词搜索云空间（云盘/云存储）里的表格文件，请改用 lark-drive 的 drive +search 先定位资源。当用户给出 doubao.com 的 /sheets/ URL/token 时，也应直接使用本 skill，不要因为域名不是飞书而回退到 WebFetch；路由依据是 URL 路径模式和 token，而不是域名。
- `lark-skill-maker`: 创建 lark-cli 的自定义 Skill。当用户需要把飞书 API 操作封装成可复用的 Skill（包装原子 API 或编排多步流程）时使用。
- `lark-slides`: 飞书幻灯片：创建和编辑幻灯片。创建演示文稿、读取幻灯片内容、管理幻灯片页面（创建、删除、读取、局部替换）。当用户需要创建或编辑幻灯片、读取或修改单个页面时使用。当用户给出 doubao.com 的 /slides/ URL/token 时，也应直接使用本 skill，不要因为域名不是飞书而回退到 WebFetch；路由依据是 URL 路径模式和 token，而不是域名。不负责：云文档内容编辑（走 lark-doc）、云文档里的独立画板对象（走 lark-whiteboard）、上传或下载普通文件（走 lark-drive）。
- `lark-task`: 飞书任务：管理任务、清单和任务智能体。创建待办任务、查看和更新任务状态、拆分子任务、组织任务清单、分配协作成员、上传任务附件、注册或注销任务智能体、更新任务智能体的主页数据、写入智能体任务记录。当用户需要创建待办事项、查看任务列表、跟踪任务进度、管理项目清单或给他人分配任务、为任务上传附件文件、注册注销任务智能体、更新智能体主页数据、写入任务记录时使用。
- `lark-vc`: 仅当用户或上游配置显式指定 lark-vc 时使用，相关请求统一交由 lark-meeting 技能处理。
- `lark-vc-agent`: 仅当用户或上游配置显式指定 lark-vc-agent 时使用，相关请求统一交由 lark-meeting 技能处理。
- `lark-whiteboard`: 飞书画板：查询和编辑飞书云文档中的画板。支持导出画板为预览图片、导出原始节点结构、使用多种格式更新画板内容。 当用户需要查看画板内容、导出画板图片、编辑画板时使用此 skill。不负责：飞书云文档内容编辑（lark-doc）、文档内嵌电子表格/Base（lark-sheets / lark-base）。
- `lark-wiki`: 飞书知识库：管理知识空间、空间成员和文档节点。创建和查询知识空间、查看和管理空间成员、管理节点层级结构、在知识库中组织文档和快捷方式。当用户需要在知识库中查找或创建文档、浏览知识空间结构、查看或管理空间成员、移动或复制节点时使用。当用户给出 doubao.com 的 /wiki/ URL/token 时，也应直接使用本 skill，不要因为域名不是飞书而回退到 WebFetch；路由依据是 URL 路径模式和 token，而不是域名。不负责：上传文件到知识库节点下（走 lark-drive）、编辑文档/表格/Base 内容（走 lark-doc / lark-sheets / lark-base）。
- `lark-workflow-meeting-summary`: 会议纪要整理工作流：汇总指定时间范围内的会议纪要并生成结构化报告。当用户需要整理会议纪要、生成会议周报、回顾一段时间内的会议内容时使用。
- `lark-workflow-standup-report`: 日程待办摘要：编排 calendar +agenda 和 task +get-my-tasks，生成指定日期的日程与未完成任务摘要。适用于了解今天/明天/本周的安排。
- `office`: Create, edit, inspect, or convert Office documents, spreadsheets, presentations, and PDFs. Load to choose the relevant workflow.
- `office-docx`: Create, read, edit, and validate Word documents (.docx).
- `office-export-pdf`: Convert an Office document to a requested PDF with LibreOffice Kit.
- `office-pptx`: Create, read, edit, and validate PowerPoint presentations (.pptx).
- `office-recalculate`: Refresh spreadsheet formula caches and verify calculated values with LibreOffice Kit.
- `office-render`: Render requested document images or inspect visual layout with LibreOffice Kit.
- `office-xlsx`: Read, create, edit, and validate Excel workbooks, data, and formulas (.xlsx).
</available_skills>

If the user names a skill, or the task clearly matches a skill's description, call the `skill` tool with the exact skill name before taking task actions. Load all applicable skills, then follow their full instructions. This catalog contains summaries only; do not infer or follow a skill's instructions until it has been loaded.
A user may also invoke a skill directly; its <skill_content> block then appears in this conversation. Follow it, and do not call the `skill` tool again for that skill.
</system-reminder>

===== USER #6 =====
Time sampled while preparing turn 1, step 1: 2026-11-18T08:40:25+08:00[Asia/Shanghai]
Browser time zone for this request: unavailable. Ask the user to clarify otherwise-unqualified dates and times.
Elapsed since the preceding model-visible message: unavailable.

===== ASSISTANT #7 =====
I'll start by inspecting the workspace to see where the project currently stands.

===== ASSISTANT #8 =====
I'll read the design docs and core simulation files.

===== ASSISTANT #9 =====
The baseline is green (227 tests). I've mapped the codebase. Now I'll implement the design: a logistics layer (belts/loaders), mechanism effects that modify ghosts, new ghost threshold types, and a big-map territory/outlaw system. Let me start with the core entities.

===== ASSISTANT #10 =====
Now the main simulation. This is the largest piece — I'll rewrite `Sim.gd` integrating belts, loaders, mechanism effects, relay/anchor ghosts, territory expansion, and outlaw aggro.

===== ASSISTANT #11 =====
Now I'll add tests for each new system, starting with belts/loaders, mechanism effects, and new thresholds.

===== USER #12 =====
Time sampled while preparing turn 1, step 43: 2026-11-18T08:50:42+08:00[Asia/Shanghai]
Browser time zone for this request: unavailable. Ask the user to clarify otherwise-unqualified dates and times.
Elapsed since the preceding step context: 10m 17s.

===== ASSISTANT #13 =====
I need to refine the loader into a directional, atomic-swap device — that's what makes belt logistics readable. Let me update it.

===== USER #14 =====
Time sampled while preparing turn 1, step 57: 2026-11-18T09:05:39+08:00[Asia/Shanghai]
Browser time zone for this request: unavailable. Ask the user to clarify otherwise-unqualified dates and times.
Elapsed since the preceding step context: 14m 57s.

===== ASSISTANT #15 =====
The machine works and self-sustains. Now I'll wire the new content into the HUD (data-driven build bar, territory/outlaw readouts).

===== ASSISTANT #16 =====
Now let me verify the real game scene boots and the behemoth dev scenario runs with rendering.

===== ASSISTANT #17 =====
Now documentation. Let me check the end of the design doc and append a v15 section.

===== USER #18 =====
Time sampled while preparing turn 1, step 122: 2026-11-18T09:15:40+08:00[Asia/Shanghai]
Browser time zone for this request: unavailable. Ask the user to clarify otherwise-unqualified dates and times.
Elapsed since the preceding step context: 10m 0s.

===== USER #19 =====
<system-reminder>
Updated instructions from: AGENTS.md

This file changed after it was loaded. Use the following content instead of the previously loaded instructions from this file.

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
2. `SimCrystal.slotted_in` 与 `SimMechanism.crystal_id` 必须成对更新；
   删除机关时要把槽里的晶落到地上，否则会丢晶。
3. 快照 / 恢复必须保留实体 `id`，否则插槽引用会断。
4. 视图在 `WorldRestored` 后必须全量重建；不要试图增量修复。
5. 测试不要写 `user://`（本机可能不可写）；临时文件放 `res://.godot/` 下。

## 5. 性能边界

- 逻辑 20 Hz；热力图 5 Hz；不要在每个 `_process` 里重算场。
- 实体节点数量很小（几十个），结构变化时全量重建是可接受的。
- 新增每帧计算前，先想清楚是否能用「事件 + 缓存」。

## 6. 加东西的路径

| 想加 | 正确做法 |
|---|---|
| 新鬼（同类型阈值） | 只加 `Data/ghosts/*.json` |
| 新机关（同类型「顶」） | 只加 `Data/mechanisms/*.json` |
| 新搬运手（同类型换晶） | 只加 `Data/swappers/*.json` |
| 新关卡 / 波次 | 只加 `Data/levels/*.json`，并把上一关的 `next_level` 指过来 |
| 新夜规 | 只加 `Data/modifiers.json` 条目 |
| 新阈值类型 | 改 `SimGhost` + `Sim._tick_ghosts`，补测试 |
| 新机关作用方式 | 改 `SimMechanism` + `Sim._tick_mechanisms`，补测试 |
| 新视图 | 新建 `Code/Game/Views/*View.gd`，在 `WorldView` 里注册，不改 Core |
| 新 UI 面板 | 改 `Hud.gd`，数据从 `Sim` 公开字段读 |

## 7. 已废弃 / 别碰

- `ghost-factory/`：最初的空骨架，已被 `.gdignore` 排除（原因见其 `SUPERSEDED.md`）。
- `_acl-recovery/`、`_newtest/`、`_wtest.txt`：本机排查沙箱权限留下的临时物，可删。
- `Core/SimGrid.gd`（如果还存在）：误建的空占位，真正实现在 `Code/Core/SimGrid.gd`。

</system-reminder>

===== USER #20 =====
<system-reminder>
Updated instructions from: AGENTS.md

This file changed after it was loaded. Use the following content instead of the previously loaded instructions from this file.

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
7. 测试不要写 `user://`（本机可能不可写）；临时文件放 `res://.godot/` 下。

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
| 新机关作用方式 | 改 `SimMechanism` + `Sim._tick_ghosts` 的参数改写段，补测试 |
| 新物流形态 | 新建 `Code/Core/Sim*.gd` + `Sim` 的 tick / Build 分支，补测试 |
| 新视图 | 新建 `Code/Game/Views/*View.gd`，在 `WorldView` 里注册，不改 Core |
| 新 UI 面板 | 改 `Hud.gd`，数据从 `Sim` 公开字段读 |

## 7. 已废弃 / 别碰

- `ghost-factory/`：最初的空骨架，已被 `.gdignore` 排除（原因见其 `SUPERSEDED.md`）。
- `_acl-recovery/`、`_newtest/`、`_wtest.txt`：本机排查沙箱权限留下的临时物，可删。
- `Core/SimGrid.gd`（如果还存在）：误建的空占位，真正实现在 `Code/Core/SimGrid.gd`。

</system-reminder>

===== ASSISTANT #21 =====
Let me attempt a full six-wave run on the new big map with a scripted player, to verify the level is actually beatable.

===== USER #22 =====
Time sampled while preparing turn 1, step 159: 2026-11-18T09:26:52+08:00[Asia/Shanghai]
Browser time zone for this request: unavailable. Ask the user to clarify otherwise-unqualified dates and times.
Elapsed since the preceding step context: 11m 11s.

===== ASSISTANT #23 =====
The HUD grew and now covers the play field (the drag test caught it). Let me compact it.

===== USER #24 =====
Time sampled while preparing turn 1, step 213: 2026-11-18T09:36:53+08:00[Asia/Shanghai]
Browser time zone for this request: unavailable. Ask the user to clarify otherwise-unqualified dates and times.
Elapsed since the preceding step context: 10m 1s.

===== USER #25 =====
<goal_complete>
Objective: "丰富鬼和鬼能机关。她应该是在一个大地图里不断拓展空间，超过这个空间的造物会被怪物集火，同时鬼屋数量激增。她本质上就一个大地图，但是需要不断的抵御。每过一个波次就会给一些新的鬼和成本、\n第二个她的机关应该是紧密相连的，需要传送带去做物流管理的一个机关的鬼能被用过之后不能再用只能等下一个鬼能就是需要这一份物流管理的和机关设计的，不然这个游戏没有意思了，填充着部分的内容，你要证明这个机关和鬼的内容的上限，就是根据这些乱七八糟的东西可以造出来一个精密的庞然大物，你设计的时候先实践一下行不行，然后有些鬼和机关的存在可以提高效率改动之前的鬼。\n就是让这个游戏变得好玩。\n好玩的点在于上限非常高的自由搭建\n搭完之后清怪的爽感\n新的鬼或者机关带来的尤米尔时刻。\n\n让这个游戏变得好玩，你可以设计新的内容，修改微量的系统再不是本味的情况下，我给你极高的权限，"
The goal is marked complete and this autonomous run is ending. Write the closing message to the user now: state the outcome, summarize what was done and how it was verified, and point to the concrete results (files, commits, or other artifacts). Report only what earlier rounds and tool results in this session actually establish; when a detail is not in the session, say so instead of inventing it. Note anything the user should review or do next. Address the user directly. Do not call any more tools in this run; further work waits for the user's next instruction.
</goal_complete>

===== ASSISTANT #26 =====
## 已完成：v15「物流 · 自持机器 · 大地图」

这一轮把「机关 → 鬼 → 脉冲 → 充能 → 机关」这条闭环，从一句话做成了真的能铺、能跑、能证的产线。最终验证结果：**412 项自动化测试，0 失败**。

---

### 1. 新增的系统

**物流层（新的一类建筑）**
- **传送带** `belt / express`：只能往一个方向送，会堵，有速度/容量差。带面上的鬼晶仍然能被脉冲充能。
- **装卸臂** `arm`：有朝向。正前方是来料带、背后是回程带、只往“和自己同向走”的带子上货。
  它的一次动作是**交换**：把槽里的空晶挪走，同时把充能晶塞回去——所以机关换料时**不会断电**。每次搬运抽 1 单位鬼能。
- 鬼晶现在有严格的三种位置：**地上 / 机关槽里 / 传动带上**，互斥维护；快照也能把带面上的晶一起回溯。

**机关：能“改之前的鬼”**
- 长撬 `crank`：一根撬杆沿线段同时顶住多只鬼的脚。
- 节拍 `tune`：把半径内鬼的固有周期改写成 2.0 秒（守夜钟的 3.2 秒能被它拉进同频）。
- 共鸣腔 `amp`：放大振幅；传声筒 `reach`：延长射程。
- 这三种只在有电时生效，失电立刻还原——所以“改鬼的机器”自己也得喂。

**鬼：三种阈值形态**
- 原有倾角阈值之外，新增 **双支撑**（锚鬼：必须两台机关同时顶住脚才立正）和 **脉冲触发**（接力鬼：不站，被脉冲扫到后延迟再响一次，可链式传波）。
- 新鬼数值：守夜钟（重、3.2 秒、1.7 振幅）、低鸣鬼（1.4 秒、一次给 2 颗晶各充 3 点，是鬼能泵）、提灯鬼（便宜的长射程补洞）。

**大地图：第三夜 · 大屋**
- 23×23 地图，开局 5×5 领地；每清一波扩 1 圈，最后一波 +2 圈，最终 19×19。
- **越界造物**：领地外也能建，但脚下亮红环；魅会优先走向仇恨半径内最近的越界造物，啃掉它并同归于尽。
- **鬼屋激增**：每处越界造物让每个刷怪组多刷 0.5 只（HUD 实时显示 +N）。
- **收编**：扩地时新圈进来的越界造物自动合法化——风险是当下的，收益是永久的。
- 每波奖励给预算 + 新图纸；第三夜初始解锁全部核心新内容，奖励依次解锁装卸臂、共鸣腔、节拍、传声筒、接力鬼。

---

### 2. 上限证明：一台真的在转的庞然大物

`Code/Dev/Behemoth.gd` 是一份写死的参考解，测试和 `--dev-behemoth` 共用同一份代码：

- 核心：锚鬼 + 翘脚鬼×2 + 守夜钟围成十字，四只鬼围着一台装卸臂；长撬给锚鬼第二个支撑；节拍机关把守夜钟改成 2.0 秒；共鸣腔放大、传声筒延长。
- 产线：去程快带 5 格 → 核心；回程带 5 格 → 鬼屋。
- 鬼屋：两只低鸣鬼 + 两台顶足机关 + 一台装卸臂，负责换泵、卸回程带、把充好的晶送上带。
- 外圈再摆一只接力鬼，把清场区往外推。

`Test_Behemoth` 一次建好之后**不再有任何玩家输入**，跑 60 秒：

| 读数 | 结果 |
|---|---|
| 立正的鬼 | 6 / 7（接力鬼不站） |
| 机关供电 | **10 / 10** |
| 脉冲 | 236 次（含接力） |
| 传送带搬运 | 104 次 |
| 装卸臂换料 | 100 次 |
| 场峰值 | 6.58（清场线 1.45） |
| 清场线覆盖 | 179 / 529 格 |
| 漏怪 | 0 |
| 往清场区丢一只 800 血厚甲魅王 | 同一 tick 被抹掉 |

这说明：“上限”不是数值表上写出来的，而是**用这些数据、这些规则、这个摆法，确实能跑出自己转的机器**。整台机器约 305 预算，第三夜六波总预算约 335，空间在最后一波后够放下——它在关卡经济内是可达的。

另外，`Test_Level03Run` 用一个“四向小机器 + 会换晶的脚本玩家”**完整打通了第三夜六波**，0 判负；所以新地图不只是数据，是可通关的。

---

### 3. 界面与表现

- 建造栏改成**数据驱动**：`Data/content.json` 登记一行，HUD 与快捷键自动跟上；当前 18 项，两行排布。
- 顶部新增 **领地 / 越界 / 鬼屋激增** 三个读数；右侧面板保留共振指数与下一波预览；扩地、收编、被拆都有提示。
- 新增 **BeltView**（滚动带面、载货发光）、5 种新鬼造型（钟 / 鼓 / 天线 / 锚 / 提灯）、改鬼机关的环形视觉、越界造物的红环。
- 相机扩到 5 档缩放，平移范围跟随地图；热力图对高值做了压缩，机器再大也看得见装置本身。
- 顺手修了一个旧 bug：`--dev-input` 的拖拽测试把视口坐标当窗口坐标注入，导致一直点偏；现在 `DEV_INPUT ... moved=true`。

截图（`_shots/`）：

![第三夜 · 大屋：小领地、物流线、越界哨站](_shots/night3.png)

![庞然大物：近距离的十字核心与两条带子](_shots/behemoth_close.png)

![内容陈列：全部鬼 / 机关 / 带子 / 臂](_shots/gallery.png)

---

### 4. 怎么验收

```powershell
$g = "D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"

# 412 项测试
& $g --headless --path . res://Code/Tests/TestRunner.tscn

# 看庞然大物自己转（30 秒 + 两张截图）
& $g --path . -- --dev-behemoth

# 看第三夜开局 / 内容陈列
& $g --path . -- --dev-shot3
& $g --path . -- --dev-gallery
```

测试入口里新增的关键组：`内容目录`、`传送带`、`装卸臂`（含朝向规则）、`机关改鬼`、`长撬`、`锚鬼`、`接力鬼`、`越界`、`领奖扩地`、`物流快照`、`庞然大物`、`第三夜第一波`、`第三夜六波通关`。

---

### 5. 改了哪些文件

**新增**
- `Code/Core/SimBelt.gd`、`Code/Game/Views/BeltView.gd`、`Code/Dev/Behemoth.gd`
- `Data/ghosts/{toll,hum,relay,anchor,lantern}.json`
- `Data/mechanisms/{crank,tuner,amp,reach}.json`
- `Data/belts/{belt,express}.json`、`Data/swappers/arm.json`、`Data/crystals/cell.json`
- `Data/content.json`、`Data/levels/03.json`

**修改**
- Core：`Sim`、`SimGhost`、`SimMechanism`、`SimSwapper`、`SimCrystal`、`SimConfig`、`SimWaves`、`SimEnemy`、`SimEvents`、`GameData`、`NightReport`
- UI/表现：`Main`、`Hud`、`WorldView`、`CameraRig`、`HeatmapView`、`GhostView`、`MechanismView`、`Sfx`
- 数据：`game.json`（改鬼封顶）、`levels/02.json`（指向第三夜）
- 文档：`GameDesign.md` 新增 **§16 v15**（设计口径、5 条尤里卡、新待定 78–83）、`docs/ARCHITECTURE.md`、`docs/CONTENT_GUIDE.md`、`docs/DESIGN_MAPPING.md`、`README.md`、`AGENTS.md`

（这个目录不是 git 仓库，所以没有提交记录；以上都是工作区里的实际改动。）

---

### 6. 需要你拍板的数值（都在 `§16.9`）

1. 传送带速度 / 容量与装卸臂 `swap_period` 的配比（当前 1.0 格/秒、容量 1/2.2、1.1 秒）。
2. 越界压力 0.5 只/组是否过重；要不要改成按面积占比。
3. 第三夜每波 +1 圈是否够快；要不要加“用预算买扩地”的第二条路。
4. 锚鬼的双支撑是否只认“两台机关”而不限类型（当前不限，长撬 + 顶足最省）。
5. 接力鬼冷却 0.9 秒是否让链式接力过强。
6. 改鬼机关封顶（当前振幅 2.2×、射程 2.4×）。

如果下一轮继续，我建议优先做两件事：**第三夜的物流新手引导**（现在只有文字提示 + 45 秒后的 no_belt/no_arm 提示），以及**通关后的自由沙盒**（让玩家能在 19×19 领地上真正把庞然大物搭完，而不是只在 dev 场景里看到）。

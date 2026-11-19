extends Node
## 无界面测试入口。
##   Godot --headless --path <project> res://Code/Tests/TestRunner.tscn
## 全部通过退出码 0，有失败退出码 1（可直接用于 CI）。

var _passed: int = 0
var _failed: int = 0
var _messages: Array = []
var _current: String = ""


func _ready() -> void:
	print("=== 鬼工厂 · 核心规则测试 ===")

	_run("内容数据", Test_Data)
	_run("脉冲场：相干 / 反相 / 异频 / 衰减", Test_Field)
	_run("鬼：翘脚 / 立正 / 推倒", Test_Ghost)
	_run("节拍：同周期鬼的相位对齐", Test_PhaseSync)
	_run("机关：耗能与停摆", Test_MechanismEnergy)
	_run("脉冲充能：最近空晶、排除槽内", Test_PulseCharging)
	_run("建造：越界 / 占用 / 预算 / 拆退", Test_Build)
	_run("搬运：拿起 / 放下 / 插入 / 取出", Test_CrystalFlow)
	_run("自动化：搬运手自动换晶并抽能", Test_Swapper)
	_run("调场：鬼 / 机关整体挪位", Test_Move)
	_run("波次：准备 / 刷怪 / 清空", Test_WavesUnit)
	_run("波次预览：下一波的来向与甲魅", Test_WavePreview)
	_run("甲魅：减伤，但挡不住清场线", Test_Armor)
	_run("机器共振：同频叠加 → 大波段", Test_Resonance)
	_run("夜间报告：从统计读出打法", Test_NightReport)
	_run("夜规：预算 / 准备时间 / 禁用图纸", Test_Modifiers)
	_run("魅王：漏过去直接判负", Test_BossBreach)
	_run("失败与回溯", Test_FailAndRollback)
	_run("完整闭环：机关 → 鬼 → 脉冲 → 充能", Test_ClosedLoop)
	_run("实战：第一波能被守住", Test_WaveOneSurvives)
	_run("实战：完整四波可通关", Test_FullRun)
	_run("第二夜：走廊场地可通关", Test_Level02)
	_run("一拱全爆：同相叠加越线即抹杀", Test_OneWaveClear)
	_run("新图纸：摆臂鬼可叠加越线", Test_SwingInterference)
	_run("奖励：清波解锁新图纸", Test_WaveRewardUnlock)
	_run("暂停：世界冻结但可建造", Test_Pause)
	_run("回溯：id 与脉冲链保持完整", Test_RollbackIds)
	_run("存档版本迁移", Test_Save)
	_run("内容目录：建造栏与关卡登记", Test_Catalog)
	_run("传送带：推进 / 落地 / 带面充能", Test_Belt)
	_run("装卸臂：带面 → 机关 → 空地", Test_Loader)
	_run("装卸臂的朝向：背后放空晶、同向才上货", Test_LoaderDirection)
	_run("机关改鬼：节拍 / 放大 / 传声", Test_MechanismEffects)
	_run("长撬：一根撬杆顶住两只鬼", Test_Crank)
	_run("锚鬼：单支撑不立正，双支撑才立正", Test_Anchor)
	_run("接力鬼：被脉冲扫到再发一次，并可成链", Test_Relay)
	_run("锤鬼：倒下砸邻格，砸身推倒、砸脚顶立正", Test_HammerStrike)
	_run("撑鬼：撑住倒向它的锚鬼，算一个支撑", Test_BraceSupport)
	_run("摆锤鬼：速度过阈值才响，没被砸时不动", Test_PendulumSpeed)
	_run("联动：锤鬼砸摆锤，一锤把摆锤荡起来", Test_HammerDrivesPendulum)
	_run("越界：可建造、引鬼、被拆、被领地吞并", Test_Outlaw)
	_run("领奖扩地：扩圈与合法化", Test_Territory)
	_run("新物流快照：带子 / 越界 / 领地一起回溯", Test_LogisticsSnapshot)
	_run("庞然大物：自持产线 + 同相清场", Test_Behemoth)
	_run("第三夜：起手机器能守住第一波", Test_Level03FirstWave)
	_run("第三夜：四向小机器能走完全程", Test_Level03Run)
	_run("相机：W/S 方向与幽灵视角基向量", Test_CameraBasis)
	_run("拆除：鬼可以拆，且全额退款", Test_RemoveGhost)
	_run("数值曲线：威胁 / 预算 / 奖励对账", Test_BalanceCurve)

	print("")
	for line in _messages:
		print(line)
	print("")
	# 依赖脚本编译失败时，断言根本不会执行，套件会「假通过」。用总数兜底。
	if _passed + _failed < 100:
		_failed += 1
		print("SUITE_INCOMPLETE：只执行了 %d 项断言，依赖脚本可能编译失败" % (_passed + _failed))
	print("=== 结果：%d 通过，%d 失败 ===" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _run(title: String, fn: Callable) -> void:
	_current = title
	var before := _failed
	fn.call()
	var mark := "OK  " if _failed == before else "FAIL"
	print("[%s] %s" % [mark, title])


func Check(condition: bool, what: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		_messages.append("  ✗ [%s] %s" % [_current, what])


func CheckEq(actual: Variant, expected: Variant, what: String) -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		_messages.append("  ✗ [%s] %s（期望 %s，实际 %s）" % [_current, what, str(expected), str(actual)])


func CheckNear(actual: float, expected: float, what: String, eps: float = 0.01) -> void:
	if absf(actual - expected) <= eps:
		_passed += 1
	else:
		_failed += 1
		_messages.append("  ✗ [%s] %s（期望 %.4f ± %.4f，实际 %.4f）" % [_current, what, expected, eps, actual])


# ---------------------------------------------------------------------------

func Test_Data() -> void:
	var result := GameData.Validate()
	Check(bool(result["ok"]), "内容数据自洽：" + str(result.get("errors", [])))
	var game := GameData.Game()
	Check(int(game.get("tick_rate", 0)) > 0, "game.json 有 tick_rate")
	Check(not GameData.Ghost("waver").is_empty(), "翘脚鬼定义可加载")
	Check(not GameData.Ghost("swing").is_empty(), "摆臂鬼定义可加载")
	Check(not GameData.Swapper("hand").is_empty(), "搬运手定义可加载")
	Check(not GameData.Mechanism("pusher").is_empty(), "顶足机关定义可加载")
	Check(not GameData.Crystal("crystal").is_empty(), "鬼晶定义可加载")
	var level := GameData.Level("01")
	Check(not level.is_empty(), "第一夜可加载")
	CheckEq(String(level.get("next_level", "")), "02", "第一夜指向第二夜")
	Check(int(level.get("grid", {}).get("w", 0)) == 13, "关卡网格宽度")
	Check(level.get("waves", []).size() == 4, "关卡有四波")
	var level2 := GameData.Level("02")
	Check(not level2.is_empty(), "第二夜可加载")
	Check(int(level2.get("grid", {}).get("w", 0)) == 15, "第二夜是走廊")
	Check(int(level2.get("buildable", {}).get("h", 0)) == 3, "第二夜只有三格宽")


func Test_Field() -> void:
	var f := SimField.new()
	f.speed = 6.0
	f.AddSource(Vector2.ZERO, 2.0, 0.0, 1.0, 10.0)
	CheckNear(f.EnvelopeAt(Vector2.ZERO), 1.0, "单源原点振幅")
	CheckNear(f.EnvelopeAt(Vector2(5, 0)), 0.5, "距离衰减到一半")
	CheckNear(f.EnvelopeAt(Vector2(11, 0)), 0.0, "超出范围归零")

	# 同频同相：相干叠加
	f.Clear()
	f.AddSource(Vector2.ZERO, 2.0, 0.0, 1.0, 10.0)
	f.AddSource(Vector2.ZERO, 2.0, 0.0, 1.0, 10.0)
	CheckNear(f.EnvelopeAt(Vector2.ZERO), 2.0, "同相相加")

	# 同频反相：抵消
	f.Clear()
	f.AddSource(Vector2.ZERO, 2.0, 0.0, 1.0, 10.0)
	f.AddSource(Vector2.ZERO, 2.0, PI, 1.0, 10.0)
	CheckNear(f.EnvelopeAt(Vector2.ZERO), 0.0, "反相抵消")

	# 异频：按能量相加，不会互相抵消
	f.Clear()
	f.AddSource(Vector2.ZERO, 2.0, 0.0, 1.0, 10.0)
	f.AddSource(Vector2.ZERO, 2.5, 0.0, 1.0, 10.0)
	CheckNear(f.EnvelopeAt(Vector2.ZERO), sqrt(2.0), "异频按能量叠加")

	# 传播延迟：离源越远相位越滞后，两点之间的相对关系会变
	f.Clear()
	f.AddSource(Vector2.ZERO, 2.0, 0.0, 1.0, 20.0)
	f.AddSource(Vector2(6, 0), 2.0, 0.0, 1.0, 20.0)
	var mid := f.EnvelopeAt(Vector2(3, 0))
	Check(mid >= 0.0, "两源中间可采样")


func Test_PhaseSync() -> void:
	var def := GameData.Ghost("waver")
	var events := SimEvents.new()
	var a := SimGhost.new().Configure(1, "waver", def, Vector2i.ZERO, 0, Vector2.ZERO)
	var b := SimGhost.new().Configure(2, "waver", def, Vector2i.ZERO, 0, Vector2.ZERO)
	a.angle = 0.0
	b.angle = 0.0
	var dt := 0.05
	for i in 240:
		var t := float(i) * dt
		a.Step(dt, -5.4, events, t)
		b.Step(dt, -5.4 if t >= 0.7 else 0.0, events, t)
	Check(a.standing, "先立正的鬼保持立正")
	Check(b.standing, "后立正的鬼也立正")
	CheckNear(a.phase, b.phase, "同周期鬼的相位被全场节拍对齐", 0.05)


func Test_Ghost() -> void:
	var def := GameData.Ghost("waver")
	var events := SimEvents.new()
	var g := SimGhost.new().Configure(1, "waver", def, Vector2i.ZERO, 0, Vector2.ZERO)
	# 没人顶：停在翘脚姿态，不立正
	for i in 20:
		g.Step(0.05, 0.0, events)
	Check(g.angle > 0.4, "无人施力时保持翘脚")
	Check(not g.standing, "无人施力时不立正")
	CheckEq(g.pulse_total, 0, "没人顶就不发脉冲")

	# 顶住翘起的脚：立正并发脉冲
	for i in 60:
		g.Step(0.05, -5.4, events)
	Check(g.standing, "被顶到阈值后立正")
	Check(g.pulse_total >= 1, "立正瞬间发脉冲")
	var pulses := g.pulse_total
	for i in 45:
		g.Step(0.05, -5.4, events)
	Check(g.pulse_total > pulses, "立正后按周期续发")
	Check(g.angle <= g.stand_angle + 0.05, "立正后倾角很小")

	# 顶错地方（推身体）：倒下
	var g2 := SimGhost.new().Configure(2, "waver", def, Vector2i.ZERO, 0, Vector2.ZERO)
	for i in 30:
		g2.Step(0.05, 6.0, events)
	Check(g2.angle > 1.0, "被推身体会倒下")
	Check(not g2.standing, "倒下后不立正")


func Test_MechanismEnergy() -> void:
	var sim := _new_sim("01")
	var built := sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)
	Check(bool(built["ok"]), "机关可建造")
	var mech: SimMechanism = sim.mechanisms[int(built["id"])]
	CheckEq(mech.crystal_id, -1, "新机关插槽为空")

	var picked := sim.PickCrystal(Vector2i(5, 8))
	Check(bool(picked["ok"]), "拿起初始充能鬼晶")
	var inserted := sim.InsertHeld(Vector2i(4, 8))
	Check(bool(inserted["ok"]), "鬼晶插入机关")
	var crystal: SimCrystal = sim.crystals[mech.crystal_id]
	var before := crystal.charge
	CheckEq(before, crystal.capacity, "初始鬼晶满格")

	_step_for(sim, 2.1)
	CheckNear(crystal.charge, before - 1.0, "一次发力消耗 1 单位", 0.001)
	_step_for(sim, 12.0)
	CheckNear(crystal.charge, 0.0, "鬼能耗尽")
	Check(not mech.pushing, "没电后机关停摆")

	var empty_pick := sim.Build("crystal", "crystal", Vector2i(6, 8), 0)
	Check(bool(empty_pick["ok"]), "空鬼晶可建造")


func Test_PulseCharging() -> void:
	var sim := _new_sim("01")
	var ghost: SimGhost = sim.ghosts.values()[0]
	# 直接把鬼摆到「已立正、下一 tick 就要发脉冲」的状态
	ghost.angle = 0.0
	ghost.angular_velocity = 0.0
	ghost.standing = true
	ghost.phase = TAU - 0.001
	var empty: SimCrystal = null
	for id in sim.crystals:
		var c: SimCrystal = sim.crystals[id]
		if c.IsOnGround() and c.charge < 1.0:
			empty = c
	Check(empty != null, "关卡有空的鬼晶")
	var charge_before := empty.charge
	sim.Step(1.0 / float(sim.config.tick_rate))
	Check(empty.charge > charge_before, "脉冲给最近的空鬼晶充能")

	# 槽内的晶不参与充能
	var slotted := SimCrystal.new().Configure(99, "crystal", GameData.Crystal("crystal"), Vector2i(-1, -1), 0.0)
	slotted.slotted_in = 1
	Check(not slotted.IsChargable(), "槽内鬼晶不接收充能")


func Test_Build() -> void:
	var sim := _new_sim("01")
	CheckEq(String(sim.Build("ghost", "waver", Vector2i(0, 0))["reason"]), "outside_build", "越界不能建")
	CheckEq(String(sim.Build("ghost", "waver", Vector2i(3, 8))["reason"]), "occupied", "占用格不能建")
	CheckEq(String(sim.Build("ghost", "nope", Vector2i(6, 6))["reason"]), "unknown_type", "未知类型不能建")

	var budget_before := sim.economy.budget
	var ok := sim.Build("ghost", "waver", Vector2i(6, 6), 1)
	Check(bool(ok["ok"]), "合法位置可建造")
	CheckEq(sim.economy.budget, budget_before - 10, "建造扣预算")
	var removed := sim.RemoveAt(Vector2i(6, 6))
	Check(bool(removed["ok"]), "可拆除")
	CheckEq(sim.economy.budget, budget_before, "拆除全额退还")
	Check(not sim.cells.has(Vector2i(6, 6)), "拆除后格子释放")

	sim.economy.budget = 0
	CheckEq(String(sim.Build("ghost", "waver", Vector2i(6, 6))["reason"]), "no_budget", "预算不足不能建")
	sim.economy.budget = budget_before

	# 未解锁
	var locked_sim := _new_sim("01")
	locked_sim.economy.unlocked.clear()
	CheckEq(String(locked_sim.Build("ghost", "waver", Vector2i(6, 6))["reason"]), "locked", "未解锁不能建")


func Test_CrystalFlow() -> void:
	var sim := _new_sim("01")
	var picked := sim.PickCrystal(Vector2i(5, 8))
	Check(bool(picked["ok"]), "拿起鬼晶")
	Check(sim.held_crystal >= 0, "手持状态成立")
	Check(not sim.cells.has(Vector2i(5, 8)), "拿走后格子空出")
	CheckEq(String(sim.PickCrystal(Vector2i(5, 6))["reason"]), "hands_full", "一次只能拿一块")

	var built := sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)
	Check(bool(built["ok"]), "建造机关")
	var inserted := sim.InsertHeld(Vector2i(4, 8))
	Check(bool(inserted["ok"]), "插入机关")
	CheckEq(sim.held_crystal, -1, "插入后手上空出")

	var ejected := sim.EjectCrystal(Vector2i(4, 8))
	Check(bool(ejected["ok"]), "可从机关取出")
	CheckEq(String(ejected["reason"]), "to_hand", "取出优先放手上")

	var dropped := sim.DropHeld(Vector2i(6, 8))
	Check(bool(dropped["ok"]), "可放回地面")
	Check(sim.cells.has(Vector2i(6, 8)), "放下后占格")
	Check(int(sim.stats.get("manual_inserts", 0)) >= 1, "手插次数被统计")

	# 空鬼晶不能插
	Check(bool(sim.PickCrystal(Vector2i(3, 6))["ok"]), "拿起空鬼晶")
	CheckEq(String(sim.InsertHeld(Vector2i(4, 8))["reason"]), "empty_crystal", "空鬼晶不能插")


func Test_Swapper() -> void:
	var sim := _new_sim("01")
	sim.economy.Unlock("hand")
	Check(bool(sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)["ok"]), "建机关")
	Check(bool(sim.Build("swapper", "hand", Vector2i(5, 7))["ok"]), "建搬运手")
	var mech: SimMechanism = sim.mechanisms.values()[0]
	var works := [0]
	sim.events.SwapperWorked.connect(func(_s: int, _m: int, _c: int): works[0] += 1)

	_step_for(sim, 2.6)
	Check(mech.crystal_id >= 0, "空槽被自动插上充能晶")
	var c: SimCrystal = sim.crystals.get(mech.crystal_id)
	Check(c != null, "槽里有晶")
	if c != null:
		CheckNear(c.charge, 4.0, "搬运抽走 1 单位", 0.001)
	Check(not sim.cells.has(Vector2i(5, 8)), "被搬走的地上格子空出")
	Check(works[0] >= 1, "换晶事件触发")

	# 机关把电用光后，搬运手会再换一颗（附近还有 5,6 的满晶）
	_step_for(sim, 16.0)
	Check(works[0] >= 2, "没电后会自动再换一次")
	Check(mech.crystal_id >= 0, "机关始终保持有晶")
	Check(int(sim.stats.get("auto_swaps", 0)) >= 2, "自动换晶次数被统计")


func Test_Move() -> void:
	var sim := _new_sim("01")
	var moved := sim.MoveEntity(Vector2i(3, 8), Vector2i(5, 5))
	Check(bool(moved["ok"]), "鬼可整体挪位")
	Check(not sim.cells.has(Vector2i(3, 8)), "旧格子释放")
	Check(sim.cells.has(Vector2i(5, 5)), "新格子占用")
	var ghost: SimGhost = sim.ghosts.values()[0]
	CheckEq(ghost.cell, Vector2i(5, 5), "鬼的格子更新")
	Check(ghost.base == sim.grid.CellToWorld(Vector2i(5, 5)), "鬼的世界坐标更新")

	CheckEq(String(sim.MoveEntity(Vector2i(5, 5), Vector2i(5, 8))["reason"]), "occupied", "不能挪到已占用格")
	CheckEq(String(sim.MoveEntity(Vector2i(5, 5), Vector2i(0, 0))["reason"]), "outside_build", "不能挪出可放置区")
	CheckEq(String(sim.MoveEntity(Vector2i(1, 1), Vector2i(2, 2))["reason"]), "empty", "空格没有东西可挪")
	CheckEq(String(sim.MoveEntity(Vector2i(5, 8), Vector2i(6, 6))["reason"]), "cannot_move", "鬼晶不能整体挪位")

	# 机关连同插槽里的鬼晶一起走
	Check(bool(sim.Build("mechanism", "pusher", Vector2i(4, 7), 2)["ok"]), "建机关")
	Check(bool(sim.PickCrystal(Vector2i(5, 8))["ok"]), "拿晶")
	Check(bool(sim.InsertHeld(Vector2i(4, 7))["ok"]), "插晶")
	var mech: SimMechanism = sim.mechanisms.values()[0]
	var crystal: SimCrystal = sim.crystals.get(mech.crystal_id)
	Check(crystal != null, "槽里有晶")
	Check(bool(sim.MoveEntity(Vector2i(4, 7), Vector2i(4, 6))["ok"]), "机关可整体挪位")
	CheckEq(mech.cell, Vector2i(4, 6), "机关格子更新")
	Check(mech.base == sim.grid.CellToWorld(Vector2i(4, 6)), "机关世界坐标更新")
	if crystal != null:
		CheckEq(crystal.slotted_in, mech.id, "鬼晶仍插在这台机关上")
	Check(not sim.cells.has(Vector2i(4, 7)), "机关旧格释放")
	CheckEq(int(sim.stats.get("moves", 0)), 2, "挪位次数被统计")


func Test_WavesUnit() -> void:
	var w := SimWaves.new()
	w.Configure([
		{"prep": 0.10, "groups": [
			{"count": 2, "interval": 0.10, "center_deg": 0, "arc_deg": 0, "hp": 10, "speed": 1.0},
		]},
	], 5.0)
	var out: Array = []
	w.Step(0.05, 0, out)
	CheckEq(out.size(), 0, "准备阶段不刷怪")
	Check(w.state == SimWaves.PREP, "准备阶段状态")
	CheckNear(w.time_to_wave, 0.05, "倒计时递减", 0.001)

	w.Step(0.06, 0, out)
	CheckEq(String(out[0].get("op", "")), "wave_start", "倒计时结束开波")
	out.clear()

	w.Step(0.05, 0, out)
	CheckEq(out.size(), 1, "第一只怪立即刷出")
	Check(String(out[0].get("op", "")) == "spawn", "产出 spawn 指令")
	CheckNear(out[0]["pos"].length(), 5.0, "刷怪半径正确", 0.001)
	out.clear()

	w.Step(0.10, 0, out)
	CheckEq(out.size(), 1, "第二只怪按间隔刷出")
	out.clear()
	Check(w.state == SimWaves.ACTIVE, "刷完后进入战斗阶段")

	w.Step(0.05, 1, out)
	CheckEq(out.size(), 0, "还有魅活着时不清波")

	w.Step(0.05, 0, out)
	CheckEq(out.size(), 2, "场上清空后清波 + 全清")
	CheckEq(String(out[0].get("op", "")), "wave_clear", "清波指令")
	Check(String(out[1].get("op", "")) == "all_clear", "最后一波后全清")


func Test_WavePreview() -> void:
	var sim := _new_sim("01")
	Check(sim.waves.state == SimWaves.PREP, "开局处于准备阶段")
	var wave := sim.NextWave()
	Check(not wave.is_empty(), "准备阶段能读到下一波")
	Check(wave.get("groups", []).size() > 0, "下一波有分组信息")

	var armored_wave := false
	for w in sim.level.get("waves", []):
		for grp in w.get("groups", []):
			if float(grp.get("armor", 1.0)) < 0.8:
				armored_wave = true
	Check(armored_wave, "关卡里至少有一波甲魅")

	sim.waves.prep_timer = 0.01
	sim.Step(1.0 / float(sim.config.tick_rate))
	Check(sim.waves.state != SimWaves.PREP, "倒计时结束进入战斗")
	Check(not sim.NextWave().is_empty(), "战斗中仍能读到当前波")


func Test_Armor() -> void:
	var sim := _new_sim("01")
	var ghost: SimGhost = sim.ghosts.values()[0]
	ghost.angle = 0.0
	ghost.angular_velocity = 0.0
	ghost.standing = true
	ghost.phase = 0.0
	sim._rebuild_field()
	var p := Vector2(-2.0, 2.0)
	Check(sim.field.EnvelopeAt(p) > sim.DamageLine(), "测试点在场内")
	Check(sim.field.EnvelopeAt(p) < sim.ClearLine(), "测试点没到清场线")
	sim.SpawnEnemy(p, 200.0, 0.0, 1.0)
	sim.SpawnEnemy(p, 200.0, 0.0, 0.4)
	_step_for(sim, 1.0)

	var soft: SimEnemy = null
	var hard: SimEnemy = null
	for id in sim.enemies:
		var e: SimEnemy = sim.enemies[id]
		if e.armor >= 0.99:
			soft = e
		else:
			hard = e
	Check(soft != null and hard != null, "两种魅都在场")
	if soft != null and hard != null:
		Check(soft.hp < hard.hp, "甲魅吃到的伤害更少")
		Check(hard.hp < 200.0, "甲魅仍然会掉血")


func Test_NightReport() -> void:
	var clear_stats := {"killed": 10, "cleared_killed": 7, "manual_inserts": 2, "auto_swaps": 5, "moves": 4}
	var tags := NightReport.Tags(clear_stats, 0)
	Check(tags.has("清场流"), "清场占多数标为清场流")
	Check(tags.has("零漏"), "零漏标出来")
	Check(tags.has("调场师"), "挪位多标为调场师")
	Check(tags.has("半自动"), "手搬与自动并存标为半自动")
	var summary := NightReport.Summary(clear_stats, 0)
	Check(not summary.is_empty(), "清场流有描述")

	var grind_stats := {"killed": 6, "cleared_killed": 0, "manual_inserts": 12, "auto_swaps": 0, "moves": 0}
	var grind_tags := NightReport.Tags(grind_stats, 2)
	Check(grind_tags.has("磨血流"), "没有越线标为磨血流")
	Check(grind_tags.has("手搬"), "手动换晶多标为手搬")
	Check(not grind_tags.has("零漏"), "有漏就不标零漏")

	var auto_stats := {"killed": 5, "cleared_killed": 1, "manual_inserts": 0, "auto_swaps": 6, "moves": 0}
	Check(NightReport.Tags(auto_stats, 0).has("自动物流"), "全自动标为自动物流")
	Check(NightReport.Tags(auto_stats, 0).has("混合流"), "少量清场标为混合流")
	var reso_stats := {"killed": 9, "cleared_killed": 3, "resonance_bursts": 4}
	Check(NightReport.Tags(reso_stats, 0).has("共振流"), "多次共振标为共振流")

	var logi := {
		"killed": 8, "cleared_killed": 4, "manual_inserts": 0, "auto_swaps": 0,
		"loader_swaps": 9, "belt_transfers": 40, "outlaw_built": 4, "annexed": 2,
	}
	var logi_tags := NightReport.Tags(logi, 0)
	Check(logi_tags.has("传送带流"), "带子搬得多标为传送带流")
	Check(logi_tags.has("越界者"), "越界建造多标为越界者")
	Check(logi_tags.has("收编者"), "收编多标为收编者")
	Check(logi_tags.has("自动物流"), "装卸臂也算自动物流")
	Check(NightReport.Summary(logi, 0).contains("带子上"), "报告里提到传送带")


func Test_Modifiers() -> void:
	var mods := GameData.Modifiers()
	CheckEq(mods.size(), 3, "加载到三条夜规")
	var tight := GameData.Modifier("tight")
	Check(not tight.is_empty(), "紧箍可加载")
	var lv := LevelModifier.Apply(GameData.Level("01"), tight)
	CheckEq(int(lv.get("budget", 0)), 63, "紧箍把预算降到 70%")
	CheckNear(float(lv.get("waves", [])[0].get("prep", 0.0)), 35.0, "紧箍不改准备时间", 0.001)
	CheckEq(String(lv.get("active_modifier", {}).get("id", "")), "tight", "关卡记下当前夜规")
	CheckEq(int(GameData.Level("01").get("budget", 0)), 90, "原关卡数据没有被改")

	var rush := LevelModifier.Apply(GameData.Level("01"), GameData.Modifier("rush"))
	CheckNear(float(rush.get("waves", [])[0].get("prep", 0.0)), 21.0, "催命把准备时间降到 60%", 0.001)
	CheckEq(int(rush.get("budget", 0)), 90, "催命不改预算")

	var solo := LevelModifier.Apply(GameData.Level("02"), GameData.Modifier("solo"))
	Check(not solo.get("unlocks", []).has("hand"), "孤军移除搬运手图纸")

	var solo_lv1 := LevelModifier.Apply(GameData.Level("01"), GameData.Modifier("solo"))
	var reward_has_hand := false
	for r in solo_lv1.get("rewards", []):
		if r is Dictionary and String(r.get("unlock", "")) == "hand":
			reward_has_hand = true
	Check(not reward_has_hand, "孤军也清掉奖励里的搬运手解锁")


func Test_Resonance() -> void:
	var sim := _new_sim("01")
	var bursts := [0]
	sim.events.ResonanceBurst.connect(func(_p: Vector2, _a: float, _r: float): bursts[0] += 1)
	sim.SpawnEnemy(Vector2(2.0, 0.0), 40.0, 0.0)
	sim.time = 1.0
	sim._pulse_tick_sum = 3.4
	sim._pulse_tick_count = 3
	sim._pulse_centroid = Vector2.ZERO
	sim._resolve_resonance(0.05)
	CheckEq(bursts[0], 1, "三只同频鬼叠过阈值 → 触发一次共振")
	CheckEq(int(sim.stats.get("resonance_bursts", 0)), 1, "共振次数入统计")
	Check(sim.enemies.is_empty(), "范围内的魅被大波段抹掉")
	Check(sim.resonance_charge < 0.01, "触发后蓄能清零")
	Check(sim.resonance_ready_at > sim.time, "进入冷却")

	# 冷却中不再触发
	sim._pulse_tick_sum = 3.4
	sim._pulse_tick_count = 3
	sim._pulse_centroid = Vector2.ZERO
	sim._resolve_resonance(0.05)
	CheckEq(bursts[0], 1, "冷却中不会连续触发")

	# 单只鬼即使振幅很大，也不算“同频叠加”
	var solo := _new_sim("01")
	solo._pulse_tick_sum = 5.0
	solo._pulse_tick_count = 1
	solo._pulse_centroid = Vector2.ZERO
	solo._resolve_resonance(0.05)
	CheckEq(int(solo.stats.get("resonance_bursts", 0)), 0, "单只鬼不触发共振")
	Check(solo.resonance_charge >= 0.99, "单只大振幅仍会蓄能")

	# 未满时是蓄能，不触发；松开后会衰减
	solo._pulse_tick_count = 0
	solo.resonance_charge = 0.5
	solo._resolve_resonance(0.5)
	Check(solo.resonance_charge < 0.5, "没有脉冲时蓄能会衰减")

	# 快照保留蓄能与冷却
	solo.resonance_charge = 0.6
	solo.resonance_ready_at = 9.0
	var snap := solo.Snapshot()
	solo.resonance_charge = 0.0
	solo.resonance_ready_at = 0.0
	solo._snapshot = snap
	solo.RestoreSnapshot()
	CheckNear(solo.resonance_charge, 0.6, "回溯保留共振蓄能", 0.001)
	CheckNear(solo.resonance_ready_at, 9.0, "回溯保留共振冷却", 0.001)


func Test_BossBreach() -> void:
	var sim := _new_sim("01")
	Check(sim.run_state == Sim.PLAYING, "开局进行中")
	sim.SpawnEnemy(Vector2(1.0, 0.0), 300.0, 1.0, 0.2, true)
	sim.Step(1.0 / float(sim.config.tick_rate))
	Check(sim.run_state == Sim.FAILED, "魅王抵达中央直接判负")
	var has_boss := false
	for w in sim.level.get("waves", []):
		for grp in w.get("groups", []):
			if bool(grp.get("boss", false)):
				has_boss = true
	Check(has_boss, "关卡最后一波包含魅王")


func Test_FailAndRollback() -> void:
	var level := {
		"id": "test",
		"grid": {"w": 9, "h": 9},
		"buildable": {"x": 1, "y": 1, "w": 7, "h": 7},
		"center_radius": 1.0,
		"spawn_radius": 5.0,
		"max_breaches": 3,
		"budget": 20,
		"unlocks": ["waver"],
		"initial": [],
		"initial_crystals": [],
		"hints": [],
		"rewards": [{"budget": 5}],
		"waves": [
			{"prep": 0.05, "groups": [
				{"count": 5, "interval": 0.05, "center_deg": 0, "arc_deg": 0, "hp": 10, "speed": 30},
			]},
		],
	}
	var cfg := SimConfig.FromDictionary(GameData.Game())
	var sim := Sim.new()
	sim.Setup(level, cfg)
	_step_for(sim, 3.0)
	Check(sim.run_state == Sim.FAILED, "抵达中央满额即失败")
	CheckEq(sim.breaches, 3, "抵达计数正确")

	sim.RestoreSnapshot()
	Check(sim.run_state == Sim.PLAYING, "回溯后恢复进行中")
	CheckEq(sim.breaches, 0, "回溯清空抵达计数")
	CheckEq(sim.enemies.size(), 0, "回溯清空场上魅")
	CheckEq(sim.economy.budget, 20, "回溯恢复预算")


func Test_ClosedLoop() -> void:
	var sim := _new_sim("01")
	var built := sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)
	Check(bool(built["ok"]), "机关落在鬼的脚边")
	Check(bool(sim.PickCrystal(Vector2i(5, 8))["ok"]), "拿起充能鬼晶")
	Check(bool(sim.InsertHeld(Vector2i(4, 8))["ok"]), "插入")
	_step_for(sim, 6.0)
	var ghost: SimGhost = sim.ghosts.values()[0]
	Check(ghost.standing, "闭环第一步：机关把鬼顶到立正")
	Check(ghost.pulse_total >= 1, "闭环第二步：鬼发脉冲")

	var charged := false
	for id in sim.crystals:
		var c: SimCrystal = sim.crystals[id]
		if c.IsOnGround() and c.charge > 0.0 and c.cell == Vector2i(3, 6):
			charged = true
	Check(charged, "闭环第三步：脉冲给空鬼晶充能")


func Test_SwingInterference() -> void:
	var sim := _new_sim("01")
	sim.economy.Unlock("swing")
	var built := sim.Build("ghost", "swing", Vector2i(6, 8), 0)
	Check(bool(built["ok"]), "摆臂鬼可建造")
	for id in sim.ghosts:
		var g: SimGhost = sim.ghosts[id]
		g.angle = 0.0
		g.angular_velocity = 0.0
		g.standing = true
		g.phase = 0.0
	sim._rebuild_field()
	var mid := Vector2(-1.5, 2.0)
	Check(sim.field.EnvelopeAt(mid) > sim.ClearLine(), "翘脚鬼 + 摆臂鬼同相叠加越过清场线")
	Check(sim.field.EnvelopeAt(Vector2(-1.5, 2.0)) > sim.field.EnvelopeAt(Vector2(5.0, 5.0)), "场向边缘衰减")


func Test_WaveRewardUnlock() -> void:
	var sim := _new_sim("01")
	var budget := sim.economy.budget
	Check(not sim.economy.IsUnlocked("swing"), "开局未解锁摆臂鬼")
	sim._on_wave_cleared(0)
	Check(sim.economy.IsUnlocked("swing"), "第一波奖励解锁摆臂鬼")
	CheckEq(sim.economy.budget, budget + 20, "第一波奖励入账")
	sim._on_wave_cleared(1)
	Check(sim.economy.IsUnlocked("hand"), "第二波奖励解锁搬运手")
	CheckEq(sim.economy.budget, budget + 20 + 20, "第二波奖励入账")


func Test_WaveOneSurvives() -> void:
	# 模拟一个「会换晶」的玩家：机关没电就换一颗，看第一波能否不漏。
	var sim := _new_sim("01")
	var built := sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)
	Check(bool(built["ok"]), "布置机关")
	var mech: SimMechanism = sim.mechanisms[int(built["id"])]
	Check(bool(sim.PickCrystal(Vector2i(5, 8))["ok"]), "上第一颗晶")
	Check(bool(sim.InsertHeld(Vector2i(4, 8))["ok"]), "插晶")

	var step := sim.config.tick_step
	var swaps := 0
	var max_ticks := int(75.0 / step)
	for i in max_ticks:
		sim.Step(step)
		if sim.run_state != Sim.PLAYING:
			break
		if sim.waves.next_index >= 1:
			break
		if mech.crystal_id < 0:
			continue
		var c: SimCrystal = sim.crystals.get(mech.crystal_id)
		if c == null or c.charge >= 1.0:
			continue
		var src := _find_charged_on_ground(sim)
		if src == null:
			continue
		if bool(sim.PickCrystal(src.cell).get("ok", false)):
			sim.EjectCrystal(mech.cell)
			if bool(sim.InsertHeld(mech.cell).get("ok", false)):
				swaps += 1

	Check(sim.waves.next_index >= 1, "第一波被清空（换晶 %d 次）" % swaps)
	CheckEq(sim.breaches, 0, "第一波没有漏")
	Check(sim.run_state == Sim.PLAYING, "仍在进行中")


func _find_charged_on_ground(sim: Sim) -> SimCrystal:
	for id in sim.crystals:
		var c: SimCrystal = sim.crystals[id]
		if c.IsOnGround() and c.charge >= 1.0:
			return c
	return null


func Test_FullRun() -> void:
	# 一个「会换晶、会用新图纸」的脚本玩家，把第一夜从头打到尾。
	var sim := _new_sim("01")
	var built := sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)
	Check(bool(built["ok"]), "起手机关")
	var m1: SimMechanism = sim.mechanisms[int(built["id"])]
	Check(bool(sim.PickCrystal(Vector2i(5, 8))["ok"]), "第一颗晶")
	Check(bool(sim.InsertHeld(Vector2i(4, 8))["ok"]), "插晶")

	var m2: SimMechanism = null
	var step := sim.config.tick_step
	var max_ticks := int(280.0 / step)
	for i in max_ticks:
		sim.Step(step)
		if sim.run_state != Sim.PLAYING:
			break
		# 第一波奖励解锁摆臂鬼后，把它摆到鬼的同一排，配一台机关（干涉最亮的位置）
		if m2 == null and sim.economy.IsUnlocked("swing"):
			var g := sim.Build("ghost", "swing", Vector2i(6, 8), 0)
			var mech := sim.Build("mechanism", "pusher", Vector2i(7, 8), 2)
			if bool(g.get("ok", false)) and bool(mech.get("ok", false)):
				m2 = sim.mechanisms[int(mech["id"])]
		if m2 != null and m2.crystal_id < 0:
			var src := _find_charged_on_ground(sim)
			if src != null and bool(sim.PickCrystal(src.cell).get("ok", false)):
				sim.InsertHeld(Vector2i(7, 8))
		_keep_powered(sim, m1)
		if m2 != null:
			_keep_powered(sim, m2)

	if sim.run_state != Sim.CLEARED:
		print("FULLRUN_FAIL state=%s wave=%d breaches=%d ghosts=%d mechs=%d budget=%d" % [
			String(sim.run_state), sim.waves.next_index, sim.breaches,
			sim.ghosts.size(), sim.mechanisms.size(), sim.economy.budget,
		])
	Check(sim.run_state == Sim.CLEARED, "完整四波通关（状态 %s，漏 %d）" % [String(sim.run_state), sim.breaches])
	Check(sim.breaches < sim.max_breaches, "没有判负")


func _keep_powered(sim: Sim, mech: SimMechanism) -> void:
	if mech == null or mech.crystal_id < 0:
		return
	var c: SimCrystal = sim.crystals.get(mech.crystal_id)
	if c == null or c.charge >= 1.0:
		return
	var src := _find_charged_on_ground(sim)
	if src == null:
		return
	if bool(sim.PickCrystal(src.cell).get("ok", false)):
		sim.EjectCrystal(mech.cell)
		sim.InsertHeld(mech.cell)


func Test_Level02() -> void:
	# 走廊：预置鬼在西，摆臂鬼放在东；魅王来之前把两只鬼和机关整体挪到东段，
	# 让清场区落在魅王的必经路上。这就是「读下一波 → 调场」的参考解。
	var cfg := SimConfig.FromDictionary(GameData.Game())
	var sim := Sim.new()
	sim.Setup(GameData.Level("02"), cfg)

	Check(bool(sim.Build("mechanism", "pusher", Vector2i(5, 4), 2)["ok"]), "起手机关")
	var m1: SimMechanism = sim.mechanisms.values()[0]
	Check(bool(sim.PickCrystal(Vector2i(6, 4))["ok"]), "拿西侧充能晶")
	Check(bool(sim.InsertHeld(Vector2i(5, 4))["ok"]), "插给机关")

	Check(bool(sim.Build("ghost", "swing", Vector2i(11, 4), 0)["ok"]), "建摆臂鬼")
	Check(bool(sim.Build("mechanism", "pusher", Vector2i(12, 4), 2)["ok"]), "建第二台机关")
	var m2: SimMechanism = null
	for mid in sim.mechanisms:
		if sim.mechanisms[mid].cell == Vector2i(12, 4):
			m2 = sim.mechanisms[mid]
	Check(m2 != null, "找到第二台机关")
	Check(bool(sim.PickCrystal(Vector2i(8, 4))["ok"]), "拿东侧充能晶")
	Check(bool(sim.InsertHeld(Vector2i(12, 4))["ok"]), "插给第二台机关")

	var boss_prepped := false
	var step := sim.config.tick_step
	for i in int(300.0 / step):
		sim.Step(step)
		if sim.run_state != Sim.PLAYING:
			break
		if not boss_prepped and _wave_has_boss(sim.NextWave()):
			if sim.cells.has(Vector2i(9, 4)):
				sim.RemoveAt(Vector2i(9, 4))
			var mv1 := sim.MoveEntity(Vector2i(4, 4), Vector2i(8, 4))
			var mv2 := sim.MoveEntity(Vector2i(5, 4), Vector2i(9, 4))
			boss_prepped = bool(mv1.get("ok", false)) and bool(mv2.get("ok", false))
		_keep_powered(sim, m1)
		_keep_powered(sim, m2)

	if sim.run_state != Sim.CLEARED:
		print("LEVEL02_FAIL state=%s wave=%d breaches=%d budget=%d" % [
			String(sim.run_state), sim.waves.next_index, sim.breaches, sim.economy.budget,
		])
	Check(boss_prepped, "魅王波之前完成了调场")
	Check(sim.run_state == Sim.CLEARED, "第二夜完整通关")


func _wave_has_boss(wave: Dictionary) -> bool:
	for grp in wave.get("groups", []):
		if bool(grp.get("boss", false)):
			return true
	return false


func Test_OneWaveClear() -> void:
	var sim := _new_sim("01")
	var built := sim.Build("ghost", "waver", Vector2i(6, 8), 0)
	Check(bool(built["ok"]), "第二只鬼可建造")
	# 把两只鬼都摆到「已立正、同相」的状态
	for id in sim.ghosts:
		var g: SimGhost = sim.ghosts[id]
		g.angle = 0.0
		g.angular_velocity = 0.0
		g.standing = true
		g.phase = 0.0
	var mid := Vector2(-1.5, 2.0)
	sim._rebuild_field()
	Check(sim.field.EnvelopeAt(mid) > sim.ClearLine(), "两只同相鬼的中间越过了清场线")
	sim.SpawnEnemy(mid, 500.0, 0.0, 0.2, true)
	sim.Step(1.0 / float(sim.config.tick_rate))
	Check(int(sim.stats.get("cleared_killed", 0)) >= 1, "越过清场线的魅王被直接抹掉")


func Test_Pause() -> void:
	var sim := _new_sim("01")
	var t0 := sim.time
	sim.SetPaused(true)
	_step_for(sim, 2.0)
	CheckNear(sim.time, t0, "暂停时世界时钟冻结", 0.0001)
	var built := sim.Build("mechanism", "pusher", Vector2i(6, 6), 0)
	Check(bool(built["ok"]), "暂停中仍可建造")
	sim.SetPaused(false)
	_step_for(sim, 0.5)
	Check(sim.time > t0, "解除暂停后继续推进")


func Test_RollbackIds() -> void:
	# 回归：回溯时曾用新 id 建实体、再把 id 改回旧的，字典键却还是新 id，
	# 导致脉冲事件找不到鬼。这里锁死「键 == 实体 id」。
	var sim := _new_sim("01")
	sim.Build("mechanism", "pusher", Vector2i(4, 8), 2)
	sim.PickCrystal(Vector2i(5, 8))
	sim.InsertHeld(Vector2i(4, 8))
	sim.economy.Unlock("hand")
	Check(bool(sim.Build("swapper", "hand", Vector2i(6, 6))["ok"]), "建搬运手")
	sim._snapshot = sim.Snapshot()
	sim._fail("test")
	sim.RestoreSnapshot()

	for id in sim.ghosts:
		CheckEq(int(sim.ghosts[id].id), int(id), "回溯后鬼的 id 与字典键一致")
	for id in sim.mechanisms:
		CheckEq(int(sim.mechanisms[id].id), int(id), "回溯后机关 id 与字典键一致")
	for id in sim.crystals:
		CheckEq(int(sim.crystals[id].id), int(id), "回溯后鬼晶 id 与字典键一致")
	CheckEq(sim.swappers.size(), 1, "回溯后搬运手仍在")
	for id in sim.swappers:
		CheckEq(int(sim.swappers[id].id), int(id), "回溯后搬运手 id 与字典键一致")
		Check(sim.cells.has(sim.swappers[id].cell), "回溯后搬运手占格还在")

	var ghost: SimGhost = sim.ghosts.values()[0]
	var mech: SimMechanism = sim.mechanisms.values()[0]
	Check(mech.crystal_id >= 0 and sim.crystals.has(mech.crystal_id), "回溯后插槽引用仍然有效")

	ghost.angle = 0.0
	ghost.angular_velocity = 0.0
	ghost.standing = true
	ghost.phase = TAU - 0.001
	var empty: SimCrystal = null
	for id in sim.crystals:
		var c: SimCrystal = sim.crystals[id]
		if c.IsOnGround() and c.charge < 1.0:
			empty = c
	Check(empty != null, "有空鬼晶")
	var charge_before := empty.charge if empty != null else 0.0
	sim.Step(1.0 / float(sim.config.tick_rate))
	Check(ghost.pulse_total > 0, "回溯后仍能发脉冲")
	if empty != null:
		Check(empty.charge > charge_before, "回溯后脉冲仍能充能")


func Test_Save() -> void:
	# 用 res:// 下的路径：测试进程的 user:// 目录在沙箱外，可能不可写。
	# 默认档必须用一个「肯定不存在」的路径，避免上一次测试残留的文件干扰。
	var fresh_path := "res://.godot/test_save_fresh_%d.json" % int(Time.get_ticks_usec())
	var fresh := SaveService.new(fresh_path)
	var meta := fresh.LoadMeta()
	CheckEq(int(meta.get("version", 0)), SaveService.CURRENT_VERSION, "无档时返回默认档")
	CheckEq(String(meta.get("current_level", "")), "01", "默认档从第一夜开始")
	Check(not bool(meta.get("tutorial_done", true)), "默认档尚未完成新手引导")

	var path := "res://.godot/test_save_ghost_factory.json"
	var svc := SaveService.new(path)
	var mine := svc.LoadMeta()
	mine["best_wave"] = 3
	mine["current_level"] = "02"
	mine["unlocks"] = ["waver", "pusher"]
	Check(svc.SaveMeta(mine), "存档写入成功")
	var back := svc.LoadMeta()
	CheckEq(int(back.get("best_wave", 0)), 3, "存档往返：最佳波次")
	CheckEq(String(back.get("current_level", "")), "02", "存档往返：当前关卡")
	CheckEq(back.get("unlocks", []).size(), 2, "存档往返：解锁列表")

	var v0 := {"unlocks": ["waver"], "best_wave": 1}
	var migrated := SaveService.Migrate(v0)
	CheckEq(int(migrated.get("version", 0)), SaveService.CURRENT_VERSION, "v0 迁移到当前版本")
	Check(migrated.has("settings"), "迁移补上默认设置段")
	Check(migrated.has("stats"), "迁移补上默认统计段")


# ---------------------------------------------------------------------------

func Test_Catalog() -> void:
	var content := GameData.Content()
	Check(not content.is_empty(), "content.json 可加载")
	var catalog := GameData.Catalog()
	Check(catalog.size() >= 18, "建造栏登记了全部内容（%d 条）" % catalog.size())
	var kinds := {}
	for entry in catalog:
		var kind := String(entry.get("kind", ""))
		var cid := String(entry.get("id", ""))
		kinds[kind] = true
		Check(GameData.HasDefinition(kind, cid), "目录条目存在：%s/%s" % [kind, cid])
		Check(int(GameData.DefinitionFor(kind, cid).get("cost", -1)) >= 0, "目录条目有造价：%s" % cid)
	for kind in ["ghost", "mechanism", "crystal", "swapper", "belt"]:
		Check(kinds.has(kind), "目录覆盖了 %s" % kind)
	var ids := GameData.LevelIds()
	Check(ids.has("03"), "关卡列表包含第三夜")
	Check(not GameData.Level("03").is_empty(), "第三夜可加载")
	CheckEq(String(GameData.Level("02").get("next_level", "")), "03", "第二夜指向第三夜")
	var lv3 := GameData.Level("03")
	Check(bool(lv3.get("allow_outlaw", false)), "第三夜允许越界建造")
	Check(int(lv3.get("expand_per_wave", 0)) > 0, "第三夜每波扩地")
	Check(int(lv3.get("grid", {}).get("w", 0)) >= 21, "第三夜是一张大地图")


func Test_Belt() -> void:
	var sim := _new_sim_custom(_test_level(8, 8))
	Check(bool(sim.Build("belt", "belt", Vector2i(1, 4), 0)["ok"]), "建传送带")
	Check(bool(sim.Build("belt", "belt", Vector2i(2, 4), 0)["ok"]), "建第二条传送带")
	CheckEq(String(sim.Build("belt", "belt", Vector2i(1, 4), 0)["reason"]), "occupied", "带子占格")
	var built := sim.Build("crystal", "crystal", Vector2i(1, 5))
	var cid := int(built["id"])
	Check(bool(sim.PickCrystal(Vector2i(1, 5))["ok"]), "拿起鬼晶")
	Check(bool(sim.DropHeld(Vector2i(1, 4))["ok"]), "可以放到带面上")
	var c: SimCrystal = sim.crystals[cid]
	Check(c.ride_belt >= 0, "鬼晶骑在带面上")
	Check(not sim.cells.has(Vector2i(1, 5)), "旧格释放")
	_step_for(sim, 1.1)
	CheckEq(c.cell, Vector2i(2, 4), "一格一秒：交给下一条带子")
	_step_for(sim, 1.1)
	CheckEq(c.cell, Vector2i(3, 4), "带面尽头落到地上")
	CheckEq(c.ride_belt, -1, "落地后不再骑带")
	Check(sim.cells.has(Vector2i(3, 4)), "落地占格")
	Check(bool(sim.PickCrystal(Vector2i(3, 4))["ok"]), "地上的晶还能再拿起来")

	# 带面上的晶会被脉冲充能
	var sim2 := _new_sim_custom(_test_level(9, 9))
	sim2.Build("ghost", "waver", Vector2i(4, 4), 0)
	sim2.Build("belt", "belt", Vector2i(5, 4), 0)
	var b2 := sim2.Build("crystal", "crystal", Vector2i(5, 5))
	var c2: SimCrystal = sim2.crystals[int(b2["id"])]
	sim2.PickCrystal(Vector2i(5, 5))
	Check(bool(sim2.DropHeld(Vector2i(5, 4))["ok"]), "放下时落到带面上")
	var g: SimGhost = sim2.ghosts.values()[0]
	g.angle = 0.0
	g.angular_velocity = 0.0
	g.standing = true
	g.phase = TAU - 0.001
	sim2.Step(1.0 / float(sim2.config.tick_rate))
	Check(c2.charge > 0.0, "带面上的鬼晶能被脉冲充能")
	CheckEq(c2.ride_belt >= 0, true, "充能时仍在带面上")


func Test_Loader() -> void:
	var sim := _new_sim_custom(_test_level(8, 8))
	Check(bool(sim.Build("mechanism", "pusher", Vector2i(3, 4), 0)["ok"]), "建机关")
	Check(bool(sim.Build("belt", "belt", Vector2i(1, 4), 0)["ok"]), "建带子")
	Check(bool(sim.Build("swapper", "arm", Vector2i(2, 4))["ok"]), "建装卸臂")
	var cb := sim.Build("crystal", "crystal", Vector2i(0, 4))
	var c: SimCrystal = sim.crystals[int(cb["id"])]
	c.charge = 5.0
	Check(bool(sim.PickCrystal(Vector2i(0, 4))["ok"]), "拿起充能晶")
	Check(bool(sim.DropHeld(Vector2i(1, 4))["ok"]), "放上带面")
	_step_for(sim, 1.3)
	var mech: SimMechanism = sim.mechanisms.values()[0]
	Check(mech.crystal_id >= 0, "装卸臂把带面充能晶送进机关")
	var slotted: SimCrystal = sim.crystals.get(mech.crystal_id)
	Check(slotted != null, "槽里有晶")
	if slotted != null:
		CheckNear(slotted.charge, 4.0, "搬运抽走 1 单位", 0.001)
	# 运行到电耗尽：空晶会被换出来，落到带面 / 空地
	_step_for(sim, 12.0)
	Check(int(sim.stats.get("loader_swaps", 0)) >= 2, "装卸臂至少完成了两次搬运")
	var any_empty_out := false
	for id in sim.crystals:
		var cc: SimCrystal = sim.crystals[id]
		if cc.slotted_in < 0 and cc.charge < 1.0:
			any_empty_out = true
	Check(any_empty_out, "空晶被换出到场上")


func Test_MechanismEffects() -> void:
	# 节拍机关：把守夜钟的 3.2 秒改写成 2.0，让它和翘脚鬼相干叠加
	var sim := _new_sim_custom(_test_level(9, 9))
	var toll := _standing_ghost(sim, "toll", Vector2i(2, 4), 0)
	var waver := _standing_ghost(sim, "waver", Vector2i(6, 4), 0)
	sim._rebuild_field()
	var mid := Vector2(0.0, 0.0)  # 9x9 的中心
	var before := sim.field.EnvelopeAt(mid)
	CheckNear(toll.EffPeriod(), 3.2, "守夜钟固有周期 3.2", 0.001)
	Check(before < sim.ClearLine(), "异频两只鬼叠不过清场线（%.3f）" % before)
	Check(bool(sim.Build("mechanism", "tuner", Vector2i(4, 4), 0)["ok"]), "建节拍机关")
	_power_cell(sim, Vector2i(4, 4), Vector2i(4, 5), 5.0)
	_step_for(sim, 0.1)
	CheckNear(toll.EffPeriod(), 2.0, "节拍机关把周期改写成 2.0", 0.001)
	sim._rebuild_field()
	var after := sim.field.EnvelopeAt(mid)
	Check(after > before + 0.2, "同频后振幅叠加（%.3f → %.3f）" % [before, after])
	Check(after > sim.ClearLine(), "改写周期后越过了清场线")

	# 共鸣腔：放大振幅
	var sim2 := _new_sim_custom(_test_level(9, 9))
	_standing_ghost(sim2, "waver", Vector2i(2, 4), 0)
	sim2._rebuild_field()
	var at := sim2.grid.CellToWorld(Vector2i(2, 4))
	var base_amp := sim2.field.EnvelopeAt(at)
	Check(bool(sim2.Build("mechanism", "amp", Vector2i(4, 4), 0)["ok"]), "建共鸣腔")
	_power_cell(sim2, Vector2i(4, 4), Vector2i(4, 5), 5.0)
	_step_for(sim2, 0.1)
	sim2._rebuild_field()
	var boosted := sim2.field.EnvelopeAt(at)
	Check(boosted > base_amp + 0.25, "共鸣腔把振幅放大（%.3f → %.3f）" % [base_amp, boosted])

	# 传声筒：延长射程
	var sim3 := _new_sim_custom(_test_level(15, 15))
	_standing_ghost(sim3, "waver", Vector2i(3, 7), 0)
	sim3._rebuild_field()
	var far_cell := Vector2i(10, 7)
	var far_world := sim3.grid.CellToWorld(far_cell)
	CheckNear(sim3.field.EnvelopeAt(far_world), 0.0, "原射程之外是 0", 0.001)
	Check(bool(sim3.Build("mechanism", "reach", Vector2i(6, 7), 0)["ok"]), "建传声筒")
	_power_cell(sim3, Vector2i(6, 7), Vector2i(6, 8), 5.0)
	_step_for(sim3, 0.1)
	sim3._rebuild_field()
	Check(sim3.field.EnvelopeAt(far_world) > 0.1, "传声筒把射程推到远处")
	Check(waver.standing, "被改写的鬼仍然立正")
	Check(toll.standing, "守夜钟仍然立正")


func Test_Crank() -> void:
	var sim := _new_sim_custom(_test_level(9, 9))
	var a := _spawn_ghost(sim, "waver", Vector2i(3, 4), 0)
	var b := _spawn_ghost(sim, "waver", Vector2i(4, 4), 0)
	Check(bool(sim.Build("mechanism", "crank", Vector2i(2, 4), 0)["ok"]), "建长撬")
	_power_cell(sim, Vector2i(2, 4), Vector2i(2, 5), 5.0)
	_step_for(sim, 2.2)
	Check(a.standing, "长撬顶到第一只鬼的脚")
	Check(b.standing, "同一根撬杆顶到第二只鬼的脚")


func Test_Anchor() -> void:
	# 只有一根撬杆：支撑数 1，锚鬼不立正
	var sim := _new_sim_custom(_test_level(9, 9))
	var anchor := _spawn_ghost(sim, "anchor", Vector2i(3, 4), 0)
	Check(bool(sim.Build("mechanism", "crank", Vector2i(2, 4), 0)["ok"]), "建长撬")
	_power_cell(sim, Vector2i(2, 4), Vector2i(2, 5), 5.0)
	_step_for(sim, 2.2)
	Check(not anchor.standing, "单支撑不足以让锚鬼立正")
	# 再补一台顶足机关：支撑数 2 → 立正
	Check(bool(sim.Build("mechanism", "pusher", Vector2i(4, 4), 2)["ok"]), "补一台顶足机关")
	_power_cell(sim, Vector2i(4, 4), Vector2i(4, 5), 5.0)
	_step_for(sim, 2.2)
	Check(anchor.standing, "双支撑让锚鬼立正")


func Test_Relay() -> void:
	var sim := _new_sim_custom(_test_level(15, 15))
	var waver := _spawn_ghost(sim, "waver", Vector2i(2, 7), 0)
	var r1 := _spawn_ghost(sim, "relay", Vector2i(5, 7), 0)
	var r2 := _spawn_ghost(sim, "relay", Vector2i(8, 7), 0)
	waver.angle = 0.0
	waver.angular_velocity = 0.0
	waver.standing = true
	waver.phase = TAU - 0.001
	sim.Step(1.0 / float(sim.config.tick_rate))
	Check(r1.relay_due >= 0.0, "脉冲扫到接力鬼，排了一次发射")
	_step_for(sim, 0.2)
	Check(int(sim.stats.get("relay_pulses", 0)) >= 1, "接力鬼发出了第二手脉冲")
	Check(r1.relay_cooldown_left > 0.0, "发射后进入冷却")
	_step_for(sim, 0.2)
	Check(int(sim.stats.get("relay_pulses", 0)) >= 2, "接力链传到了第二只接力鬼")
	Check(r2.relay_active > 0.0, "接力鬼在活跃窗口里是波源")
	Check(sim.field.SourceCount() >= 1, "场里有接力鬼的波源")


func Test_HammerStrike() -> void:
	# 砸身体：目标朝东（背对锤鬼）→ 被推倒
	var sim := _new_sim_custom(_test_level(15, 15))
	var hammer := _spawn_ghost(sim, "hammer", Vector2i(6, 7), 0)
	var target := _spawn_ghost(sim, "waver", Vector2i(7, 7), 0)
	var struck := [0]
	var struck_helps: Array = []
	sim.events.GhostStruck.connect(func(_a, _b, _p, h):
		struck[0] += 1
		struck_helps.append(h)
	)
	sim.Build("mechanism", "pusher", Vector2i(5, 7), 0)
	_power_cell(sim, Vector2i(5, 7), Vector2i(4, 7), 6.0)
	var before := target.angle
	var max_angle := before
	for i in 60:
		sim.Step(0.05)
		max_angle = maxf(max_angle, target.angle)
	Check(int(sim.stats.get("strikes", 0)) >= 1, "锤鬼倒下砸中了邻鬼")
	Check(hammer.pulse_total >= 1, "锤鬼砸击时打出脉冲")
	Check(struck_helps.size() >= 1 and not bool(struck_helps[0]), "砸到身体：方向是推倒")
	Check(max_angle > before + 0.15, "砸到身体：目标被推倒（峰值 %.2f）" % max_angle)
	Check(struck[0] >= 1, "GhostStruck 事件被广播")

	# 砸脚：目标朝西（脚对着锤鬼）→ 被顶立正
	var sim2 := _new_sim_custom(_test_level(15, 15))
	var target2 := _spawn_ghost(sim2, "waver", Vector2i(7, 7), 2)
	_spawn_ghost(sim2, "hammer", Vector2i(6, 7), 0)
	sim2.Build("mechanism", "pusher", Vector2i(5, 7), 0)
	_power_cell(sim2, Vector2i(5, 7), Vector2i(4, 7), 6.0)
	var stood := [0]
	var helps2: Array = []
	sim2.events.GhostStruck.connect(func(_a, _b, _p, h): helps2.append(h))
	sim2.events.GhostStood.connect(func(gid):
		if gid == target2.id:
			stood[0] += 1
	)
	_step_for(sim2, 3.0)
	Check(helps2.size() >= 1 and bool(helps2[0]), "砸到脚：方向是帮它立正")
	Check(target2.pulse_total >= 1, "砸到脚：目标被顶立正并发脉冲")
	Check(stood[0] >= 1, "目标鬼确实站起过")


func Test_BraceSupport() -> void:
	var sim := _new_sim_custom(_test_level(15, 15))
	var anchor := _spawn_ghost(sim, "anchor", Vector2i(7, 7), 0)
	sim.Build("mechanism", "crank", Vector2i(5, 7), 0)
	_power_cell(sim, Vector2i(5, 7), Vector2i(4, 7), 8.0)
	_step_for(sim, 1.6)
	Check(not anchor.standing, "只有一台长撬，锚鬼站不起来")
	var brace := _spawn_ghost(sim, "prop", Vector2i(8, 7), 0)
	sim.Build("mechanism", "pusher", Vector2i(9, 7), 2)
	_power_cell(sim, Vector2i(9, 7), Vector2i(10, 7), 8.0)
	_step_for(sim, 2.4)
	Check(brace.standing, "撑鬼自己被顶住了")
	Check(brace.support_load >= 1, "撑鬼撑住了倒向它的锚鬼")
	Check(anchor.standing, "长撬 + 撑鬼两个支撑让锚鬼立正")
	Check(sim.links.size() >= 1, "支撑关系有一条连杆")


func Test_PendulumSpeed() -> void:
	var sim := _new_sim_custom(_test_level(15, 15))
	var p := _spawn_ghost(sim, "pendulum", Vector2i(7, 7), 0)
	_step_for(sim, 1.0)
	CheckEq(p.pulse_total, 0, "没人碰它，它不响")
	p.angular_velocity = 3.0
	_step_for(sim, 2.0)
	Check(p.pulse_total >= 1, "速度过阈值后发脉冲")
	Check(not p.standing, "摆锤鬼不站")


func Test_HammerDrivesPendulum() -> void:
	var sim := _new_sim_custom(_test_level(15, 15))
	_spawn_ghost(sim, "hammer", Vector2i(6, 7), 0)
	var p := _spawn_ghost(sim, "pendulum", Vector2i(7, 7), 0)
	sim.Build("mechanism", "pusher", Vector2i(5, 7), 0)
	_power_cell(sim, Vector2i(5, 7), Vector2i(4, 7), 6.0)
	_step_for(sim, 3.0)
	Check(int(sim.stats.get("strikes", 0)) >= 1, "锤鬼砸到摆锤")
	Check(p.pulse_total >= 1, "摆锤被砸后荡出脉冲")


func Test_Outlaw() -> void:
	var sim := _new_sim_custom(GameData.Level("03"))
	CheckEq(sim.OutlawCount(), 0, "开局没有越界造物")
	Check(bool(sim.Build("ghost", "waver", Vector2i(6, 11), 0)["ok"]), "领地外可以建造（第三夜）")
	CheckEq(sim.OutlawCount(), 1, "越界造物被计数")
	CheckEq(int(sim.stats.get("outlaw_built", 0)), 1, "越界建造入统计")
	CheckEq(sim.WavePressureBonus(), 1, "一处越界 → 每组多刷 1 只")
	Check(bool(sim.Build("crystal", "crystal", Vector2i(5, 11), 0)["ok"]), "领地外也能放晶")
	CheckEq(sim.OutlawCount(), 1, "鬼晶不算造物，不引鬼")

	# 魅会来拆它
	var cell := Vector2i(6, 11)
	var w := sim.grid.CellToWorld(cell)
	sim.SpawnEnemy(w + Vector2(0.4, 0.0), 300.0, 0.0)
	_step_for(sim, 2.8)
	Check(not sim.cells.has(cell), "越界造物被魅拆掉")
	CheckEq(int(sim.stats.get("outlaw_lost", 0)), 1, "被拆计入统计")
	CheckEq(sim.enemies.size(), 0, "啃食者同归于尽")
	CheckEq(sim.OutlawCount(), 0, "拆掉后不再有越界造物")

	# 没有开放越界的关卡仍然拒绝
	var lv1 := _new_sim_custom(GameData.Level("01"))
	CheckEq(String(lv1.Build("ghost", "waver", Vector2i(0, 0))["reason"]), "outside_build", "第一夜不能越界建造")


func Test_Territory() -> void:
	var sim := _new_sim_custom(GameData.Level("03"))
	var before := sim.grid.build_rect
	CheckEq(before.size, Vector2i(5, 5), "第三夜开局 5×5 领地")
	Check(bool(sim.Build("ghost", "waver", Vector2i(7, 11), 0)["ok"]), "先在领地外落一只鬼")
	CheckEq(sim.OutlawCount(), 1, "它现在是越界造物")
	var r := sim.ExpandTerritory(2)
	Check(bool(r["ok"]), "扩地成功")
	CheckEq(sim.grid.build_rect.size, Vector2i(9, 9), "两圈后 9×9")
	CheckEq(int(r["annexed"]), 1, "新圈进来的造物被合法化")
	CheckEq(sim.OutlawCount(), 0, "扩地后不再越界")
	CheckEq(sim.territory_rings, 2, "扩地圈数被记录")
	var expanded: Array = []
	sim.events.TerritoryExpanded.connect(func(_rect: Rect2i, _n: int): expanded.append(true))
	sim.ExpandTerritory(1)
	Check(expanded.size() == 1, "扩地事件被广播")


func Test_LogisticsSnapshot() -> void:
	var sim := _new_sim_custom(GameData.Level("03"))
	sim.economy.Unlock("arm")
	Check(bool(sim.Build("belt", "belt", Vector2i(11, 12), 0)["ok"]), "建带子")
	var cb := sim.Build("crystal", "cell", Vector2i(12, 12))
	var c: SimCrystal = sim.crystals[int(cb["id"])]
	c.charge = 2.0
	sim.PickCrystal(Vector2i(12, 12))
	sim.DropHeld(Vector2i(11, 12))
	Check(bool(sim.Build("swapper", "arm", Vector2i(11, 13))["ok"]), "建装卸臂")
	Check(bool(sim.Build("ghost", "waver", Vector2i(6, 11), 0)["ok"]), "建越界鬼")
	var rings := sim.territory_rings
	sim._snapshot = sim.Snapshot()
	# 弄乱现场
	sim.RemoveAt(Vector2i(11, 12))
	sim.cells.erase(Vector2i(6, 11))
	sim.ghosts.clear()
	sim.belts.clear()
	sim.swappers.clear()
	sim.crystals.clear()
	sim.ExpandTerritory(1)
	sim.RestoreSnapshot()
	Check(sim.belts.size() == 1, "回溯恢复传送带")
	Check(sim.swappers.size() == 1, "回溯恢复装卸臂")
	Check(sim.ghosts.size() == 2, "回溯恢复鬼（预置 + 越界各一只）")
	Check(sim.cells.has(Vector2i(6, 11)), "越界鬼回到原位")
	CheckEq(sim.OutlawCount(), 1, "回溯恢复越界计数")
	CheckEq(sim.territory_rings, rings, "回溯恢复扩地圈数")
	var belt: SimBelt = sim.belts.values()[0]
	CheckEq(belt.cell, Vector2i(11, 12), "带子回到原格")
	CheckEq(belt.items.size(), 1, "带面上的晶随快照回来")
	if belt.items.size() == 1:
		var rc: SimCrystal = sim.crystals.get(int(belt.items[0]))
		Check(rc != null and rc.ride_belt == belt.id, "晶与带子的引用一致")


func Test_Behemoth() -> void:
	var sim := _new_sim_custom(GameData.Level("03"))
	var built := Behemoth.Build(sim)
	Check(int(built["failed"].size()) == 0, "庞然大物全部建好：" + str(built["failed"]))
	CheckEq(sim.territory_rings, 5, "领地扩到 15×15")
	print("BEHEMOTH built=%d ghosts=%d mechs=%d belts=%d swappers=%d crystals=%d" % [
		int(built["built"]), sim.ghosts.size(), sim.mechanisms.size(),
		sim.belts.size(), sim.swappers.size(), sim.crystals.size(),
	])
	var last := {}
	for step in range(1, 7):
		_step_for(sim, 10.0)
		last = Behemoth.Report(sim)
		print("BEHEMOTH t=%5.1f standing=%d/%d pulses=%d relay=%d energy=%6.1f powered=%d/%d beltmove=%d beltitems=%d loader=%d peak=%.2f hot=%d killed=%d clear=%d breach=%d wave=%d hungry=%s" % [
			float(last["time"]), int(last["standing"]), int(last["ghosts"]),
			int(last["pulses"]), int(last["relay_pulses"]), float(last["energy"]),
			int(last["powered"]), int(last["mechs"]),
			int(last["belt_transfers"]), int(last["belt_items"]), int(last["loader_swaps"]),
			float(last["field_peak"]), int(last["hot_cells"]), int(last["killed"]), int(last["cleared_killed"]),
			int(last["breaches"]), int(last["wave"]), str(last["hungry"]),
		])
	Check(sim.run_state == Sim.PLAYING, "六十秒后仍在运行")
	Check(int(last.get("pulses", 0)) >= 100, "脉冲一直没停（%d 次）" % int(last.get("pulses", 0)))
	Check(int(last.get("belt_transfers", 0)) > 0, "传送带在运鬼晶（%d 次）" % int(last.get("belt_transfers", 0)))
	Check(int(last.get("loader_swaps", 0)) > 0, "装卸臂完成了自动换料（%d 次）" % int(last.get("loader_swaps", 0)))
	Check(int(last.get("powered", 0)) == int(last.get("mechs", -1)), "所有机关都在工作（%d / %d）" % [int(last.get("powered", 0)), int(last.get("mechs", 0))])
	Check(int(last.get("hot_cells", 0)) >= 80, "清场线盖住了一大片（%d 格）" % int(last.get("hot_cells", 0)))
	Check(int(last.get("killed", 0)) > 0, "魅被机器打死")
	CheckEq(int(last.get("breaches", 0)), 0, "没有魅抵达中央")

	# 「一拱全爆」：往清场区里丢一只厚甲魅，它应该在同一 tick 被抹掉
	var hot_cell := Vector2i(-1, -1)
	for y in sim.grid.height:
		for x in sim.grid.width:
			if sim.heat[y * sim.heat_w + x] >= sim.ClearLine():
				hot_cell = Vector2i(x, y)
				break
		if hot_cell.x >= 0:
			break
	Check(hot_cell.x >= 0, "热力图里有超过清场线的格子")
	if hot_cell.x >= 0:
		var before_clear := int(sim.stats.get("cleared_killed", 0))
		sim.SpawnEnemy(sim.grid.CellToWorld(hot_cell), 800.0, 0.0, 0.2, true)
		sim.Step(1.0 / float(sim.config.tick_rate))
		Check(int(sim.stats.get("cleared_killed", 0)) > before_clear, "厚甲魅王在清场区里被一发抹掉")


func Test_Level03FirstWave() -> void:
	# 第三夜：用起手鬼 + 会换晶的脚本玩家守住第一波（不造越界，压力为 0）
	var sim := _new_sim_custom(GameData.Level("03"))
	var pusher: SimMechanism = null
	for id in sim.mechanisms:
		if sim.mechanisms[id].cell == Vector2i(11, 10):
			pusher = sim.mechanisms[id]
	Check(pusher != null, "起手机关在鬼脚边")
	Check(bool(sim.PickCrystal(Vector2i(10, 11)).get("ok", false)), "拿充能晶")
	Check(bool(sim.InsertHeld(Vector2i(11, 10)).get("ok", false)), "插进机关")
	var step := sim.config.tick_step
	for i in int(90.0 / step):
		sim.Step(step)
		if sim.run_state != Sim.PLAYING or sim.waves.next_index >= 1:
			break
		_keep_powered(sim, pusher)
	Check(sim.waves.next_index >= 1, "第三夜第一波能被守住（wave=%d）" % sim.waves.next_index)
	CheckEq(sim.breaches, 0, "第一波零漏")
	CheckEq(sim.OutlawCount(), 0, "没有越界造物，压力保持 0")
	Check(sim.grid.build_rect.size.x > 5, "清掉第一波后领地扩了一圈（%d）" % sim.grid.build_rect.size.x)


func Test_Level03Run() -> void:
	# 四向小机器：四只翘脚鬼围住中央，各自一台机关；脚本玩家负责换晶。
	var sim := _new_sim_custom(GameData.Level("03"))
	var units := [
		{"ghost": Vector2i(10, 10), "pusher": Vector2i(11, 10)},
		{"ghost": Vector2i(12, 10), "pusher": Vector2i(13, 10)},
		{"ghost": Vector2i(10, 12), "pusher": Vector2i(11, 12)},
		{"ghost": Vector2i(12, 12), "pusher": Vector2i(13, 12)},
	]
	for i in range(1, units.size()):
		var u: Dictionary = units[i]
		Check(bool(sim.Build("ghost", "waver", u["ghost"], 0).get("ok", false)), "补一只鬼 %d" % i)
		Check(bool(sim.Build("mechanism", "pusher", u["pusher"], 2).get("ok", false)), "补一台机关 %d" % i)
	var pushers: Array = []
	for u in units:
		var m := _mech_at(sim, u["pusher"])
		if m != null:
			pushers.append(m)
	CheckEq(pushers.size(), 4, "四台机关都在场")
	# 补充几颗空晶当周转
	for cell in [Vector2i(9, 10), Vector2i(9, 12), Vector2i(12, 9), Vector2i(12, 13)]:
		if not sim.cells.has(cell):
			Check(bool(sim.Build("crystal", "crystal", cell).get("ok", false)), "补一颗周转晶 " + str(cell))
	for m in pushers:
		_feed(sim, m)
	var step := sim.config.tick_step
	for i in int(700.0 / step):
		sim.Step(step)
		if sim.run_state != Sim.PLAYING:
			break
		for m in pushers:
			_feed(sim, m)
	if sim.run_state != Sim.CLEARED:
		print("LEVEL03_FAIL state=%s wave=%d breaches=%d budget=%d ghosts=%d mechs=%d territory=%s" % [
			String(sim.run_state), sim.waves.next_index, sim.breaches, sim.economy.budget,
			sim.ghosts.size(), sim.mechanisms.size(), str(sim.grid.build_rect.size),
		])
	Check(sim.run_state == Sim.CLEARED, "第三夜六波通关（状态 %s，漏 %d，波 %d）" % [
		String(sim.run_state), sim.breaches, sim.waves.next_index])
	Check(sim.breaches < sim.max_breaches, "没有判负")
	Check(sim.grid.build_rect.size.x > 5, "打通过程中领地扩张了（%d）" % sim.grid.build_rect.size.x)


func _mech_at(sim: Sim, cell: Vector2i) -> SimMechanism:
	var e := sim.CellEntity(cell)
	if e.is_empty() or String(e.get("kind", "")) != Sim.KIND_MECH:
		return null
	return sim.mechanisms.get(int(e.get("id", -1)))


## 脚本玩家的手：把机关里的空晶换掉，再从附近地上拿一颗充能晶塞进去。
func _feed(sim: Sim, mech: SimMechanism) -> void:
	if mech == null or not sim.mechanisms.has(mech.id):
		return
	if mech.crystal_id >= 0:
		var c: SimCrystal = sim.crystals.get(mech.crystal_id)
		if c != null and c.charge >= 1.0:
			return
		sim.EjectCrystal(mech.cell)
	if sim.held_crystal >= 0:
		var spot := _free_cell_near(sim, mech.cell)
		if spot.x < 0:
			return
		sim.DropHeld(spot)
	var src := _find_charged_on_ground(sim)
	if src == null:
		return
	if bool(sim.PickCrystal(src.cell).get("ok", false)):
		sim.InsertHeld(mech.cell)


func _free_cell_near(sim: Sim, cell: Vector2i) -> Vector2i:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var c := cell + Vector2i(dx, dy)
			if c == cell:
				continue
			if sim.CanBuildAt(c) and not sim.cells.has(c):
				return c
	return Vector2i(-1, -1)


func Test_LoaderDirection() -> void:
	# 臂朝北：背后（南）是回程带，正前方（北）是同向的来料带
	var sim := _new_sim_custom(_test_level(9, 9))
	Check(bool(sim.Build("mechanism", "pusher", Vector2i(3, 4), 0)["ok"]), "建机关")
	Check(bool(sim.Build("swapper", "arm", Vector2i(2, 4), 3)["ok"]), "建臂（朝北）")
	Check(bool(sim.Build("belt", "belt", Vector2i(2, 5), 1)["ok"]), "背后的回程带")
	Check(bool(sim.Build("belt", "belt", Vector2i(2, 3), 3)["ok"]), "正前方的来料带")
	var spent := _power_cell(sim, Vector2i(3, 4), Vector2i(4, 4), 1.0)
	var mech: SimMechanism = sim.mechanisms.values()[0]
	var slotted: SimCrystal = sim.crystals.get(mech.crystal_id)
	Check(slotted != null, "机关槽里有一颗晶")
	if slotted != null:
		slotted.charge = 0.0
	_step_for(sim, 1.2)
	CheckEq(mech.crystal_id, -1, "空晶被换出机关")
	var back: SimBelt = _belt_at(sim, Vector2i(2, 5))
	Check(back != null and back.items.size() >= 1, "空晶被放到背后的带子上")
	_step_for(sim, 1.2)
	if slotted != null:
		CheckEq(slotted.cell, Vector2i(2, 6), "回程带把空晶往前带走了")
	if spent != null:
		Check(spent.slotted_in < 0, "被换出的晶已经不在槽里")

	# 地面充能晶：只放上「和自己同向走」的正前方带，不碰侧向带
	var sim2 := _new_sim_custom(_test_level(9, 9))
	Check(bool(sim2.Build("swapper", "arm", Vector2i(2, 4), 3)["ok"]), "建臂")
	Check(bool(sim2.Build("belt", "belt", Vector2i(2, 3), 3)["ok"]), "同向的来料带")
	Check(bool(sim2.Build("belt", "belt", Vector2i(1, 4), 1)["ok"]), "侧向的带子")
	var ground := sim2.Build("crystal", "crystal", Vector2i(1, 3))
	var gc: SimCrystal = sim2.crystals[int(ground["id"])]
	gc.charge = 5.0
	_step_for(sim2, 1.2)
	var front: SimBelt = _belt_at(sim2, Vector2i(2, 3))
	var side: SimBelt = _belt_at(sim2, Vector2i(1, 4))
	Check(front != null and front.items.has(gc.id), "充能晶被放上同向的来料带")
	Check(side != null and side.items.is_empty(), "侧向带没有被塞东西")


func _belt_at(sim: Sim, cell: Vector2i) -> SimBelt:
	var e := sim.CellEntity(cell)
	if e.is_empty() or String(e.get("kind", "")) != Sim.KIND_BELT:
		return null
	return sim.belts.get(int(e.get("id", -1)))


func Test_CameraBasis() -> void:
	# 上帝视角：W 必须朝「镜头看的方向」（远离镜头），之前是反的。
	var w := CameraRig.PanDelta(0.0, Vector2(0, 1))
	CheckNear(w.x, 0.0, "yaw=0 时 W 不横移", 0.001)
	CheckNear(w.y, -1.0, "yaw=0 时 W 朝北（远离镜头）", 0.001)
	var s := CameraRig.PanDelta(0.0, Vector2(0, -1))
	CheckNear(s.y, 1.0, "S 朝南（靠近镜头）", 0.001)
	var d := CameraRig.PanDelta(0.0, Vector2(1, 0))
	CheckNear(d.x, 1.0, "D 朝东", 0.001)
	var a := CameraRig.PanDelta(0.0, Vector2(-1, 0))
	CheckNear(a.x, -1.0, "A 朝西", 0.001)
	var at45 := CameraRig.PanDelta(45.0, Vector2(0, 1))
	CheckNear(at45.x, -0.7071, "yaw=45 时 W 的 x", 0.002)
	CheckNear(at45.y, -0.7071, "yaw=45 时 W 的 y", 0.002)
	# 幽灵视角：默认朝北，pitch=90 朝上。
	var dir := CameraRig.EyeDir(0.0, 0.0)
	CheckNear(dir.x, 0.0, "幽灵视角默认不横偏", 0.001)
	CheckNear(dir.z, -1.0, "幽灵视角默认朝北", 0.001)
	var up := CameraRig.EyeDir(0.0, deg_to_rad(90.0))
	CheckNear(up.y, 1.0, "pitch=90 朝上", 0.001)


func Test_RemoveGhost() -> void:
	var sim := _new_sim("01")
	var budget := sim.economy.budget
	var ghosts := sim.ghosts.size()
	var r := sim.RemoveAt(Vector2i(3, 8))
	Check(bool(r.get("ok", false)), "可以拆除鬼")
	CheckEq(sim.ghosts.size(), ghosts - 1, "鬼从场上消失")
	CheckEq(sim.economy.budget, budget + 10, "拆除全额退款")
	Check(not sim.cells.has(Vector2i(3, 8)), "格子释放")


func Test_BalanceCurve() -> void:
	var rows := BalanceAudit.Rows()
	var expected_waves := 0
	for level_id in GameData.LevelIds():
		expected_waves += GameData.Level(String(level_id)).get("waves", []).size()
	CheckEq(rows.size(), expected_waves, "审计覆盖每一波")
	print("--- BALANCE ---")
	print(BalanceAudit.Format())

	var by_level := {}
	for row in rows:
		var id := String(row["level"])
		if not by_level.has(id):
			by_level[id] = []
		by_level[id].append(row)
	for id in by_level:
		var list: Array = by_level[id]
		Check(list.size() >= 4, "%s 至少四波" % id)
		var first_budget := int(list[0]["budget_before"])
		Check(first_budget >= 60, "%s 第一波预算够起手（%d）" % [id, first_budget])
		var max_eff := 0.0
		var boss_eff := 0.0
		var prev_budget := -1
		for row in list:
			var eff := float(row["eff_hp"])
			max_eff = maxf(max_eff, eff)
			if bool(row["boss"]):
				boss_eff = eff
			Check(int(row["budget_before"]) >= prev_budget, "%s 预算不倒退（第 %d 波）" % [id, int(row["wave"]) + 1])
			prev_budget = int(row["budget_before"])
		Check(boss_eff > 0.0, "%s 最后一波有 boss" % id)
		CheckNear(boss_eff, max_eff, "%s 的 boss 波是威胁峰值" % id, 0.01)
		Check(BalanceAudit.TotalBudget(id) >= 140, "%s 总预算够至少两台机器（%d）" % [id, BalanceAudit.TotalBudget(id)])

	# 第三夜的参考机器（约 300 预算）必须在整夜的预算之内
	Check(BalanceAudit.TotalBudget("03") >= 300, "第三夜总预算放得下参考机器（%d）" % BalanceAudit.TotalBudget("03"))
	# 第一波的有效血量必须低于最终 boss 波，否则曲线是倒的
	var first_wave_eff := float(rows[0]["eff_hp"])
	Check(first_wave_eff > 0.0, "第一波有威胁")
	Check(first_wave_eff < 2000.0, "第一波不是劝退波（有效 HP %.0f）" % first_wave_eff)


# ---------------------------------------------------------------------------

func _test_level(w: int, h: int, extra: Dictionary = {}) -> Dictionary:
	var level := {
		"id": "test",
		"grid": {"w": w, "h": h},
		"buildable": {"x": 0, "y": 0, "w": w, "h": h},
		"center_radius": 0.6,
		"spawn_radius": 5.0,
		"max_breaches": 99,
		"budget": 500,
		"unlocks": [
			"waver", "swing", "lantern", "hum", "toll", "relay", "anchor",
			"hammer", "prop", "pendulum",
			"pusher", "crank", "tuner", "amp", "reach",
			"belt", "express", "arm", "hand", "crystal", "cell",
		],
		"initial": [],
		"initial_crystals": [],
		"hints": [],
		"waves": [{"prep": 9999.0, "groups": []}],
		"rewards": [],
	}
	for key in extra:
		level[key] = extra[key]
	return level


func _new_sim_custom(level: Dictionary) -> Sim:
	var sim := Sim.new()
	sim.Setup(level, SimConfig.FromDictionary(GameData.Game()))
	return sim


func _spawn_ghost(sim: Sim, type_id: String, cell: Vector2i, facing: int = 0) -> SimGhost:
	var r := sim.Build("ghost", type_id, cell, facing)
	return sim.ghosts.get(int(r.get("id", -1)))


func _standing_ghost(sim: Sim, type_id: String, cell: Vector2i, facing: int = 0) -> SimGhost:
	var g := _spawn_ghost(sim, type_id, cell, facing)
	if g != null:
		g.angle = 0.0
		g.angular_velocity = 0.0
		g.standing = true
		g.phase = 0.0
	return g


## 在 mech_cell 放一颗充能晶（crystal_cell 需要是空地）。
func _power_cell(sim: Sim, mech_cell: Vector2i, crystal_cell: Vector2i, charge: float = 5.0) -> SimCrystal:
	var r := sim.Build("crystal", "crystal", crystal_cell)
	var c: SimCrystal = sim.crystals.get(int(r.get("id", -1)))
	if c != null:
		c.charge = charge
	sim.PickCrystal(crystal_cell)
	sim.InsertHeld(mech_cell)
	return c


func _new_sim(level_id: String) -> Sim:
	var sim := Sim.new()
	var cfg := SimConfig.FromDictionary(GameData.Game())
	sim.Setup(GameData.Level(level_id), cfg)
	return sim


func _step_for(sim: Sim, seconds: float) -> void:
	var step := 1.0 / float(sim.config.tick_rate)
	var count := int(round(seconds / step))
	for i in count:
		sim.Step(step)

class_name Sim
extends RefCounted
## 本作的完整规则模拟。
##
## 分层约定：
##   - 本文件不 import 任何 Node / 场景 / 渲染类型，可 headless 跑、可单测。
##   - 时间由外部驱动（固定 tick），本类不读 delta，也不管暂停的真实时间。
##   - 表现层只通过 SimEvents 订阅事件，并读取公开状态做每帧同步。
##
## 一 tick 的顺序是刻意排的：
##   搬运（手 / 装卸臂）→ 传送带 → 机关（耗能、发力）→ 鬼（受力、过阈值、发脉冲、充能鬼晶）
##   → 重建场 → 魅（移动、吃伤害、抵达 / 拆越界造物）→ 波次 → 热力图
## 脉冲先于伤害结算，所以「刚立正的那一拍」就能打到魅。

const KIND_GHOST := "ghost"
const KIND_MECH := "mechanism"
const KIND_CRYSTAL := "crystal"
const KIND_SWAPPER := "swapper"
const KIND_BELT := "belt"

const PLAYING := &"playing"
const FAILED := &"failed"
const CLEARED := &"cleared"

var config: SimConfig
var level: Dictionary
var grid: SimGrid
var field: SimField
var events: SimEvents
var economy: SimEconomy
var waves: SimWaves

var ghosts: Dictionary = {}      # id:int -> SimGhost
var mechanisms: Dictionary = {}  # id:int -> SimMechanism
var crystals: Dictionary = {}    # id:int -> SimCrystal
var swappers: Dictionary = {}    # id:int -> SimSwapper
var belts: Dictionary = {}       # id:int -> SimBelt
var enemies: Dictionary = {}     # id:int -> SimEnemy
var cells: Dictionary = {}       # Vector2i -> {"kind": String, "id": int}

var paused: bool = false
var run_state: StringName = PLAYING
var breaches: int = 0
var time: float = 0.0
var held_crystal: int = -1

var center_radius: float = 1.6
var max_breaches: int = 10
var spawn_radius: float = 8.0

# 大地图：领地 / 越界造物
var allow_outlaw: bool = false
var outlaw_pressure: float = 0.34
var aggro_radius: float = 6.0
var outlaw_attack_time: float = 2.4
var expand_per_wave: int = 0
var territory_rings: int = 0
var outlaw_cells: Array = []      # Array[Vector2i]，供魅找目标
var outlaw_count: int = 0
## 鬼与鬼之间的物理支撑连线：[{"from": brace_id, "to": supported_id}]，给视图画连杆。
var links: Array = []

# 热力图缓存：heat[y * heat_w + x]
var heat: PackedFloat32Array = PackedFloat32Array()
var heat_w: int = 0
var heat_h: int = 0
var field_peak: float = 0.0

# 机器共振：同频鬼在同一 tick 发出的脉冲总和越过阈值，就打出一次大波段。
var resonance_charge: float = 0.0
var resonance_ready_at: float = 0.0
var resonance_last_sum: float = 0.0
var _pulse_tick_sum: float = 0.0
var _pulse_tick_count: int = 0
var _pulse_centroid: Vector2 = Vector2.ZERO

var stats: Dictionary = {}

var _next_id: int = 1
var _heat_timer: float = 0.0
var _snapshot: Dictionary = {}
var _hint_key: String = ""
var _ghost_defs: Dictionary = {}
var _mech_defs: Dictionary = {}
var _crystal_defs: Dictionary = {}
var _swapper_defs: Dictionary = {}
var _belt_defs: Dictionary = {}


## 建立一局。level_data 见 Data/levels/*.json。
func Setup(level_data: Dictionary, cfg: SimConfig) -> void:
	config = cfg
	level = level_data
	events = SimEvents.new()
	events.GhostPulse.connect(_on_ghost_pulse)
	field = SimField.new()
	field.speed = config.wave_speed
	economy = SimEconomy.new()
	grid = SimGrid.new()

	var grid_def: Dictionary = level.get("grid", {})
	var build_def: Dictionary = level.get("buildable", {})
	grid.Configure(
		int(grid_def.get("w", 13)),
		int(grid_def.get("h", 13)),
		config.cell_size,
		Rect2i(
			int(build_def.get("x", 0)),
			int(build_def.get("y", 0)),
			int(build_def.get("w", int(grid_def.get("w", 13)))),
			int(build_def.get("h", int(grid_def.get("h", 13))))))

	center_radius = float(level.get("center_radius", 1.6))
	max_breaches = maxi(1, int(level.get("max_breaches", 10)))
	spawn_radius = float(level.get("spawn_radius", grid.FieldRadius() + 1.5))
	allow_outlaw = bool(level.get("allow_outlaw", false))
	outlaw_pressure = maxf(0.0, float(level.get("outlaw_pressure", 0.34)))
	aggro_radius = maxf(0.0, float(level.get("aggro_radius", 6.0)))
	outlaw_attack_time = maxf(0.2, float(level.get("outlaw_attack_time", 2.4)))
	expand_per_wave = maxi(0, int(level.get("expand_per_wave", 0)))
	territory_rings = 0
	outlaw_cells.clear()
	outlaw_count = 0
	links.clear()

	economy.Configure(int(level.get("budget", config.starting_budget)))
	for uid in level.get("unlocks", []):
		economy.Unlock(String(uid))

	waves = SimWaves.new()
	waves.Configure(level.get("waves", []), spawn_radius)
	waves.Begin(0)

	time = 0.0
	breaches = 0
	run_state = PLAYING
	paused = false
	held_crystal = -1
	_next_id = 1
	heat = PackedFloat32Array()
	heat_w = grid.width
	heat_h = grid.height
	heat.resize(heat_w * heat_h)
	heat.fill(0.0)
	field_peak = 0.0
	resonance_charge = 0.0
	resonance_ready_at = 0.0
	resonance_last_sum = 0.0
	_pulse_tick_sum = 0.0
	_pulse_tick_count = 0
	_pulse_centroid = Vector2.ZERO
	stats = {
		"pulses": 0,
		"killed": 0,
		"cleared_killed": 0,
		"breached": 0,
		"built": 0,
		"spent": 0,
		"manual_inserts": 0,
		"auto_swaps": 0,
		"moves": 0,
		"resonance_bursts": 0,
		"resonance_damage": 0.0,
		"belt_deliveries": 0,
		"belt_transfers": 0,
		"loader_swaps": 0,
		"relay_pulses": 0,
		"strikes": 0,
		"outlaw_built": 0,
		"outlaw_lost": 0,
		"annexed": 0,
	}

	_ghost_defs.clear()
	_mech_defs.clear()
	_crystal_defs.clear()
	_swapper_defs.clear()
	_belt_defs.clear()

	for entry in level.get("initial", []):
		_place_initial(entry)
	for entry in level.get("initial_crystals", []):
		var cdata: Array = entry.get("cell", [0, 0])
		var c := _create_crystal(String(entry.get("type", "crystal")), Vector2i(int(cdata[0]), int(cdata[1])), float(entry.get("charge", 0.0)))
		if c == null:
			push_error("Sim: 初始鬼晶放置失败 " + str(entry))

	_recount_outlaws()
	_rebuild_field()
	_update_heat_now()
	_snapshot = Snapshot()
	_hint_key = ""
	_update_hint(true)


## 固定步长推进。
func Step(dt: float) -> void:
	if paused or run_state != PLAYING:
		return
	if dt <= 0.0:
		return
	time += dt
	_tick_swappers(dt)
	_tick_belts(dt)
	_tick_mechanisms(dt)
	_tick_ghosts(dt)
	_rebuild_field()
	_tick_enemies(dt)
	_tick_waves(dt)
	_update_heat(dt)
	_update_hint(false)


func SetPaused(value: bool) -> void:
	paused = value


func TogglePause() -> void:
	paused = not paused


## 当前波结束的倒计时（秒）。非准备阶段返回 0。
func WaveCountdown() -> float:
	if waves == null:
		return 0.0
	return waves.time_to_wave if waves.state == SimWaves.PREP else 0.0


## 共振指数（0..，与清场线比较）。
func ResonanceIndex() -> float:
	return field_peak


## 清场线。
func ClearLine() -> float:
	return config.clear_line


## 伤害线。
func DamageLine() -> float:
	return config.damage_line


## 场上活着的魅。
func AliveEnemies() -> int:
	return enemies.size()


## 越界造物数量（鬼 / 机关 / 传送带 / 装卸装置）。
func OutlawCount() -> int:
	return outlaw_count


## 每个刷怪组因为越界造物多出来的数量。
func WavePressureBonus() -> int:
	if outlaw_count <= 0 or outlaw_pressure <= 0.0:
		return 0
	return int(round(float(outlaw_count) * outlaw_pressure))


## 查询格子上的东西；没有返回空字典。
func CellEntity(cell: Vector2i) -> Dictionary:
	return cells.get(cell, {})


## 某类定义的成本（没有定义返回 0）。
func CostOf(kind: String, type_id: String) -> int:
	return int(_def_for(kind, type_id).get("cost", 0))


## 某格是不是越界造物（在领地外，但仍建成了）。
func IsOutlaw(cell: Vector2i) -> bool:
	if not allow_outlaw:
		return false
	if grid.InBuildArea(cell):
		return false
	var entry: Dictionary = cells.get(cell, {})
	if entry.is_empty():
		return false
	if String(entry.get("kind", "")) == KIND_CRYSTAL:
		return false
	return true


# ---------------------------------------------------------------------------
# 建造 / 拆除 / 搬运
# ---------------------------------------------------------------------------

## 建造是否允许落在这一格：领地内永远可以；领地外要看关卡是否放开越界。
func CanBuildAt(cell: Vector2i) -> bool:
	if grid.InBuildArea(cell):
		return true
	return allow_outlaw and grid.InField(cell)


## 尝试在 cell 上建造。返回 {"ok": bool, "reason": String, "id": int}。
func Build(kind: String, type_id: String, cell: Vector2i, facing: int = 0) -> Dictionary:
	if run_state != PLAYING:
		return _err("run_not_playing")
	if not CanBuildAt(cell):
		return _err("outside_build")
	if cells.has(cell):
		return _err("occupied")
	var def := _def_for(kind, type_id)
	if def.is_empty():
		return _err("unknown_type")
	if not economy.IsUnlocked(type_id):
		return _err("locked")
	var cost := int(def.get("cost", 0))
	if not economy.CanAfford(cost):
		return _err("no_budget")
	if not economy.Spend(cost):
		return _err("no_budget")

	var new_id := -1
	match kind:
		KIND_GHOST:
			var g := _create_ghost(type_id, cell, facing)
			if g == null:
				economy.Refund(cost)
				return _err("create_failed")
			new_id = g.id
			events.Built.emit(KIND_GHOST, g.id, cell)
		KIND_MECH:
			var m := _create_mechanism(type_id, cell, facing)
			if m == null:
				economy.Refund(cost)
				return _err("create_failed")
			new_id = m.id
			events.Built.emit(KIND_MECH, m.id, cell)
		KIND_CRYSTAL:
			var c := _create_crystal(type_id, cell, 0.0)
			if c == null:
				economy.Refund(cost)
				return _err("create_failed")
			new_id = c.id
			events.Built.emit(KIND_CRYSTAL, c.id, cell)
		KIND_SWAPPER:
			var s := _create_swapper(type_id, cell, facing)
			if s == null:
				economy.Refund(cost)
				return _err("create_failed")
			new_id = s.id
			events.Built.emit(KIND_SWAPPER, s.id, cell)
		KIND_BELT:
			var b := _create_belt(type_id, cell, facing)
			if b == null:
				economy.Refund(cost)
				return _err("create_failed")
			new_id = b.id
			events.Built.emit(KIND_BELT, b.id, cell)
		_:
			economy.Refund(cost)
			return _err("unknown_kind")

	stats["built"] = int(stats["built"]) + 1
	stats["spent"] = int(stats["spent"]) + cost
	if _is_structure(kind) and not grid.InBuildArea(cell):
		stats["outlaw_built"] = int(stats.get("outlaw_built", 0)) + 1
	_recount_outlaws()
	_refresh_after_change()
	return {"ok": true, "reason": "", "id": new_id}


## 拆除某格上的建筑，全额退还。返回 {"ok": bool, "reason": String}。
func RemoveAt(cell: Vector2i) -> Dictionary:
	if run_state != PLAYING:
		return _err("run_not_playing")
	var result := _remove_entity(cell, true)
	if bool(result.get("ok", false)):
		_refresh_after_change()
	return result


## 拆除并把插槽里的鬼晶落到地上。refund=false 用于「被魅拆掉」。
func _remove_entity(cell: Vector2i, refund: bool) -> Dictionary:
	if not cells.has(cell):
		return _err("empty")
	var entry: Dictionary = cells[cell]
	var kind := String(entry.get("kind", ""))
	var id := int(entry.get("id", -1))
	match kind:
		KIND_GHOST:
			var g: SimGhost = ghosts.get(id)
			if g == null:
				return _err("missing")
			ghosts.erase(id)
			cells.erase(cell)
			if refund:
				economy.Refund(g.cost)
			events.Removed.emit(KIND_GHOST, id)
		KIND_MECH:
			var m: SimMechanism = mechanisms.get(id)
			if m == null:
				return _err("missing")
			var slotted := m.crystal_id
			mechanisms.erase(id)
			cells.erase(cell)
			if refund:
				economy.Refund(m.cost)
			if slotted >= 0:
				var c: SimCrystal = crystals.get(slotted)
				if c != null:
					c.slotted_in = -1
					c.cell = cell
					c.ride_belt = -1
					cells[cell] = {"kind": KIND_CRYSTAL, "id": c.id}
			events.Removed.emit(KIND_MECH, id)
		KIND_CRYSTAL:
			var c2: SimCrystal = crystals.get(id)
			if c2 == null:
				return _err("missing")
			crystals.erase(id)
			cells.erase(cell)
			if refund:
				economy.Refund(c2.cost)
			events.Removed.emit(KIND_CRYSTAL, id)
		KIND_SWAPPER:
			var s: SimSwapper = swappers.get(id)
			if s == null:
				return _err("missing")
			swappers.erase(id)
			cells.erase(cell)
			if refund:
				economy.Refund(s.cost)
			events.Removed.emit(KIND_SWAPPER, id)
		KIND_BELT:
			var b: SimBelt = belts.get(id)
			if b == null:
				return _err("missing")
			# 先腾出带子自己占的格子，再让带面上的晶落地，避免覆盖/被擦掉
			cells.erase(cell)
			belts.erase(id)
			var drop := cell
			for cid in b.items:
				var bc: SimCrystal = crystals.get(int(cid))
				if bc == null:
					continue
				bc.ride_belt = -1
				bc.slotted_in = -1
				if not cells.has(drop):
					bc.cell = drop
					cells[drop] = {"kind": KIND_CRYSTAL, "id": bc.id}
				else:
					var spot := _adjacent_free_cell(drop)
					if spot.x >= 0:
						bc.cell = spot
						cells[spot] = {"kind": KIND_CRYSTAL, "id": bc.id}
					else:
						bc.cell = Vector2i(-1, -1)
			b.items.clear()
			if refund:
				economy.Refund(b.cost)
			events.Removed.emit(KIND_BELT, id)
		_:
			return _err("unknown_kind")
	if _is_structure(kind) and not grid.InBuildArea(cell):
		_recount_outlaws()
	return {"ok": true, "reason": ""}


## 把一格上的建筑整体挪到另一格。
## 插槽里的鬼晶跟着机关走；带面上的鬼晶跟着带子走；相位不变（位置变了，场会立刻重算）。
func MoveEntity(from_cell: Vector2i, to_cell: Vector2i) -> Dictionary:
	if run_state != PLAYING:
		return _err("run_not_playing")
	if not cells.has(from_cell):
		return _err("empty")
	if not CanBuildAt(to_cell):
		return _err("outside_build")
	if cells.has(to_cell):
		return _err("occupied")
	var entry: Dictionary = cells[from_cell]
	var kind := String(entry.get("kind", ""))
	var id := int(entry.get("id", -1))

	if kind == KIND_GHOST:
		var g: SimGhost = ghosts.get(id)
		if g == null:
			return _err("missing")
		cells.erase(from_cell)
		cells[to_cell] = {"kind": KIND_GHOST, "id": id}
		g.cell = to_cell
		g.base = grid.CellToWorld(to_cell)
	elif kind == KIND_MECH:
		var m: SimMechanism = mechanisms.get(id)
		if m == null:
			return _err("missing")
		cells.erase(from_cell)
		cells[to_cell] = {"kind": KIND_MECH, "id": id}
		m.cell = to_cell
		m.base = grid.CellToWorld(to_cell)
	elif kind == KIND_BELT:
		var b: SimBelt = belts.get(id)
		if b == null:
			return _err("missing")
		cells.erase(from_cell)
		cells[to_cell] = {"kind": KIND_BELT, "id": id}
		b.cell = to_cell
		b.base = grid.CellToWorld(to_cell)
		for cid in b.items:
			var bc: SimCrystal = crystals.get(int(cid))
			if bc != null:
				bc.cell = to_cell
	elif kind == KIND_SWAPPER:
		var s: SimSwapper = swappers.get(id)
		if s == null:
			return _err("missing")
		cells.erase(from_cell)
		cells[to_cell] = {"kind": KIND_SWAPPER, "id": id}
		s.cell = to_cell
		s.base = grid.CellToWorld(to_cell)
	else:
		return _err("cannot_move")

	events.Moved.emit(kind, id, from_cell, to_cell)
	stats["moves"] = int(stats.get("moves", 0)) + 1
	_recount_outlaws()
	_refresh_after_change()
	return {"ok": true, "reason": ""}


## 拿起地上的鬼晶（一次只能拿一块）。传送带最前面那颗也能拿。
func PickCrystal(cell: Vector2i) -> Dictionary:
	if run_state != PLAYING:
		return _err("run_not_playing")
	if held_crystal >= 0:
		return _err("hands_full")
	var entry := CellEntity(cell)
	if entry.is_empty():
		return _err("no_crystal")
	var kind := String(entry.get("kind", ""))
	if kind == KIND_BELT:
		var b: SimBelt = belts.get(int(entry["id"]))
		if b == null or b.items.is_empty():
			return _err("no_crystal")
		var cid := b.TakeFront()
		var bc: SimCrystal = crystals.get(cid)
		if bc == null:
			return _err("missing")
		bc.ride_belt = -1
		bc.cell = Vector2i(-1, -1)
		held_crystal = cid
		events.CrystalHeld.emit(cid, true)
		return {"ok": true, "reason": ""}
	if kind != KIND_CRYSTAL:
		return _err("no_crystal")
	var c: SimCrystal = crystals.get(int(entry["id"]))
	if c == null:
		return _err("missing")
	cells.erase(cell)
	c.cell = Vector2i(-1, -1)
	held_crystal = c.id
	events.CrystalHeld.emit(c.id, true)
	return {"ok": true, "reason": ""}


## 把手上的鬼晶放到空地（或传送带上）。
func DropHeld(cell: Vector2i) -> Dictionary:
	if held_crystal < 0:
		return _err("empty_hand")
	if not grid.InField(cell):
		return _err("outside_build")
	var c: SimCrystal = crystals.get(held_crystal)
	if c == null:
		held_crystal = -1
		return _err("missing")
	if cells.has(cell):
		var entry: Dictionary = cells[cell]
		if String(entry.get("kind", "")) == KIND_BELT:
			var b: SimBelt = belts.get(int(entry["id"]))
			if b != null and b.HasRoom():
				c.cell = cell
				c.slotted_in = -1
				c.ride_belt = b.id
				b.Accept(c.id)
				held_crystal = -1
				events.CrystalChanged.emit(c.id, c.charge)
				_refresh_after_change()
				return {"ok": true, "reason": ""}
		return _err("occupied")
	if not CanBuildAt(cell):
		return _err("outside_build")
	c.cell = cell
	c.slotted_in = -1
	c.ride_belt = -1
	cells[cell] = {"kind": KIND_CRYSTAL, "id": c.id}
	held_crystal = -1
	events.CrystalChanged.emit(c.id, c.charge)
	_refresh_after_change()
	return {"ok": true, "reason": ""}


## 把手上的鬼晶插进机关的槽。
func InsertHeld(mech_cell: Vector2i) -> Dictionary:
	if held_crystal < 0:
		return _err("empty_hand")
	var entry := CellEntity(mech_cell)
	if entry.is_empty() or String(entry.get("kind", "")) != KIND_MECH:
		return _err("not_mechanism")
	var m: SimMechanism = mechanisms.get(int(entry["id"]))
	if m == null:
		return _err("missing")
	if m.crystal_id >= 0:
		return _err("slot_full")
	var c: SimCrystal = crystals.get(held_crystal)
	if c == null:
		held_crystal = -1
		return _err("missing")
	if c.charge < 1.0:
		return _err("empty_crystal")
	m.crystal_id = c.id
	c.slotted_in = m.id
	c.cell = Vector2i(-1, -1)
	c.ride_belt = -1
	held_crystal = -1
	stats["manual_inserts"] = int(stats.get("manual_inserts", 0)) + 1
	events.CrystalInserted.emit(m.id, c.id)
	_refresh_after_change()
	return {"ok": true, "reason": ""}


## 把机关槽里的鬼晶取出来：优先放手上，手占着就放到相邻空格。
func EjectCrystal(mech_cell: Vector2i) -> Dictionary:
	var entry := CellEntity(mech_cell)
	if entry.is_empty() or String(entry.get("kind", "")) != KIND_MECH:
		return _err("not_mechanism")
	var m: SimMechanism = mechanisms.get(int(entry["id"]))
	if m == null:
		return _err("missing")
	if m.crystal_id < 0:
		return _err("slot_empty")
	var c: SimCrystal = crystals.get(m.crystal_id)
	m.crystal_id = -1
	if c == null:
		return {"ok": true, "reason": ""}
	c.slotted_in = -1
	if held_crystal < 0:
		c.cell = Vector2i(-1, -1)
		held_crystal = c.id
		events.CrystalEjected.emit(m.id, c.id)
		events.CrystalHeld.emit(c.id, true)
		_refresh_after_change()
		return {"ok": true, "reason": "to_hand"}
	var spot := _adjacent_free_cell(mech_cell)
	if spot.x < 0:
		# 没地方放，塞回槽里，保持状态自洽
		m.crystal_id = c.id
		c.slotted_in = m.id
		return _err("no_space")
	c.cell = spot
	c.ride_belt = -1
	cells[spot] = {"kind": KIND_CRYSTAL, "id": c.id}
	events.CrystalEjected.emit(m.id, c.id)
	_refresh_after_change()
	return {"ok": true, "reason": "to_ground"}


## 把领地向外扩 rings 圈（波次奖励）。新圈进来的越界造物自动合法化。
## 返回 {"ok": bool, "rect": Rect2i, "annexed": int}。
func ExpandTerritory(rings: int = 1) -> Dictionary:
	if rings <= 0:
		return {"ok": false, "reason": "no_rings", "annexed": 0}
	if run_state != PLAYING:
		return _err("run_not_playing")
	var before := outlaw_count
	var r := grid.build_rect
	for i in rings:
		var x0 := maxi(0, r.position.x - 1)
		var y0 := maxi(0, r.position.y - 1)
		var x1 := mini(grid.width, r.position.x + r.size.x + 1)
		var y1 := mini(grid.height, r.position.y + r.size.y + 1)
		r = Rect2i(x0, y0, x1 - x0, y1 - y0)
	grid.build_rect = r
	territory_rings += rings
	_recount_outlaws()
	var annexed := maxi(0, before - outlaw_count)
	stats["annexed"] = int(stats.get("annexed", 0)) + annexed
	events.TerritoryExpanded.emit(r, annexed)
	_refresh_after_change()
	return {"ok": true, "reason": "", "rect": r, "annexed": annexed}


# ---------------------------------------------------------------------------
# 快照 / 回溯
# ---------------------------------------------------------------------------

## 完整快照（用于失败回溯与存档）。
func Snapshot() -> Dictionary:
	var ghost_list: Array = []
	for id in ghosts:
		ghost_list.append(ghosts[id].Export())
	var mech_list: Array = []
	for id in mechanisms:
		mech_list.append(mechanisms[id].Export())
	var crystal_list: Array = []
	for id in crystals:
		crystal_list.append(crystals[id].Export())
	var swapper_list: Array = []
	for id in swappers:
		swapper_list.append(swappers[id].Export())
	var belt_list: Array = []
	for id in belts:
		belt_list.append(belts[id].Export())
	return {
		"version": 2,
		"ghosts": ghost_list,
		"mechanisms": mech_list,
		"crystals": crystal_list,
		"swappers": swapper_list,
		"belts": belt_list,
		"economy": economy.Export(),
		"breaches": breaches,
		"next_wave": waves.next_index,
		"next_id": _next_id,
		"stats": stats.duplicate(),
		"resonance_charge": resonance_charge,
		"resonance_ready_at": resonance_ready_at,
		"build_rect": [grid.build_rect.position.x, grid.build_rect.position.y, grid.build_rect.size.x, grid.build_rect.size.y],
		"territory_rings": territory_rings,
	}


## 失败后回到「上一波刚打完」的瞬间：布局、预算、鬼能全部回滚，解锁保留。
func RestoreSnapshot() -> void:
	if _snapshot.is_empty():
		return
	var snap := _snapshot
	_clear_entities()
	economy.Import(snap.get("economy", {}))
	breaches = int(snap.get("breaches", 0))
	_next_id = int(snap.get("next_id", 1))
	stats = snap.get("stats", stats).duplicate()
	held_crystal = -1
	resonance_charge = float(snap.get("resonance_charge", 0.0))
	resonance_ready_at = float(snap.get("resonance_ready_at", 0.0))
	_pulse_tick_sum = 0.0
	_pulse_tick_count = 0
	_pulse_centroid = Vector2.ZERO
	territory_rings = int(snap.get("territory_rings", 0))
	var br: Array = snap.get("build_rect", [])
	if br.size() == 4:
		grid.build_rect = Rect2i(int(br[0]), int(br[1]), int(br[2]), int(br[3]))

	for data in snap.get("ghosts", []):
		var g := _create_ghost(String(data.get("type", "")), Vector2i.ZERO, 0, false, int(data.get("id", -1)))
		if g != null:
			g.Import(data)
			g.base = grid.CellToWorld(g.cell)
	for data in snap.get("mechanisms", []):
		var m := _create_mechanism(String(data.get("type", "")), Vector2i.ZERO, 0, false, int(data.get("id", -1)))
		if m != null:
			m.Import(data)
			m.base = grid.CellToWorld(m.cell)
	for data in snap.get("belts", []):
		var b := _create_belt(String(data.get("type", "")), Vector2i.ZERO, 0, false, int(data.get("id", -1)))
		if b != null:
			b.Import(data)
			b.base = grid.CellToWorld(b.cell)
	for data in snap.get("swappers", []):
		var s := _create_swapper(String(data.get("type", "")), Vector2i.ZERO, int(data.get("facing", 0)), false, int(data.get("id", -1)))
		if s != null:
			s.Import(data)
			s.base = grid.CellToWorld(s.cell)
	for data in snap.get("crystals", []):
		var c := _create_crystal(String(data.get("type", "")), Vector2i.ZERO, 0.0, false, int(data.get("id", -1)))
		if c != null:
			c.Import(data)
			if c.slotted_in >= 0:
				c.cell = Vector2i(-1, -1)
			elif c.ride_belt >= 0:
				var b2: SimBelt = belts.get(c.ride_belt)
				if b2 != null:
					c.cell = b2.cell
					if not b2.items.has(c.id):
						b2.items.append(c.id)
				else:
					c.ride_belt = -1
			elif c.cell.x >= 0:
				cells[c.cell] = {"kind": KIND_CRYSTAL, "id": c.id}
	# 重建占用表里机关/鬼/搬运手/传送带的格子（Import 不负责写 cells）
	for id in ghosts:
		var g2: SimGhost = ghosts[id]
		cells[g2.cell] = {"kind": KIND_GHOST, "id": id}
	for id in mechanisms:
		var m2: SimMechanism = mechanisms[id]
		cells[m2.cell] = {"kind": KIND_MECH, "id": id}
	for id in swappers:
		var s2: SimSwapper = swappers[id]
		cells[s2.cell] = {"kind": KIND_SWAPPER, "id": id}
	for id in belts:
		var b3: SimBelt = belts[id]
		cells[b3.cell] = {"kind": KIND_BELT, "id": id}
	# 插槽引用修复
	for id in mechanisms:
		var m3: SimMechanism = mechanisms[id]
		if m3.crystal_id >= 0 and not crystals.has(m3.crystal_id):
			m3.crystal_id = -1

	enemies.clear()
	run_state = PLAYING
	paused = false
	waves.Begin(int(snap.get("next_wave", 0)))
	_recount_outlaws()
	_rebuild_field()
	_update_heat_now()
	_hint_key = ""
	_update_hint(true)
	events.WorldRestored.emit()


# ---------------------------------------------------------------------------
# 内部：实体创建
# ---------------------------------------------------------------------------

func _def_for(kind: String, type_id: String) -> Dictionary:
	if not GameData.HasDefinition(kind, type_id):
		return {}
	match kind:
		KIND_GHOST:
			if not _ghost_defs.has(type_id):
				_ghost_defs[type_id] = GameData.Ghost(type_id)
			return _ghost_defs[type_id]
		KIND_MECH:
			if not _mech_defs.has(type_id):
				_mech_defs[type_id] = GameData.Mechanism(type_id)
			return _mech_defs[type_id]
		KIND_CRYSTAL:
			if not _crystal_defs.has(type_id):
				_crystal_defs[type_id] = GameData.Crystal(type_id)
			return _crystal_defs[type_id]
		KIND_SWAPPER:
			if not _swapper_defs.has(type_id):
				_swapper_defs[type_id] = GameData.Swapper(type_id)
			return _swapper_defs[type_id]
		KIND_BELT:
			if not _belt_defs.has(type_id):
				_belt_defs[type_id] = GameData.Belt(type_id)
			return _belt_defs[type_id]
	return {}


func _create_ghost(type_id: String, cell: Vector2i, facing: int, register: bool = true, forced_id: int = -1) -> SimGhost:
	var d := _def_for(KIND_GHOST, type_id)
	if d.is_empty():
		return null
	var id := forced_id if forced_id >= 0 else _next_id
	if forced_id < 0:
		_next_id += 1
	var g := SimGhost.new()
	g.Configure(id, type_id, d, cell, posmod(facing, 4), grid.CellToWorld(cell))
	ghosts[id] = g
	if register:
		cells[cell] = {"kind": KIND_GHOST, "id": id}
	return g


func _create_mechanism(type_id: String, cell: Vector2i, facing: int, register: bool = true, forced_id: int = -1) -> SimMechanism:
	var d := _def_for(KIND_MECH, type_id)
	if d.is_empty():
		return null
	var id := forced_id if forced_id >= 0 else _next_id
	if forced_id < 0:
		_next_id += 1
	var m := SimMechanism.new()
	m.Configure(id, type_id, d, cell, posmod(facing, 4), grid.CellToWorld(cell))
	mechanisms[id] = m
	if register:
		cells[cell] = {"kind": KIND_MECH, "id": id}
	return m


func _create_crystal(type_id: String, cell: Vector2i, charge: float, register: bool = true, forced_id: int = -1) -> SimCrystal:
	var d := _def_for(KIND_CRYSTAL, type_id)
	if d.is_empty():
		return null
	var id := forced_id if forced_id >= 0 else _next_id
	if forced_id < 0:
		_next_id += 1
	var c := SimCrystal.new()
	c.Configure(id, type_id, d, cell, charge)
	crystals[id] = c
	if register and cell.x >= 0 and cell.y >= 0:
		cells[cell] = {"kind": KIND_CRYSTAL, "id": id}
	return c


func _create_swapper(type_id: String, cell: Vector2i, facing: int = 0, register: bool = true, forced_id: int = -1) -> SimSwapper:
	var d := _def_for(KIND_SWAPPER, type_id)
	if d.is_empty():
		return null
	var id := forced_id if forced_id >= 0 else _next_id
	if forced_id < 0:
		_next_id += 1
	var s := SimSwapper.new()
	s.Configure(id, type_id, d, cell, posmod(facing, 4), grid.CellToWorld(cell))
	swappers[id] = s
	if register:
		cells[cell] = {"kind": KIND_SWAPPER, "id": id}
	return s


func _create_belt(type_id: String, cell: Vector2i, facing: int, register: bool = true, forced_id: int = -1) -> SimBelt:
	var d := _def_for(KIND_BELT, type_id)
	if d.is_empty():
		return null
	var id := forced_id if forced_id >= 0 else _next_id
	if forced_id < 0:
		_next_id += 1
	var b := SimBelt.new()
	b.Configure(id, type_id, d, cell, posmod(facing, 4), grid.CellToWorld(cell))
	belts[id] = b
	if register:
		cells[cell] = {"kind": KIND_BELT, "id": id}
	return b


func _place_initial(entry: Dictionary) -> void:
	var kind := String(entry.get("kind", ""))
	var type_id := String(entry.get("type", ""))
	var cdata: Array = entry.get("cell", [0, 0])
	var cell := Vector2i(int(cdata[0]), int(cdata[1]))
	var facing := int(entry.get("facing", 0))
	match kind:
		KIND_GHOST:
			if _create_ghost(type_id, cell, facing) == null:
				push_error("Sim: 初始鬼创建失败 " + str(entry))
		KIND_MECH:
			if _create_mechanism(type_id, cell, facing) == null:
				push_error("Sim: 初始机关创建失败 " + str(entry))
		KIND_CRYSTAL:
			if _create_crystal(type_id, cell, float(entry.get("charge", 0.0))) == null:
				push_error("Sim: 初始鬼晶创建失败 " + str(entry))
		KIND_SWAPPER:
			if _create_swapper(type_id, cell, facing) == null:
				push_error("Sim: 初始搬运装置创建失败 " + str(entry))
		KIND_BELT:
			if _create_belt(type_id, cell, facing) == null:
				push_error("Sim: 初始传送带创建失败 " + str(entry))


func _clear_entities() -> void:
	ghosts.clear()
	mechanisms.clear()
	crystals.clear()
	swappers.clear()
	belts.clear()
	enemies.clear()
	cells.clear()


func _adjacent_free_cell(cell: Vector2i) -> Vector2i:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var c: Vector2i = cell + d
		if CanBuildAt(c) and not cells.has(c):
			return c
	return Vector2i(-1, -1)


## 找出 radius 内最近的空格（给装卸臂把晶放到地上用）。
func _free_ground_near(pos: Vector2, radius: float) -> Vector2i:
	var center := grid.WorldToCell(pos)
	var r := int(ceil(radius))
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell := center + Vector2i(dx, dy)
			if not grid.InField(cell) or cells.has(cell):
				continue
			var d := pos.distance_to(grid.CellToWorld(cell))
			if d <= radius and d < best_d:
				best_d = d
				best = cell
	return best


## 把鬼晶放到某格地上。
func _drop_crystal_at(c: SimCrystal, cell: Vector2i) -> bool:
	if not grid.InField(cell) or cells.has(cell):
		return false
	c.cell = cell
	c.slotted_in = -1
	c.ride_belt = -1
	cells[cell] = {"kind": KIND_CRYSTAL, "id": c.id}
	return true


## 记账：哪些格子上的造物属于「越界」。
func _recount_outlaws() -> void:
	outlaw_cells.clear()
	if allow_outlaw:
		for cell in cells:
			if grid.InBuildArea(cell):
				continue
			var kind := String(cells[cell].get("kind", ""))
			if _is_structure(kind):
				outlaw_cells.append(cell)
	outlaw_count = outlaw_cells.size()


func _is_structure(kind: String) -> bool:
	return kind == KIND_GHOST or kind == KIND_MECH or kind == KIND_BELT or kind == KIND_SWAPPER


# ---------------------------------------------------------------------------
# 内部：每 tick 结算
# ---------------------------------------------------------------------------

func _tick_swappers(dt: float) -> void:
	for sid in swappers:
		var s: SimSwapper = swappers[sid]
		s.work_pulse = maxf(0.0, s.work_pulse - dt)
		s.timer += dt
		if s.timer < s.swap_period:
			continue
		var worked := false
		if s.source == "belt":
			worked = _loader_action(s)
		else:
			worked = _hand_action(s)
		if worked:
			s.timer = 0.0
			s.work_pulse = 0.5


## 搬运手：地上充能晶 ↔ 缺电机关（原有行为，保持逐字不变）。
func _hand_action(s: SimSwapper) -> bool:
	var mech := _needy_mechanism_near(s)
	if mech == null:
		return false
	var src := _charged_crystal_near(s)
	if src == null:
		return false
	# 搬完还得给机关留下至少 1 单位
	if src.charge < 1.0 + s.drain:
		return false

	var old_id := mech.crystal_id
	var ground_cell := src.cell
	cells.erase(ground_cell)
	src.charge = maxf(0.0, src.charge - s.drain)
	src.cell = Vector2i(-1, -1)
	src.slotted_in = mech.id
	src.ride_belt = -1
	mech.crystal_id = src.id
	if old_id >= 0:
		var old: SimCrystal = crystals.get(old_id)
		if old != null:
			old.slotted_in = -1
			old.cell = ground_cell
			old.ride_belt = -1
			cells[ground_cell] = {"kind": KIND_CRYSTAL, "id": old.id}
	stats["auto_swaps"] = int(stats.get("auto_swaps", 0)) + 1
	events.CrystalChanged.emit(src.id, src.charge)
	events.SwapperWorked.emit(s.id, mech.id, src.id)
	return true


## 装卸臂：带面 / 机关槽 / 地面之间的四向搬运，一次只做一个动作。
## 有朝向：正前方的带子是来料，背后的带子是回程，同向的带子可以上货。
func _loader_action(s: SimSwapper) -> bool:
	# ① 槽里的空晶：能换就一次换完（空晶走背后带 / 空地，充能晶塞回槽），机关不断电
	var spent_mech := _spent_mechanism_near(s)
	if spent_mech != null:
		var spent: SimCrystal = crystals.get(spent_mech.crystal_id)
		if spent == null:
			spent_mech.crystal_id = -1
			return false
		var src := _charged_belt_crystal_near(s, true)
		if src == null:
			src = _charged_ground_crystal_near(s)
		if src != null:
			var dest := _belt_with_room_behind(s)
			var placed := false
			if dest != null:
				_detach_crystal(spent)
				spent.slotted_in = -1
				spent.ride_belt = dest.id
				spent.cell = dest.cell
				dest.Accept(spent.id)
				placed = true
			else:
				var spot := _free_ground_near(s.base, s.crystal_radius)
				if spot.x >= 0:
					_detach_crystal(spent)
					spent.slotted_in = -1
					spent.ride_belt = -1
					_drop_crystal_at(spent, spot)
					placed = true
			if placed:
				spent_mech.crystal_id = -1
				_detach_crystal(src)
				src.charge = maxf(0.0, src.charge - s.drain)
				src.slotted_in = spent_mech.id
				src.ride_belt = -1
				src.cell = Vector2i(-1, -1)
				spent_mech.crystal_id = src.id
				stats["loader_swaps"] = int(stats.get("loader_swaps", 0)) + 1
				events.CrystalEjected.emit(spent_mech.id, spent.id)
				events.CrystalInserted.emit(spent_mech.id, src.id)
				events.CrystalChanged.emit(src.id, src.charge)
				return true
		# 没有可换的充能晶：先把空晶卸掉，等下一轮上料
		var dest2 := _belt_with_room_behind(s)
		if dest2 != null:
			_detach_crystal(spent)
			spent.slotted_in = -1
			spent.ride_belt = dest2.id
			spent.cell = dest2.cell
			dest2.Accept(spent.id)
			spent_mech.crystal_id = -1
			stats["loader_swaps"] = int(stats.get("loader_swaps", 0)) + 1
			events.CrystalEjected.emit(spent_mech.id, spent.id)
			return true
		var spot2 := _free_ground_near(s.base, s.crystal_radius)
		if spot2.x >= 0:
			_detach_crystal(spent)
			spent.slotted_in = -1
			spent.ride_belt = -1
			_drop_crystal_at(spent, spot2)
			spent_mech.crystal_id = -1
			stats["loader_swaps"] = int(stats.get("loader_swaps", 0)) + 1
			events.CrystalEjected.emit(spent_mech.id, spent.id)
			return true
		return false

	# ② 空槽上料：来料带（优先）或地面充能晶
	var empty_mech := _empty_mechanism_near(s)
	if empty_mech != null:
		var src2 := _charged_belt_crystal_near(s, true)
		if src2 == null:
			src2 = _charged_ground_crystal_near(s)
		if src2 != null:
			_detach_crystal(src2)
			src2.charge = maxf(0.0, src2.charge - s.drain)
			src2.slotted_in = empty_mech.id
			src2.ride_belt = -1
			src2.cell = Vector2i(-1, -1)
			empty_mech.crystal_id = src2.id
			stats["loader_swaps"] = int(stats.get("loader_swaps", 0)) + 1
			events.CrystalInserted.emit(empty_mech.id, src2.id)
			events.CrystalChanged.emit(src2.id, src2.charge)
			return true
		return false

	# ③ 带面上的空晶 → 附近空地（让鬼去充）
	for bid in belts:
		var b: SimBelt = belts[bid]
		if b.items.is_empty():
			continue
		if b.base.distance_to(s.base) > s.belt_radius + 0.001:
			continue
		var front: SimCrystal = crystals.get(int(b.items[0]))
		if front == null:
			b.TakeFront()
			continue
		if front.charge >= 1.0:
			continue
		var spot3 := _free_ground_near(b.base, s.crystal_radius)
		if spot3.x < 0:
			continue
		b.TakeFront()
		front.ride_belt = -1
		front.slotted_in = -1
		_drop_crystal_at(front, spot3)
		stats["loader_swaps"] = int(stats.get("loader_swaps", 0)) + 1
		return true

	# ④ 地面充能晶 → 同向的去程带
	var belt2 := _belt_with_room_aligned(s)
	if belt2 != null:
		var src3 := _charged_ground_crystal_near(s)
		if src3 != null:
			_detach_crystal(src3)
			src3.charge = maxf(0.0, src3.charge - s.drain)
			src3.cell = belt2.cell
			src3.ride_belt = belt2.id
			src3.slotted_in = -1
			belt2.Accept(src3.id)
			stats["loader_swaps"] = int(stats.get("loader_swaps", 0)) + 1
			events.CrystalChanged.emit(src3.id, src3.charge)
			return true
	return false


## 找到服务范围内「最缺电」的机关（没插晶或存量 < 1）。
func _needy_mechanism_near(s: SimSwapper) -> SimMechanism:
	var best: SimMechanism = null
	var best_charge := 2.0
	for mid in mechanisms:
		var m: SimMechanism = mechanisms[mid]
		if m.base.distance_to(s.base) > s.service_radius + 0.001:
			continue
		var charge := 0.0
		if m.crystal_id >= 0:
			var c: SimCrystal = crystals.get(m.crystal_id)
			if c != null:
				charge = c.charge
		if charge >= 1.0:
			continue
		if charge < best_charge:
			best_charge = charge
			best = m
	return best


## 服务范围内最近的一个空槽机关。
func _empty_mechanism_near(s: SimSwapper) -> SimMechanism:
	var best: SimMechanism = null
	var best_d := INF
	for mid in mechanisms:
		var m: SimMechanism = mechanisms[mid]
		if m.crystal_id >= 0:
			continue
		var d := m.base.distance_to(s.base)
		if d <= s.service_radius + 0.001 and d < best_d:
			best_d = d
			best = m
	return best


## 找到附近地上、够搬（>= 1 + 损耗）的最近一颗鬼晶。
func _charged_crystal_near(s: SimSwapper) -> SimCrystal:
	var best: SimCrystal = null
	var best_d := INF
	for id in crystals:
		var c: SimCrystal = crystals[id]
		if not c.IsOnGround():
			continue
		if c.charge < 1.0 + s.drain:
			continue
		var d := grid.CellToWorld(c.cell).distance_to(s.base)
		if d <= s.crystal_radius and d < best_d:
			best_d = d
			best = c
	return best


## 附近地上、够搬的充能晶（装卸臂用，半径取 crystal_radius）。
func _charged_ground_crystal_near(s: SimSwapper) -> SimCrystal:
	var best: SimCrystal = null
	var best_d := INF
	for id in crystals:
		var c: SimCrystal = crystals[id]
		if not c.IsOnGround():
			continue
		if c.charge < 1.0 + s.drain:
			continue
		var d := c.cell
		var w := grid.CellToWorld(d)
		var dist := w.distance_to(s.base)
		if dist <= s.crystal_radius and dist < best_d:
			best_d = dist
			best = c
	return best


## 附近带面上、够搬的充能晶。front_first=true 时优先拿正前方带子上的。
func _charged_belt_crystal_near(s: SimSwapper, front_first: bool = false) -> SimCrystal:
	var passes := [true, false] if front_first else [false]
	for want_front in passes:
		var best: SimCrystal = null
		var best_d := INF
		for bid in belts:
			var b: SimBelt = belts[bid]
			if b.items.is_empty():
				continue
			var side := s.BeltSide(b)
			if want_front and side <= 0.15:
				continue
			var d := b.base.distance_to(s.base)
			if d > s.belt_radius + 0.001:
				continue
			if d >= best_d:
				continue
			for cid in b.items:
				var c: SimCrystal = crystals.get(int(cid))
				if c == null:
					continue
				if c.charge >= 1.0 + s.drain:
					best_d = d
					best = c
					break
		if best != null:
			return best
	return null


## 背后（回程方向）还有空位的传送带。没有就是没有——不会退而求其次塞到去程带上。
func _belt_with_room_behind(s: SimSwapper) -> SimBelt:
	var best: SimBelt = null
	var best_d := INF
	for bid in belts:
		var b: SimBelt = belts[bid]
		if not b.HasRoom():
			continue
		if s.BeltSide(b) >= -0.15:
			continue
		var d := b.base.distance_to(s.base)
		if d <= s.belt_radius + 0.001 and d < best_d:
			best_d = d
			best = b
	return best


## 正前方、且和装置朝同一方向走（会把货带离这里）的空位传送带。
func _belt_with_room_aligned(s: SimSwapper) -> SimBelt:
	var best: SimBelt = null
	var best_d := INF
	var face := s.FacingDir()
	for bid in belts:
		var b: SimBelt = belts[bid]
		if not b.HasRoom():
			continue
		if s.BeltSide(b) <= 0.15:
			continue
		if b.PushDir().dot(face) < 0.5:
			continue
		var d := b.base.distance_to(s.base)
		if d <= s.belt_radius + 0.001 and d < best_d:
			best_d = d
			best = b
	return best


## 服务范围内「最需要换料」的机关：先比谁更空，再比谁更近。
## 只比距离会让两台同距的机关里的一台永远排队（另一台一直占着臂）。
func _spent_mechanism_near(s: SimSwapper) -> SimMechanism:
	var best: SimMechanism = null
	var best_charge := 2.0
	var best_d := INF
	for mid in mechanisms:
		var m: SimMechanism = mechanisms[mid]
		if m.crystal_id < 0:
			continue
		var c: SimCrystal = crystals.get(m.crystal_id)
		if c == null:
			m.crystal_id = -1
			continue
		if c.charge >= 1.0:
			continue
		var d := m.base.distance_to(s.base)
		if d > s.service_radius + 0.001:
			continue
		if c.charge < best_charge - 0.001 or (absf(c.charge - best_charge) <= 0.001 and d < best_d):
			best_charge = c.charge
			best_d = d
			best = m
	return best


## 把一颗晶从它现在的位置（地面 / 带面）摘下来，不处理槽内引用。
func _detach_crystal(c: SimCrystal) -> void:
	if c.ride_belt >= 0:
		var b: SimBelt = belts.get(c.ride_belt)
		if b != null:
			b.RemoveItem(c.id)
		c.ride_belt = -1
	elif c.cell.x >= 0 and c.slotted_in < 0:
		cells.erase(c.cell)
	c.cell = Vector2i(-1, -1)


func _tick_belts(dt: float) -> void:
	for bid in belts:
		var b: SimBelt = belts[bid]
		b.move_timer += dt
		var period := b.MovePeriod()
		var guard := 0
		while b.move_timer >= period and guard < 4:
			guard += 1
			b.move_timer -= period
			if b.items.is_empty():
				break
			if not _belt_advance(b):
				break


## 把带子最前面那颗晶往前送一格。成功返回 true。
func _belt_advance(b: SimBelt) -> bool:
	if b.items.is_empty():
		return false
	var cid := int(b.items[0])
	var c: SimCrystal = crystals.get(cid)
	if c == null:
		b.TakeFront()
		return true
	var to := b.cell + _dir_delta(b.facing)
	if not grid.InField(to):
		return false
	var entry: Dictionary = cells.get(to, {})
	if entry.is_empty():
		if _drop_crystal_at(c, to):
			b.TakeFront()
			stats["belt_transfers"] = int(stats.get("belt_transfers", 0)) + 1
			events.BeltDelivered.emit(b.id, c.id)
			return true
		return false
	var kind := String(entry.get("kind", ""))
	if kind == KIND_BELT:
		var nb: SimBelt = belts.get(int(entry.get("id", -1)))
		if nb != null and nb.HasRoom():
			b.TakeFront()
			nb.Accept(cid)
			c.ride_belt = nb.id
			c.cell = to
			stats["belt_transfers"] = int(stats.get("belt_transfers", 0)) + 1
			events.BeltDelivered.emit(b.id, c.id)
			return true
		return false
	if kind == KIND_MECH:
		var m: SimMechanism = mechanisms.get(int(entry.get("id", -1)))
		if m != null and m.crystal_id < 0 and c.charge >= 1.0:
			b.TakeFront()
			c.ride_belt = -1
			c.cell = Vector2i(-1, -1)
			c.slotted_in = m.id
			m.crystal_id = c.id
			stats["belt_deliveries"] = int(stats.get("belt_deliveries", 0)) + 1
			stats["belt_transfers"] = int(stats.get("belt_transfers", 0)) + 1
			events.CrystalInserted.emit(m.id, c.id)
			events.BeltDelivered.emit(b.id, c.id)
			return true
		return false
	return false


func _dir_delta(facing: int) -> Vector2i:
	match posmod(facing, 4):
		0:
			return Vector2i(1, 0)
		1:
			return Vector2i(0, 1)
		2:
			return Vector2i(-1, 0)
	return Vector2i(0, -1)


func _tick_mechanisms(dt: float) -> void:
	for mid in mechanisms:
		var m: SimMechanism = mechanisms[mid]
		m.pushing = false
		if m.crystal_id < 0:
			continue
		var c: SimCrystal = crystals.get(m.crystal_id)
		if c == null:
			m.crystal_id = -1
			continue
		if c.charge < 1.0:
			continue
		m.pushing = true
		m.push_timer += dt
		if m.push_timer >= m.push_period:
			m.push_timer -= m.push_period
			c.charge = maxf(0.0, c.charge - m.energy_per_push)
			events.MechanismPushed.emit(m.id, m.HeadWorld())
			events.MechanismEnergyChanged.emit(m.id, c.charge)
			if c.charge < 1.0:
				m.pushing = false


func _tick_ghosts(dt: float) -> void:
	# 先发掉到点的接力脉冲（它们会作为波源进入本 tick 的场）。
	_flush_due_relays()

	# 机关对鬼的参数改写（每 tick 重算，离开半径就恢复）。
	for gid in ghosts:
		var gr: SimGhost = ghosts[gid]
		gr.amp_mult = 1.0
		gr.range_mult = 1.0
		gr.period_override = 0.0
	for mid in mechanisms:
		var m: SimMechanism = mechanisms[mid]
		if not m.pushing or not m.ModifiesGhosts():
			continue
		for gid in ghosts:
			var g: SimGhost = ghosts[gid]
			if m.base.distance_to(g.base) > m.effect_radius + 0.001:
				continue
			match m.effect:
				"amp":
					g.amp_mult += m.amplitude_mult - 1.0
				"reach":
					g.range_mult += m.range_mult - 1.0
				"tune":
					if m.target_period > 0.0:
						g.period_override = m.target_period
	for gid in ghosts:
		var gc: SimGhost = ghosts[gid]
		gc.amp_mult = minf(gc.amp_mult, config.effect_amp_cap)
		gc.range_mult = minf(gc.range_mult, config.effect_range_cap)

	# 先把每只鬼受到的总力矩与支撑数算出来，再统一步进（与遍历顺序无关）。
	_pulse_tick_sum = 0.0
	_pulse_tick_count = 0
	_pulse_centroid = Vector2.ZERO
	var torques: Dictionary = {}
	var supports: Dictionary = {}
	# 鬼与鬼的物理支撑：撑鬼站着时，撑住所有「倒向它」的邻鬼
	_compute_brace_supports(torques, supports)
	for mid in mechanisms:
		var m2: SimMechanism = mechanisms[mid]
		if not m2.pushing or not m2.AppliesTorque():
			continue
		for gid in ghosts:
			var g2: SimGhost = ghosts[gid]
			if g2.IsRelay():
				continue
			if m2.effect == "crank":
				if m2.SegmentDistance(g2.FootWorld()) <= g2.foot_radius + m2.head_radius:
					torques[gid] = float(torques.get(gid, 0.0)) - m2.push_torque
					supports[gid] = int(supports.get(gid, 0)) + 1
				elif m2.SegmentDistance(g2.BodyWorld()) <= g2.body_radius + m2.head_radius:
					torques[gid] = float(torques.get(gid, 0.0)) + m2.push_torque * g2.topple_factor
				continue
			var head := m2.HeadWorld()
			if head.distance_to(g2.FootWorld()) <= g2.foot_radius + m2.head_radius:
				torques[gid] = float(torques.get(gid, 0.0)) - m2.push_torque
				supports[gid] = int(supports.get(gid, 0)) + 1
			elif head.distance_to(g2.BodyWorld()) <= g2.body_radius + m2.head_radius:
				torques[gid] = float(torques.get(gid, 0.0)) + m2.push_torque * g2.topple_factor

	for gid in ghosts:
		var g3: SimGhost = ghosts[gid]
		if g3.IsRelay():
			continue
		g3.Step(dt, float(torques.get(gid, 0.0)), events, time, int(supports.get(gid, 0)))

	# 计时器与「倒下砸邻格」的结算
	var strike_ids: Array = []
	for gid in ghosts:
		var g4: SimGhost = ghosts[gid]
		g4.TickTimers(dt)
		if g4.strike_pending:
			g4.strike_pending = false
			strike_ids.append(gid)
	for gid in strike_ids:
		_resolve_strike(ghosts.get(gid))
	_resolve_resonance(dt)


## 撑鬼的支撑关系：撑鬼站着时，凡是「倒向它」的邻鬼都算被撑住。
## 支撑关系同时写进本 tick 的支撑数与一条给视图画的连杆。
func _compute_brace_supports(torques: Dictionary, supports: Dictionary) -> void:
	links.clear()
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for bid in ghosts:
		var b: SimGhost = ghosts[bid]
		b.support_load = 0
		if not b.IsBrace() or not b.standing:
			continue
		for d in dirs:
			var e: Dictionary = cells.get(b.cell + d, {})
			if e.is_empty() or String(e.get("kind", "")) != KIND_GHOST:
				continue
			var n: SimGhost = ghosts.get(int(e.get("id", -1)))
			if n == null or n.IsRelay():
				continue
			if n.LeanDir() != Vector2(-float(d.x), -float(d.y)):
				continue
			b.support_load += 1
			supports[n.id] = int(supports.get(n.id, 0)) + 1
			# 撑住 = 一直压着对方的脚，帮它立正
			torques[n.id] = float(torques.get(n.id, 0.0)) - b.support_weight
			links.append({"from": b.id, "to": n.id})


## 一只鬼倒下/倾倒时砸进它倒向的那一格。
## 砸到脚（对方朝它倒）→ 帮对方立正；砸到身体（对方背对它）→ 把对方推倒。
func _resolve_strike(g: SimGhost) -> void:
	if g == null:
		return
	var dir := g.LeanDir()
	var target_cell := g.cell + Vector2i(roundi(dir.x), roundi(dir.y))
	var e: Dictionary = cells.get(target_cell, {})
	if not e.is_empty() and String(e.get("kind", "")) == KIND_GHOST and g.strike_torque > 0.0:
		var t: SimGhost = ghosts.get(int(e.get("id", -1)))
		if t != null and not t.IsRelay():
			var helps := t.LeanDir() == -dir
			t.pending_impulse += (-g.strike_torque if helps else g.strike_torque)
			stats["strikes"] = int(stats.get("strikes", 0)) + 1
			events.GhostStruck.emit(g.id, t.id, t.base, helps)
	if g.pulse_on_strike:
		g.FireStrikePulse(events)


## 发掉所有到点的接力脉冲。只发「这一 tick 开始时就已经到点」的那批，
## 避免一条长链在同一 tick 里递归传到底。
func _flush_due_relays() -> void:
	var due: Array = []
	for gid in ghosts:
		var g: SimGhost = ghosts[gid]
		if not g.IsRelay():
			continue
		if g.relay_due >= 0.0 and g.relay_due <= time + 0.0001:
			due.append(gid)
	for gid in due:
		var g2: SimGhost = ghosts.get(gid)
		if g2 != null and g2.FireRelay(time, events):
			stats["relay_pulses"] = int(stats.get("relay_pulses", 0)) + 1


func _rebuild_field() -> void:
	field.Clear()
	for id in ghosts:
		var g: SimGhost = ghosts[id]
		# 冲击脉冲的短窗口波源（锤鬼 / 摆锤鬼）
		if g.burst_active > 0.0:
			field.AddSource(g.base, g.burst_period, g.burst_phase, g.EffAmplitude(), g.EffRange())
		if g.IsRelay():
			if g.relay_active > 0.0:
				field.AddSource(g.base, g.relay_period, g.relay_phase, g.EffAmplitude(), g.EffRange())
			continue
		# 撑鬼只有在承重时才是波源；普通鬼立正就是波源
		if g.standing and (not g.IsBrace() or g.support_load > 0):
			field.AddSource(g.base, g.EffPeriod(), g.phase, g.EffAmplitude(), g.EffRange())


func _on_ghost_pulse(ghost_id: int, pos: Vector2, amplitude: float, period: float) -> void:
	if not ghosts.has(ghost_id):
		return
	_pulse_tick_sum += amplitude
	_pulse_tick_count += 1
	_pulse_centroid += pos
	stats["pulses"] = int(stats["pulses"]) + 1
	var g: SimGhost = ghosts[ghost_id]
	for i in g.charges_per_pulse:
		var c := _nearest_chargable_crystal(pos, g.EffRange())
		if c == null:
			break
		var added := c.AddCharge(g.charge_amount)
		if added > 0.0:
			events.CrystalChanged.emit(c.id, c.charge)
	# 接力：脉冲扫到的接力鬼排一次发射（下一 tick 起生效）。
	for rid in ghosts:
		if rid == ghost_id:
			continue
		var r: SimGhost = ghosts[rid]
		if not r.IsRelay():
			continue
		if pos.distance_to(r.base) <= g.EffRange():
			r.ScheduleRelay(time, period)


## 同频鬼在同一 tick 一起发脉冲时，把振幅加总；越过阈值就打出一发大波段。
func _resolve_resonance(dt: float) -> void:
	if _pulse_tick_count > 0:
		resonance_last_sum = _pulse_tick_sum
		resonance_charge = clampf(_pulse_tick_sum / config.resonance_threshold, 0.0, 1.0)
		if _pulse_tick_count >= 2 and _pulse_tick_sum >= config.resonance_threshold and time >= resonance_ready_at:
			_fire_resonance()
	else:
		resonance_charge = maxf(0.0, resonance_charge - config.resonance_decay * dt)


func _fire_resonance() -> void:
	var centroid := _pulse_centroid / float(maxi(1, _pulse_tick_count))
	resonance_ready_at = time + config.resonance_cooldown
	resonance_charge = 0.0

	var total_damage := 0.0
	for eid in enemies.keys():
		if not enemies.has(eid):
			continue
		var e: SimEnemy = enemies[eid]
		var d := e.pos.distance_to(centroid)
		if d > config.resonance_radius:
			continue
		var falloff := 1.0 - 0.5 * clampf(d / config.resonance_radius, 0.0, 1.0)
		var dmg := config.resonance_damage * _pulse_tick_sum * falloff
		e.hp -= dmg
		total_damage += dmg
		if e.hp <= 0.0:
			_kill_enemy(e, false)

	# 大波段也会把地上的空晶一起充满：机器轰鸣之后，下一轮有电。
	for cid in crystals:
		var c: SimCrystal = crystals[cid]
		if c.IsChargable():
			var added := c.AddCharge(config.resonance_charge_amount)
			if added > 0.0:
				events.CrystalChanged.emit(c.id, c.charge)

	stats["resonance_bursts"] = int(stats.get("resonance_bursts", 0)) + 1
	stats["resonance_damage"] = float(stats.get("resonance_damage", 0.0)) + total_damage
	events.ResonanceBurst.emit(centroid, _pulse_tick_sum, config.resonance_radius)


func _nearest_chargable_crystal(pos: Vector2, radius: float) -> SimCrystal:
	var best: SimCrystal = null
	var best_d := INF
	for id in crystals:
		var c: SimCrystal = crystals[id]
		if not c.IsChargable():
			continue
		var d := pos.distance_to(grid.CellToWorld(c.cell))
		if d <= radius and d < best_d:
			best_d = d
			best = c
	return best


func _tick_enemies(dt: float) -> void:
	for eid in enemies.keys():
		var e: SimEnemy = enemies[eid]
		if not enemies.has(eid):
			continue
		# 先吃脉冲伤害
		var envelope := field.EnvelopeAt(e.pos)
		if envelope >= config.clear_line:
			_kill_enemy(e, true)
			continue
		if envelope >= config.damage_line:
			e.hp -= (envelope - config.damage_line) * config.dps_scale * dt * e.armor
			events.EnemyDamaged.emit(e.id, e.hp)
			if e.hp <= 0.0:
				_kill_enemy(e, false)
				continue

		# 魅会先去拆「越界造物」——这是扩张的真实代价。
		var target := _enemy_outlaw_target(e)
		if target.x >= 0 and cells.has(target):
			var tp := grid.CellToWorld(target)
			var td := e.pos.distance_to(tp)
			if td <= 0.62:
				e.attack_timer += dt
				if e.attack_timer >= outlaw_attack_time:
					_raze_outlaw(target, e)
				continue
			e.pos += (tp - e.pos).normalized() * e.speed * dt
			continue

		var to_center := -e.pos
		var dist := to_center.length()
		if dist <= center_radius:
			_breach(e)
			continue
		e.pos += to_center.normalized() * e.speed * dt


## 离这只魅最近的越界造物（在仇恨半径内）。没有返回 (-1,-1)。
func _enemy_outlaw_target(e: SimEnemy) -> Vector2i:
	if outlaw_cells.is_empty() or aggro_radius <= 0.0:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for cell in outlaw_cells:
		var d := e.pos.distance_to(grid.CellToWorld(cell))
		if d <= aggro_radius and d < best_d:
			best_d = d
			best = cell
	return best


## 拆掉一处越界造物，魅也被这次啃食耗尽。
func _raze_outlaw(cell: Vector2i, e: SimEnemy) -> void:
	var entry: Dictionary = cells.get(cell, {})
	if entry.is_empty():
		return
	var kind := String(entry.get("kind", ""))
	var id := int(entry.get("id", -1))
	_remove_entity(cell, false)
	stats["outlaw_lost"] = int(stats.get("outlaw_lost", 0)) + 1
	events.OutlawRazed.emit(cell, kind)
	# 啃食者同归于尽：每个越界造物最多换掉一只魅。
	if enemies.has(e.id):
		enemies.erase(e.id)
		events.EnemyKilled.emit(e.id, e.pos, false)
	_recount_outlaws()


## 在场上生成一只魅。波次系统与调试工具共用。
func SpawnEnemy(pos: Vector2, hp: float, speed: float, armor: float = 1.0, boss: bool = false) -> void:
	var id := _next_id
	_next_id += 1
	var e := SimEnemy.new().Configure(id, pos, hp, speed, armor, boss)
	enemies[id] = e
	events.EnemySpawned.emit(id, pos, hp)


## 下一波（准备阶段为待来的波）。HUD 与场地标记用来做「读下一波」。
func NextWave() -> Dictionary:
	return waves.NextWave()


func _kill_enemy(e: SimEnemy, by_clear: bool) -> void:
	if not enemies.has(e.id):
		return
	enemies.erase(e.id)
	stats["killed"] = int(stats["killed"]) + 1
	if by_clear:
		stats["cleared_killed"] = int(stats["cleared_killed"]) + 1
	events.EnemyKilled.emit(e.id, e.pos, by_clear)


func _breach(e: SimEnemy) -> void:
	if not enemies.has(e.id):
		return
	enemies.erase(e.id)
	breaches += 1
	stats["breached"] = int(stats["breached"]) + 1
	events.EnemyBreached.emit(e.id, breaches)
	if e.IsBoss():
		_run_fail("boss")
		return
	if breaches >= max_breaches and run_state == PLAYING:
		_run_fail("breaches")


func _run_fail(reason: String) -> void:
	if run_state != PLAYING:
		return
	_fail(reason)


func _tick_waves(dt: float) -> void:
	var out: Array = []
	waves.Step(dt, enemies.size(), out, WavePressureBonus())
	for directive in out:
		match String(directive.get("op", "")):
			"wave_start":
				events.WaveStarted.emit(int(directive.get("index", 0)))
			"spawn":
				SpawnEnemy(
					directive.get("pos", Vector2.ZERO),
					float(directive.get("hp", 50.0)),
					float(directive.get("speed", 0.5)),
					float(directive.get("armor", 1.0)),
					bool(directive.get("boss", false)))
			"wave_clear":
				_on_wave_cleared(int(directive.get("index", 0)))
			"all_clear":
				_win()


func _on_wave_cleared(index: int) -> void:
	var rewards: Array = level.get("rewards", [])
	if index >= 0 and index < rewards.size():
		var reward: Dictionary = rewards[index]
		economy.Earn(int(reward.get("budget", 0)))
		if reward.has("unlock"):
			economy.Unlock(String(reward.get("unlock")))
		var expand := int(reward.get("expand", expand_per_wave))
		if expand > 0:
			ExpandTerritory(expand)
	elif expand_per_wave > 0:
		ExpandTerritory(expand_per_wave)
	events.WaveCleared.emit(index)
	# 存档点：波次边界。失败回溯回到这一刻。
	_snapshot = Snapshot()


func _fail(reason: String) -> void:
	run_state = FAILED
	paused = false
	events.RunFailed.emit(reason)


func _win() -> void:
	run_state = CLEARED
	paused = false
	events.RunCleared.emit()


# ---------------------------------------------------------------------------
# 内部：热力图 / 提示
# ---------------------------------------------------------------------------

func _update_heat(dt: float) -> void:
	_heat_timer -= dt
	if _heat_timer > 0.0:
		return
	_update_heat_now()


func _update_heat_now() -> void:
	_heat_timer = 1.0 / config.heat_sample_hz
	if heat.size() != grid.width * grid.height:
		heat_w = grid.width
		heat_h = grid.height
		heat = PackedFloat32Array()
		heat.resize(heat_w * heat_h)
		heat.fill(0.0)
	var peak := 0.0
	for y in heat_h:
		for x in heat_w:
			var v := field.EnvelopeAt(grid.CellToWorld(Vector2i(x, y)))
			heat[y * heat_w + x] = v
			if v > peak:
				peak = v
	field_peak = peak


## 建造 / 取值变化后立刻刷新场与热力图（暂停时也要正确）。
func _refresh_after_change() -> void:
	_rebuild_field()
	_update_heat_now()
	_update_hint(false)


## 当前教程提示文本（HUD 初始化时直接取用）。
func CurrentHintText() -> String:
	for rule in level.get("hints", []):
		if String(rule.get("when", "")) == _hint_key:
			return String(rule.get("text", ""))
	return ""


func _update_hint(force: bool) -> void:
	if run_state != PLAYING:
		return
	var key := _current_hint_key()
	if not force and key == _hint_key:
		return
	_hint_key = key
	var text := ""
	for rule in level.get("hints", []):
		if String(rule.get("when", "")) == key:
			text = String(rule.get("text", ""))
			break
	events.HintChanged.emit(text)


func _current_hint_key() -> String:
	if mechanisms.is_empty():
		return "no_mechanism"
	var any_power := false
	for id in mechanisms:
		var m: SimMechanism = mechanisms[id]
		if m.crystal_id >= 0:
			var c: SimCrystal = crystals.get(m.crystal_id)
			if c != null and c.charge >= 1.0:
				any_power = true
				break
	if not any_power:
		for id in crystals:
			var c2: SimCrystal = crystals[id]
			if c2.IsInField() and c2.charge >= 1.0:
				any_power = true
				break
	if not any_power:
		return "no_power"
	if allow_outlaw:
		if outlaw_count > 0:
			return "outlaw"
		if time > 45.0 and belts.is_empty():
			return "no_belt"
		if time > 45.0 and not belts.is_empty() and not _has_swapper_type("arm"):
			return "no_arm"
	if _has_unlocked_link() and not _has_link_ghost():
		return "link_available"
	if economy.IsUnlocked("swing") and not _has_ghost_type("swing"):
		return "swing_available"
	if ghosts.size() >= 2 and resonance_charge > 0.01 and resonance_charge < 0.999:
		return "resonance"
	for id in ghosts:
		if ghosts[id].standing:
			return "default"
	return "ghost_idle"


func _has_swapper_type(type_id: String) -> bool:
	for id in swappers:
		if swappers[id].type_id == type_id:
			return true
	return false


func _has_unlocked_link() -> bool:
	for id in ["hammer", "prop", "pendulum"]:
		if economy.IsUnlocked(id):
			return true
	return false


func _has_link_ghost() -> bool:
	for id in ghosts:
		var g: SimGhost = ghosts[id]
		if g.IsTopple() or g.IsBrace() or g.IsOscillate():
			return true
	return false


func _has_ghost_type(type_id: String) -> bool:
	for id in ghosts:
		if ghosts[id].type_id == type_id:
			return true
	return false


func _err(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "id": -1}

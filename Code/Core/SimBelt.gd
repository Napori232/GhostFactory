class_name SimBelt
extends RefCounted
## 传送带：物流的轨道。
##
## 它不耗鬼能、不吃脉冲，只做一件事：把停在带面上的鬼晶沿朝向一格一格送出去。
## 鬼晶在带面上仍然是一个「实体」，只是不在 cells 占用表里——带子自己占着格子。
## 因此带面上的鬼晶可以被脉冲充能（鬼晶是容器，装电不挑地方），
## 但它不能被玩家直接踩到，也不参与机构碰撞。
##
## 运送规则（Sim._tick_belts）：
##   - 每 1/speed 秒推进一格；
##   - 前方是空地带 / 另一条有空位的带子 / 空槽机关 → 交出去；
##   - 前方被占 → 原地等（堵带是玩家要解决的物流问题，不是 bug）。

var id: int = -1
var type_id: String = ""
var def: Dictionary = {}
var cell: Vector2i = Vector2i.ZERO
var facing: int = 0
var base: Vector2 = Vector2.ZERO

var items: Array = []          # 带面上的鬼晶 id，items[0] 是最前面那颗
var capacity: int = 1
var speed: float = 1.0         # 格 / 秒
var move_timer: float = 0.0
var cost: int = 0


func Configure(id_: int, type_id_: String, d: Dictionary, cell_: Vector2i, facing_: int, base_: Vector2) -> SimBelt:
	id = id_
	type_id = type_id_
	def = d
	cell = cell_
	facing = facing_
	base = base_
	capacity = maxi(1, int(d.get("capacity", 1)))
	speed = maxf(0.05, float(d.get("speed", 1.0)))
	cost = int(d.get("cost", 0))
	items.clear()
	move_timer = 0.0
	return self


## 带宽（格 / 秒）。
func MovePeriod() -> float:
	return 1.0 / speed


## 朝向的单位向量。
func PushDir() -> Vector2:
	match facing:
		0:
			return Vector2(1, 0)
		1:
			return Vector2(0, 1)
		2:
			return Vector2(-1, 0)
	return Vector2(0, -1)


## 带面是否还有空位。
func HasRoom() -> bool:
	return items.size() < capacity


## 往带面上塞一颗晶（调用方负责改鬼晶的 ride_belt）。
## 刚上带的东西要先待满一个节拍，不能在同一 tick 里被连续接力传走。
func Accept(crystal_id: int) -> void:
	items.append(crystal_id)
	move_timer = 0.0


## 带走最前面那颗；没有返回 -1。
func TakeFront() -> int:
	if items.is_empty():
		return -1
	return int(items.pop_front())


## 从带面上摘掉指定的晶（玩家拿走时用）。
func RemoveItem(crystal_id: int) -> bool:
	var index := items.find(crystal_id)
	if index < 0:
		return false
	items.remove_at(index)
	return true


func Export() -> Dictionary:
	var ids: Array = []
	for cid in items:
		ids.append(int(cid))
	return {
		"id": id,
		"type": type_id,
		"cell": [cell.x, cell.y],
		"facing": facing,
		"items": ids,
		"move_timer": move_timer,
	}


func Import(data: Dictionary) -> void:
	id = int(data.get("id", id))
	type_id = String(data.get("type", type_id))
	var c: Array = data.get("cell", [cell.x, cell.y])
	cell = Vector2i(int(c[0]), int(c[1]))
	facing = int(data.get("facing", facing))
	items.clear()
	for cid in data.get("items", []):
		items.append(int(cid))
	move_timer = float(data.get("move_timer", 0.0))

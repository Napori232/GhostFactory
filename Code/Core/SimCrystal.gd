class_name SimCrystal
extends RefCounted
## 鬼晶：唯一的能量容器。
## 充能只来自「鬼的脉冲」；消耗只发生在「机关发力」。
## 它本身不被提交、不被消耗，壳永远留下——这一条是物流系统存在的理由。
##
## 三种「位置」：
##   - 地上：cell 有效、slotted_in < 0、ride_belt < 0；
##   - 机关槽里：slotted_in >= 0（cell 为 -1）；
##   - 传送带上：ride_belt >= 0，cell 记成带子所在格（用于测距与充能），但不占 cells。
##
## 只有「地上 / 带面上」的晶能被脉冲充能；槽里的晶不充。

var id: int = -1
var type_id: String = ""
var def: Dictionary = {}
var charge: float = 0.0
var capacity: float = 3.0
var cell: Vector2i = Vector2i(-1, -1)  # (-1,-1) 表示不在场上
var slotted_in: int = -1               # >=0 表示插在某台机关里
var ride_belt: int = -1                # >=0 表示躺在某条传送带上
var cost: int = 0


func Configure(id_: int, type_id_: String, d: Dictionary, cell_: Vector2i, charge_: float) -> SimCrystal:
	id = id_
	type_id = type_id_
	def = d
	capacity = maxf(1.0, float(d.get("capacity", 3.0)))
	charge = clampf(charge_, 0.0, capacity)
	cell = cell_
	slotted_in = -1
	ride_belt = -1
	cost = int(d.get("cost", 0))
	return self


## 是否躺在场上（未插槽、未手持、不在带上）。
func IsOnGround() -> bool:
	return cell.x >= 0 and cell.y >= 0 and slotted_in < 0 and ride_belt < 0


## 是否在场上可被脉冲找到（地上或带面上）。
func IsInField() -> bool:
	return cell.x >= 0 and cell.y >= 0 and slotted_in < 0


## 还能不能装更多鬼能。
func IsChargable() -> bool:
	return IsInField() and charge < capacity - 0.0001


## 充电量（不超过容量），返回实际充入量。
func AddCharge(amount: float) -> float:
	var before := charge
	charge = clampf(charge + amount, 0.0, capacity)
	return charge - before


func Export() -> Dictionary:
	return {
		"id": id,
		"type": type_id,
		"cell": [cell.x, cell.y],
		"charge": charge,
		"slotted": slotted_in,
		"belt": ride_belt,
	}


func Import(data: Dictionary) -> void:
	id = int(data.get("id", id))
	type_id = String(data.get("type", type_id))
	var c: Array = data.get("cell", [cell.x, cell.y])
	cell = Vector2i(int(c[0]), int(c[1]))
	charge = clampf(float(data.get("charge", charge)), 0.0, capacity)
	slotted_in = int(data.get("slotted", -1))
	ride_belt = int(data.get("belt", -1))

class_name SimSwapper
extends RefCounted
## 自动化物流装置。两种形态，同一套管路（建造 / 拆退 / 快照 / 视图都复用）：
##
##   source = "ground"（搬运手，hand）
##     定点把附近地上的充能鬼晶换进缺电机关，空晶落回原地。每换一次抽走 drain。
##
##   source = "belt"（装卸臂，arm）
##     在带面、机关槽、地面之间做四向搬运，是「长距离产线」的接口。
##     它有朝向，方向决定它认哪条带子：
##       · 只从「正前方」的带子上取充能晶；
##       · 只把空晶放到「背后」的带子上（回程带）；
##       · 只把地面的充能晶放上「和自己同向走」的带子（去程带）。
##     这样一条去程带 + 一条回程带 + 一只臂就能构成闭环，不用玩家猜。
##
##     一次动作可以是「交换」：把槽里的空晶挪走、同时把充能晶塞进去，
##     所以机关不会因为换料而断电（这是自持产线的基础）。
##
## 它是定点装置：不移动、不参与物理、不占机关槽。

var id: int = -1
var type_id: String = ""
var def: Dictionary = {}
var cell: Vector2i = Vector2i.ZERO
var facing: int = 0
var base: Vector2 = Vector2.ZERO

var source: String = "ground"   # ground | belt
var service_radius: float = 1.7 # 到机关
var crystal_radius: float = 2.6 # 到地上鬼晶
var belt_radius: float = 2.2    # 到传送带
var swap_period: float = 2.5
var drain: float = 1.0
var timer: float = 0.0
var work_pulse: float = 0.0
var cost: int = 0


func Configure(id_: int, type_id_: String, d: Dictionary, cell_: Vector2i, facing_: int, base_: Vector2) -> SimSwapper:
	id = id_
	type_id = type_id_
	def = d
	cell = cell_
	facing = posmod(facing_, 4)
	base = base_
	cost = int(d.get("cost", 0))
	source = String(d.get("source", "ground"))
	service_radius = float(d.get("service_radius", 1.7))
	crystal_radius = float(d.get("crystal_radius", 2.6))
	belt_radius = float(d.get("belt_radius", 2.2))
	swap_period = maxf(0.2, float(d.get("swap_period", 2.5)))
	drain = maxf(0.0, float(d.get("drain", 1.0)))
	timer = 0.0
	work_pulse = 0.0
	return self


## 朝向的单位向量。
func FacingDir() -> Vector2:
	match facing:
		0:
			return Vector2(1, 0)
		1:
			return Vector2(0, 1)
		2:
			return Vector2(-1, 0)
	return Vector2(0, -1)


## 某条带子相对这台装置的「前后」：>0 正前方，<0 背后，≈0 侧向。
func BeltSide(belt: SimBelt) -> float:
	var off := belt.base - base
	if off.length_squared() < 0.0001:
		return 0.0
	return off.normalized().dot(FacingDir())


func Export() -> Dictionary:
	return {
		"id": id,
		"type": type_id,
		"cell": [cell.x, cell.y],
		"facing": facing,
		"timer": timer,
	}


func Import(data: Dictionary) -> void:
	id = int(data.get("id", id))
	type_id = String(data.get("type", type_id))
	var c: Array = data.get("cell", [cell.x, cell.y])
	cell = Vector2i(int(c[0]), int(c[1]))
	facing = int(data.get("facing", facing))
	timer = float(data.get("timer", 0.0))

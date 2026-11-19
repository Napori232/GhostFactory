class_name SimEnemy
extends RefCounted
## 魅：外敌。
## 它不遵守鬼的规则——没有阈值、不发脉冲、不受物理碰撞影响。
## 它只做两件事：径直走向中央区域；被脉冲伤害。
##
## armor 是对普通脉冲伤害的减免系数（1 = 无减免，0.4 = 只吃 40%）。
## 清场线无视 armor：越线即抹杀。于是「甲魅」把玩家从磨血推向摆场。

var id: int = -1
var pos: Vector2 = Vector2.ZERO
var hp: float = 50.0
var max_hp: float = 50.0
var speed: float = 0.5
var armor: float = 1.0
var boss: bool = false
## 正在啃食越界造物的累计时间（到 outlaw_attack_time 就拆掉它）。
var attack_timer: float = 0.0


func Configure(id_: int, pos_: Vector2, hp_: float, speed_: float, armor_: float = 1.0, boss_: bool = false) -> SimEnemy:
	id = id_
	pos = pos_
	hp = hp_
	max_hp = maxf(1.0, hp_)
	speed = maxf(0.0, speed_)
	armor = clampf(armor_, 0.05, 1.0)
	boss = boss_
	return self


## 生命比例（0..1），视图用来做明暗。
func HealthRatio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


## 是不是硬壳（视图与 HUD 用）。
func IsArmored() -> bool:
	return armor < 0.8


## 是不是魅王（漏过去直接判负）。
func IsBoss() -> bool:
	return boss

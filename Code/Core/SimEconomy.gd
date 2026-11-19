class_name SimEconomy
extends RefCounted
## 预算与解锁。
## 设计口径（v14.5）：成本按关卡解锁累积，不是每波重置；拆除全额退还。
## 因此这里只有「余额」与「已解锁集合」两样东西，没有租金、没有破产。

var budget: int = 0
var unlocked: Dictionary = {}


func Configure(start_budget: int) -> void:
	budget = maxi(0, start_budget)
	unlocked.clear()


func Unlock(id: String) -> void:
	if not id.is_empty():
		unlocked[id] = true


func IsUnlocked(id: String) -> bool:
	return unlocked.has(id)


func CanAfford(cost: int) -> bool:
	return budget >= cost


## 扣款；余额不足返回 false 且不改动余额。
func Spend(cost: int) -> bool:
	if cost < 0:
		return false
	if budget < cost:
		return false
	budget -= cost
	return true


## 入账（波次奖励）。
func Earn(amount: int) -> void:
	budget += maxi(0, amount)


## 退款（拆除）。
func Refund(amount: int) -> void:
	budget += maxi(0, amount)


func Export() -> Dictionary:
	return {"budget": budget, "unlocked": unlocked.keys()}


func Import(data: Dictionary) -> void:
	budget = int(data.get("budget", 0))
	unlocked.clear()
	for id in data.get("unlocked", []):
		unlocked[String(id)] = true

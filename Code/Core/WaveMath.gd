class_name WaveMath
extends RefCounted
## 波次读数的唯一口径。HUD、审计工具、测试都用它，避免「界面显示 80、审计算出 100」。
##
## 有效血量 = Σ 数量 × 血量 ÷ 护甲 × (0.7 + 速度)
##   - 护甲：普通脉冲要磨更久（清场线仍然无视护甲）；
##   - 速度：压到中央更快，留给玩家的反应时间更少。
## 这是一个给玩家做预算/取舍的估算，不是伤害公式。

static func Count(wave: Dictionary, bonus: int = 0) -> int:
	var total := 0
	for grp in wave.get("groups", []):
		total += maxi(1, int(grp.get("count", 1))) + maxi(0, bonus)
	return total


static func ArmoredCount(wave: Dictionary, bonus: int = 0) -> int:
	var total := 0
	for grp in wave.get("groups", []):
		if float(grp.get("armor", 1.0)) < 0.8:
			total += maxi(1, int(grp.get("count", 1))) + maxi(0, bonus)
	return total


static func Threat(wave: Dictionary, bonus: int = 0) -> float:
	var eff := 0.0
	for grp in wave.get("groups", []):
		var count := maxi(1, int(grp.get("count", 1))) + maxi(0, bonus)
		var hp := float(grp.get("hp", 50.0))
		var armor := clampf(float(grp.get("armor", 1.0)), 0.05, 1.0)
		var speed := float(grp.get("speed", 0.5))
		eff += float(count) * hp / armor * (0.7 + speed)
	return eff


static func HasBoss(wave: Dictionary) -> bool:
	for grp in wave.get("groups", []):
		if bool(grp.get("boss", false)):
			return true
	return false

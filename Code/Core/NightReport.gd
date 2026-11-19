class_name NightReport
extends RefCounted
## 把一局的统计翻译成「这一夜你是怎么打的」。
## 它刻意不做数值排名：只给几个标签 + 一句描述，让不同打法留下不同的印记。

## 玩法标签。stats 来自 Sim.stats，breaches 为累计漏怪数。
static func Tags(stats: Dictionary, breaches: int) -> Array:
	var tags: Array = []
	var killed := int(stats.get("killed", 0))
	var cleared := int(stats.get("cleared_killed", 0))
	if killed > 0:
		var ratio := float(cleared) / float(killed)
		if ratio >= 0.5:
			tags.append("清场流")
		elif cleared == 0:
			tags.append("磨血流")
		else:
			tags.append("混合流")
	if breaches == 0:
		tags.append("零漏")
	if int(stats.get("moves", 0)) >= 3:
		tags.append("调场师")
	if int(stats.get("resonance_bursts", 0)) >= 3:
		tags.append("共振流")

	var manual := int(stats.get("manual_inserts", 0))
	var auto := int(stats.get("auto_swaps", 0)) + int(stats.get("loader_swaps", 0))
	if auto > 0 and manual > 0:
		tags.append("半自动")
	elif auto > 0:
		tags.append("自动物流")
	elif manual >= 8:
		tags.append("手搬")
	if int(stats.get("belt_transfers", 0)) >= 20:
		tags.append("传送带流")
	if int(stats.get("outlaw_built", 0)) >= 3:
		tags.append("越界者")
	if int(stats.get("annexed", 0)) >= 2:
		tags.append("收编者")
	return tags


## 一句描述：先说主要打法，再说物流是谁在干。
static func Summary(stats: Dictionary, breaches: int) -> String:
	var killed := int(stats.get("killed", 0))
	var cleared := int(stats.get("cleared_killed", 0))
	var manual := int(stats.get("manual_inserts", 0))
	var auto := int(stats.get("auto_swaps", 0)) + int(stats.get("loader_swaps", 0))
	var belt := int(stats.get("belt_transfers", 0))
	var first := ""
	if killed > 0 and float(cleared) / float(killed) >= 0.5:
		first = "魅大多是被清场线一次性抹掉的——你把整片场抬过了临界。"
	elif killed > 0 and cleared == 0:
		first = "没有一次越线，全靠脉冲一点点磨完。稳，但每一只都是硬啃下来的。"
	elif killed > 0:
		first = "一半靠磨、一半靠清场：你能在两种节奏之间切换。"
	else:
		first = "这一夜没有留下太多战斗记录。"

	var second := ""
	if belt >= 20 and auto > 0:
		second = "鬼晶在带子上跑了 %d 趟，装卸臂换了 %d 次料——这条产线会自己转。" % [belt, auto]
	elif auto > 0 and manual > 0:
		second = "搬运手接走了一部分腿，剩下的还是你自己跑。"
	elif auto > 0:
		second = "换晶几乎全交给了自动化，你把时间花在摆位上。"
	elif manual >= 8:
		second = "鬼能几乎是一颗一颗手塞进去的——这台装置还很依赖你。"
	else:
		second = "装置和你的手各干了一半。"
	if int(stats.get("outlaw_built", 0)) > 0:
		second += "你在领地外造了 %d 样东西，鬼屋因此更凶。" % int(stats.get("outlaw_built", 0))
	return first + second

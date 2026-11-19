class_name SimConfig
extends RefCounted
## 全局调参（来自 res://Data/game.json）。
## 这里只做取值与默认值兜底，不含任何玩法判定代码。

var tick_rate: int = 20
var tick_step: float = 0.05
var cell_size: float = 1.0
var wave_speed: float = 6.0
var damage_line: float = 0.55
var clear_line: float = 1.75
var dps_scale: float = 45.0
var heat_sample_hz: float = 5.0
var starting_budget: int = 80
var resonance_threshold: float = 3.0
var resonance_damage: float = 22.0
var resonance_radius: float = 6.0
var resonance_cooldown: float = 7.0
var resonance_decay: float = 0.4
var resonance_charge_amount: float = 2.0
# 机关「改鬼」的上限：多个同类机关叠在同一只鬼身上时的封顶倍率。
var effect_amp_cap: float = 2.2
var effect_range_cap: float = 2.4


## 从 game.json 的字典构造配置；缺字段时回退到安全默认值。
static func FromDictionary(data: Dictionary) -> SimConfig:
	var c := SimConfig.new()
	c.tick_rate = maxi(1, int(data.get("tick_rate", 20)))
	c.tick_step = 1.0 / float(c.tick_rate)
	c.cell_size = maxf(0.01, float(data.get("cell_size", 1.0)))
	c.wave_speed = maxf(0.01, float(data.get("wave_speed", 6.0)))
	c.damage_line = maxf(0.0, float(data.get("damage_line", 0.55)))
	c.clear_line = maxf(c.damage_line + 0.01, float(data.get("clear_line", 1.75)))
	c.dps_scale = maxf(0.0, float(data.get("dps_scale", 45.0)))
	c.heat_sample_hz = maxf(0.5, float(data.get("heat_sample_hz", 5.0)))
	c.starting_budget = int(data.get("starting_budget", 80))
	c.resonance_threshold = maxf(0.1, float(data.get("resonance_threshold", 3.0)))
	c.resonance_damage = maxf(0.0, float(data.get("resonance_damage", 22.0)))
	c.resonance_radius = maxf(0.5, float(data.get("resonance_radius", 6.0)))
	c.resonance_cooldown = maxf(0.0, float(data.get("resonance_cooldown", 7.0)))
	c.resonance_decay = maxf(0.0, float(data.get("resonance_decay", 0.4)))
	c.resonance_charge_amount = maxf(0.0, float(data.get("resonance_charge_amount", 2.0)))
	c.effect_amp_cap = maxf(1.0, float(data.get("effect_amp_cap", 2.2)))
	c.effect_range_cap = maxf(1.0, float(data.get("effect_range_cap", 2.4)))
	return c

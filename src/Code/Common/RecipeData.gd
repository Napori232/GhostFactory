class_name RecipeData
extends Resource

## 配方资源。形态之间的转换只能由配方决定，参见 Docs/GameDesign.md §6.2。
##
## 损耗由产出率体现：产出率 0.75 表示每次加工产出 0.75 份目标形态，
## 差额 0.25 转为杂质。

## 配方 id，全局唯一，例如 SpiritToOffer。
@export var id: String = ""
## 输入形态 id，对应 FormData.id。
@export var from_form: String = ""
## 输出形态 id，对应 FormData.id。
@export var to_form: String = ""
## 产出率，0.0-1.0，差额部分转化为杂质。
@export_range(0.0, 1.0, 0.05) var yield_rate: float = 0.75
## 单次加工耗时，单位秒。
@export_range(0.1, 10.0, 0.1) var cycle_time: float = 1.2

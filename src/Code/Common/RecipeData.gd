class_name RecipeData
extends Resource

## 配方资源。形态之间的转换只能由配方决定，参见 Docs/GameDesign.md §9.3。

## 配方 id，全局唯一，例如 RawToProcessed。
@export var id: String = ""
## 输入形态 id，对应 FormData.id。
@export var from_form: String = ""
## 输出形态 id，对应 FormData.id。
@export var to_form: String = ""
## 产出率，0.0-1.0，差额部分转化为垃圾。
@export var yield_rate: float = 0.8
## 单次加工耗时，单位秒。
@export var cycle_time: float = 1.2

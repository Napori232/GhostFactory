class_name DroppedItem
extends RefCounted

## 地面掉落物。占 1 格，携带形态与堆叠数量；同格堆叠超过阈值时 3D 视图改画 ×N。
## 参见 Docs/GameDesign.md §5.1。

var cell: Vector2i = Vector2i.ZERO
var form: String = "Spirit"
var amount: int = 1

## 构造掉落物。
## @param at_cell 所在格。
## @param item_form 形态 id（FormData.id）。
## @param item_amount 堆叠数量，单位：件。
func _init(at_cell: Vector2i, item_form: String, item_amount: int) -> void:
	cell = at_cell
	form = item_form
	amount = maxi(1, item_amount)

## 导出可持久化的状态。
## @return 含格坐标、形态与数量的字典。
func ExportSaveData() -> Dictionary:
	return {"cell": [cell.x, cell.y], "form": form, "amount": amount}

## 从存档还原状态。
## @param saved 由 ExportSaveData 产出的字典，缺字段时保留当前值。
func LoadSaveData(saved: Dictionary) -> void:
	var pos: Array = saved.get("cell", [cell.x, cell.y])
	if pos.size() >= 2:
		cell = Vector2i(int(pos[0]), int(pos[1]))
	form = String(saved.get("form", form))
	amount = int(saved.get("amount", amount))

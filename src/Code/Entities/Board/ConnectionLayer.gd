class_name ConnectionLayer
extends RefCounted

## 连线层。连线只描述「一条从输出端口到输入端口的通路」，不写死任何鬼 id 或形态规则。
## 合法性一律用 GhostTag.CanConnect 按物料标签判定（D1）；采集鬼输出标签按缓冲内容动态计算（D2）。

## 表示这条线连到设施而非另一只鬼。
const NO_GHOST: int = -1

var links: Array[Dictionary] = []

## 把形态 id 映射成物料标签。
## @param form 形态 id，例如 Spirit / Offer / Impurity。
## @return 对应的物料标签；未知形态返回空标签。
static func FormToTag(form: String) -> StringName:
	match form:
		"Spirit":
			return GhostTag.SPIRIT
		"Offer":
			return GhostTag.OFFER
		"Impurity":
			return GhostTag.IMPURITY
	return &""

## 把设施接收形态映射成物料标签。
## @param accepted_form 设施的 accepted_form。
## @return 对应的物料标签。
static func FormToInputTags(accepted_form: String) -> Array[StringName]:
	var result: Array[StringName] = []
	var tag := FormToTag(accepted_form)
	if tag != &"":
		result.append(tag)
	return result

## 计算一只鬼当前输出端口实际能送出的物料标签。
## 静态 produces 非空时直接用；为空（采集鬼）时按输出缓冲内容动态生成。
## @param ghost 鬼实例。
## @param output_port 该鬼的输出端口定义。
## @return 物料标签数组，可能为空。
static func DynamicOutputTags(ghost, output_port: BoardPortDef) -> Array[StringName]:
	if output_port == null:
		return []
	var result: Array[StringName] = []
	if not output_port.produces.is_empty():
		for tag in output_port.produces:
			result.append(tag)
		return result
	if ghost == null:
		return result
	for form in ghost.output_buffer:
		var tag := FormToTag(String(form))
		if tag != &"" and not result.has(tag):
			result.append(tag)
	return result

## 新增一条连线。
## @param from_uid 上游鬼实例编号。
## @param to_uid 下游鬼实例编号；连到设施时传 NO_GHOST。
## @param from_cell 上游所在格，用于画线与算路程。
## @param to_cell 下游所在格或设施格。
## @param path GridUtil.PathL 生成的正交折线路径。
## @return 新增的连线字典（引用，可直接改 timer）。
func AddLink(from_uid: int, to_uid: int, from_cell: Vector2i, to_cell: Vector2i, path: Array[Vector2i]) -> Dictionary:
	var link: Dictionary = {
		"from_uid": from_uid,
		"to_uid": to_uid,
		"from_cell": from_cell,
		"to_cell": to_cell,
		"path": path.duplicate(),
		"timer": 0.0,
	}
	links.append(link)
	return link

## 判断两点之间是否已有连线，避免重复接线。
## @param from_uid 上游鬼实例编号。
## @param to_cell 下游格坐标。
## @return 已存在返回 true。
func HasLink(from_uid: int, to_cell: Vector2i) -> bool:
	for link in links:
		if int(link["from_uid"]) == from_uid and link["to_cell"] == to_cell:
			return true
	return false

## 取从某只鬼出发的全部连线。
## @param from_uid 上游鬼实例编号。
## @return 连线字典数组（引用）。
func GetLinksFrom(from_uid: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for link in links:
		if int(link["from_uid"]) == from_uid:
			result.append(link)
	return result

## 移除一条指定起点 → 终点的连线。
## @param from_uid 上游鬼实例编号。
## @param to_cell 下游格坐标。
## @return 找到并移除返回 true；本来没有这条线返回 false。
func RemoveLink(from_uid: int, to_cell: Vector2i) -> bool:
	for i in range(links.size()):
		if int(links[i]["from_uid"]) == from_uid and links[i]["to_cell"] == to_cell:
			links.remove_at(i)
			return true
	return false

## 移除一条线身经过指定格的连线，用于「点一下线就拆」。
## 多条线经过同一格时优先拆最后建的那条，让连续点击可以逐条清掉。
## @param cell 被点击的格坐标。
## @return 找到并移除返回 true。
func RemoveLinkPassing(cell: Vector2i) -> bool:
	for i in range(links.size() - 1, -1, -1):
		var path: Array = links[i]["path"]
		if path.has(cell):
			links.remove_at(i)
			return true
	return false

## 判断某格是否被连线线身经过（端点不算，端点由鬼 / 设施占据）。
## @param cell 待判断的格坐标。
## @return 有线身经过返回 true。
func HasLinkPassing(cell: Vector2i) -> bool:
	for link in links:
		var path: Array = link["path"]
		if link["from_cell"] != cell and link["to_cell"] != cell and path.has(cell):
			return true
	return false

## 移除与某只鬼相关的全部连线（拆除时调用）。
## @param uid 鬼实例编号。
func RemoveLinksOf(uid: int) -> void:
	var kept: Array[Dictionary] = []
	for link in links:
		if int(link["from_uid"]) != uid and int(link["to_uid"]) != uid:
			kept.append(link)
	links = kept

## 清空全部连线。
func Clear() -> void:
	links.clear()

## 导出连线存档。
## @return 连线字典数组。
func ExportSaveData() -> Array[Dictionary]:
	return links.duplicate(true)

## 从存档还原连线。
## @param saved 由 ExportSaveData 产出的数组。
func LoadSaveData(saved: Array) -> void:
	links.clear()
	for link in saved:
		if link is Dictionary:
			links.append(link.duplicate())

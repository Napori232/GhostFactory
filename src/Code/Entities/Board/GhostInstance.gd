class_name GhostInstance
extends RefCounted

## 一只鬼的运行时状态。静态配置在 GhostData，这里只存位置、状态、计时与缓冲。
## 状态机见 Docs/GameDesign.md §4.5：待机 → 运行 → 暂停 → 待机，故障需玩家点击恢复。

## 待机：放好但没开工。
const STATE_IDLE: StringName = &"IDLE"
## 运行：正在干活。
const STATE_RUNNING: StringName = &"RUNNING"
## 暂停：临时按住，停工但保状态。
const STATE_PAUSED: StringName = &"PAUSED"
## 故障：条件不满足而停摆，只能由玩家手动点击恢复。
const STATE_FAULT: StringName = &"FAULT"

var uid: int = 0
var data: GhostData = null
var cell: Vector2i = Vector2i.ZERO
var state: StringName = STATE_IDLE
var timer: float = 0.0
var fault_timer: float = 0.0
var input_buffer: Array[String] = []
var output_buffer: Array[String] = []
var process_counter: int = 0
var search_cells: Array[Vector2i] = []

## 构造运行时实例。
## @param ghost_data 静态配置。
## @param at_cell 本体原点格坐标。
## @param instance_id 实例唯一编号。
func _init(ghost_data: GhostData, at_cell: Vector2i, instance_id: int) -> void:
	data = ghost_data
	cell = at_cell
	uid = instance_id

## 取输入缓冲容量（件）。
## @return 输入端口的 buffer_size，没有输入端口时返回 0。
func GetInputCapacity() -> int:
	var port := data.GetInputPort()
	return port.buffer_size if port != null else 0

## 取输出缓冲容量（件）。
## @return 输出端口的 buffer_size；生产鬼无端口时用 GhostData.buffer_capacity。
func GetOutputCapacity() -> int:
	var port := data.GetOutputPort()
	return port.buffer_size if port != null else data.buffer_capacity

## 判断输入缓冲是否已满。
## @return 已满返回 true。
func IsInputFull() -> bool:
	return input_buffer.size() >= GetInputCapacity()

## 判断输出缓冲是否已满。
## @return 已满返回 true。
func IsOutputFull() -> bool:
	return output_buffer.size() >= GetOutputCapacity()

## 按 IDLE → RUNNING → PAUSED → IDLE 循环切换；FAULT 点击后回到 IDLE。
## @return 切换后的状态。
func CycleState() -> StringName:
	match state:
		STATE_IDLE:
			state = STATE_RUNNING
		STATE_RUNNING:
			state = STATE_PAUSED
		STATE_PAUSED:
			state = STATE_IDLE
		STATE_FAULT:
			state = STATE_IDLE
			timer = 0.0
			fault_timer = 0.0
		_:
			state = STATE_IDLE
	return state

## 导出可持久化的运行时状态。
## @return 含位置、状态、缓冲与计时的字典。
func ExportSaveData() -> Dictionary:
	return {
		"uid": uid,
		"ghost_id": String(data.id),
		"cell": [cell.x, cell.y],
		"state": String(state),
		"timer": timer,
		"input_buffer": input_buffer.duplicate(),
		"output_buffer": output_buffer.duplicate(),
		"process_counter": process_counter,
	}

## 从存档还原运行时状态。
## @param saved 由 ExportSaveData 产出的字典，缺字段时保留当前值。
func LoadSaveData(saved: Dictionary) -> void:
	uid = int(saved.get("uid", uid))
	var pos: Array = saved.get("cell", [cell.x, cell.y])
	if pos.size() >= 2:
		cell = Vector2i(int(pos[0]), int(pos[1]))
	state = StringName(saved.get("state", String(state)))
	timer = float(saved.get("timer", timer))
	input_buffer.clear()
	for form in saved.get("input_buffer", []):
		input_buffer.append(String(form))
	output_buffer.clear()
	for form in saved.get("output_buffer", []):
		output_buffer.append(String(form))
	process_counter = int(saved.get("process_counter", process_counter))

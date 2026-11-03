extends Node

## 关卡场景生成器。用脚本构建三个可编辑的关卡场景，避免手写 .tscn 出错。
## 运行：Godot --headless --path D:/GhostFactory/src res://Code/Tests/BuildLevelScenes.tscn
## 生成结果落在 res://Code/Entities/Level/Levels/Level01..03.tscn。

const OUTPUT_DIR: String = "res://Code/Entities/Level/Levels"

## 关卡定义。每项包含网格尺寸、预置采集区、预置供品口与障碍物。
const LEVELS: Array = [
	{
		"id": 1,
		"grid": Vector2i(10, 8),
		"fields": [
			{"origin": Vector2i(0, 3), "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], "drops": "Raw", "interval": 1.0, "garbage": 0.4, "rate": 0.6},
		],
		"terminals": [
			{"cell": Vector2i(8, 2), "accepts": "Raw", "score": 1, "facing": 2},
		],
		"obstacles": [
			{"origin": Vector2i(4, 0), "shape": [Vector2i(0, 0), Vector2i(0, 1)], "kind": "wall"},
			{"origin": Vector2i(5, 6), "shape": [Vector2i(0, 0), Vector2i(1, 0)], "kind": "machine"},
		],
	},
	{
		"id": 2,
		"grid": Vector2i(12, 9),
		"fields": [
			{"origin": Vector2i(0, 3), "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], "drops": "Raw", "interval": 1.0, "garbage": 0.4, "rate": 0.6},
		],
		"terminals": [
			{"cell": Vector2i(10, 2), "accepts": "Processed", "score": 1, "facing": 2},
		],
		"obstacles": [
			{"origin": Vector2i(4, 1), "shape": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)], "kind": "wall"},
			{"origin": Vector2i(6, 5), "shape": [Vector2i(0, 0), Vector2i(1, 0)], "kind": "machine"},
			{"origin": Vector2i(3, 7), "shape": [Vector2i(0, 0), Vector2i(0, 1)], "kind": "wall"},
		],
	},
	{
		"id": 3,
		"grid": Vector2i(14, 10),
		"fields": [
			{"origin": Vector2i(0, 3), "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], "drops": "Raw", "interval": 1.0, "garbage": 0.4, "rate": 0.6},
		],
		"terminals": [
			{"cell": Vector2i(11, 1), "accepts": "Raw", "score": 1, "facing": 2},
			{"cell": Vector2i(11, 7), "accepts": "Processed", "score": 1, "facing": 2},
		],
		"obstacles": [
			{"origin": Vector2i(4, 2), "shape": [Vector2i(0, 0), Vector2i(0, 1)], "kind": "wall"},
			{"origin": Vector2i(7, 4), "shape": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], "kind": "machine"},
			{"origin": Vector2i(4, 8), "shape": [Vector2i(0, 0), Vector2i(0, 1)], "kind": "wall"},
			{"origin": Vector2i(9, 2), "shape": [Vector2i(0, 0)], "kind": "wall"},
		],
	},
]

func _ready() -> void:
	for level: Dictionary in LEVELS:
		_build_level(level)
	get_tree().quit(0)

## 构建单个关卡场景并保存。
## @param level 关卡定义
func _build_level(level: Dictionary) -> void:
	var level_id: int = level["id"]
	var root := Node2D.new()
	root.name = "Level%02d" % level_id

	var grid_script: Script = load("res://Code/Entities/Board/BoardGrid.gd")
	var grid := Node2D.new()
	grid.name = "BoardGrid"
	grid.set_script(grid_script)
	grid.set("grid_size", level["grid"])
	root.add_child(grid)

	var field_scene: PackedScene = load("res://Code/Entities/Board/FieldComponent.tscn")
	for field: Dictionary in level["fields"]:
		var node := field_scene.instantiate()
		node.name = "Field"
		node.set("origin_cell", field["origin"])
		node.set("shape", GridUtil.ToCellArray(field["shape"]))
		node.set("drops", field["drops"])
		node.set("interval", field["interval"])
		node.set("garbage_rate", field["garbage"])
		node.set("base_rate", field["rate"])
		grid.add_child(node)
		node.owner = root

	var terminal_scene: PackedScene = load("res://Code/Entities/Board/TerminalComponent.tscn")
	var index := 0
	for terminal: Dictionary in level["terminals"]:
		var node := terminal_scene.instantiate()
		node.name = "Terminal%d" % index
		node.set("cell", terminal["cell"])
		node.set("accepts", terminal["accepts"])
		node.set("score", terminal["score"])
		node.set("facing", terminal["facing"])
		grid.add_child(node)
		node.owner = root
		index += 1

	var obstacle_scene: PackedScene = load("res://Code/Entities/Board/ObstacleComponent.tscn")
	index = 0
	for obstacle: Dictionary in level["obstacles"]:
		var node := obstacle_scene.instantiate()
		node.name = "Obstacle%d" % index
		node.set("origin_cell", obstacle["origin"])
		node.set("shape", GridUtil.ToCellArray(obstacle["shape"]))
		node.set("kind", obstacle["kind"])
		grid.add_child(node)
		node.owner = root
		index += 1

	grid.owner = root
	root.owner = null

	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	if pack_result != OK:
		printerr("FAIL: Level%02d 打包失败，错误码 %d" % [level_id, pack_result])
		return
	var path := "%s/Level%02d.tscn" % [OUTPUT_DIR, level_id]
	var save_result := ResourceSaver.save(packed, path)
	if save_result != OK:
		printerr("FAIL: Level%02d 保存失败，错误码 %d" % [level_id, save_result])
		return
	print("PASS: 生成 %s" % path)
	root.free()

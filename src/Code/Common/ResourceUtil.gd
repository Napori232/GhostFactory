class_name ResourceUtil
extends RefCounted

## 资源属性读取工具。Godot 的 Object.get() 只接受一个参数，
## 而 Dictionary.get(key, default) 接受两个——直接用 get 会因参数个数报错。
## 这里统一封装两种取法，并做类型收敛。

## 取得资源上的字符串属性。
## @param resource 目标资源
## @param key 属性名
## @param default_value 缺失时的默认值
## @return 属性值。
static func GetString(resource: Resource, key: String, default_value: String = "") -> String:
	if resource == null:
		return default_value
	var value: Variant = resource.get(key)
	if value == null:
		return default_value
	return String(value)

## 取得资源上的整数属性。
## @param resource 目标资源
## @param key 属性名
## @param default_value 缺失时的默认值
## @return 属性值。
static func GetInt(resource: Resource, key: String, default_value: int = 0) -> int:
	if resource == null:
		return default_value
	var value: Variant = resource.get(key)
	if value == null:
		return default_value
	return int(value)

## 取得资源上的浮点属性。
## @param resource 目标资源
## @param key 属性名
## @param default_value 缺失时的默认值
## @return 属性值。
static func GetFloat(resource: Resource, key: String, default_value: float = 0.0) -> float:
	if resource == null:
		return default_value
	var value: Variant = resource.get(key)
	if value == null:
		return default_value
	return float(value)

## 取得资源上的数组属性。
## @param resource 目标资源
## @param key 属性名
## @return 属性值；缺失时返回空数组。
static func GetArray(resource: Resource, key: String) -> Array:
	if resource == null:
		return []
	var value: Variant = resource.get(key)
	if value is Array:
		return value
	return []

## 取得资源上的字符串数组属性。
## @param resource 目标资源
## @param key 属性名
## @return 属性值；缺失时返回空数组。
static func GetStringArray(resource: Resource, key: String) -> PackedStringArray:
	if resource == null:
		return PackedStringArray()
	var value: Variant = resource.get(key)
	if value is PackedStringArray:
		return value
	return PackedStringArray()

## 取得资源上的格数组属性，并统一转成 Vector2i 数组。
## @param resource 目标资源
## @param key 属性名
## @return 格数组；缺失时返回空数组。
static func GetCellArray(resource: Resource, key: String) -> Array[Vector2i]:
	return GridUtil.ToCellArray(GetArray(resource, key))

## 从字典取字符串值，键缺失时返回默认值。
## @param source 源字典
## @param key 键名
## @param default_value 默认值
## @return 属性值。
static func DictString(source: Dictionary, key: String, default_value: String = "") -> String:
	if not source.has(key):
		return default_value
	return String(source[key])

## 从字典取整数值，键缺失时返回默认值。
## @param source 源字典
## @param key 键名
## @param default_value 默认值
## @return 属性值。
static func DictInt(source: Dictionary, key: String, default_value: int = 0) -> int:
	if not source.has(key):
		return default_value
	return int(source[key])

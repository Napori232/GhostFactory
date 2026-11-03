class_name GhostTag
extends RefCounted

## 鬼的端口标签词表。开放词表：ACTION 端口表示「我能作用于什么」，
## RECEPTACLE 端口表示「我能被什么作用」。标签只在 Common/ 声明一次，
## 数据层与实体层共用同一套 StringName 值。

## 攫取：主动伸舌取料。对应长舌鬼的 ACTION 端口。
const GRAB: StringName = &"GRAB"
## 悬挂：主动挂上吊绳。对应吊死鬼的 ACTION 端口。
const HANG: StringName = &"HANG"
## 吞噬：被动吞下物料。对应灶鬼的 RECEPTACLE 端口。
const SWALLOW: StringName = &"SWALLOW"
## 投喂：主动投喂物料。对应灶鬼的 ACTION 端口。
const FEED: StringName = &"FEED"
## 分流：主动把物料一分为二。对应岔口鬼的 ACTION 端口。
const SPLIT: StringName = &"SPLIT"
## 复制：主动复制邻居端口。对应镜鬼的 ACTION 端口。
const MIRROR: StringName = &"MIRROR"
## 交付：被动接受交付物。对应供品口的 RECEPTACLE 端口。
const OFFER: StringName = &"OFFER"
## 喷吐：主动把采集到的物料吐进物流。对应采集鬼的 ACTION 端口。
const SPIT: StringName = &"SPIT"
## 垃圾：收容鬼吃的废料标签，不参与端口共鸣。
const GARBAGE: StringName = &"GARBAGE"

## 全部标签，按词表顺序排列。
const ALL: Array[StringName] = [
	GRAB,
	HANG,
	SWALLOW,
	FEED,
	SPLIT,
	MIRROR,
	OFFER,
	SPIT,
	GARBAGE,
]

## 判断一个标签是否属于本词表。
## @param tag 待检查的标签。
## @return 属于词表时返回 true，否则返回 false。
static func IsValid(tag: StringName) -> bool:
	return ALL.has(tag)

## 返回标签的中文说明。
## 标签与说明的映射：GRAB 攫取 / HANG 悬挂 / SWALLOW 吞噬 / FEED 投喂 /
## SPLIT 分流 / MIRROR 复制 / OFFER 交付 / SPIT 喷吐 / GARBAGE 垃圾。
## @param tag 待描述的标签。
## @return 中文说明；未知标签返回「未知标签」。
static func Describe(tag: StringName) -> String:
	match tag:
		GRAB:
			return "攫取"
		HANG:
			return "悬挂"
		SWALLOW:
			return "吞噬"
		FEED:
			return "投喂"
		SPLIT:
			return "分流"
		MIRROR:
			return "复制"
		OFFER:
			return "交付"
		SPIT:
			return "喷吐"
		GARBAGE:
			return "垃圾"
	return "未知标签"

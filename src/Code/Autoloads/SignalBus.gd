extends Node

## 全局信号总线。实体之间的状态变化统一由此广播，避免直接调用彼此方法。

## 音量设置发生变化。
## @param channel 音量类别：master、music、sfx、dialogue 或 ambience
## @param volume 0.0-1.0 的线性音量比例
signal AudioVolumeChanged(channel: StringName, volume: float)

## 请求调整音量。
## @param channel 音量类别：master、music、sfx、dialogue 或 ambience
## @param volume 0.0-1.0 的线性音量比例
signal AudioVolumeChangeRequested(channel: StringName, volume: float)

## 实体可用状态发生变化。
## @param entity 发生变化的实体节点
## @param is_available 是否处于可交互状态
signal EntityAvailabilityChanged(entity: Node, is_available: bool)

## 玩家与可交互实体建立交互。
## @param entity 被交互的实体节点
signal PlayerInteracted(entity: Node)

## 玩家离开可交互范围。
## @param entity 被离开的实体节点
signal PlayerInteractionEnded(entity: Node)

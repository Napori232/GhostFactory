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

## 关卡开始。
## @param level_id 关卡编号，从 1 开始
signal LevelStarted(level_id: int)

## 关卡通关并完成结算。
## @param level_id 关卡编号，从 1 开始
## @param stars 本次获得的星级，1~3
signal LevelCompleted(level_id: int, stars: int)

## 关卡失败。
## @param level_id 关卡编号，从 1 开始
signal LevelFailed(level_id: int)

## 新内容解锁。
## @param ghost_id 解锁的鬼 id
signal GhostUnlocked(ghost_id: String)

## 存档写入完成。
## @param success 是否写入成功
signal SaveGameWritten(success: bool)

## 设置项发生变化。
## @param key 设置项键名
## @param value 设置项的新值
signal SettingChanged(key: StringName, value: Variant)

## 请求切换场景。
## @param target 目标场景标识：menu 主菜单、level_select 关卡选择、level 关卡、settings 设置
signal NavigateTo(target: StringName)

## 进度发生变化（解锁关卡或星级更新），界面据此刷新。
signal ProgressChanged

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

## 鬼能数量变化。
## @param spirit 当前鬼能
signal SpiritChanged(spirit: int)

## 供品交付计数变化。
## @param delivered 已交付数量
## @param goal 关卡目标数量
signal DeliveredChanged(delivered: int, goal: int)

## 鬼被放置。
## @param ghost 放置的鬼组件节点
signal GhostPlaced(ghost: Node)

## 鬼被移除。
## @param ghost 被移除的鬼组件节点
signal GhostRemoved(ghost: Node)

## 鬼发生位移（被推挤链推动）。
## @param ghost 位移的鬼组件节点
## @param from_cell 位移前的格子
## @param to_cell 位移后的格子
signal GhostDisplaced(ghost: Node, from_cell: Vector2i, to_cell: Vector2i)

## 供品口收到一份供品。
## @param form 供品形态 id
## @param terminal 接收的供品口节点
signal ItemDelivered(form: String, terminal: Node)

## 鬼的缓冲状态变化。
## @param ghost 状态变化的鬼组件节点
## @param is_full 当前缓冲是否已满
signal BufferStateChanged(ghost: Node, is_full: bool)

## 关卡倒计时每 0.1 秒刷新一次。
## @param time_left 剩余秒数
signal LevelTimerTick(time_left: float)

## 两个节点之间建立了连线。
## @param from 起点鬼节点
## @param to 终点鬼节点
signal LineCreated(from: Node, to: Node)

## 教程全部步骤完成。
signal TutorialCompleted

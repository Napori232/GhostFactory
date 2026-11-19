class_name GameSession
extends RefCounted
## 跨场景保持的会话状态。
## 目前只有「当前关卡」：通关后下一夜会被写进存档，下次启动从这一夜继续。
## 它不参与任何玩法规则，只决定 Main 载入哪份关卡数据。

static var current_level: String = "01"
## 当前夜规（Data/modifiers.json 的 id）。空 = 标准夜。
static var modifier_id: String = ""
## 从开始界面选了一夜之后，重载场景时直接开局，不再弹开始界面。
static var autostart: bool = false

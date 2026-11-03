class_name TutorialScript
extends Resource

## 教程脚本资源。按顺序保存一条教程流程中的全部步骤，供 TutorialController 加载。

## 教程步骤列表，按播放顺序排列。
@export var steps: Array[TutorialStep] = []

## 取得步骤数量。
## @return 步骤数。
func GetStepCount() -> int:
	return steps.size()

## 按下标取得步骤。
## @param index 步骤下标，从 0 开始。
## @return 对应的步骤；下标越界时返回 null。
func GetStep(index: int) -> TutorialStep:
	if index < 0 or index >= steps.size():
		return null
	return steps[index]

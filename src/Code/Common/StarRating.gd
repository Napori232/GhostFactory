class_name StarRating
extends RefCounted

## 星级计算。当前为占位实现：阈值取自 ExportSettings 的占位常量，
## 玩法实装后需要用真实的三轴评分（效率 / 手动 / 空间）替换这里的判定逻辑。

## 根据三轴分数计算星级。
## @param efficiency 效率轴分数
## @param manual 手动轴分数
## @param space 空间轴分数
## @return 星级 1~3；未达标返回 0。
static func CalculateStars(efficiency: float, manual: float, space: float) -> int:
	if efficiency <= 0.0 and manual <= 0.0 and space <= 0.0:
		return 0
	var stars := 1
	if efficiency >= ExportSettings.star_threshold_efficiency \
			and manual >= ExportSettings.star_threshold_manual \
			and space >= ExportSettings.star_threshold_space:
		stars = 2
		var extra := 0
		if efficiency >= ExportSettings.star_threshold_efficiency * 2.0:
			extra += 1
		if manual >= ExportSettings.star_threshold_manual * 2.0:
			extra += 1
		if space >= ExportSettings.star_threshold_space * 2.0:
			extra += 1
		stars = 3 if extra >= 2 else 2
	return stars

## 把星级转为文本形式。
## @param stars 星级 0~3
## @return 形如 ★★☆ 的文本。
static func ToText(stars: int) -> String:
	match clampi(stars, 0, 3):
		1:
			return "★☆☆"
		2:
			return "★★☆"
		3:
			return "★★★"
		_:
			return "☆☆☆"

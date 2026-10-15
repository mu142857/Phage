# 戟卫:标准身材、猪嘴盔,长戟。举过头顶憋两帧(第 3~4 帧),劈下来拖一道弧(第 6~7 帧判定),
# 够得很远——别站在戟头底下等它劈。
extends BureauMob


func _lines() -> Dictionary:
	return {
		"attack": ["斩。", "依规处理。", "退后。"],
	}

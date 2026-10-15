# 下水道第二段【赔灯费】:稽查员说上一段你打坏了一盏灯(不管你打没打)。后面一整队管道局齐步巡逻:
# 两面塔盾在前、戟卫、队长、两个重弩手——不交钱就列阵推过来,队长喊"放"弩手齐射。先打队长。
extends SewerRoom


func _fee_lines() -> Array:
	return [["稽查员", "这段归我管。"], ["稽查员", "还有，刚才那段，"], ["稽查员", "你打坏了一盏灯。"], ["稽查员", "赔。"]]


func _refuse_options(can_pay: bool) -> Array:
	return ["我没打坏", "没钱了"] if can_pay else ["没钱了", "我没打坏"]


func _refused_reply(idx: int, can_pay: bool) -> Array:
	var opts := _refuse_options(can_pay)
	return ["那就打。"] if opts[idx] == "没钱了" else ["表上写着打坏了。", "按章处理。"]


func _paid_lines() -> Array:
	return ["灯费收到。", "下一位。"]

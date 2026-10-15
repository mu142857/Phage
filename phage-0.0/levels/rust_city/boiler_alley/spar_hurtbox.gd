# 陪练里"能被砍"的那块:挂在 monster 组、layer 4,主角的刀砍到就调 on_hit(不扣谁的血)。
extends Area2D

var on_hit: Callable


func take_damage(_value: int) -> void:
	if on_hit.is_valid():
		on_hit.call()

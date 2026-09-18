# 大章鱼 Null(0):开打前 / BossIntro 演出期间 / 剧情杀时停在这里,不走不打。
extends BasicState

@onready var monster = $"../.."


func enter() -> void:
	monster.set_advancing(false)
	monster.set_drops(false)

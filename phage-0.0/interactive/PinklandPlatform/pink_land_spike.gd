extends Node2D

## 地刺:碰到玩家时扣血并把玩家弹回上一个安全点(类似空洞骑士)。
## 与会触发陷阱的 PinklandPlatform 不同——陷阱只扣血,不弹回。

@export var damage: int = 1
@export var shake_strength: float = 4.0  # 命中时的屏幕震动强度


func _on_hit_box_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	if body.has_method("respawn_to_safe"):
		body.call("respawn_to_safe")
	Game.shake_camera(shake_strength)

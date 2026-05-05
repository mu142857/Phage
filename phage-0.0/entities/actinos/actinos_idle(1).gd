extends BasicState

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var timer: Timer = get_node_or_null("Timer")

var next_attack: int = 2 # 初始默认接 JumpAttack(2)

func enter():
	# 动画名首字母大写
	if ani_2D:
		ani_2D.play("Idle")
	
	# 仅用于调试生成与受击时，保持在Idle
	if "idle_only" in monster and monster.idle_only:
		return
	
	# 根据血量比例计算Idle时间 (范围 3.0 ~ 6.0 秒)
	# 需要在 actinos.gd 中定义 health 和 max_health
	var health_ratio: float = 1.0 # 默认比例为1
	if "health" in monster and "max_health" in monster and monster.max_health > 0:
		health_ratio = float(monster.health) / float(monster.max_health)
	
	var duration: float = lerp(3.0, 6.0, health_ratio)
	
	if timer:
		timer.start(duration)

func process(_delta: float) -> void:
	pass

func _on_timer_timeout() -> void:
	if "idle_only" in monster and monster.idle_only:
		return
	# 切换到对应的攻击状态
	get_parent().change_state(next_attack)
	
	# 更新下一次的攻击方式 (交替进行)
	if next_attack == 2: # 如果这次是 JumpAttack
		next_attack = 3  # 下次变成 SpikeAttack
	else:
		next_attack = 2  # 否则变回 JumpAttack

func exit():
	if timer:
		timer.stop()

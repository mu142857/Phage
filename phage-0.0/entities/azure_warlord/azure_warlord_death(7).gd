# =============================================================================
# Death(7)  —  蓝晶死亡：挣扎抖动 → 水晶炸开（方形粒子爆发 + 闪白 + 重震）→ 移除
# =============================================================================
# 蓝晶没有 Death 动画，用 Idle 定格 + 震屏演「挣扎」，然后一炸了事。
# 进入时关掉全部碰撞/交互：尸体不再打人也不再被打。
extends BasicState

@export var rattle_duration: float = 0.8   # 爆炸前的挣扎抖动时长
@export var rattle_shake: float = 2.0      # 挣扎震屏强度
@export var burst_shake: float = 6.0       # 炸开瞬间的重震
@export var burst_offset: Vector2 = Vector2(0, -14)  # 爆点相对脚底（root）的偏移

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/azure_warlord/azure_warlord_death_effect.tscn")

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var boss: AzureWarlord = $"../.." as AzureWarlord

var death_ticket: int = 0


func enter() -> void:
	death_ticket += 1
	if boss != null and is_instance_valid(boss):
		boss.velocity = Vector2.ZERO
		boss.set_physics_process(false)
		_disable_all_interactions()
		if boss.has_method("hide_health_ui"):
			boss.hide_health_ui()
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Idle")
	_run_sequence(death_ticket)


func _run_sequence(ticket: int) -> void:
	var elapsed := 0.0
	while elapsed < rattle_duration:
		if ticket != death_ticket or not is_instance_valid(boss):
			return
		Game.shake_camera(rattle_shake)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if ticket != death_ticket:
		return
	Game.stop_shake()
	# 水晶炸开：粒子从整个身体范围爆出
	if DEATH_EFFECT_SCENE != null and get_tree().current_scene != null and is_instance_valid(boss):
		var eff := DEATH_EFFECT_SCENE.instantiate()
		get_tree().current_scene.add_child(eff)
		if eff is Node2D:
			(eff as Node2D).global_position = boss.global_position + burst_offset
		if eff is GPUParticles2D:
			(eff as GPUParticles2D).emitting = true
	Game.flash(0.35, Color(0.45, 0.9, 0.95))
	Game.shake_camera(burst_shake)
	if boss != null and is_instance_valid(boss):
		boss.queue_free()


# take_damage 是在物理回调里进来的,碰撞开关必须 set_deferred,同步改会报 flushing queries
func _disable_all_interactions() -> void:
	boss.collision_layer = 0
	boss.collision_mask = 0
	var shape := get_node_or_null("../../CollisionShape2D") as CollisionShape2D
	if is_instance_valid(shape):
		shape.set_deferred("disabled", true)
	for path in ["../../PlayerCheck", "../../TramplingHitBox", "../../AttackHitBox", "../../PunchHitBox"]:
		var area := get_node_or_null(path) as Area2D
		if is_instance_valid(area):
			area.set_deferred("monitoring", false)
			area.set_deferred("monitorable", false)
			area.collision_layer = 0
			area.collision_mask = 0

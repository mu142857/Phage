# =============================================================================
# state_death.gd  —  rust_goat 死亡（2 号）：「坠机」演出
# =============================================================================
# 流程：
#   1. 战吼段：原地播 Idle 动画 + 持续震屏（battlecry_duration 秒）
#   2. 跳起：像 Actinos 跳跃一样向上弹起（Idle 动画）
#   3. 滞空：到最高点后停在半空 hang_duration 秒（坠机名场面的停顿）
#   4. 直坠：垂直下落，【不检测地面】，穿过地板继续掉
#   5. 掉出屏幕（y > exit_y）→ 震一下（屏外砸地闷响）→ 消失
#
# 进入时就关闭全部碰撞/交互：既保证坠落能穿过地板，也防止尸体还能打人/被打。
# =============================================================================

extends BasicState

# --- 战吼段 ---
@export var battlecry_duration: float = 1.2   # 死前战吼时长
@export var battlecry_shake: float = 3.0      # 战吼震屏强度

# --- 跳起/坠落（参考 Actinos JumpAttack: jump_y=-180, gravity=350）---
@export var jump_velocity_y: float = -280.0   # 起跳初速
@export var gravity: float = 750.0            # 上升段重力（决定跳多高）
@export var hang_duration: float = 0.0        # 滞空停顿（名场面！不要就设 0）
@export var fall_gravity: float = 650.0       # 下坠段重力
@export var exit_y: float = 130.0             # 掉过这条线就算出屏（90 高的屏幕，130 稳出）

# --- 收尾 ---
@export var crash_shake: float = 4.0          # 出屏瞬间的闷震（0=不震）

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

# 内部阶段：0=战吼 1=上升 2=滞空 3=下坠
var stage: int = 0
var vy: float = 0.0
var is_active: bool = false
var ticket: int = 0


func enter() -> void:
	is_active = true
	stage = 0
	vy = 0.0
	ticket += 1

	if not is_instance_valid(monster):
		return
	monster.velocity = Vector2.ZERO
	monster.set_physics_process(false)   # 停掉主体的横向 clamp 等
	_disable_all_interactions()          # 关碰撞：能穿地板，也不再打人/被打

	if monster.has_method("hide_health_ui"):
		monster.hide_health_ui()

	if is_instance_valid(ani_2d):
		ani_2d.play(&"Idle")

	_run_battlecry(ticket)


func process(delta: float) -> void:
	if not is_active:
		return
	match stage:
		1:  # 上升
			vy += gravity * delta
			monster.global_position.y += vy * delta
			if vy >= 0.0:  # 到顶
				vy = 0.0
				stage = 2
				_run_hang(ticket)
		3:  # 直坠（不检测地面，一路穿）
			vy += fall_gravity * delta
			monster.global_position.y += vy * delta
			if monster.global_position.y > exit_y:
				_crash_and_free()


func exit() -> void:
	is_active = false
	ticket += 1
	Game.stop_shake()


# --- 阶段 0：战吼段 ---
func _run_battlecry(t: int) -> void:
	var elapsed := 0.0
	while elapsed < battlecry_duration:
		if t != ticket or not is_active:
			return
		Game.shake_camera(battlecry_shake)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if t != ticket or not is_active:
		return
	Game.stop_shake()
	# 起跳
	stage = 1
	vy = jump_velocity_y


# --- 阶段 2：滞空停顿（名场面）---
func _run_hang(t: int) -> void:
	await get_tree().create_timer(hang_duration).timeout
	if t != ticket or not is_active:
		return
	stage = 3  # 开坠


# --- 出屏：闷震 + 消失 ---
func _crash_and_free() -> void:
	is_active = false
	if crash_shake > 0.0:
		Game.shake_camera(crash_shake)
	if is_instance_valid(monster):
		monster.queue_free()


func _disable_all_interactions() -> void:
	monster.collision_layer = 0
	monster.collision_mask = 0
	_disable_shape("../../CollisionShape2D")
	_disable_area("../../PlayerCheck")
	_disable_area("../../ElbowStrikeHitbox")


func _disable_shape(path: String) -> void:
	var shape := get_node_or_null(path) as CollisionShape2D
	if is_instance_valid(shape):
		shape.disabled = true


func _disable_area(path: String) -> void:
	var area := get_node_or_null(path) as Area2D
	if is_instance_valid(area):
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 0

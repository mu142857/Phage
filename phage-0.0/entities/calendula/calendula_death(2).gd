# =============================================================================
# calendula_death(2).gd  —  金盏死亡（2 号）：「夺路而逃」演出
# =============================================================================
# 没有 Death 动画。流程：
#   1. 踉跄段：原地播 Ram（没有就 Idle）+ 持续震屏（stagger_duration 秒）
#   2. 冲出段：朝更近的屏幕边缘全速横冲，无视场地边界，一头撞出屏幕
#   3. 出屏（x 超出边界 exit_margin）→ 闷震一下 → queue_free
#
# 进入时就关闭全部碰撞/交互，防止尸体还能打人/被打。
# 之后的「蛛网解除 + 梦结束」是关卡侧的事：监听本体 tree_exited 接演出。
# =============================================================================

extends BasicState

@export var stagger_duration: float = 0.45  # 踉跄停顿时长
@export var stagger_shake: float = 3.0      # 踉跄震屏强度
@export var charge_speed: float = 300.0     # 冲出屏幕的速度（比 Ram 更快，逃命）
@export var exit_margin: float = 60.0       # 冲出边界这么远才算出屏（大素材要多留）
@export var exit_shake: float = 2.5         # 出屏瞬间的闷震（0=不震）

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."

# 内部阶段：0=踉跄 1=冲出
var stage: int = 0
var charge_dir: float = 1.0
var is_active: bool = false
var ticket: int = 0


func enter() -> void:
	is_active = true
	stage = 0
	ticket += 1

	if not is_instance_valid(monster):
		return
	monster.velocity = Vector2.ZERO
	monster.set_physics_process(false)   # 停掉主体的横向 clamp（要冲出边界）
	_disable_all_interactions()

	if monster.has_method("hide_health_ui"):
		monster.hide_health_ui()

	# 朝脸面对的方向逃（-side：右侧位朝左脸就往左冲），不转向不翻转
	var side: int = monster.side if "side" in monster else 1
	charge_dir = -float(side)

	if is_instance_valid(ani_2d):
		if ani_2d.sprite_frames != null and ani_2d.sprite_frames.has_animation(&"Ram"):
			ani_2d.play(&"Ram")
		else:
			ani_2d.play(&"Idle")

	_run_stagger(ticket)


func process(delta: float) -> void:
	if not is_active or stage != 1:
		return
	monster.global_position.x += charge_dir * charge_speed * delta
	var center: float = monster.center_x if "center_x" in monster else 0.0
	if absf(monster.global_position.x - center) > 80.0 + exit_margin:
		_exit_screen_and_free()


func exit() -> void:
	is_active = false
	ticket += 1
	Game.stop_shake()


# --- 阶段 0：踉跄段 ---
func _run_stagger(t: int) -> void:
	var elapsed := 0.0
	while elapsed < stagger_duration:
		if t != ticket or not is_active:
			return
		Game.shake_camera(stagger_shake)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if t != ticket or not is_active:
		return
	Game.stop_shake()
	stage = 1  # 开冲


# --- 出屏：闷震 + 消失（蛛网解除/梦结束由关卡接手）---
func _exit_screen_and_free() -> void:
	is_active = false
	if exit_shake > 0.0:
		Game.shake_camera(exit_shake)
	if is_instance_valid(monster):
		monster.queue_free()


func _disable_all_interactions() -> void:
	monster.collision_layer = 0
	monster.collision_mask = 0
	_disable_shape("../../CollisionShape2D")
	_disable_area("../../PlayerCheck")
	_disable_area("../../RamHitbox")


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

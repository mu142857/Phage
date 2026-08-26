# =============================================================================
# calendula_web_bolt.gd  —  金盏网弹（挂在 calendula_web_bolt.tscn 根节点）
# =============================================================================
# 全程【零伤害】的控制弹，抛物线飞行：
#   setup_arc(start, initial_velocity)：初速任意（吐弹 vy=0 只有 vx；
#   轰炸弹 vx=vy=0 从屏幕顶垂直落），fall_gravity 一路加速
#   飞行中按速度方向旋转贴图：素材 rotation=0 朝左、-90 垂直向下、180 朝右
#   → rotation = velocity.angle() - PI（这是全项目唯一获准旋转的贴图，用户钦定）
#   碰到玩家 → 糊脸缠身（跟随玩家）：禁跳跃/禁冲刺/移速×0.12（基本动不了）
#   落地（y >= land_y）→ 播 Explode 成网陷阱，玩家踩到 → 同样缠身
#   缠身/落地后进 "monster" 组 + collision_layer=4（玩家攻击框 mask=4 才扫得到），
#   被玩家攻击 hits_to_break(3) 下打破 → 解除缠身，渐隐消失
#   已缠身的玩家再碰到别的网弹：不叠加，原地散开
#
# z_index=15 > 玩家(10)：网永远糊在主角前面。
# =============================================================================

extends Area2D

@export var fall_gravity: float = 260.0    # 抛物线重力（像素/秒²）
@export var land_y: float = 74.0           # 落地停点（地面 80，网片中心贴地）
@export var bound_left: float = -110.0     # 出界删除线（盖住 [-80,80] 的 boss 房）
@export var bound_right: float = 110.0
@export var bound_top: float = -90.0
@export var hits_to_break_attached: int = 4  # 缠身状态：打几下挣脱
@export var hits_to_break_landed: int = 1    # 落地陷阱：一下就扫掉（清场爽快）
@export var attach_offset: Vector2 = Vector2(0, -4)  # 糊在主角身上的位置偏移
# 缠身时的受击半径：攻击判定框在主角前方 16px 起，必须够大才能被挥砍够到
@export var attached_hit_radius: float = 20.0
@export var landed_hit_radius: float = 8.0

const MODE_FLYING: int = 0
const MODE_LANDED: int = 1
const MODE_ATTACHED: int = 2
const MODE_DEAD: int = 3   # 散开/破碎中，只等删除

var mode: int = MODE_FLYING
var velocity: Vector2 = Vector2.ZERO
var hits_left: int = 3
var _victim: Node2D = null
var _flash_tween: Tween = null

@onready var ani: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_shape: CollisionShape2D = $CollisionShape2D


## 抛物线出弹：initial_velocity 是出手瞬间的速度（吐弹给横向，轰炸弹给零）
func setup_arc(start_pos: Vector2, initial_velocity: Vector2) -> void:
	global_position = start_pos
	velocity = initial_velocity
	mode = MODE_FLYING
	_update_rotation()
	if is_instance_valid(ani):
		ani.play(&"Flying")


func _physics_process(delta: float) -> void:
	match mode:
		MODE_FLYING:
			velocity.y += fall_gravity * delta
			global_position += velocity * delta
			_update_rotation()
			var player := _overlapping_player()
			if player != null:
				_attach(player)
				return
			if global_position.y >= land_y:
				_land()
				return
			if _out_of_bounds():
				queue_free()
		MODE_LANDED:
			var player := _overlapping_player()
			if player != null:
				_attach(player)
		MODE_ATTACHED:
			if not is_instance_valid(_victim):
				queue_free()
				return
			global_position = _victim.global_position + attach_offset


# 素材 rotation=0 朝左（头左尾右），所以旋转 = 速度方向角 - PI：
# 朝左飞 0°、垂直下落 -90°、朝右飞 180°，正好对上素材的语义
func _update_rotation() -> void:
	if velocity != Vector2.ZERO:
		rotation = velocity.angle() - PI


func _out_of_bounds() -> bool:
	return global_position.x < bound_left or global_position.x > bound_right \
			or global_position.y < bound_top


func _overlapping_player() -> Node2D:
	for body in get_overlapping_bodies():
		if body != null and body.is_in_group("player"):
			return body as Node2D
	return null


# --- 落地成网陷阱 ---
func _land() -> void:
	mode = MODE_LANDED
	global_position.y = land_y
	velocity = Vector2.ZERO
	rotation = 0.0  # 落地的网平铺，回正
	if is_instance_valid(ani):
		ani.play(&"Explode")
	_become_hittable(landed_hit_radius, hits_to_break_landed)


# --- 糊到玩家身上：缠身 ---
func _attach(player: Node2D) -> void:
	# 已被别的网缠住：不叠加，这张网原地散开
	if "web_snared" in player and player.web_snared:
		_fizzle()
		return
	mode = MODE_ATTACHED
	_victim = player
	if player.has_method("set_web_snared"):
		player.call("set_web_snared", true)
	global_position = player.global_position + attach_offset
	rotation = 0.0  # 糊在身上的网回正
	if is_instance_valid(ani):
		ani.play(&"Explode")
	_become_hittable(attached_hit_radius, hits_to_break_attached)


# 进入可被打状态：入 monster 组 + 上怪物层（玩家攻击框 mask=4）+ 撑大受击半径
func _become_hittable(radius: float, break_hits: int) -> void:
	hits_left = break_hits
	add_to_group("monster")
	# 挂 monster 是为了能被主角攻击打破;召唤物别自动帮忙清网(见 spider_egg)
	add_to_group("summon_ignore")
	collision_layer = 4
	if is_instance_valid(hit_shape):
		# CircleShape2D 是场景共享资源，必须先 duplicate 再改，不然改了所有网弹
		var circle := hit_shape.shape.duplicate() as CircleShape2D
		if circle != null:
			circle.radius = radius
			hit_shape.shape = circle


# --- 被玩家攻击（player_attack 按 monster 组调 take_damage）---
func take_damage(_value: int) -> void:
	if mode == MODE_FLYING or mode == MODE_DEAD:
		return
	hits_left -= 1
	_flash()
	if hits_left <= 0:
		_break_web()


func _flash() -> void:
	if not is_instance_valid(ani):
		return
	if is_instance_valid(_flash_tween):
		_flash_tween.kill()
	ani.modulate = Color(1.9, 1.9, 1.9)
	_flash_tween = create_tween()
	_flash_tween.tween_property(ani, "modulate", Color.WHITE, 0.12)


# 打破：解除缠身 + 快速渐隐
func _break_web() -> void:
	_release_victim()
	mode = MODE_DEAD
	remove_from_group("monster")
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


# 不叠加时的原地散开：播个 Explode 意思一下，慢慢淡掉，不可被打不挡刀
func _fizzle() -> void:
	mode = MODE_DEAD
	velocity = Vector2.ZERO
	rotation = 0.0
	if is_instance_valid(ani):
		ani.play(&"Explode")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _release_victim() -> void:
	if is_instance_valid(_victim) and _victim.has_method("set_web_snared"):
		_victim.call("set_web_snared", false)
	_victim = null


# 任何方式被拆掉（切场景/玩家死亡重载）都不能把玩家永久钉住
func _exit_tree() -> void:
	_release_victim()

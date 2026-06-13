# =============================================================================
# state_shoot.gd  —  发射攻击样板（飞篮球 / 抛物线砸地 / 多向弹射）
# =============================================================================
# 积木结构：朝向玩家 → 播攻击动画 → 计时器猜帧到出手时刻 → 生成子弹 → 动画完回 Idle。
# 出手时机 = trigger_frame / attack_fps（Actinos SpikeAttack: 第3帧 / 10fps = 0.3s）。
#
# 三种子弹都走统一的 setup 约定（见各 bullet_*.gd 顶部注释）：
#   bullet_straight.gd  直线匀速（飞篮球）  setup(start, dir_vector)
#   bullet_parabola.gd  抛物线砸地         setup(start, target, flight_time, gravity)
#   bullet_bounce.gd    弹射反弹           setup(start, dir_vector)
# 本样板按 bullet_kind 分发参数；一招多发（散射）改 _spawn_bullets() 即可，
# 多角度散射的写法参考文件底部注释（来自栗子劫念 ShootCrystal）。
#
# 节点要求：
#   - AnimatedSprite2D 有本招动画
#   - BulletReleasePoint (Node2D) 标记发射口位置（没有就从 boss 中心发）
# =============================================================================

extends BasicState

@export var attack_animation: StringName = &"Attack"

# --- 出手时机（计时器猜帧）---
@export var attack_fps: float = 10.0       # 动画帧率（Actinos: 10）
@export var trigger_frame: int = 3         # 第几帧出手（Actinos: 3）

# --- 子弹选择与参数 ---
@export_enum("straight", "parabola", "bounce") var bullet_kind: String = "straight"
const BULLET_SCENE: PackedScene = null     # 子弹场景，例: preload("res://entities/xxx/xxx_bullet.tscn")

# straight / bounce 用：
@export var bullet_speed: float = 120.0    # 直线弹速度（160 宽屏幕参考 100~150）
@export var aim_at_player: bool = true     # true=瞄准玩家方向, false=按朝向水平直飞
# parabola 用：
@export var flight_time: float = 1.1       # 飞行时长（Actinos: 1.1）
@export var bullet_gravity: float = 400.0  # 弹道重力（Actinos: 400）
@export var ground_y: float = 80.0         # 落点地面高度（Actinos: 80）

# --- 发射瞬间表现（参考栗子劫念：闪光+震屏）---
@export var fire_shake: float = 0.0        # 出手震屏（0=不震；栗子 ShootCrystal: 11）
@export var fire_flash_amount: float = 0.0 # 出手闪光（0=不闪；栗子: 3）
@export var fire_flash_color: Color = Color(0.9, 0.8, 1.0, 0.3)

@onready var ani_2d: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."
@onready var release_point: Node2D = get_node_or_null("../../BulletReleasePoint")

var elapsed: float = 0.0
var fired: bool = false


func enter() -> void:
	elapsed = 0.0
	fired = false
	monster.velocity = Vector2.ZERO

	if monster.has_method("face_player"):
		monster.face_player()
	_apply_facing()

	if is_instance_valid(ani_2d):
		ani_2d.play(attack_animation)
		if not ani_2d.animation_finished.is_connected(_on_animation_finished):
			ani_2d.animation_finished.connect(_on_animation_finished)


func process(delta: float) -> void:
	elapsed += delta
	if not fired and elapsed >= _trigger_time():
		fired = true
		_spawn_bullets()


func exit() -> void:
	if is_instance_valid(ani_2d) and ani_2d.animation_finished.is_connected(_on_animation_finished):
		ani_2d.animation_finished.disconnect(_on_animation_finished)
	_reset_facing_scale()


func _on_animation_finished() -> void:
	if is_instance_valid(ani_2d) and ani_2d.animation == attack_animation:
		change_state(1)


func _trigger_time() -> float:
	if attack_fps <= 0.0:
		return 0.0
	return float(trigger_frame) / attack_fps


# =============================================================================
# 发射 —— 改这里实现一招多发/散射
# =============================================================================
func _spawn_bullets() -> void:
	# 出手表现
	if fire_shake > 0.0:
		Game.shake_camera(fire_shake)
	if fire_flash_amount > 0.0:
		Game.flash(fire_flash_amount, fire_flash_color)

	_spawn_one()

	# === 多发散射示例（仿栗子劫念四向水晶；取消注释改角度即可）===
	# 角度是弧度：0=右, PI=左, -PI/2=上, PI/2=下
	# for angle in [-PI/3, -PI/2, -2*PI/3]:
	#     _spawn_one(Vector2(cos(angle), sin(angle)))


func _spawn_one(custom_dir: Vector2 = Vector2.ZERO) -> void:
	if BULLET_SCENE == null:
		push_warning("state_shoot: BULLET_SCENE 没填！")
		return
	var bullet := BULLET_SCENE.instantiate()
	if bullet == null or get_tree().current_scene == null:
		return
	get_tree().current_scene.add_child(bullet)

	var start_pos: Vector2 = monster.global_position
	if is_instance_valid(release_point):
		start_pos = release_point.global_position

	match bullet_kind:
		"parabola":
			# 抛物线：瞄准玩家脚下落点
			var target := Vector2(_get_player_x(), ground_y)
			if bullet.has_method("setup"):
				bullet.setup(start_pos, target, flight_time, bullet_gravity)
		_:
			# straight / bounce：给方向向量
			var dir := custom_dir
			if dir == Vector2.ZERO:
				dir = _aim_dir(start_pos)
			if bullet.has_method("setup"):
				bullet.setup(start_pos, dir * bullet_speed)
			else:
				bullet.global_position = start_pos


# 瞄准方向：瞄玩家 or 按朝向水平直飞
func _aim_dir(from_pos: Vector2) -> Vector2:
	if aim_at_player:
		var player: Node2D = monster._get_player() if monster.has_method("_get_player") else null
		if player != null:
			return (player.global_position - from_pos).normalized()
	var d: int = monster.direct if "direct" in monster else 1
	return Vector2(d, 0)


func _get_player_x() -> float:
	var player: Node2D = monster._get_player() if monster.has_method("_get_player") else null
	if player != null:
		return player.global_position.x
	return monster.global_position.x


# 朝向翻转（翻转方向按你素材改；发射口 release_point 挂在主体下会跟着 scale 翻，
# 若发现发射位置不对，参考 Actinos 用 BulletReleasePoint 记录正确位置的做法）
func _apply_facing() -> void:
	if not is_instance_valid(ani_2d):
		return
	var d: int = monster.direct if "direct" in monster else 1
	var s := maxf(absf(ani_2d.scale.x), 1.0)
	ani_2d.scale.x = -s if d > 0 else s


func _reset_facing_scale() -> void:
	if is_instance_valid(ani_2d):
		ani_2d.scale.x = maxf(absf(ani_2d.scale.x), 1.0)

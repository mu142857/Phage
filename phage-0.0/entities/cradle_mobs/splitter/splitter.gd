# 分身(会复制自己的怪):一坨趴在地上的肉。
# 生命周期:
#   Spawn(幼体):由分身弹落地生成时先播 Spawn(独立的 $Spawn 精灵,帧来自子弹图集),
#         这期间没有接触伤害、不动;能被打,挨打的碰撞箱是 $CollisionShapeSpawn(小)。
#   Walk:播完 Spawn 换回主体精灵和普通碰撞箱,开始慢吞吞地走来走去——
#         每次 Walk 动画回到第 0 帧就"窜"一下:hop_distance 像素,正弦缓入缓出 hop_duration 秒,
#         其余时间停着,看起来一窜一窜但不生硬;
#         每段 0.8~1.6s 重摇方向:3/5 朝主角、2/5 背对;这时候身体有接触伤害(AttackCheck)。
#   Attack:主角进 PlayerCheck 就停下播 Attack,第 spit_frame 帧朝主角方向抛一颗分身弹(抛物线),
#         冷却 10s。Attack 本身没有伤害,只有身体的接触伤害。
# 分裂规则(用户定):出手瞬间自己血量减半(最少 1),弹落到地面长成新的一只(血量=减半后的值);
# 场上总数封顶 max_total(8),满了就抛普通弹(落地炸)。弹打到左右墙只爆不生。
# 动画名:主体 Walk(循环)/Attack(单次),$Spawn 节点 Spawn(单次)。素材默认朝左。
# 可选节点 FloorRay/WallRay(RayCast2D,mask 1):有就探地/探墙掉头。
extends CharacterBody2D

const BULLET_SCENE: PackedScene = preload("res://entities/cradle_mobs/splitter/splitter_bullet.tscn")
const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/cradle_mobs/splitter/splitter_death.tscn")

@export var max_health: int = 1000
@export var health: int = 1000
@export var gravity: float = 850.0

@export_group("Walk")
@export var hop_distance: float = 4.0           # 一窜挪几像素
@export var hop_duration: float = 0.25          # 一窜用多久(正弦缓入缓出)
@export var hop_interval: float = 0.4           # 多久窜一次(没导 Walk 帧时按这个;有帧时每次 Walk 回到第 0 帧窜)
@export var segment_time: Vector2 = Vector2(0.8, 1.6)  # 每段走多久重摇方向
@export var toward_player_chance: float = 0.6   # 3/5 朝主角,2/5 背对
@export var wander_distance: float = 60.0       # 离出生点最远多远就掉头

@export_group("Split")
@export var spit_frame: int = 6           # Attack 动画的出弹帧(0 起数)
@export var attack_cooldown: float = 4.0
@export var max_total: int = 8            # 场上分身(含本体)封顶
## 侦测范围往下多伸这么多像素:站在平台上的本体也能看见底下地面上的主角,往下面抛弹让分身长在地上
@export var detect_below: float = 0.0
## 由分身弹生成的分身:先当幼体播 Spawn 再开始活动
@export var spawned_from_bullet: bool = false

@export_group("Contact")
@export var contact_damage: int = 10      # 0 = 关掉接触伤害(数值对主角无意义,碰一下就是一次破盾)
@export var contact_cooldown: float = 0.6

enum Phase { SPAWN, WALK, ATTACK }

var _phase: Phase = Phase.WALK
var _cooldown := 0.0
var _spat := false
var _contact_cd := 0.0
var _walk_dir := -1.0
var _segment_left := 0.0
var _spawn_x := 0.0
var _hop_from_x := 0.0
var _hop_elapsed := 999.0       # >= hop_duration 表示没在窜
var _hop_wait := 0.0
var _last_walk_frame := -1

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var spawn_sprite: AnimatedSprite2D = get_node_or_null("Spawn") as AnimatedSprite2D
@onready var body_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var spawn_shape: CollisionShape2D = get_node_or_null("CollisionShapeSpawn") as CollisionShape2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var attack_check: Area2D = get_node_or_null("AttackCheck") as Area2D
@onready var muzzle: Node2D = get_node_or_null("Muzzle") as Node2D
@onready var floor_ray: RayCast2D = get_node_or_null("FloorRay") as RayCast2D
@onready var wall_ray: RayCast2D = get_node_or_null("WallRay") as RayCast2D


func _ready() -> void:
	add_to_group("monster")
	if detect_below > 0.0 and player_check != null:
		var pc_shape := player_check.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if pc_shape != null and pc_shape.shape is RectangleShape2D:
			var rect := (pc_shape.shape as RectangleShape2D).duplicate() as RectangleShape2D
			rect.size.y += detect_below
			pc_shape.shape = rect
			pc_shape.position.y += detect_below * 0.5
	if floor_ray == null:
		# 场景里没画探地射线就自己造一根:站在平台上(21 房中间平台)才不会一窜窜下去
		floor_ray = RayCast2D.new()
		floor_ray.name = "FloorRay"
		floor_ray.position = Vector2(hop_distance + 4.0, -2.0)
		floor_ray.target_position = Vector2(0.0, 8.0)
		floor_ray.collision_mask = 1
		add_child(floor_ray)
	add_to_group("splitter")
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	if ani_2d != null and ani_2d.material != null:
		ani_2d.material = ani_2d.material.duplicate()
		if ani_2d.material is ShaderMaterial:
			(ani_2d.material as ShaderMaterial).set_shader_parameter("Enabled", false)
	_spawn_x = global_position.x
	if spawned_from_bullet and _has_anim(spawn_sprite, &"Spawn"):
		_enter_spawn()
	else:
		_enter_walk()
		_cooldown = attack_cooldown * 0.5 if spawned_from_bullet else 0.0


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	_cooldown = maxf(0.0, _cooldown - delta)
	_contact_cd = maxf(0.0, _contact_cd - delta)
	match _phase:
		Phase.SPAWN:
			if spawn_sprite == null or not spawn_sprite.is_playing():
				_enter_walk()
				_cooldown = attack_cooldown * 0.5
		Phase.WALK:
			_process_walk(delta)
			if _cooldown <= 0.0:
				var player := _get_detected_player()
				if player != null:
					_start_attack(player)
		Phase.ATTACK:
			if not _spat and ani_2d != null and ani_2d.animation == &"Attack" and ani_2d.frame >= spit_frame:
				_spit()
			if ani_2d == null or not ani_2d.is_playing():
				_enter_walk()
				_cooldown = attack_cooldown
	move_and_slide()
	if _phase != Phase.SPAWN and contact_damage > 0:
		_try_contact_damage()


# ---- 幼体:独立的 Spawn 精灵 + 小碰撞箱,无接触伤害 ----
func _enter_spawn() -> void:
	_phase = Phase.SPAWN
	velocity.x = 0.0
	_show_spawn_form(true)
	spawn_sprite.play(&"Spawn")


func _show_spawn_form(on: bool) -> void:
	if ani_2d != null:
		ani_2d.visible = not on
	if spawn_sprite != null:
		spawn_sprite.visible = on
		if not on:
			spawn_sprite.stop()
	# 挨打的箱子:幼体用小的(没有小箱就一直用普通的)
	if spawn_shape != null:
		spawn_shape.set_deferred("disabled", not on)
		if body_shape != null:
			body_shape.set_deferred("disabled", on)
	if attack_check != null:
		attack_check.set_deferred("monitoring", not on)


# ---- 一窜一窜地走 ----
func _enter_walk() -> void:
	if _phase == Phase.SPAWN or spawn_sprite != null and spawn_sprite.visible:
		_show_spawn_form(false)
	_phase = Phase.WALK
	_pick_segment()
	_play_anim(&"Walk")


func _pick_segment() -> void:
	_segment_left = randf_range(segment_time.x, segment_time.y)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var toward := signf(player.global_position.x - global_position.x)
		if toward == 0.0:
			toward = _walk_dir
		_walk_dir = toward if randf() < toward_player_chance else -toward
	else:
		_walk_dir = -1.0 if randf() < 0.5 else 1.0
	_apply_walk_facing()


func _process_walk(delta: float) -> void:
	_segment_left -= delta
	if _segment_left <= 0.0:
		_pick_segment()
	_play_anim(&"Walk")
	# 什么时候起跳:有 Walk 帧就在动画回到第 0 帧时;没帧就按 hop_interval 定时
	var trigger := false
	if _has_anim(ani_2d, &"Walk") and ani_2d.animation == &"Walk":
		var f := ani_2d.frame
		if f == 0 and _last_walk_frame != 0:
			trigger = true
		_last_walk_frame = f
	else:
		_hop_wait += delta
		if _hop_wait >= hop_interval:
			_hop_wait = 0.0
			trigger = true
	if trigger and _hop_elapsed >= hop_duration:
		# 探地铁律:前面没地/有墙/出了巡逻范围就掉头再窜
		var next_x := global_position.x + _walk_dir * hop_distance
		if absf(next_x - _spawn_x) > wander_distance or not _floor_ahead() or _wall_ahead():
			_walk_dir = -_walk_dir
			_apply_walk_facing()
		_hop_from_x = global_position.x
		_hop_elapsed = 0.0
	if _hop_elapsed < hop_duration:
		# 正弦缓入缓出:用 tween 的插值公式算目标位置,再换算成速度交给 move_and_slide(撞墙会停)
		var before := Tween.interpolate_value(0.0, hop_distance, _hop_elapsed, hop_duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT) as float
		_hop_elapsed = minf(_hop_elapsed + delta, hop_duration)
		var after := Tween.interpolate_value(0.0, hop_distance, _hop_elapsed, hop_duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT) as float
		velocity.x = _walk_dir * (after - before) / maxf(delta, 0.0001)


func _apply_walk_facing() -> void:
	_face_towards(global_position.x + _walk_dir)
	for ray in [floor_ray, wall_ray]:
		if ray != null:
			ray.position.x = absf(ray.position.x) * _walk_dir
			ray.target_position.x = absf(ray.target_position.x) * _walk_dir


func _floor_ahead() -> bool:
	if floor_ray == null:
		return true
	floor_ray.force_raycast_update()
	return floor_ray.is_colliding()


func _wall_ahead() -> bool:
	if wall_ray == null:
		return false
	wall_ray.force_raycast_update()
	return wall_ray.is_colliding()


# ---- 召唤:Attack 动画出弹 ----
func _start_attack(player: Node2D) -> void:
	_phase = Phase.ATTACK
	_spat = false
	velocity.x = 0.0
	_face_towards(player.global_position.x)
	if _has_anim(ani_2d, &"Attack"):
		ani_2d.play(&"Attack")
	else:
		_spit()
		_enter_walk()
		_cooldown = attack_cooldown


func _spit() -> void:
	_spat = true
	var player := _get_detected_player()
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null or BULLET_SCENE == null or get_tree().current_scene == null:
		return
	# 满员就抛普通弹;没满就分裂:自己先减半,弹带着减半后的血量落地长出来
	var can_split := get_tree().get_nodes_in_group("splitter").size() < max_total
	var payload_hp := 0
	if can_split:
		health = maxi(1, health / 2)
		payload_hp = health
	var start := muzzle.global_position if muzzle != null else global_position + Vector2(0, -8)
	var dir_x := signf(player.global_position.x - global_position.x)
	if dir_x == 0.0:
		dir_x = -1.0
	var bullet := BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	if bullet.has_method("setup"):
		bullet.call("setup", start, dir_x, payload_hp, max_health)


# 素材默认朝左;朝右=两张贴图和炮口一起 x 镜像(物理本体不缩放)
func _face_towards(target_x: float) -> void:
	var flip: float = -1.0 if target_x > global_position.x else 1.0
	for spr in [ani_2d, spawn_sprite]:
		if spr != null:
			spr.scale.x = absf(spr.scale.x) * flip
	if muzzle != null:
		muzzle.position.x = absf(muzzle.position.x) * -flip


func take_damage(value: int) -> void:
	health = clampi(health - value, 0, max_health)
	if hit_effect_player != null:
		if not hit_effect_player.active:
			hit_effect_player.active = true
		hit_effect_player.play(&"HitFlash")
	if health <= 0:
		_spawn_death_effect()
		queue_free()


func _try_contact_damage() -> void:
	if _contact_cd > 0.0 or attack_check == null or not attack_check.monitoring:
		return   # 幼体转成体那一帧 monitoring 还是 set_deferred 的 off,查重叠会报错
	for body in attack_check.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", contact_damage)
			_contact_cd = contact_cooldown
		return


func _get_detected_player() -> Node2D:
	if player_check == null:
		return null
	for body in player_check.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body is Node2D:
			return body as Node2D
	return null


static func _has_anim(spr: AnimatedSprite2D, anim: StringName) -> bool:
	return spr != null and spr.sprite_frames != null \
		and spr.sprite_frames.has_animation(anim) \
		and spr.sprite_frames.get_frame_count(anim) > 0


func _play_anim(anim: StringName) -> void:
	if not _has_anim(ani_2d, anim):
		return
	if ani_2d.animation != anim or not ani_2d.is_playing():
		ani_2d.play(anim)


func _spawn_death_effect() -> void:
	if DEATH_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	var effect := DEATH_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true

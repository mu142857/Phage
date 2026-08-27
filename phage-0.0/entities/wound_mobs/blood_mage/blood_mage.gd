# 血法师(红法师)：徘徊输出的辅助怪，没有接触伤害。
# 行为循环：走到自己左侧 pace_distance(10px) → 施法 → 歇一会(cast_rest_time，
# 第一关别太咄咄逼人) → 走到右侧 10px → 施法 → 歇一会……
# 主角贴近(retreat_distance 内)时，这一步改成往主角反方向挪，然后照常施法。
# 不会主动走下平台：每步之前向前探地，前面是悬崖就换边，两边都不行原地施法。
# 施法按固定拍子循环：红、绿、绿、红、绿、绿……红弹只占 1/3 拍子。
# 空拍(绿拍没伤员/红拍主角不在范围)不出手但【占满一整拍的时长】——省下的
# 施法动画时间补进休息，保证"红空空/红绿绿/空绿绿"三种情况节奏完全一样：
#   绿弹——给 PlayerCheck 范围内掉血最多的怪物回血(追踪，回90，命中绿闪)；
#           绿弹是"额外的"：这拍没有伤员就空过，绝不会补成红弹。
#   红弹——攻击玩家。出手瞬间锁定玩家【当时】的位置直线飞：不追踪、不预判，
#           玩家保持移动就能躲。穿透障碍物飞出场外才消失。
# 翻转包括一切判定：AnimatedSprite2D 的 scale.x 取反 + Muzzle 镜像到另一侧。
# 动画名：Idle(站立/徘徊循环)、Attack(施法单次)。
extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/wound_mobs/blood_mage/blood_mage_death.tscn")
const ATTACK_BOLT_SCENE: PackedScene = preload("res://entities/wound_mobs/blood_mage/blood_mage_bolt.tscn")
const HEAL_BOLT_SCENE: PackedScene = preload("res://entities/wound_mobs/blood_mage/blood_mage_heal_bolt.tscn")

@export var max_health: int = 200
@export var health: int = 200
@export var gravity: float = 850.0
@export var knockback_speed: float = 120.0
@export var knockback_duration: float = 0.1
## 贴图默认面朝左(Muzzle 在左侧)；素材面朝右就取消勾选
@export var sprite_faces_left: bool = true

@export_group("Pace")
@export var walk_speed: float = 25.0       # 徘徊速度
@export var pace_distance: float = 10.0    # 每步挪多远
@export var retreat_distance: float = 30.0 # 主角近于这个距离→这步往反方向挪
@export var edge_probe_distance: float = 6.0  # 向前探地距离(防走下平台)

@export_group("Cast")
@export var cast_frame: int = 4            # Attack 动画的出手帧(0 起数)
@export var cast_rest_time: float = 1.4    # 每次施法后的 Idle 歇息时长

enum Phase { IDLE, PACE, CAST, REST }

var _phase: Phase = Phase.IDLE
var _pace_side: float = -1.0               # 下一步往哪边(左右交替)
var _target_x: float = 0.0
var _pace_timeout: float = 0.0
var _rest_timer: float = 0.0
var _cast_fired: bool = false
var _beat: int = 0                         # 施法拍子：0=红，1、2=绿，循环
var _cast_is_heal: bool = false            # 当前这手是不是绿弹
var _face_dir: float = -1.0
var _muzzle_base_x: float = 7.0
var _knock_left: float = 0.0
var _knock_vx: float = 0.0

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var muzzle: Node2D = get_node_or_null("Muzzle") as Node2D


func _ready() -> void:
	add_to_group("monster")
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	if muzzle != null:
		_muzzle_base_x = absf(muzzle.position.x)
	if ani_2d != null and ani_2d.material != null:
		ani_2d.material = ani_2d.material.duplicate()
		if ani_2d.material is ShaderMaterial:
			(ani_2d.material as ShaderMaterial).set_shader_parameter("Enabled", false)


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	_pace_timeout = maxf(0.0, _pace_timeout - delta)

	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		velocity.x = _knock_vx
		if _knock_left <= 0.0:
			velocity.x = 0.0
	else:
		match _phase:
			Phase.IDLE:
				velocity.x = 0.0
				_play_anim(&"Idle")
				# 主角在范围 或 有伤员要奶，都会进入拍子循环
				if _get_detected_player() != null or _find_heal_target() != null:
					_plan_next_step()
			Phase.PACE:
				_process_pace()
			Phase.CAST:
				velocity.x = 0.0
				_process_cast()
			Phase.REST:
				velocity.x = 0.0
				_play_anim(&"Idle")
				_rest_timer = maxf(0.0, _rest_timer - delta)
				if _rest_timer <= 0.0:
					if _get_detected_player() != null or _find_heal_target() != null:
						_plan_next_step()
					else:
						_phase = Phase.IDLE

	move_and_slide()


# ---- 徘徊 ----

# 定下一步：默认左右交替；主角贴近就往反方向；悬崖/走不了就换边；都不行原地施法
func _plan_next_step() -> void:
	var step_dir: float
	var player := _get_detected_player()
	if player != null and absf(player.global_position.x - global_position.x) <= retreat_distance:
		step_dir = signf(global_position.x - player.global_position.x)
		if step_dir == 0.0:
			step_dir = _pace_side
	else:
		step_dir = _pace_side
		_pace_side = -_pace_side
	if not _floor_ahead(step_dir):
		step_dir = -step_dir
	if not _floor_ahead(step_dir):
		_start_cast()
		return
	_target_x = global_position.x + step_dir * pace_distance
	_pace_timeout = 1.0  # 兜底：卡住也最多走 1 秒
	_face_dir = step_dir
	_apply_facing()
	_phase = Phase.PACE


func _process_pace() -> void:
	var dx: float = _target_x - global_position.x
	if absf(dx) <= 1.0 or _pace_timeout <= 0.0 or is_on_wall() \
			or not _floor_ahead(signf(dx)):
		velocity.x = 0.0
		_start_cast()
		return
	velocity.x = signf(dx) * walk_speed
	_play_anim(&"Idle")


# 向前下方打一条射线探地(只查世界层1)，探不到=前面是悬崖
func _floor_ahead(dir: float) -> bool:
	if dir == 0.0 or not is_on_floor():
		return true
	var space := get_world_2d().direct_space_state
	var origin: Vector2 = global_position + Vector2(dir * edge_probe_distance, -1.0)
	var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0.0, 6.0), 1)
	return not space.intersect_ray(query).is_empty()


# ---- 施法 ----

func _start_cast() -> void:
	# 固定拍子 红绿绿 循环：红弹只占 1/3。
	_cast_is_heal = _beat % 3 != 0
	_beat = (_beat + 1) % 3
	# 空拍：绿拍没伤员 / 红拍主角不在范围。不出手，但把施法动画的时长补进
	# 休息——空拍必须和实拍一样长，不然空拍一多节奏就变快(踩过的坑)
	var empty_beat: bool = (_cast_is_heal and _find_heal_target() == null) \
		or (not _cast_is_heal and _get_detected_player() == null)
	if empty_beat:
		_rest_timer = cast_rest_time + _attack_anim_duration()
		_phase = Phase.REST
		return
	var player := _get_detected_player()
	if player != null:
		var dx: float = player.global_position.x - global_position.x
		if dx != 0.0:
			_face_dir = signf(dx)
		_apply_facing()
	if ani_2d != null and ani_2d.sprite_frames != null \
			and ani_2d.sprite_frames.has_animation(&"Attack"):
		_phase = Phase.CAST
		_cast_fired = false
		ani_2d.play(&"Attack")
	else:
		# 没有 Attack 动画的兜底：直接出手接着走
		_fire()
		_after_cast()


func _process_cast() -> void:
	if not _cast_fired and ani_2d != null \
			and ani_2d.animation == &"Attack" and ani_2d.frame >= cast_frame:
		_cast_fired = true
		_fire()
	if ani_2d == null or not ani_2d.is_playing():
		_after_cast()


# 施法完不马上动，Idle 歇一会再走下一步(第一关，节奏放缓)
func _after_cast() -> void:
	_rest_timer = cast_rest_time
	_phase = Phase.REST


# Attack 动画的实际时长(帧数/帧率)，空拍用它补时长；没动画兜底 0.8s
func _attack_anim_duration() -> float:
	if ani_2d != null and ani_2d.sprite_frames != null \
			and ani_2d.sprite_frames.has_animation(&"Attack"):
		var frame_count := ani_2d.sprite_frames.get_frame_count(&"Attack")
		var anim_speed := ani_2d.sprite_frames.get_animation_speed(&"Attack")
		if anim_speed > 0.0:
			return float(frame_count) / anim_speed
	return 0.8


func _fire() -> void:
	if get_tree().current_scene == null:
		return
	var start: Vector2 = muzzle.global_position if muzzle != null else global_position
	if _cast_is_heal:
		# 出手瞬间再找一次目标(蓄力期间伤员可能死了，那就这手落空)
		var target := _find_heal_target()
		if target != null:
			var bolt := HEAL_BOLT_SCENE.instantiate()
			get_tree().current_scene.add_child(bolt)
			if bolt.has_method("setup"):
				bolt.call("setup", start, target)
		return
	_fire_attack_bolt(start)


func _fire_attack_bolt(start: Vector2) -> void:
	var player := _get_detected_player()
	if player == null:
		return
	var bolt := ATTACK_BOLT_SCENE.instantiate()
	get_tree().current_scene.add_child(bolt)
	if bolt.has_method("setup"):
		# 锁定玩家此刻的位置(半身高)，之后直线飞，不追踪不预判
		bolt.call("setup", start, player.global_position + Vector2(0, -4))


# PlayerCheck 范围内掉血最多的怪物(不含自己)；都满血返回 null
func _find_heal_target() -> Node2D:
	if player_check == null:
		return null
	var best: Node2D = null
	var best_deficit: int = 0
	for body in player_check.get_overlapping_bodies():
		if body == null or body == self or not body.is_in_group("monster"):
			continue
		if not ("health" in body and "max_health" in body):
			continue
		var deficit: int = int(body.max_health) - int(body.health)
		if deficit > best_deficit:
			best_deficit = deficit
			best = body as Node2D
	return best


# ---- 通用 ----

func take_damage(value: int) -> void:
	health = clampi(health - value, 0, max_health)
	if hit_effect_player != null:
		if not hit_effect_player.active:
			hit_effect_player.active = true
		hit_effect_player.play(&"HitFlash")
	_start_knockback()
	if health <= 0:
		_spawn_death_effect()
		queue_free()


func _start_knockback() -> void:
	if Game.suppress_hit_knockback:
		return  # 召唤物等软伤害:掉血但不位移
	var direction: float = -1.0
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		direction = signf(global_position.x - (players[0] as Node2D).global_position.x)
		if direction == 0.0:
			direction = -1.0
	_knock_left = knockback_duration
	_knock_vx = knockback_speed * direction


func _get_detected_player() -> Node2D:
	if player_check == null:
		return null
	for body in player_check.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body is Node2D:
			return body as Node2D
	return null


# 翻转=贴图镜像 + Muzzle 换到面朝的那一侧
func _apply_facing() -> void:
	var flip: float = _face_dir * (-1.0 if sprite_faces_left else 1.0)
	if flip == 0.0:
		flip = 1.0
	if ani_2d != null:
		ani_2d.scale.x = absf(ani_2d.scale.x) * flip
	if muzzle != null:
		muzzle.position.x = _muzzle_base_x * _face_dir


func _play_anim(anim: StringName) -> void:
	if ani_2d == null or ani_2d.sprite_frames == null:
		return
	if not ani_2d.sprite_frames.has_animation(anim):
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

# 喷射战士(sprayer,素材 2怪):挂在天花板上的喷雾口,定点、无接触伤害、血厚(600=20 刀)。
# 持续不断地喷浓雾弹(sprayer_fog),不瞄主角:方向 = 节点中心指向 Muzzle 的那条向量
# (Muzzle 放在正下方就是垂直往下喷,想斜着喷就把 Muzzle 挪一挪),在 ±spread_degrees 的扇形里撒,
# 中间密、两边稀(三个随机数取平均,天然中间多);每颗速度、大小、颜色都略有不同,出现时渐显。
# 空地上躲不掉——只有躲到蚯蚓身后,雾弹撞在蚯蚓身上就散了。
# hanging=true:不吃重力、不动(挂顶/贴墙);关掉就是站在地上的版本。
# 动画:喷的时候循环播 Attack,不喷时 Idle。贴图不旋转(渲染铁律),贴墙版另画帧。
extends CharacterBody2D

const FOG_SCENE: PackedScene = preload("res://entities/cradle_mobs/sprayer/sprayer_fog.tscn")
const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/cradle_mobs/sprayer/sprayer_death.tscn")

@export var max_health: int = 600
@export var health: int = 600
## 挂在天花板/墙上:不吃重力、不落地。关掉就是站在地上的版本。
@export var hanging: bool = true
@export var gravity: float = 850.0

@export_group("Spray")
## 只在主角进 PlayerCheck 时才喷;关掉 = 永远在喷(环境危害)
@export var only_when_player_near: bool = true
@export var linger_time: float = 1.5            # 主角离开范围后再喷这么久才停
## 侦测范围左右各多宽(像素)。0 = 用场景里 PlayerCheck 画的框。
## 要比雾柱宽很多:雾从顶上落到地面要 0.5~1.5 秒,主角冲刺 220 像素/秒,
## 侦测太窄的话主角冲进来时雾还没落地,等于白喷(实测 40 次只中 5 次)。
@export var detect_half_width: float = 0.0
@export var fogs_per_second: float = 10.0
@export var spread_degrees: float = 30.0        # 扇形半角(中间密两边稀)
@export var spawn_half_width: float = 8.0       # 出生点不是一个点,是枪口左右各这么宽的一条线(中间密两边稀)
@export var fog_speed: Vector2 = Vector2(30.0, 210.0)  # 每颗速度随机区间(又快又慢;最快的要能追上冲刺)
@export var fog_gravity: float = 45.0           # 雾弹吃一点重力,往下弯
@export var fog_size: Vector2 = Vector2(0.7, 1.7)      # 每颗大小随机区间(又大又小,1=3px)
@export var fog_color: Color = Color(0.78, 0.66, 0.9, 0.85)
@export var color_jitter: float = 0.12          # 颜色每通道 ±抖动

var _emit_acc := 0.0
var _spraying := false
var _linger_left := 0.0

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var player_check: Area2D = get_node_or_null("PlayerCheck") as Area2D
@onready var muzzle: Node2D = get_node_or_null("Muzzle") as Node2D


func _ready() -> void:
	add_to_group("monster")
	_apply_detect_width()
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	if ani_2d != null and ani_2d.material != null:
		ani_2d.material = ani_2d.material.duplicate()
		if ani_2d.material is ShaderMaterial:
			(ani_2d.material as ShaderMaterial).set_shader_parameter("Enabled", false)


# 侦测框按 detect_half_width 放宽(形状资源先复制,不影响别的实例)
func _apply_detect_width() -> void:
	if detect_half_width <= 0.0 or player_check == null:
		return
	var shape_node := player_check.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is RectangleShape2D):
		return
	var rect := (shape_node.shape as RectangleShape2D).duplicate() as RectangleShape2D
	rect.size.x = detect_half_width * 2.0
	shape_node.shape = rect
	shape_node.position.x = 0.0


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not hanging:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = 0.0
		move_and_slide()
	# 看到主角就喷,主角走了再喷 linger_time 秒才停
	if not only_when_player_near or _player_near():
		_linger_left = linger_time
	else:
		_linger_left = maxf(0.0, _linger_left - delta)
	_spraying = not only_when_player_near or _linger_left > 0.0
	_play_anim(&"Attack" if _spraying else &"Idle")
	if not _spraying:
		_emit_acc = 0.0
		return
	# 匀速持续出雾:按每秒颗数攒够一颗就喷一颗
	_emit_acc += fogs_per_second * delta
	while _emit_acc >= 1.0:
		_emit_acc -= 1.0
		_spawn_fog()


# 喷的方向 = 中心 → Muzzle
func _spray_dir() -> Vector2:
	if muzzle != null and muzzle.position != Vector2.ZERO:
		return muzzle.position.normalized()
	return Vector2.DOWN


func _spawn_fog() -> void:
	if FOG_SCENE == null or get_tree().current_scene == null:
		return
	var origin := muzzle.global_position if muzzle != null else global_position
	var base := _spray_dir()
	# 三个均匀随机取平均:钟形分布,中间密两边稀(角度和出生点各摇一次)
	var t := _bell()
	var dir := base.rotated(deg_to_rad(spread_degrees) * t)
	# 出生点沿着与喷射方向垂直的那条线摊开:枪口左右各 spawn_half_width 像素
	var side := Vector2(-base.y, base.x)
	# 出生点用两个随机数取平均(三角分布):比角度那个钟形平一点,两头 5 格也能铺到
	var start := origin + side * (spawn_half_width * ((randf() + randf()) - 1.0))
	var speed := randf_range(fog_speed.x, fog_speed.y)
	var size := randf_range(fog_size.x, fog_size.y)
	var col := Color(
		clampf(fog_color.r + randf_range(-color_jitter, color_jitter), 0.0, 1.0),
		clampf(fog_color.g + randf_range(-color_jitter, color_jitter), 0.0, 1.0),
		clampf(fog_color.b + randf_range(-color_jitter, color_jitter), 0.0, 1.0),
		fog_color.a)
	var fog := FOG_SCENE.instantiate()
	get_tree().current_scene.add_child(fog)
	if fog.has_method("setup"):
		fog.call("setup", start, dir, speed, size, col, fog_gravity)


# -1~1 的钟形随机(三个均匀随机取平均)
func _bell() -> float:
	return (randf() + randf() + randf()) / 3.0 * 2.0 - 1.0


func _player_near() -> bool:
	if player_check == null:
		return false
	for body in player_check.get_overlapping_bodies():
		if body != null and body.is_in_group("player"):
			return true
	return false


func take_damage(value: int) -> void:
	health = clampi(health - value, 0, max_health)
	if hit_effect_player != null:
		if not hit_effect_player.active:
			hit_effect_player.active = true
		hit_effect_player.play(&"HitFlash")
	if health <= 0:
		_spawn_death_effect()
		queue_free()


func _has_anim(anim: StringName) -> bool:
	return ani_2d != null and ani_2d.sprite_frames != null \
		and ani_2d.sprite_frames.has_animation(anim) \
		and ani_2d.sprite_frames.get_frame_count(anim) > 0


func _play_anim(anim: StringName) -> void:
	if not _has_anim(anim):
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

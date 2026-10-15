# 下水道帮小怪的公共底子(收钱小弟/刀仔/井盖盾兵/扔瓶子的/大块头/放哨的都从这儿派生)。
# 贴图朝右画,翻面 = AnimatedSprite2D 和 AttackCheck 的 scale.x 一起取反(判定跟着镜像)。
# 原点在脚底,贴图最后一行落在地面线上面一行。
# 状态:FALL(从天上掉下来)→ LAND(落地蹲一下)→ ENGAGE(各怪自己的打法,_engage 里写)
#      ATTACK(播一段攻击动画,hit_frames 那几帧用 AttackCheck 判定一次)/ CUSTOM(子类自己管)。
# 动画都是 10 帧/秒等长(奥斯卡的节奏),没导帧的动画名一律跳过不报错。
class_name GangMob
extends CharacterBody2D

signal died(mob: GangMob)

const DEATH_SCENE: PackedScene = preload("res://entities/gang/gang_death.tscn")
const FONT: FontFile = preload("res://asstes/fonts/PixelFont.ttf")
const BARK_COLOR := Color(0.95, 0.86, 0.78)

@export var max_health: int = 300
@export var gravity: float = 850.0
@export var move_speed: float = 30.0
## 离主角多远就开始找他(伏击巷是封闭的,默认整条巷子都算)
@export var aggro_range: float = 400.0
@export var attack_range: float = 22.0
@export var attack_cooldown: float = 1.2
@export var attack_anim: StringName = &"Attack"
## Attack 动画里哪几帧有判定(0 起数),一次攻击只打中一下
@export var hit_frames: PackedInt32Array = PackedInt32Array([7, 8])
@export var knockback_speed: float = 70.0
@export var knockback_duration: float = 0.1
## 大块头:挨打不后退
@export var heavy: bool = false
## 从屏幕上面掉下来出场
@export var drop_in: bool = false
## 空降时落在消防梯这种单向平台上(默认穿过去落到地面)
@export var land_on_platforms: bool = false
@export var edge_probe_distance: float = 8.0
## 前面往下落差不超过这么多就照走(从木托盘、箱子上走下来),再高就站住
@export var max_step_down: float = 14.0
## 死亡方块粒子数量(体型大就多给点)
@export var death_amount: int = 18
@export var death_height: float = 10.0
## 头顶冒字的高度
@export var bark_height: float = 26.0

enum S { FALL, LAND, ENGAGE, ATTACK, CUSTOM }

var state: S = S.ENGAGE
var health: int = 0
var facing: float = 1.0
var cooldown: float = 0.0
var _hit_done: bool = false
var _knock_left: float = 0.0
var _knock_vx: float = 0.0
var _once_anim: StringName = &""
var _once_then: Callable = Callable()
var _bark: Label = null
var _bark_tween: Tween = null
var _passed_platforms: Array = []

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var attack_check: Area2D = get_node_or_null("AttackCheck") as Area2D


func _ready() -> void:
	add_to_group("monster")
	add_to_group("gang")
	health = max_health
	if sprite.material != null:
		sprite.material = sprite.material.duplicate()
		if sprite.material is ShaderMaterial:
			(sprite.material as ShaderMaterial).set_shader_parameter("Enabled", false)
	sprite.animation_finished.connect(_on_animation_finished)
	_make_bark()
	var p := player()
	if p != null:
		face(signf(p.global_position.x - global_position.x))
	if drop_in:
		state = S.FALL
		play(&"Fall")
		if not land_on_platforms:
			_pass_platforms(true)
	else:
		_start()


## 子类:不是空降时一开场干什么(默认直接开打)
func _start() -> void:
	state = S.ENGAGE


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 420.0)
	cooldown = maxf(0.0, cooldown - delta)
	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		velocity.x = _knock_vx
		if _knock_left <= 0.0:
			velocity.x = 0.0
	else:
		match state:
			S.FALL:
				velocity.x = 0.0
				if is_on_floor():
					_land()
			S.LAND:
				velocity.x = 0.0
			S.ENGAGE:
				_engage(delta)
			S.ATTACK:
				_attack_tick(delta)
			S.CUSTOM:
				_custom_tick(delta)
	move_and_slide()


# ------------------------------------------------------------------ 出场
func _land() -> void:
	_pass_platforms(false)
	state = S.LAND
	_on_landed()
	play_once(&"Land", _after_land)


## 子类:落地那一下(大块头震屏)
func _on_landed() -> void:
	pass


## 子类:落地站稳以后(小弟先喊一声"交钱!")
func _after_land() -> void:
	state = S.ENGAGE


## 下落时穿过单向平台(drop_through_platform 那种 StaticBody2D),落地后恢复
func _pass_platforms(on: bool) -> void:
	if on:
		var scene := get_tree().current_scene
		if scene == null:
			return
		for n in scene.find_children("*", "StaticBody2D", true, false):
			if n.has_method("_drop"):
				add_collision_exception_with(n)
				_passed_platforms.append(n)
	else:
		for n in _passed_platforms:
			if is_instance_valid(n):
				remove_collision_exception_with(n)
		_passed_platforms.clear()


# ------------------------------------------------------------------ 打法(子类覆盖)
## 默认:走到跟前,冷却好了就打。
func _engage(_delta: float) -> void:
	var p := player()
	if p == null:
		velocity.x = 0.0
		play(&"Idle")
		return
	var dx := p.global_position.x - global_position.x
	if absf(dx) > aggro_range:
		velocity.x = 0.0
		play(&"Idle")
		return
	if absf(dx) > 2.0:
		face(signf(dx))
	if absf(dx) <= attack_range:
		velocity.x = 0.0
		if cooldown <= 0.0:
			start_attack()
		else:
			play(&"Idle")
		return
	walk(facing, move_speed)


func _custom_tick(_delta: float) -> void:
	pass


## 往 dir 走;前面没地就站住。前面贴着同伙就排队等着,不挤成一坨。
func walk(dir: float, speed: float, anim: StringName = &"Walk") -> void:
	if floor_ahead(dir) and not buddy_ahead(dir):
		velocity.x = dir * speed + _separation()
		play(anim)
	else:
		velocity.x = _separation()
		play(&"Idle")


## 正前方 gap 格以内有没有站在地上的同伙
func buddy_ahead(dir: float, gap: float = 10.0) -> bool:
	for n in get_tree().get_nodes_in_group("gang"):
		if n == self or not (n is GangMob):
			continue
		var m := n as GangMob
		var dx := (m.global_position.x - global_position.x) * dir
		if dx > 0.0 and dx < gap and absf(m.global_position.y - global_position.y) < 6.0:
			return true
	return false


## 叠在一起(掉在同一个地方)时慢慢错开
func _separation() -> float:
	var push := 0.0
	for n in get_tree().get_nodes_in_group("gang"):
		if n == self or not (n is Node2D):
			continue
		var dx := global_position.x - (n as Node2D).global_position.x
		if absf(dx) < 4.0:
			push += (1.0 if dx > 0.0 or (dx == 0.0 and get_instance_id() > n.get_instance_id()) else -1.0) * 12.0
	return push


# ------------------------------------------------------------------ 攻击
func start_attack(anim: StringName = &"") -> void:
	if anim == &"":
		anim = attack_anim
	state = S.ATTACK
	_hit_done = false
	velocity.x = 0.0
	_on_attack_started()
	play_once(anim, _end_attack)


func _on_attack_started() -> void:
	pass


func _attack_tick(_delta: float) -> void:
	velocity.x = 0.0
	if sprite.animation == attack_anim and sprite.frame in hit_frames:
		try_hit()


## 在 AttackCheck 里的主角挨一下(一次攻击只打一下)
func try_hit() -> bool:
	if _hit_done or attack_check == null:
		return false
	for body in attack_check.get_overlapping_bodies():
		if body != null and body.is_in_group("player") and body.has_method("take_damage"):
			body.call("take_damage", 1)
			_hit_done = true
			return true
	return false


func _end_attack() -> void:
	cooldown = attack_cooldown
	state = S.ENGAGE


# ------------------------------------------------------------------ 挨打 / 死
func take_damage(value: int) -> void:
	if health <= 0:
		return
	if _blocks(value):
		return
	health = maxi(health - value, 0)
	if hit_player != null:
		if not hit_player.active:
			hit_player.active = true
		hit_player.play(&"HitFlash")
	_on_hurt()
	if health <= 0:
		_die()
		return
	if not heavy:
		_knockback()


## 子类:要不要挡下这一刀(井盖盾兵)
func _blocks(_value: int) -> bool:
	return false


func _on_hurt() -> void:
	pass


func _knockback() -> void:
	if Game.suppress_hit_knockback:
		return
	var p := player()
	var dir := -facing
	if p != null:
		dir = signf(global_position.x - p.global_position.x)
		if dir == 0.0:
			dir = -facing
	_knock_left = knockback_duration
	_knock_vx = knockback_speed * dir


func _die() -> void:
	died.emit(self)
	var scene := get_tree().current_scene
	if scene != null and DEATH_SCENE != null:
		var fx := DEATH_SCENE.instantiate() as GPUParticles2D
		scene.add_child(fx)
		fx.global_position = global_position
		fx.amount = death_amount
		var mat := fx.process_material as ParticleProcessMaterial
		if mat != null:
			mat = mat.duplicate() as ParticleProcessMaterial
			mat.emission_shape_offset = Vector3(0.0, -death_height, 0.0)
			mat.emission_box_extents = Vector3(death_height * 0.5, death_height, 1.0)
			fx.process_material = mat
		fx.emitting = true
	queue_free()


# ------------------------------------------------------------------ 小工具
func player() -> Node2D:
	var list := get_tree().get_nodes_in_group("player")
	if list.is_empty():
		return null
	var p := list[0] as Node2D
	if p != null and p.get("is_dying") == true:
		return null
	return p


func face(dir: float) -> void:
	if dir == 0.0:
		return
	facing = signf(dir)
	sprite.scale.x = absf(sprite.scale.x) * facing
	if attack_check != null:
		attack_check.scale.x = absf(attack_check.scale.x) * facing
	_on_faced()


func _on_faced() -> void:
	pass


## 前下方探地(只查世界层 1),max_step_down 以内探不到 = 前面是坑/高台边
func floor_ahead(dir: float) -> bool:
	if not is_on_floor():
		return true
	var space := get_world_2d().direct_space_state
	var origin := global_position + Vector2(dir * edge_probe_distance, -1.0)
	var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0.0, max_step_down + 1.0), 1)
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


func has_anim(anim: StringName) -> bool:
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim) \
		and sprite.sprite_frames.get_frame_count(anim) > 0


func play(anim: StringName) -> void:
	if not has_anim(anim):
		return
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


## 播一遍(不循环的动画),播完调 then;没这段动画就下一帧直接调
func play_once(anim: StringName, then: Callable = Callable()) -> void:
	_once_anim = anim
	_once_then = then
	if has_anim(anim):
		sprite.play(anim)
		sprite.frame = 0
	else:
		_once_anim = &""
		if then.is_valid():
			then.call_deferred()


func _on_animation_finished() -> void:
	if sprite.animation != _once_anim or _once_anim == &"":
		return
	_once_anim = &""
	var then := _once_then
	_once_then = Callable()
	if then.is_valid():
		then.call()


func _make_bark() -> void:
	_bark = Label.new()
	_bark.add_theme_font_override("font", FONT)
	_bark.add_theme_font_size_override("font_size", 11)
	_bark.add_theme_color_override("font_color", BARK_COLOR)
	_bark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_bark.add_theme_constant_override("shadow_offset_x", 1)
	_bark.add_theme_constant_override("shadow_offset_y", 1)
	_bark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bark.size = Vector2(80, 12)
	_bark.position = Vector2(-40, -bark_height - 13.0)
	_bark.visible = false
	_bark.z_index = 30
	_bark.light_mask = 0
	# 字不吃灯光,场景压暗(CanvasModulate)会把它压成灰的:按压暗程度补回来,补到 0.9 左右不发光
	var k := 1.0
	var scene := get_tree().current_scene
	if scene != null:
		for c in scene.get_children():
			if c is CanvasModulate:
				k = clampf(0.9 / maxf((c as CanvasModulate).color.r, 0.2), 1.0, 3.0)
	_bark.modulate = Color(k, k, k, 1.0)
	add_child(_bark)


## 头顶冒一句(最多五六个字)
func bark(text: String, duration := 1.2) -> void:
	if _bark == null:
		return
	if is_instance_valid(_bark_tween):
		_bark_tween.kill()
	_bark.text = text
	_bark.modulate.a = 1.0
	_bark.visible = true
	_bark_tween = create_tween()
	_bark_tween.tween_interval(duration)
	_bark_tween.tween_property(_bark, "modulate:a", 0.0, 0.25)
	_bark_tween.tween_callback(func() -> void: _bark.visible = false)

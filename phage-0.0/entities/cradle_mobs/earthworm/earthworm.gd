# 蚯蚓:一步一步在地上来回走的活盾牌。它的作用是挡子弹——喷射战士的雾弹撞到它会散掉,
# 所以画在主角之上(z=11),主角跟着它走就有掩体。
# 巡逻像 wowen:一个左右范围,走到头 → Idle 停一会 → BeforeStep(前摇) → Step 循环一路走到另一头。
# 贴图本身画了尺蠖的伸缩(Step 第 0 帧头往前探 12px),所以第 0 帧看着也像挪了一截——那是画里的动作,
# 节点只在 move_frame 那一帧瞬移。step_frame_offsets 是可选的按帧贴图补偿(默认空=不补偿),用户试过觉得像往回缩。
# 踩地的危险区只有前脚那一小块:BeforeStep/Step 期间在 StepHitBox 那块地上画个标记,
# 踩下去前一帧变亮、踩下去那一帧闪白,别的地方一看就是安全的。
# Step 是循环动画,每循环一次算一步:
#   第 stomp_frame(0) 帧 = 踩下去:轻震屏 + 脚下粒子 + 这一帧 StepHitBox 有接触伤害;
#   第 move_frame(2) 帧 = 直接挪 step_distance(7px),不平滑。
# 默认打不死(invulnerable),打它只闪白。素材默认往右走,往左整体 x 镜像。
# 动画名:Idle(循环)、BeforeStep(单次)、Step(循环)。
extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/cradle_mobs/earthworm/earthworm_death.tscn")
const STOMP_EFFECT_SCENE: PackedScene = preload("res://entities/cradle_mobs/earthworm/earthworm_stomp.tscn")

@export var invulnerable: bool = true
@export var max_health: int = 500
@export var health: int = 500
@export var gravity: float = 850.0

@export_group("Patrol")
@export var patrol_distance: float = 60.0    # 出生点左右各多远(不用自定义范围时)
@export var use_custom_patrol_range: bool = false
@export var patrol_min_x: float = 0.0
@export var patrol_max_x: float = 0.0
@export var idle_time: float = 2.0           # 走到头停多久
@export var start_facing_right: bool = true

@export_group("Step")
@export var step_distance: float = 7.0       # 一步挪几像素(瞬移)
@export var move_frame: int = 2              # Step 的哪一帧挪(0 起数)
@export var stomp_frame: int = 0             # Step 的哪一帧踩下去(震屏+粒子+伤害)
@export var stomp_shake: float = 0.5
@export var step_fallback_interval: float = 0.4  # 没导 Step 帧时多久一步
## (可选)Step 每一帧贴图的 x 补偿,素材局部坐标,朝左自动镜像;空 = 不补偿。
## 曾按尾巴位置填过 [4,-1,5,0] 把尾巴钉住,实际看着像往回缩,用户不要,留着以后备用。
@export var step_frame_offsets: Array[float] = []

@export_group("DangerMark")
@export var mark_color: Color = Color(0.95, 0.35, 0.3, 0.35)      # 平时:淡红
@export var mark_warn_color: Color = Color(1.0, 0.55, 0.4, 0.85)  # 踩下去前一帧:亮
@export var mark_hit_color: Color = Color(1.0, 1.0, 1.0, 0.95)    # 踩下去那一帧:闪白
@export var mark_fade_time: float = 0.35                          # 标记出现/消失的渐变时长
@export var show_mark_frame: bool = true                          # 地上的红框(不要就关掉,只留感叹号)
@export var bang_color: Color = Color(0.95, 0.2, 0.2, 1.0)        # 感叹号颜色(1×5 像素,画在红框正上方)
@export var bang_gap: float = 1.0                                 # 感叹号底部离红框顶多少像素

@export_group("Contact")
@export var contact_damage: int = 10         # 数值对主角无意义,碰一下=一次破盾
@export var contact_cooldown: float = 0.6

enum Phase { IDLE, BEFORE_STEP, STEP }

var _phase: Phase = Phase.IDLE
var _timer := 0.0
var _dir := 1.0
var _min_x := 0.0
var _max_x := 0.0
var _contact_cd := 0.0
var _last_frame := -1
var _fallback_timer := 0.0
var _stop_pending := false      # 走到头了:把这一循环播完(回到直立的第 3 帧)再进 Idle,别在探头时硬切
var _mark_alpha := 0.0          # 危险区标记的显示程度 0~1(渐显渐隐)
var _base_offset_x := 0.0

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var step_hitbox: Area2D = get_node_or_null("StepHitBox") as Area2D
@onready var floor_ray: RayCast2D = get_node_or_null("FloorRay") as RayCast2D
@onready var wall_ray: RayCast2D = get_node_or_null("WallRay") as RayCast2D


func _ready() -> void:
	add_to_group("monster")
	add_to_group("earthworm")   # 雾弹撞到它会散
	z_index = maxi(z_index, 11)  # 盖在主角(z=10)上面,当掩体
	if step_hitbox != null:
		# 踩地判定必须开着监测,否则 _stomp 里查不到主角还会刷 "monitoring is off" 报错
		# (tscn 里被关过一次,这里兜底强开)
		step_hitbox.monitoring = true
	if use_custom_patrol_range:
		_min_x = minf(patrol_min_x, patrol_max_x)
		_max_x = maxf(patrol_min_x, patrol_max_x)
	else:
		_min_x = global_position.x - patrol_distance
		_max_x = global_position.x + patrol_distance
	_dir = 1.0 if start_facing_right else -1.0
	_apply_facing()
	if ani_2d != null:
		_base_offset_x = ani_2d.offset.x
	health = clampi(health, 0, max_health)
	if health <= 0:
		health = max_health
	if ani_2d != null and ani_2d.material != null:
		ani_2d.material = ani_2d.material.duplicate()
		if ani_2d.material is ShaderMaterial:
			(ani_2d.material as ShaderMaterial).set_shader_parameter("Enabled", false)
	_enter_idle()


# StepHitBox 里碰撞箱的中心(本体坐标;Area2D 靠 scale.x 镜像朝向)
func _hitbox_center() -> Vector2:
	if step_hitbox == null:
		return Vector2.ZERO
	var shape_node := step_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return step_hitbox.position
	return Vector2(shape_node.position.x * step_hitbox.scale.x, shape_node.position.y) + step_hitbox.position


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	_contact_cd = maxf(0.0, _contact_cd - delta)
	match _phase:
		Phase.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_enter_before_step()
		Phase.BEFORE_STEP:
			if not _has_anim(&"BeforeStep") or ani_2d.animation != &"BeforeStep" or not ani_2d.is_playing():
				_enter_step()
		Phase.STEP:
			_process_step(delta)
	move_and_slide()
	# 标记:准备走/在走时渐显,停下来渐隐
	var target := 0.0 if _phase == Phase.IDLE else 1.0
	_mark_alpha = move_toward(_mark_alpha, target, delta / maxf(mark_fade_time, 0.01))
	queue_redraw()


func _enter_idle() -> void:
	_phase = Phase.IDLE
	_timer = idle_time
	_set_frame_offset(0.0)
	_play_anim(&"Idle")


func _enter_before_step() -> void:
	# 出发前先决定方向:到头了/前面没地/有墙就掉头
	if not _can_step():
		_dir = -_dir
		_apply_facing()
	_phase = Phase.BEFORE_STEP
	_set_frame_offset(0.0)
	if _has_anim(&"BeforeStep"):
		ani_2d.play(&"BeforeStep")
	else:
		_enter_step()


func _enter_step() -> void:
	_phase = Phase.STEP
	_last_frame = -1
	_fallback_timer = 0.0
	_stop_pending = false
	if not step_frame_offsets.is_empty():
		_set_frame_offset(step_frame_offsets[0])  # 第 0 帧的补偿当帧就生效,别闪一下
	_play_anim(&"Step")


# Step 循环:按帧触发踩地/挪步;走不动了就回 Idle
func _process_step(delta: float) -> void:
	if _has_anim(&"Step") and ani_2d.animation == &"Step":
		var frame := ani_2d.frame
		if frame != _last_frame:
			# 帧跳变的那一刻才触发一次(同一帧停留多个物理帧不重复)
			if _stop_pending and frame == 0:
				# 上一循环发现走不动了,等动画转回第 0 帧(直立姿势播完)再停下,
				# Step 尾帧是直立、Idle 是趴着的拱,这样切过去是"放下身子"而不是往回缩一截
				_enter_idle()
				return
			if frame < step_frame_offsets.size():
				_set_frame_offset(step_frame_offsets[frame])
			if frame == stomp_frame:
				_stomp()
			if frame == move_frame:
				_take_step()
			_last_frame = frame
	else:
		# 没导 Step 帧的兜底:定时一步
		_fallback_timer += delta
		if _fallback_timer >= step_fallback_interval:
			_fallback_timer = 0.0
			_stomp()
			_take_step()


func _take_step() -> void:
	if not _can_step():
		if _has_anim(&"Step"):
			_stop_pending = true   # 有帧:播完这一循环再停
		else:
			_enter_idle()
		return
	global_position.x += _dir * step_distance


func _set_frame_offset(dx: float) -> void:
	if ani_2d != null:
		ani_2d.offset.x = _base_offset_x + dx


func _can_step() -> bool:
	var next_x := global_position.x + _dir * step_distance
	if next_x < _min_x or next_x > _max_x:
		return false
	if not _floor_ahead() or _wall_ahead():
		return false
	return true


# 踩下去:轻震屏 + 脚下粒子 + 这一刻 StepHitBox 里的主角挨一下
func _stomp() -> void:
	if stomp_shake > 0.0:
		Game.shake_camera(stomp_shake)
	_spawn_stomp_effect()
	if step_hitbox == null or contact_damage <= 0 or _contact_cd > 0.0:
		return
	for body in step_hitbox.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", contact_damage)
			_contact_cd = contact_cooldown
		return


func _apply_facing() -> void:
	# 素材默认往右;往左=贴图、踩地判定、探地探墙射线一起镜像(物理本体不缩放)
	var sx := 1.0 if _dir > 0.0 else -1.0
	if ani_2d != null:
		ani_2d.scale.x = absf(ani_2d.scale.x) * sx
	if step_hitbox != null:
		step_hitbox.scale.x = absf(step_hitbox.scale.x) * sx
	for ray in [floor_ray, wall_ray]:
		if ray != null:
			ray.position.x = absf(ray.position.x) * sx
			ray.target_position.x = absf(ray.target_position.x) * sx


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


func take_damage(value: int) -> void:
	if hit_effect_player != null:
		if not hit_effect_player.active:
			hit_effect_player.active = true
		hit_effect_player.play(&"HitFlash")
	if invulnerable:
		return
	health = clampi(health - value, 0, max_health)
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


func _spawn_stomp_effect() -> void:
	if STOMP_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	var effect := STOMP_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		# 踩的地方 = StepHitBox 里那个碰撞箱(Area2D 本身在原点,朝向靠它 scale.x 镜像,子节点的全局坐标已经算进去了)
		var at := global_position
		var shape_node := step_hitbox.get_node_or_null("CollisionShape2D") as Node2D if step_hitbox != null else null
		if shape_node != null:
			at = shape_node.global_position
		(effect as Node2D).global_position = Vector2(at.x, global_position.y)
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true


func _spawn_death_effect() -> void:
	if DEATH_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	var effect := DEATH_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true


# 危险区标记:只有 StepHitBox 那一小块地是会被踩的,画出来让人一眼看懂——
# 地上一个淡红小框(可关) + 框正上方一个 1×5 像素的红色"!"(像素画笔式,没有字体、没有黑影)
func _draw() -> void:
	if _mark_alpha <= 0.0 or step_hitbox == null or contact_damage <= 0:
		return
	var shape_node := step_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is RectangleShape2D):
		return
	var size: Vector2 = (shape_node.shape as RectangleShape2D).size
	var rect := Rect2(_hitbox_center() - size * 0.5, size)
	var color := mark_color
	var bang := bang_color
	if _phase == Phase.STEP and _has_anim(&"Step") and ani_2d.animation == &"Step":
		var f := ani_2d.frame
		var frames := ani_2d.sprite_frames.get_frame_count(&"Step")
		if f == stomp_frame:
			color = mark_hit_color
			bang = Color(1, 1, 1, 1)
		elif (f + 1) % frames == stomp_frame:
			color = mark_warn_color
	color.a *= _mark_alpha
	bang.a *= _mark_alpha
	if show_mark_frame:
		# 地上那块:半透填充 + 1px 描边,再往地里压一行让它像"地面在发红"
		var ground := Rect2(rect.position.x, 0.0, rect.size.x, 1.0)
		draw_rect(ground, color)
		var fill := color
		fill.a *= 0.35
		draw_rect(rect, fill)
		draw_rect(rect, color, false, 1.0)
	# "!":锁到整数格,横向居中在框上,竖线 3 格 + 空 1 格 + 点 1 格,底部离框顶 bang_gap
	var bx := floorf(rect.position.x + rect.size.x * 0.5)
	var bottom := floorf(rect.position.y - bang_gap)
	draw_rect(Rect2(bx, bottom - 5.0, 1.0, 3.0), bang)
	draw_rect(Rect2(bx, bottom - 1.0, 1.0, 1.0), bang)

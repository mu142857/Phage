# 长虫(虫墙):立在路中间的活路障,整面都是它的身体。
# 主角打它只会硬邦邦地闪一下(不掉血,打不动);碰到身体有接触伤害。
# 只有弹幕葵的大弹能打碎它(hits_to_break 发,默认 1)。碎了同一次运行内不复活
# (MapElementCounting 记账,和周一的触手路障同一套),切场景不刷新。
# 动画名:Idle(循环);可选 Break(碎掉那一下,没有就直接粒子)。
extends CharacterBody2D

const DEATH_EFFECT_SCENE: PackedScene = preload("res://entities/cradle_mobs/worm_wall/worm_wall_death.tscn")

@export var contact_damage: int = 10
@export var contact_cooldown: float = 0.6
## 接触判定比实体碰撞箱每边宽出多少像素:实体会把主角挡在墙面外面,两个箱子一样大就永远碰不上,
## 所以运行时把 AttackCheck 的矩形自动撑宽这么多(你在编辑器里画的尺寸不用管这个)。
@export var contact_margin: float = 2.0
## 被弹幕葵的大弹打几发才碎
@export var hits_to_break: int = 1
## 碎了这次运行内不复活(重进房间不刷新)
@export var persist_break: bool = true
## 主角打它时的"叮"一下反馈:小震屏(0=不震)
@export var immune_shake: float = 0.25

var _hits := 0
var _contact_cd := 0.0
var _broken := false
var _persist_id: StringName = &""

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_effect_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var attack_check: Area2D = get_node_or_null("AttackCheck") as Area2D


func _ready() -> void:
	if persist_break:
		_persist_id = _make_persist_id()
		if not MapElementCounting.is_wall_intact(_persist_id):
			queue_free()
			return
	add_to_group("monster")
	add_to_group("worm_wall")
	_widen_contact_box()
	if ani_2d != null and ani_2d.material != null:
		ani_2d.material = ani_2d.material.duplicate()
		if ani_2d.material is ShaderMaterial:
			(ani_2d.material as ShaderMaterial).set_shader_parameter("Enabled", false)
	_play_anim(&"Idle")


func _physics_process(delta: float) -> void:
	if _broken:
		return
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_try_contact_damage()


## 主角的攻击:打不动,只闪白+轻震当反馈
func take_damage(_value: int) -> void:
	if _broken:
		return
	_flash()
	if immune_shake > 0.0:
		Game.shake_camera(immune_shake)


## 弹幕葵的大弹打中(由 anemone_bullet 调用)
func hit_by_anemone() -> void:
	if _broken:
		return
	_hits += 1
	_flash()
	if _hits >= hits_to_break:
		_break()
	else:
		Game.shake_camera(1.0)


func _break() -> void:
	_broken = true
	if _persist_id != &"":
		MapElementCounting.mark_wall_broken(_persist_id)
	Game.shake_camera(2.0)
	_spawn_death_effect()
	if _has_anim(&"Break"):
		collision_layer = 0
		if attack_check != null:
			attack_check.set_deferred("monitoring", false)
		ani_2d.play(&"Break")
		await ani_2d.animation_finished
	queue_free()


# 主角被实体挡在墙面外,接触判定必须比实体宽一圈才碰得到:
# 矩形直接加宽;手画的多边形把每个顶点按离中线的方向往外推 contact_margin(只推左右,不动上下)。
func _widen_contact_box() -> void:
	if attack_check == null or contact_margin <= 0.0:
		return
	for child in attack_check.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape is RectangleShape2D:
			var rect := ((child as CollisionShape2D).shape as RectangleShape2D).duplicate() as RectangleShape2D
			rect.size.x += contact_margin * 2.0
			(child as CollisionShape2D).shape = rect
		elif child is CollisionPolygon2D:
			var poly: CollisionPolygon2D = child
			var pts: PackedVector2Array = poly.polygon
			if pts.size() < 3:
				continue
			# 自交/退化的多边形 Godot 建不出碰撞,接触伤害会静悄悄失效——踩过:多画了一个压在底边上的顶点
			if Geometry2D.triangulate_polygon(pts).is_empty():
				push_warning("%s: AttackCheck 的多边形自交或退化(常见是多了一个压在边上的顶点),碰撞建不出来,接触伤害不会生效" % name)
				continue
			var cx := 0.0
			for pt in pts:
				cx += pt.x
			cx /= float(pts.size())
			var grown := PackedVector2Array()
			for pt in pts:
				var side := signf(pt.x - cx)
				grown.append(Vector2(pt.x + side * contact_margin, pt.y))
			poly.polygon = grown


func _try_contact_damage() -> void:
	if _contact_cd > 0.0 or attack_check == null:
		return
	for body in attack_check.get_overlapping_bodies():
		if body == null or not body.is_in_group("player"):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", contact_damage)
			_contact_cd = contact_cooldown
		return


func _flash() -> void:
	if hit_effect_player != null:
		if not hit_effect_player.active:
			hit_effect_player.active = true
		hit_effect_player.play(&"HitFlash")


# 按"场景+节点名+坐标"自动生成唯一记账ID
func _make_persist_id() -> StringName:
	var scene_path: String = "unknown"
	if get_tree().current_scene != null:
		scene_path = get_tree().current_scene.scene_file_path
	return StringName("%s/%s@%d,%d" % [scene_path, name,
		roundi(global_position.x), roundi(global_position.y)])


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

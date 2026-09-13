# 分身弹:抛物线抛出去,只有 Flying 一个动画。
# 落到地面(接触的那一刻正下方几像素内有地) → 就地生成一只分身(它自己接着播 Spawn),子弹消失;
# 撞到左右的墙 → 只爆炸不生成;碰主角 → 炸(一次破盾)不生成;场上满员/没带血量 → 落地也只爆。
# 子弹铁律:出屏用 ScreenNotifier 删,寿命到了渐隐。setup(start_pos, dir_x, payload_hp, max_hp)
extends Area2D

# 分身本体场景不能 preload——splitter.tscn 又 preload 了本弹,循环引用会拿到 null,落地时再 load
const SPLITTER_SCENE_PATH := "res://entities/cradle_mobs/splitter/splitter.tscn"
const EXPLOSION_EFFECT_SCENE: PackedScene = preload("res://entities/cradle_mobs/splitter/splitter_bullet_explosion.tscn")

@export var damage_amount: int = 6
@export var horizontal_speed: float = 40.0
@export var launch_up_speed: float = 75.0
@export var fall_gravity: float = 230.0
@export var lifetime: float = 5.0
@export var explode_shake: float = 1.2
@export var wall_arm_time: float = 0.2
@export var max_total: int = 8
@export var floor_probe: float = 4.0     # 落地判定:正下方多少像素内有地才算"落地"

var _dir := -1.0
var _vy := 0.0
var _payload_hp := 0
var _max_hp := 300
var _active := false
var _done := false
var _fading := false
var _elapsed := 0.0

@onready var ani_2d: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	if ani_2d != null and ani_2d.sprite_frames != null and ani_2d.sprite_frames.has_animation(&"Flying") \
			and ani_2d.sprite_frames.get_frame_count(&"Flying") > 0:
		ani_2d.play(&"Flying")
	var notifier := get_node_or_null("ScreenNotifier") as VisibleOnScreenNotifier2D
	if notifier != null:
		notifier.screen_exited.connect(queue_free)


func setup(start_pos: Vector2, dir_x: float, payload_hp: int, max_hp: int) -> void:
	global_position = start_pos
	_dir = signf(dir_x)
	if _dir == 0.0:
		_dir = -1.0
	_payload_hp = payload_hp
	_max_hp = max_hp
	_vy = -launch_up_speed
	_active = true
	if ani_2d != null:
		ani_2d.flip_h = _dir > 0.0


func _physics_process(delta: float) -> void:
	if not _active or _done:
		return
	_vy += fall_gravity * delta
	global_position += Vector2(_dir * horizontal_speed, _vy) * delta
	if _fading:
		return
	_elapsed += delta
	_check_touch()
	if _elapsed >= lifetime:
		_start_fade_out()


func _start_fade_out() -> void:
	_fading = true
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _check_touch() -> void:
	for body in get_overlapping_bodies():
		if body == null:
			continue
		if body.is_in_group("player"):
			_explode(true)
			return
		if body.is_in_group("monster"):
			continue
		if _elapsed < wall_arm_time:
			continue
		if _vy > 0.0 and _ground_below():
			_land()
		else:
			_explode(false)
		return


# 正下方 floor_probe 像素内有世界碰撞 = 落在地上;否则就是撞墙
func _ground_below() -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, floor_probe), 1)
	return not space.intersect_ray(query).is_empty()


# 落地:能长就当场生成分身(它自己播 Spawn),不能长就炸
func _land() -> void:
	var total := get_tree().get_nodes_in_group("splitter").size()
	if _payload_hp <= 0 or total >= max_total:
		_explode(false)
		return
	_done = true
	set_deferred("monitoring", false)
	var scene := get_tree().current_scene
	var splitter_scene := load(SPLITTER_SCENE_PATH) as PackedScene
	if scene != null and splitter_scene != null:
		var clone := splitter_scene.instantiate()
		clone.set("spawned_from_bullet", true)
		clone.set("max_health", _max_hp)
		clone.set("health", _payload_hp)
		scene.add_child(clone)
		clone.global_position = global_position
	queue_free()


func _explode(hit_player: bool) -> void:
	if _done:
		return
	_done = true
	set_deferred("monitoring", false)
	Game.shake_camera(explode_shake)
	_spawn_explosion_effect()
	if hit_player:
		for body in get_overlapping_bodies():
			if body != null and body.is_in_group("player") and body.has_method("take_damage"):
				body.call("take_damage", damage_amount)
				break
	queue_free()


func _spawn_explosion_effect() -> void:
	if EXPLOSION_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	var effect := EXPLOSION_EFFECT_SCENE.instantiate()
	get_tree().current_scene.add_child(effect)
	if effect is Node2D:
		(effect as Node2D).global_position = global_position
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true

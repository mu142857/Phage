# res://entities/spider_egg/spider_egg.gd
# 蜘蛛的伪装:格林之子式常驻仆从。有 buff 就一直陪着(player 负责生成/收回),
# 出场从主角身上弹出来(缩放 tween),漂浮跟在身后,朝射程内最近的怪快速吐弹。
# 每发伤害 = 开火瞬间主角攻击力的 1/4(破盾时它也跟着变痛)。
# 不需要碰撞体:它不承伤也不挡路,Node2D 就够。
extends Node2D

const BULLET_SCENE: PackedScene = preload("res://entities/spider_egg/spider_egg_bullet.tscn")

@export var fire_interval: float = 0.4
@export var fallback_damage: int = 22   # 拿不到主角时的保底伤害(=有盾一发 90/4)
@export var target_range: float = 90.0
@export var follow_offset: Vector2 = Vector2(-12, -14)  # 主角身后偏上
@export var follow_lerp: float = 5.0
@export var bob_amplitude: float = 1.5
@export var bob_speed: float = 4.0
@export var pop_time: float = 0.35      # 出场的缩放弹出时长
@export var fade_time: float = 0.4      # 被放下时的淡出时长

var _player: Player = null
var _fire_cooldown: float = 0.0
var _bob: float = 0.0
var _despawning: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_sprite.play(&"Float")


## 从主角身上弹出来:起点在主角中心,缩放 0 → 1,跟随 lerp 会自己飘到身后位。
func setup(player: Player) -> void:
	_player = player
	global_position = player.global_position
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## buff 被放下:淡出并消失。
func despawn() -> void:
	if _despawning:
		return
	_despawning = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_bob += delta * bob_speed
	_follow(delta)
	if _despawning:
		return
	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		var target := _nearest_monster()
		if target != null:
			_shoot(target)
			_fire_cooldown = fire_interval


# 跟随主角身后(随朝向换边),加一点上下浮动。
func _follow(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var target := _player.global_position \
		+ Vector2(follow_offset.x * float(_player.facing_direction), follow_offset.y) \
		+ Vector2(0.0, sin(_bob) * bob_amplitude)
	global_position = global_position.lerp(target, minf(1.0, follow_lerp * delta))


func _nearest_monster() -> Node2D:
	var best: Node2D = null
	var best_distance := target_range * target_range
	for node in get_tree().get_nodes_in_group("monster"):
		var monster := node as Node2D
		if monster == null or not is_instance_valid(monster):
			continue
		var distance := global_position.distance_squared_to(monster.global_position)
		if distance < best_distance:
			best_distance = distance
			best = monster
	return best


func _shoot(target: Node2D) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var damage := fallback_damage
	if is_instance_valid(_player):
		damage = maxi(1, _player.snapshot_attack_power() / 4)
	var bullet := BULLET_SCENE.instantiate() as Area2D
	scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.call("setup", target.global_position - global_position, damage)

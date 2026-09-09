# =============================================================================
# wooden_man.gd  —  木头人(人偶)本体：木偶师(puppeteer.gd)派下来的棋子
# =============================================================================
# 血不在这：打到它 → 转给木偶师扣血；它自己只管闪白、动作、判定。
# 一只人偶的一生：
#   Descend(3) 从屏幕顶飘下来 → Idle(1) 吊着晃 → 问木偶师下一招
#   → ToBlade(5) 变刀哥 → Slash(6) 落地冲砍 N 刀 → Vanish(4) 化开
#   → ToEye(7) 变激光眼 → Laser(8) 横扫激光 → Vanish(4) 化开
#   化开后木偶师再放一只新的下来(Descend)。二阶段左右各一只(木偶师管槽位)。
#   Death(2) 木偶师血空：线断、掉地、炸方块粒子。
#
# 素材约定(用户导帧)：原生朝右(刀光往右)；朝左 = AnimatedSprite2D + SlashHitbox
# 的 scale.x 一起取反、EyePoint x 镜像；物理本体不缩放。
# 动画名：Idle / ToBlade / BladeIdle / BladeMove / Slash / ToEye / EyeIdle
# (所有 play 都有 has_animation 守卫，没导帧也不报错，流程靠计时器兜底)
# =============================================================================
extends CharacterBody2D

const STATE_NULL: int = 0
const STATE_IDLE: int = 1
const STATE_DEATH: int = 2
const STATE_DESCEND: int = 3
const STATE_VANISH: int = 4
const STATE_TO_BLADE: int = 5
const STATE_SLASH: int = 6
const STATE_TO_EYE: int = 7
const STATE_LASER: int = 8

const FORM_BLANK: StringName = &"Blank"  # 无脸(吊在手上)
const FORM_BLADE: StringName = &"Blade"  # 刀哥
const FORM_EYE: StringName = &"Eye"      # 激光眼

# 素材是「手在头顶正上方」的整张画：手顶贴屏幕顶时脚就在地面附近，
# 所以吊着 = 脚离地几格晃(不是飘在半空)。
@export var hover_y: float = 76.0      # 吊着时脚底的高度(手顶正好贴屏幕顶)
@export var spawn_y: float = -15.0     # 从这个高度飘下来(整张贴图在屏外)
@export var floor_y: float = 80.0
@export var bound_min_x: float = 20.0
@export var bound_max_x: float = 140.0
@export var death_effect_scene: PackedScene = preload("res://entities/wooden_man/wooden_man_death.tscn")

var puppeteer: Node = null          # 木偶师(血/阶段/决策都在它那)
var slot_x: float = 80.0            # 木偶师分配的悬停 x
var facing: int = 1                 # 1=朝右(素材原生) / -1=朝左
var form: StringName = FORM_BLANK
var hittable: bool = true
var current_state_id: int = 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash_hitbox: Area2D = $SlashHitbox
@onready var eye_point: Node2D = $EyePoint

var _eye_point_base_x: float = 0.0


func _ready() -> void:
	add_to_group("monster")
	velocity = Vector2.ZERO
	_eye_point_base_x = eye_point.position.x
	if sprite.material is ShaderMaterial:
		(sprite.material as ShaderMaterial).set_shader_parameter("Enabled", false)
	slash_hitbox.monitoring = false
	if puppeteer == null and get_parent() != null and get_parent().has_method("register_puppet"):
		get_parent().call("register_puppet", self)


# =============================================================================
# 受伤：转给木偶师
# =============================================================================
func take_damage(value: int) -> void:
	if not hittable:
		return
	if has_node("HitEffectPlayer"):
		$HitEffectPlayer.play("HitFlash")
	if puppeteer != null and puppeteer.has_method("take_damage"):
		puppeteer.call("take_damage", value)


func change_state(state_id: int) -> void:
	current_state_id = state_id
	if has_node("StateMachine"):
		$StateMachine.change_state(state_id)


# =============================================================================
# 朝向：贴图 + 刀判定一起镜像，眼睛出光点 x 镜像
# =============================================================================
func set_facing(dir: int) -> void:
	facing = 1 if dir >= 0 else -1
	sprite.scale.x = absf(sprite.scale.x) * float(facing)
	slash_hitbox.scale.x = absf(slash_hitbox.scale.x) * float(facing)
	eye_point.position.x = _eye_point_base_x * float(facing)


func face_player() -> void:
	var player := get_player()
	if player == null:
		return
	set_facing(1 if player.global_position.x >= global_position.x else -1)


func play_anim(anim: StringName) -> void:
	if anim == &"" or sprite.sprite_frames == null:
		return
	if has_anim(anim):
		sprite.play(anim)


# 有这个动画且真的导了帧(tscn 里预建的空动画名不算,否则 animation_finished 永远不来)
func has_anim(anim: StringName) -> bool:
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim) \
			and sprite.sprite_frames.get_frame_count(anim) > 0


# =============================================================================
# 与木偶师的往来
# =============================================================================
func get_next_attack_state() -> int:
	if puppeteer != null and puppeteer.has_method("next_attack_for"):
		return int(puppeteer.call("next_attack_for", self))
	return STATE_IDLE


func idle_time() -> float:
	if puppeteer != null and puppeteer.has_method("idle_time_for"):
		return float(puppeteer.call("idle_time_for", self))
	return 2.0


func on_attack_finished() -> void:
	if puppeteer != null and puppeteer.has_method("on_puppet_attack_finished"):
		puppeteer.call("on_puppet_attack_finished", self)


func on_vanished() -> void:
	if puppeteer != null and puppeteer.has_method("on_puppet_vanished"):
		puppeteer.call("on_puppet_vanished", self)


# 木偶师放一只新的下来(同一节点复用)：回到无脸形态，从屏幕顶飘下
func respawn(at_x: float) -> void:
	slot_x = clampf(at_x, bound_min_x, bound_max_x)
	form = FORM_BLANK
	modulate.a = 1.0
	velocity = Vector2.ZERO
	global_position = Vector2(slot_x, spawn_y)
	change_state(STATE_DESCEND)


func spawn_death_effect() -> void:
	if death_effect_scene == null or get_tree().current_scene == null:
		return
	var fx := death_effect_scene.instantiate()
	get_tree().current_scene.add_child(fx)
	if fx is Node2D:
		(fx as Node2D).global_position = global_position
	if fx is GPUParticles2D:
		(fx as GPUParticles2D).emitting = true


func get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty() and players[0] is Node2D:
		return players[0] as Node2D
	return null

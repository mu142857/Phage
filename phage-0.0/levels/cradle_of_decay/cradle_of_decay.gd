# res://levels/cradle_of_decay/cradle_of_decay.gd
extends Node2D

@export var actinos_scene: PackedScene = preload("res://entities/actinos/actinos.tscn")
@export var spawn_position: Vector2 = Vector2(80.0, 0.0)
@export var land_y: float = 80.0
@export var drop_duration: float = 0.1

@export var light_shake: float = 0.3
@export var medium_shake: float = 0.6
@export var heavy_shake: float = 1.0
@export var light_duration: float = 1.5
@export var medium_duration: float = 1.5
@export var heavy_duration: float = 1.0
@export var pause_duration: float = 0.4

@export var intro_lock_player: bool = false
@export var start_battlecry_state: bool = true
@export var landing_effect_offset: Vector2 = Vector2(0.0, 6.0)

const ACTINOS_JUMP_EFFECT: PackedScene = preload("res://entities/actinos/actinos_jump_effect.tscn")

var actinos_instance: CharacterBody2D = null

func _ready() -> void:
	pass

func _start_intro() -> void:
	if intro_lock_player:
		_set_player_lock(true)

	await _shake_sequence()
	if not is_inside_tree():
		return
	_spawn_actinos()
	await _drop_actinos()

	if start_battlecry_state:
		_start_battlecry()

func _shake_sequence() -> void:
	await _do_shake(light_shake, light_duration)
	if not is_inside_tree():
		return
	await get_tree().create_timer(pause_duration).timeout
	await _do_shake(medium_shake, medium_duration)
	if not is_inside_tree():
		return
	await get_tree().create_timer(pause_duration).timeout
	await _do_shake(heavy_shake, heavy_duration)

# 场景可能在演出中途被切走(通关/死亡),每次 await 回来都要确认自己还在树里
func _do_shake(amount: float, duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		if not is_inside_tree():
			return
		Game.shake_camera(amount)
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func _spawn_actinos() -> void:
	if actinos_scene == null:
		return
	actinos_instance = actinos_scene.instantiate() as CharacterBody2D
	if actinos_instance == null:
		return
	add_child(actinos_instance)
	# boss 是运行时才生成的,DreamEnd 盯不到,在这儿挂"死亡=梦完成"
	actinos_instance.tree_exited.connect(func() -> void: Story.complete_dream())
	actinos_instance.global_position = spawn_position
	var sprite := actinos_instance.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if is_instance_valid(sprite):
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"Fall"):
			sprite.play(&"Fall")
		else:
			sprite.play(&"Jump")

func _drop_actinos() -> void:
	if actinos_instance == null:
		return
	var target := Vector2(spawn_position.x, land_y)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(actinos_instance, "global_position", target, drop_duration)
	await tween.finished
	_spawn_landing_effect()

func _start_battlecry() -> void:
	if actinos_instance == null:
		return
	Game.stop_shake()
	if intro_lock_player:
		_set_player_lock(false)
	# 字卡(头衔+名字)交给 BossIntro,播完它会亮血条并把状态机切进战斗
	var intro := get_node_or_null("BossIntro")
	if intro != null and intro.has_method("play_for"):
		await intro.play_for(actinos_instance)
		return
	# 兜底:没挂 BossIntro 就按旧路子直接开战吼
	var state_machine := actinos_instance.get_node_or_null("StateMachine")
	if state_machine != null and state_machine.has_method("change_state"):
		state_machine.call("change_state", 4)

func _spawn_landing_effect() -> void:
	if ACTINOS_JUMP_EFFECT == null:
		return
	var effect := ACTINOS_JUMP_EFFECT.instantiate()
	if effect == null:
		return
	add_child(effect)
	if actinos_instance != null:
		effect.global_position = actinos_instance.global_position + landing_effect_offset
	if effect is GPUParticles2D:
		(effect as GPUParticles2D).emitting = true

func _set_player_lock(locked: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0]
	if player.has_method("set_lock"):
		player.call("set_lock", locked)


func _on_timer_timeout() -> void:
	# 入梦字卡在播时,等它演完(它结束会 queue_free 自己)再放 boss 出场
	var dream_intro := get_node_or_null("DreamIntro")
	if dream_intro != null:
		await dream_intro.tree_exited
	call_deferred("_start_intro")

extends CharacterBody2D

@export var max_health: int = 6500
@export var health: int = 6500
@export var idle_only: bool = false # 调试用：生成后保持Idle
@export var health_ui_fade_duration: float = 0.25
@export var health_ui_base_alpha: float = 0.485
@export var health_ui_hit_flash_alpha: float = 1.0
@export var health_ui_hit_flash_in_duration: float = 0.05
@export var health_ui_hit_flash_out_duration: float = 0.12

const STATE_IDLE: int = 1
const STATE_JUMP_ATTACK: int = 2
const STATE_SPIKE_ATTACK: int = 3
const STATE_BATTLECRY: int = 4

const PHASE_NORMAL: int = 0
const PHASE_HALF: int = 1
const PHASE_QUARTER: int = 2

var direct: int = 1 # 1 = facing right, -1 = facing left
var phase: int = PHASE_NORMAL
var battlecry_done_50: bool = false
var battlecry_done_25: bool = false
var pending_battlecry: int = 0
var jump_remaining: int = 0
var spike_remaining: int = 0
var current_mode: String = "jump"
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var initial_battlecry_shown: bool = false
var health_ui_tween: Tween = null
var health_ui_flash_tween: Tween = null
@onready var health_bar: TextureProgressBar = get_node_or_null("CanvasLayer/HealthBar")
@onready var health_label: RichTextLabel = get_node_or_null("CanvasLayer/HealthLabel")

func _ready() -> void:
	velocity = Vector2.ZERO
	add_to_group("monster")
	if health <= 0:
		health = max_health
	health = clampi(health, 0, max_health)
	rng.randomize()
	phase = _calc_phase()
	_update_phase()
	# 初始隐藏血条和数值，等首个 Battlecry 结束再显示
	if health_bar != null:
		health_bar.visible = false
		health_bar.modulate.a = 0.0
	if health_label != null:
		health_label.visible = false
		health_label.modulate.a = 0.0
	_setup_health_ui()
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.material is ShaderMaterial:
		var shader_mat := sprite.material as ShaderMaterial
		shader_mat.set_shader_parameter("Enabled", false)
	if has_node("StateMachine"):
		$StateMachine.set_process(true)
		$StateMachine.set_physics_process(true)

func change_state(state_id: int) -> void:
	if has_node("StateMachine"):
		$StateMachine.change_state(state_id)

func take_damage(value: int) -> void:
	health -= value
	health = clampi(health, 0, max_health)
	_update_health_ui()
	_flash_health_ui_on_hit()
	_update_phase()
	if has_node("HitEffectPlayer"):
		if not $HitEffectPlayer.active:
			$HitEffectPlayer.active = true
		$HitEffectPlayer.play("HitFlash")
	if health <= 0:
		if has_node("StateMachine"):
			$StateMachine.change_state(5)

func face_left() -> void:
	direct = -1

func face_right() -> void:
	direct = 1

func get_next_attack_state() -> int:
	_update_phase()
	if pending_battlecry > 0:
		pending_battlecry -= 1
		return STATE_BATTLECRY
	if current_mode == "jump":
		if jump_remaining <= 0:
			jump_remaining = _roll_jump_count()
		return STATE_JUMP_ATTACK
	if spike_remaining <= 0:
		spike_remaining = _roll_spike_count()
	return STATE_SPIKE_ATTACK

func notify_jump_complete() -> void:
	if jump_remaining > 0:
		jump_remaining -= 1
	if jump_remaining <= 0:
		current_mode = "spike"

func notify_spike_complete() -> void:
	if spike_remaining > 0:
		spike_remaining -= 1
	if spike_remaining <= 0:
		current_mode = "jump"

func _calc_phase() -> int:
	if max_health <= 0:
		return PHASE_NORMAL
	var ratio := float(health) / float(max_health)
	if ratio <= 0.25:
		return PHASE_QUARTER
	if ratio <= 0.5:
		return PHASE_HALF
	return PHASE_NORMAL

func _update_phase() -> void:
	var new_phase := _calc_phase()
	if new_phase == phase:
		return
	phase = new_phase
	if phase >= PHASE_HALF and not battlecry_done_50:
		battlecry_done_50 = true
		pending_battlecry += 1
	if phase >= PHASE_QUARTER and not battlecry_done_25:
		battlecry_done_25 = true
		pending_battlecry += 1

func _physics_process(delta: float) -> void:
	# Keep boss within safe horizontal bounds
	global_position.x = clampf(global_position.x, 10.0, 150.0)

func _roll_jump_count() -> int:
	if phase == PHASE_NORMAL:
		return rng.randi_range(1, 2)
	if phase == PHASE_HALF:
		return rng.randi_range(2, 3)
	return rng.randi_range(3, 4)

func _roll_spike_count() -> int:
	if phase == PHASE_NORMAL:
		return rng.randi_range(2, 3)
	if phase == PHASE_HALF:
		return rng.randi_range(3, 4)
	return rng.randi_range(3, 4)

func _setup_health_ui() -> void:
	if health_bar != null:
		health_bar.min_value = 0
		health_bar.max_value = max_health
	_update_health_ui()

func _update_health_ui() -> void:
	if health_bar != null:
		health_bar.value = health
	if health_label == null:
		return
	health_label.text = "%d" % health

func show_health_ui() -> void:
	if is_instance_valid(health_ui_tween):
		health_ui_tween.kill()
	if health_bar != null:
		health_bar.visible = true
		health_bar.modulate.a = 0.0
	if health_label != null:
		health_label.visible = true
		health_label.modulate.a = 0.0
	health_ui_tween = create_tween()
	health_ui_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if health_bar != null:
		health_ui_tween.parallel().tween_property(health_bar, "modulate:a", health_ui_base_alpha, health_ui_fade_duration)
	if health_label != null:
		health_ui_tween.parallel().tween_property(health_label, "modulate:a", health_ui_base_alpha, health_ui_fade_duration)

func hide_health_ui() -> void:
	if is_instance_valid(health_ui_tween):
		health_ui_tween.kill()
	if is_instance_valid(health_ui_flash_tween):
		health_ui_flash_tween.kill()
	if health_bar != null:
		health_bar.visible = false
		health_bar.modulate.a = 0.0
	if health_label != null:
		health_label.visible = false
		health_label.modulate.a = 0.0

func _set_health_ui_alpha(alpha: float) -> void:
	if health_bar != null:
		health_bar.modulate.a = alpha
	if health_label != null:
		health_label.modulate.a = alpha

func _flash_health_ui_on_hit() -> void:
	if (health_bar == null or not health_bar.visible) and (health_label == null or not health_label.visible):
		return
	if is_instance_valid(health_ui_tween):
		health_ui_tween.kill()
	if is_instance_valid(health_ui_flash_tween):
		health_ui_flash_tween.kill()
	_set_health_ui_alpha(health_ui_base_alpha)
	health_ui_flash_tween = create_tween()
	health_ui_flash_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if health_bar != null:
		health_ui_flash_tween.parallel().tween_property(health_bar, "modulate:a", health_ui_hit_flash_alpha, health_ui_hit_flash_in_duration)
	if health_label != null:
		health_ui_flash_tween.parallel().tween_property(health_label, "modulate:a", health_ui_hit_flash_alpha, health_ui_hit_flash_in_duration)
	health_ui_flash_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if health_bar != null:
		health_ui_flash_tween.parallel().tween_property(health_bar, "modulate:a", health_ui_base_alpha, health_ui_hit_flash_out_duration)
	if health_label != null:
		health_ui_flash_tween.parallel().tween_property(health_label, "modulate:a", health_ui_base_alpha, health_ui_hit_flash_out_duration)

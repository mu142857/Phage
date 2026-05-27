extends CharacterBody2D

@export var max_health: int = 8000
@export var health: int = 8000
@export var idle_full: float = 1.0 # Idle 时长（满血）
@export var idle_empty: float = 0.5 # Idle 时长（0 血）
@export var idle_min_limit: float = 0.15 # Idle 最小下限，防止太短

@onready var boss_health_ui := get_node_or_null("BossHealthUI")

func _ready() -> void:
	velocity = Vector2.ZERO
	add_to_group("monster")
	if health <= 0:
		health = max_health
	health = int(clamp(float(health), 0.0, float(max_health)))
	if boss_health_ui != null:
		boss_health_ui.refresh(health, max_health)
		boss_health_ui.hide_ui(false)

func get_idle_time() -> float:
	# 按血量线性映射：满血 -> idle_full, 0血 -> idle_empty
	if max_health <= 0:
		return idle_full
	var ratio := float(health) / float(max_health)
	ratio = clampf(ratio, 0.0, 1.0)
	var t := idle_empty + ratio * (idle_full - idle_empty)
	return maxf(t, idle_min_limit)

func change_state(state_id: int) -> void:
	if has_node("StateMachine"):
		$StateMachine.change_state(state_id)

func take_damage(value: int) -> void:
	health -= value
	health = clampi(health, 0, max_health)
	if boss_health_ui != null:
		# try to refresh with animation flag if supported
		if boss_health_ui.get_method_list().has("refresh"):
			boss_health_ui.refresh(health, max_health, true)
		else:
			boss_health_ui.refresh(health, max_health)
	if has_node("HitEffectPlayer"):
		if not $HitEffectPlayer.active:
			$HitEffectPlayer.active = true
		$HitEffectPlayer.play("HitFlash")
	if health <= 0:
		if has_node("StateMachine"):
			$StateMachine.change_state(7)

extends BasicState

@export var idle_duration: float = 1.0

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var monster: CharacterBody2D = $"../.."


func enter() -> void:
	$Timer.stop()
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Idle")
	$Timer.start(idle_duration)

func process(_delta: float) -> void:
	pass

func exit() -> void:
	$Timer.stop()

func _on_timer_timeout() -> void:
	if monster != null and monster.has_method("get_next_attack_state"):
		get_parent().change_state(int(monster.get_next_attack_state()))
		return
	get_parent().change_state(1)

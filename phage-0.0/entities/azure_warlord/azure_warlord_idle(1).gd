extends BasicState

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var boss: AzureWarlord = $"../.." as AzureWarlord

var idle_ticket: int = 0

func enter() -> void:
	idle_ticket += 1
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Idle")
	var duration := 1.0
	if boss != null:
		duration = boss.get_idle_time()
	_start_idle_timer(duration, idle_ticket)

func exit() -> void:
	idle_ticket += 1

func _start_idle_timer(duration: float, ticket: int) -> void:
	await get_tree().create_timer(duration).timeout
	if ticket != idle_ticket:
		return
	change_state(2)

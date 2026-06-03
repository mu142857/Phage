extends BasicState

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var boss: AzureWarlord = $"../.." as AzureWarlord

var death_ticket: int = 0

func enter() -> void:
	death_ticket += 1
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Death")
	_start_death_cleanup(death_ticket)

func _start_death_cleanup(ticket: int) -> void:
	await get_tree().create_timer(2.0).timeout
	if ticket != death_ticket:
		return
	if boss != null and is_instance_valid(boss):
		boss.queue_free()

extends BasicState

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var boss: AzureWarlord = $"../.." as AzureWarlord

@export var fall_gravity: float = 350.0
@export var ground_y: float = 80.0

func enter() -> void:
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Fall")
	if boss != null:
		boss.velocity = Vector2.ZERO
	Game.shake_camera(3.0)

func process(delta: float) -> void:
	if boss == null:
		return
	boss.velocity.y += fall_gravity * delta
	boss.move_and_slide()
	if boss.global_position.y >= ground_y:
		boss.global_position.y = ground_y
		boss.velocity = Vector2.ZERO
		change_state(1)

func exit() -> void:
	if is_instance_valid(ani_2D):
		ani_2D.stop()

extends BasicState

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var host_monster: AzureWarlord = $"../.." as AzureWarlord

@export var start_y: float = 10.0
@export var ground_y: float = 80.0
@export var gravity: float = 350.0

func enter() -> void:
	if host_monster != null:
		host_monster.global_position.y = start_y
		host_monster.velocity = Vector2.ZERO
	if is_instance_valid(ani_2D):
		ani_2D.play(&"DiveDown")

func process(delta: float) -> void:
	if host_monster == null:
		return
	host_monster.velocity.y += gravity * delta
	host_monster.move_and_slide()
	if host_monster.global_position.y >= ground_y:
		host_monster.global_position.y = ground_y
		host_monster.velocity = Vector2.ZERO
		change_state(5)

func exit() -> void:
	if is_instance_valid(ani_2D):
		ani_2D.stop()

func _on_animated_sprite_2d_animation_finished() -> void:
	# fall-through handled in process; keep handler in case animation ends
	pass

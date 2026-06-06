extends BasicState

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var host_monster: AzureWarlord = $"../.." as AzureWarlord
@onready var attack_hitbox: Area2D = $"../../AttackHitBox"

@export var attack_damage: int = 30

var bodies_hit_this_frame := {}

func enter() -> void:
	Game.shake_camera(4)
	bodies_hit_this_frame.clear()
	if host_monster != null:
		host_monster.set_facing_from_player()
		host_monster.velocity.y = 0.0
		host_monster.global_position.y = 80.0
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Attack")
		if not ani_2D.frame_changed.is_connected(_on_frame_changed):
			ani_2D.frame_changed.connect(_on_frame_changed)
	if is_instance_valid(attack_hitbox):
		attack_hitbox.monitoring = true
		attack_hitbox.monitorable = true

func process(_delta: float) -> void:
	if host_monster != null:
		host_monster.velocity.y = 0.0
		host_monster.global_position.y = 80.0
		host_monster.move_and_slide()

func exit() -> void:
	if is_instance_valid(ani_2D) and ani_2D.frame_changed.is_connected(_on_frame_changed):
		ani_2D.frame_changed.disconnect(_on_frame_changed)
	if is_instance_valid(attack_hitbox):
		for child in attack_hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true
		attack_hitbox.monitoring = false
		attack_hitbox.monitorable = false

func _on_frame_changed() -> void:
	if not is_instance_valid(ani_2D) or not is_instance_valid(attack_hitbox):
		return
	if ani_2D.animation != &"Attack":
		return
	var frame := ani_2D.frame
	bodies_hit_this_frame.clear()
	for child in attack_hitbox.get_children():
		if child is CollisionShape2D:
			var n := String(child.name)
			var idx := -1
			if n.is_valid_int():
				idx = int(n)
			elif n.contains("-"):
				var first_part := n.get_slice("-", 0)
				if first_part.is_valid_int():
					idx = int(first_part)
			if idx == frame:
				child.disabled = false
				_attack_check(attack_damage)
			else:
				child.disabled = true

func _attack_check(dmg: int) -> void:
	if not is_instance_valid(attack_hitbox):
		return
	for body in attack_hitbox.get_overlapping_bodies():
		if body == null:
			continue
		if not body.is_in_group("player"):
			continue
		var id := str(body.get_instance_id())
		if bodies_hit_this_frame.has(id):
			continue
		if body.has_method("take_damage"):
			body.call("take_damage", dmg)
			bodies_hit_this_frame[id] = true

func _on_animated_sprite_2d_animation_finished() -> void:
	if ani_2D.animation == &"Attack":
		if host_monster != null:
			var next_state := host_monster.consume_attack_followup()
			change_state(next_state)
		else:
			change_state(2)

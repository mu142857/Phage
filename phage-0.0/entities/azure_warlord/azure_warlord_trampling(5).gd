extends BasicState

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var boss: AzureWarlord = $"../.." as AzureWarlord
@onready var trampling_hitbox: Area2D = $"../../TramplingHitBox"

@export var trampling_damage: int = 25

var bodies_hit_this_frame := {}

func enter() -> void:
	bodies_hit_this_frame.clear()
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Trampling")
		if not ani_2D.frame_changed.is_connected(_on_frame_changed):
			ani_2D.frame_changed.connect(_on_frame_changed)
	if is_instance_valid(trampling_hitbox):
		trampling_hitbox.monitoring = true
		trampling_hitbox.monitorable = true

func process(_delta: float) -> void:
	if boss != null:
		boss.velocity = Vector2.ZERO
		boss.move_and_slide()

func exit() -> void:
	if is_instance_valid(ani_2D) and ani_2D.frame_changed.is_connected(_on_frame_changed):
		ani_2D.frame_changed.disconnect(_on_frame_changed)
	if is_instance_valid(trampling_hitbox):
		for child in trampling_hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true
		trampling_hitbox.monitoring = false
		trampling_hitbox.monitorable = false

func _on_frame_changed() -> void:
	if not is_instance_valid(ani_2D) or not is_instance_valid(trampling_hitbox):
		return
	if ani_2D.animation != &"Trampling":
		return
	var frame := ani_2D.frame
	bodies_hit_this_frame.clear()
	for child in trampling_hitbox.get_children():
		if child is CollisionShape2D:
			var n := String(child.name)
			var idx := -1
			if n.is_valid_int():
				idx = int(n)
			if idx == frame:
				child.disabled = false
				_attack_check(trampling_damage)
			else:
				child.disabled = true

func _attack_check(dmg: int) -> void:
	if not is_instance_valid(trampling_hitbox):
		return
	for body in trampling_hitbox.get_overlapping_bodies():
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
	if ani_2D.animation == &"Trampling":
		if boss != null:
			boss.finish_trampling()
		else:
			change_state(1)

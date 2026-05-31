extends BasicState

@onready var ani_2D: AnimatedSprite2D = $"../../AnimatedSprite2D"
@onready var host_monster: CharacterBody2D = $"../.."
@onready var punch_hitbox: Area2D = $"../../PunchHitBox"

@export var sprint_distance: float = 40.0
@export var sprint_duration: float = 0.35
@export var punch_damage: int = 20

var hit_registered: bool = false
var tween: Tween = null

func enter() -> void:
	hit_registered = false
	if is_instance_valid(ani_2D):
		ani_2D.play(&"Sprint")
		if not ani_2D.frame_changed.is_connected(_on_frame_changed):
			ani_2D.frame_changed.connect(_on_frame_changed)

	# start horizontal tween
	var target_x := host_monster.global_position.x + host_monster.direct * sprint_distance
	target_x = clampf(target_x, 10.0, 150.0)
	tween = get_tree().create_tween()
	tween.tween_property(host_monster, "global_position:x", target_x, sprint_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.play()

func process(_delta: float) -> void:
	# simple gravity while sprinting
	if host_monster != null:
		host_monster.velocity.y += 15
		host_monster.move_and_slide()

func exit() -> void:
	if is_instance_valid(ani_2D) and ani_2D.frame_changed.is_connected(_on_frame_changed):
		ani_2D.frame_changed.disconnect(_on_frame_changed)
	if tween != null and tween.is_valid():
		tween.kill()
		tween = null

func _on_frame_changed() -> void:
	if not is_instance_valid(ani_2D):
		return
	if ani_2D.animation != &"Sprint":
		return
	var frame := ani_2D.frame
	# frames 6..10 are the damaging window
	if frame >= 6 and frame <= 10:
		if not hit_registered:
			_attack_check(punch_damage)
			hit_registered = true
	else:
		# leave window, reset registration so next window can hit again
		hit_registered = false

func _attack_check(dmg: int) -> void:
	if not is_instance_valid(punch_hitbox):
		return
	for body in punch_hitbox.get_overlapping_bodies():
		if body == null:
			continue
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.call("take_damage", dmg)

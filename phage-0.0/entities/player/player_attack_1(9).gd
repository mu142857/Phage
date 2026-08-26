extends BasicState

const ATTACK_BURST_SPEED: float = 180.0
const ATTACK_BRAKE_ACCEL: float = 800.0
const ATTACK_BURST_SPEED_AIR: float = 240.0
const ATTACK_BRAKE_ACCEL_AIR: float = 380.0
const ATTACK1_1_DAMAGE: int = 90
const ATTACK1_2_DAMAGE: int = 60
# 伤害公式(2026-08-22 改为加法制):每种增幅都按"基础伤害的百分比"单独算,
# 全部相加后一次结算:最终 = 基础 × (1 + 加成总和)。
# 旧乘法连乘会指数爆炸(盐灯×无盾×跳劈=×3.9,叠珊瑚红水晶可到×8),加法封顶可控。
# 例:无盾跳劈 = 90 × (1 + 1.0 + 0.5) = 225(旧版 270)。
const AIR_ATTACK_BONUS: float = 0.5             # 跳劈:+基础的50%
const NO_SHIELD_BONUS: float = 1.0              # 无盾:+基础的100%
const SALT_AIR_BONUS: float = 0.3               # 山的重量:跳劈时再+基础的30%
const RED_CRYSTAL_NO_SHIELD_BONUS: float = 1.1  # 红水晶:无盾加成 100%→110%(主价值是二段=一段,加伤只是点缀)
# 红水晶另一半效果:二段伤害=一段(见 attack1_2_check);花:有盾也吃无盾加成。
const ATTACK1_1_TRIGGER_FRAME: int = 1
const ATTACK1_2_TRIGGER_FRAME: int = 1
const ATTACK1_1_TRIGGER_TIME: float = 2.0 / 12.0
const ATTACK1_2_TRIGGER_TIME: float = 2.0 / 12.0
const COMBO_QUEUE_OPEN_TIME: float = 2.0 / 12.0
const HIT_RECOIL_SPEED: float = 110.0
const HIT_RECOIL_DURATION: float = 0.08
const HIT_RECOIL_INPUT_SCALE: float = 0.6
# 智能前冲:怪已在攻击范围内则不前冲(原地出刀);前冲途中怪进入判定框则立刻刹停。
# 防止前冲把身体压进怪的接触伤害框(破盾/致死),远距离突进的观感不受影响。
const LUNGE_SKIP_RANGE_X: float = 20.0
const LUNGE_SKIP_BEHIND_X: float = 6.0
const LUNGE_SKIP_RANGE_Y: float = 14.0

const ANIM_ATTACK1_1: StringName = &"Attack1_1"
const ANIM_ATTACK1_2: StringName = &"Attack1_2"
const ANIM_ATTACK_LEGACY: StringName = &"Attack1"

@onready var attack_hitbox_1: Area2D = $"../../HitBox/Attack1_1"
@onready var attack_hitbox_2: Area2D = $"../../HitBox/Attack1_2"

var phase_1_done: bool = false
var phase_2_done: bool = false
var attack_elapsed: float = 0.0
var attack_locked_facing: int = 1
var phase_2_requested: bool = false
var current_phase: int = 1
var attack_glow_tween: Tween = null
var base_sprite_modulate: Color = Color(1, 1, 1, 1)
var player_ref: Player = null
var recoil_time_left: float = 0.0
var is_air_attack: bool = false

func enter() -> void:
	var player := host as Player
	if player == null:
		return
	player._end_mist()  # 按下攻击的瞬间就破雾(各状态都直切攻击态,不走 start_attack)
	player_ref = player
	recoil_time_left = 0.0
	phase_1_done = false
	phase_2_done = false
	attack_elapsed = 0.0
	phase_2_requested = false
	current_phase = 1
	is_air_attack = not player.is_on_floor()
	attack_locked_facing = player.facing_direction
	if attack_locked_facing == 0:
		attack_locked_facing = 1
	base_sprite_modulate = player.sprite.modulate if is_instance_valid(player.sprite) else Color(1, 1, 1, 1)
	player.set_facing_direction(attack_locked_facing)
	player.set_walking_effect(false)
	player.clear_attack_hitboxes()
	player.set_attack_hitbox(1, true)
	if not _enemy_already_in_range(player):
		_apply_attack_surge(player)
	_play_attack_glow(player)
	_play_attack_animation(player, ANIM_ATTACK1_1, ANIM_ATTACK_LEGACY)
	# 攻速增益(铜灯火光/窗边的晨光)只作用在攻击动画上
	if is_instance_valid(player.sprite):
		player.sprite.speed_scale = player.attack_speed_multiplier()

func process(delta: float) -> void:
	var player := host as Player
	if player == null:
		return

	# Ignore horizontal move input during attack: do a forward lunge then decay.
	var brake_accel := ATTACK_BRAKE_ACCEL if player.is_on_floor() else ATTACK_BRAKE_ACCEL_AIR
	if recoil_time_left > 0.0:
		recoil_time_left = maxf(recoil_time_left - delta, 0.0)
		var move_input := Input.get_axis(&"move_left", &"move_right")
		var recoil_target := -float(attack_locked_facing) * HIT_RECOIL_SPEED
		var input_target := move_input * player.RUN_SPEED * HIT_RECOIL_INPUT_SCALE
		var target_x := recoil_target + input_target
		player.velocity.x = move_toward(player.velocity.x, target_x, brake_accel * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, brake_accel * delta)
		# 前冲刹车:怪一进攻击判定框就刹停前进速度,停在刚好打得到的距离。
		if player.velocity.x * float(attack_locked_facing) > 0.0 and _enemy_in_attack_hitbox():
			player.velocity.x = 0.0
	player.set_facing_direction(attack_locked_facing)

	if not player.is_on_floor():
		player.apply_gravity(delta)
	elif player.velocity.y > 0.0:
		player.velocity.y = 0.0
	player.move_and_slide()
	attack_elapsed += delta

	# Queue phase 2 only in phase 1 and after combo window opens.
	if current_phase == 1 and phase_1_done and not phase_2_done and attack_elapsed >= COMBO_QUEUE_OPEN_TIME:
		if Input.is_action_pressed(&"Attack1") or Input.is_action_just_pressed(&"Attack1"):
			phase_2_requested = true

	_try_auto_attack_phases(player)

func attack1_1_check() -> void:
	if phase_1_done:
		return
	phase_1_done = true
	if _check_attack_hitbox(attack_hitbox_1, _get_attack_damage(ATTACK1_1_DAMAGE)) \
			and player_ref != null:
		player_ref.on_attack_landed()

func attack1_2_check() -> void:
	if not phase_2_requested:
		return
	if phase_2_done:
		return
	phase_2_done = true
	# 红水晶:连击第二段不再衰减,伤害与第一段相同。
	var base := ATTACK1_2_DAMAGE
	if player_ref != null and player_ref.has_buff(&"RedCrystal"):
		base = ATTACK1_1_DAMAGE
	if _check_attack_hitbox(attack_hitbox_2, _get_attack_damage(base)) \
			and player_ref != null:
		player_ref.on_attack_landed()

func _get_attack_damage(base_damage: int) -> int:
	var bonus := 0.0
	if is_air_attack:
		bonus += AIR_ATTACK_BONUS
		if player_ref != null and player_ref.has_buff(&"SaltLight"):
			bonus += SALT_AIR_BONUS
	if player_ref != null:
		# 花:有盾也吃无盾加成;红水晶:无盾加成更高
		if not player_ref.is_guarding or player_ref.has_buff(&"Flower"):
			bonus += RED_CRYSTAL_NO_SHIELD_BONUS if player_ref.has_buff(&"RedCrystal") \
				else NO_SHIELD_BONUS
		# 珊瑚潮汐等攻击力增益,同一个加法池
		bonus += player_ref.attack_damage_bonus()
	return int(round(float(base_damage) * (1.0 + bonus)))

func _try_auto_attack_phases(player: Player) -> void:
	if not is_instance_valid(player.sprite):
		return
	var anim := player.sprite.animation

	if anim == ANIM_ATTACK1_1 or (anim == ANIM_ATTACK_LEGACY and current_phase == 1):
		var phase_1_frame := player.sprite.frame
		if phase_1_frame >= ATTACK1_1_TRIGGER_FRAME or attack_elapsed >= ATTACK1_1_TRIGGER_TIME:
			attack1_1_check()
		return

	if anim == ANIM_ATTACK1_2 or (anim == ANIM_ATTACK_LEGACY and current_phase == 2):
		var phase_2_frame := player.sprite.frame
		if phase_2_frame >= ATTACK1_2_TRIGGER_FRAME or attack_elapsed >= ATTACK1_2_TRIGGER_TIME:
			attack1_2_check()
		return

func _play_attack_animation(player: Player, primary: StringName, fallback: StringName = &"") -> void:
	if not is_instance_valid(player.sprite):
		return
	var frames := player.sprite.sprite_frames
	if frames != null and frames.has_animation(primary):
		player.play_anim(primary)
		return
	if fallback != &"" and frames != null and frames.has_animation(fallback):
		player.play_anim(fallback)

func _apply_attack_surge(player: Player) -> void:
	var burst_speed := ATTACK_BURST_SPEED if player.is_on_floor() else ATTACK_BURST_SPEED_AIR
	player.velocity.x = float(attack_locked_facing) * burst_speed

# 进入攻击/连击段时的贴脸检查:怪的中心已在面前近距离内就不前冲。
# 用组扫描而不是 Area 重叠,因为判定框刚被启用,重叠数据要下一物理帧才有效。
func _enemy_already_in_range(player: Player) -> bool:
	for node in player.get_tree().get_nodes_in_group("monster"):
		var monster := node as Node2D
		if monster == null:
			continue
		var offset := monster.global_position - player.global_position
		var dx := offset.x * float(attack_locked_facing)
		if dx >= -LUNGE_SKIP_BEHIND_X and dx <= LUNGE_SKIP_RANGE_X and absf(offset.y) <= LUNGE_SKIP_RANGE_Y:
			return true
	return false

func _enemy_in_attack_hitbox() -> bool:
	var hitbox := attack_hitbox_1 if current_phase == 1 else attack_hitbox_2
	if not is_instance_valid(hitbox):
		return false
	for body in hitbox.get_overlapping_bodies():
		if body != null and body.is_in_group("monster"):
			return true
	for area in hitbox.get_overlapping_areas():
		if area != null and area.is_in_group("monster"):
			return true
	return false

func _play_attack_glow(player: Player) -> void:
	if not is_instance_valid(player.sprite):
		return
	if is_instance_valid(attack_glow_tween):
		attack_glow_tween.kill()
	attack_glow_tween = create_tween()
	attack_glow_tween.tween_property(player.sprite, "modulate", Color(1.6, 1.6, 1.6, base_sprite_modulate.a), 0.05)
	attack_glow_tween.tween_property(player.sprite, "modulate", base_sprite_modulate, 0.10)

func _check_attack_hitbox(hitbox: Area2D, damage: int) -> bool:
	if not is_instance_valid(hitbox):
		return false

	# Range attack: damage every valid target overlapping the hitbox, not just the first.
	var hit_any := false
	var damaged: Array[Node] = []
	for body in hitbox.get_overlapping_bodies():
		if _try_damage_target(body, damage, damaged):
			hit_any = true

	for area in hitbox.get_overlapping_areas():
		if _try_damage_target(area, damage, damaged):
			hit_any = true

	if hit_any:
		_apply_hit_recoil()
	return hit_any


func _try_damage_target(target: Node, damage: int, damaged: Array[Node]) -> bool:
	if target == null:
		return false
	if not target.is_in_group("monster") and not target.is_in_group("breakable_wall"):
		return false

	var damage_target: Node = target
	if target.has_method("take_damage"):
		damage_target = target
	elif target.get_parent() != null and target.get_parent().has_method("take_damage"):
		damage_target = target.get_parent()
	else:
		return false

	# Avoid double-hitting the same entity (e.g. body + its child area both overlap).
	if damage_target in damaged:
		return false
	damaged.append(damage_target)
	damage_target.call("take_damage", damage)

	if damage_target is Node2D and player_ref != null:
		var hit_x := (damage_target as Node2D).global_position.x
		if is_air_attack:
			player_ref.spawn_jump_attack_effect(hit_x)
		player_ref.spawn_hit_effect(hit_x)
	Game.flash(0.1, Color(0.815, 0.908, 0.915, 1.0))
	Game.shake_camera(2)
	return true

func _apply_hit_recoil() -> void:
	if player_ref == null:
		return
	# 被金盏的网缠身时不后弹:网跟着人一起弹会很怪,原地砍就好
	if player_ref.web_snared:
		return
	# 命中后小幅后弹增强打击感;防撞交给智能前冲的门禁+刹车,这里不再压制下一段前冲。
	player_ref.velocity.x = -float(attack_locked_facing) * HIT_RECOIL_SPEED
	recoil_time_left = HIT_RECOIL_DURATION

func _on_animated_sprite_2d_animation_finished() -> void:
	var player := host as Player
	if player == null:
		return
	if not is_instance_valid(player.sprite):
		return

	var anim := player.sprite.animation
	if anim == ANIM_ATTACK1_1 or (anim == ANIM_ATTACK_LEGACY and current_phase == 1):
		attack1_1_check()
		if phase_2_requested:
			current_phase = 2
			attack_elapsed = 0.0
			recoil_time_left = 0.0
			player.clear_attack_hitboxes()
			player.set_attack_hitbox(2, true)
			# 怪被第一段击退出范围时,这里的智能前冲会自动追上去补第二刀。
			if not _enemy_already_in_range(player):
				_apply_attack_surge(player)
			_play_attack_glow(player)
			_play_attack_animation(player, ANIM_ATTACK1_2, ANIM_ATTACK_LEGACY)
			# 第一段命中可能刚点燃火光,二段攻速要跟着刷新
			player.sprite.speed_scale = player.attack_speed_multiplier()
			return
		player.finish_attack()
		return

	if anim == ANIM_ATTACK1_2 or (anim == ANIM_ATTACK_LEGACY and current_phase == 2):
		attack1_2_check()
		player.finish_attack()

func exit() -> void:
	var player := host as Player
	if player == null:
		return
	if is_instance_valid(attack_glow_tween):
		attack_glow_tween.kill()
		attack_glow_tween = null
	if is_instance_valid(player.sprite):
		player.sprite.modulate = base_sprite_modulate
		player.sprite.speed_scale = 1.0
	player.clear_attack_hitboxes()
	player_ref = null
	recoil_time_left = 0.0

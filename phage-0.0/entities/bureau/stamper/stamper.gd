# 稽查员:圆肚子短腿、高筒盔(头顶小管子冒汽),印章锤平时拄在地上。皮厚,挨打不退。
# 举锤憋很久(第 3~5 帧),砸地(第 7 帧):扬灰 + 地上盖一个藏青罚章 + 判定;砸中主角还要罚款(扣铜板)。
# 关卡里收"过段费"的多半是他。
extends BureauMob

const DUST: PackedScene = preload("res://entities/bureau/stamper/stamp_dust.tscn")
const STAMP_TEX: Texture2D = preload("res://entities/bureau/stamper/fine_stamp.png")
const FINE_COLOR := Color(0.62, 0.72, 0.98)

@export var slam_frame: int = 7
@export var stamp_offset: float = 28.0
## 砸中一下罚几个铜板
@export var fine: int = 5

var _slammed := false


func _on_attack_started() -> void:
	_slammed = false


func _attack_tick(_delta: float) -> void:
	velocity.x = 0.0
	if sprite.animation != attack_anim:
		return
	if sprite.frame >= slam_frame and not _slammed:
		_slammed = true
		_slam()
	if sprite.frame in hit_frames:
		_stamp_hit()


func _slam() -> void:
	Game.shake_camera(3.0)
	var scene := get_tree().current_scene
	if scene == null:
		return
	var at := global_position + Vector2(facing * stamp_offset, 0.0)
	var fx := DUST.instantiate() as GPUParticles2D
	scene.add_child(fx)
	fx.global_position = at
	fx.emitting = true
	# 地上留一个罚章,几秒后淡掉
	var mark := Sprite2D.new()
	mark.texture = STAMP_TEX
	mark.z_index = 9
	mark.centered = false
	scene.add_child(mark)
	mark.global_position = at + Vector2(-5.0, -3.0)
	var tw := mark.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(mark, "modulate:a", 0.0, 1.0)
	tw.tween_callback(mark.queue_free)


## 砸中:主角挨一下 + 罚款;对面的人挨重的
func _stamp_hit() -> void:
	if _hit_done or attack_check == null:
		return
	var hit := false
	for body in attack_check.get_overlapping_bodies():
		if body == null or body == self:
			continue
		if body.is_in_group("player"):
			if not hostile_to_player() or not body.has_method("take_damage"):
				continue
			var safe: bool = body.get("is_invincible") == true or body.get("dev_god_mode") == true
			body.call("take_damage", 1)
			hit = true
			if not safe and Story.coins > 0:
				var n := mini(fine, Story.coins)
				Story.add_coins(-n)
				var scene := get_tree().current_scene
				if scene != null:
					MiniHud.float_text(scene, (body as Node2D).global_position + Vector2(0, -14), "罚款 -%d" % n, FINE_COLOR)
			shout("fine", 1.0, true)
		elif is_enemy(body):
			(body as GangMob).take_hit(mob_damage, global_position.x, self)
			hit = true
	if hit:
		_hit_done = true


func _lines() -> Dictionary:
	return {
		"attack": ["盖章。", "依规处罚。"],
		"fine": ["罚款。", "盖章生效。", "罚单。"],
		"spot": ["证件。", "收据呢？"],
		"hurt": ["记下了。", "加罚。"],
	}

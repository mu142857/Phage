# 大块头:慢、皮厚、挨打不退。扳手拖在地上走过来,举过头憋很久(第 3~7 帧),
# 砸下去(第 9 帧)= 跟前一大块判定 + 地上往两边各跑一道震波(要跳过去)。落地也震一下。
extends GangMob

const SHOCKWAVE: PackedScene = preload("res://entities/gang/brute/shockwave.tscn")

@export var slam_frame: int = 9
@export var wave_offset: float = 26.0

var _slammed := false


func _on_landed() -> void:
	Game.shake_camera(3.0)


func _on_attack_started() -> void:
	_slammed = false


func _attack_tick(_delta: float) -> void:
	velocity.x = 0.0
	if sprite.animation != attack_anim:
		return
	if sprite.frame in hit_frames:
		try_hit()
	if sprite.frame >= slam_frame and not _slammed:
		_slammed = true
		Game.shake_camera(4.0)
		var scene := get_tree().current_scene
		if scene != null:
			for dir in [-1.0, 1.0]:
				var w := SHOCKWAVE.instantiate()
				scene.add_child(w)
				w.global_position = global_position + Vector2(facing * wave_offset, 0.0)
				w.call("go", dir)


func _lines() -> Dictionary:
	return {
		"spot": ["……", "砸扁你。"],
		"attack": ["嗯——！", "……"],
		"hurt": ["……痒。", "……"],
		"die": ["……"],
	}

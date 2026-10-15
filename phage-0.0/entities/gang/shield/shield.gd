# 井盖盾兵:前面举着一块井盖,正面砍上去"当"一声没用;转身很慢(turn_delay),
# 跳过去从背后砍、或者从头顶往下劈才行。贴近了把钢筋从盾后面捅出来(第 4~6 帧判定,够得远)。
extends GangMob

const CLANG_SPARKS: PackedScene = preload("res://entities/gang/shield/clang_sparks.tscn")

@export var turn_delay: float = 0.8
## 主角脚底比盾兵脚底高出这么多 = 从头顶劈下来,盾挡不住
@export var overhead_height: float = 16.0

var _turn_timer := 0.0


func _engage(delta: float) -> void:
	var p := foe()
	if p == null:
		velocity.x = 0.0
		play(&"Idle")
		return
	var dx := p.global_position.x - global_position.x
	var want := signf(dx)
	if want != 0.0 and want != facing:
		# 转身慢:原地愣一会儿才转
		_turn_timer += delta
		velocity.x = 0.0
		play(&"Idle")
		if _turn_timer >= turn_delay:
			_turn_timer = 0.0
			face(want)
		return
	_turn_timer = 0.0
	if absf(dx) <= attack_range:
		velocity.x = 0.0
		if cooldown <= 0.0:
			start_attack()
		else:
			play(&"Idle")
		return
	walk(facing, move_speed)


func _blocks(_value: int) -> bool:
	var p := player()
	if p == null:
		return false
	var in_front := (p.global_position.x - global_position.x) * facing > 0.0
	var from_above := global_position.y - p.global_position.y > overhead_height
	if not in_front or from_above:
		return false
	# 挡住:火星 + 往后一顿,攻击动作不打断
	shout("block", 0.7)
	var fx := CLANG_SPARKS.instantiate() as Node2D
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position + Vector2(facing * 10.0, -14.0)
	Game.shake_camera(1.5)
	if state != S.ATTACK:
		state = S.CUSTOM
		play_once(&"Block", func() -> void: state = S.ENGAGE)
	return true


func _blocks_from(from_x: float) -> bool:
	if (from_x - global_position.x) * facing <= 0.0:
		return false
	shout("block", 0.5)
	var fx := CLANG_SPARKS.instantiate() as Node2D
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position + Vector2(facing * 10.0, -14.0)
	return true


func _lines() -> Dictionary:
	return {
		"spot": ["盾在人在！", "来啊！"],
		"attack": ["捅！"],
		"block": ["当！", "没用的！", "打不动吧？"],
	}

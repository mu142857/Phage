# 章鱼馆长的十字激光:一次两根、互相垂直,交点 = 章鱼本体原点(画在章鱼身后一层)。由 Laser(5) 状态指挥:
#   aim(center, dir)     预警:两根细线渐显后呼吸闪,摆好就不动(状态里瞄主角再往左 30°)
#   fire(to_dir, time)   开火:主束张开 → time 秒内从当前角度转到 to_dir(扫到开火那一刻主角的位置),
#                        扫的全程整根都有伤害,主束打到地面的地方喷火花 → 转完直接变细收掉 → 火花飘完自删
#   cancel()             还没开火就被打断:预警线淡出自删
# 伤害是几何判定(主角身子到任一根线的距离 < 束宽一半 + 2),线在转也准;一次开火最多打一下。
# 泛光:线条颜色(顶点色)超过 1 会被截断,所以颜色都在 1 以内,亮度全靠各线的 self_modulate(4~6 倍)
# 推过泛光阈值——走廊整体还压暗 0.537,倍数小了过不去。
extends Node2D

@export var damage: int = 6
## 每根从交点往两头各伸多长(够穿过整个屏幕)
@export var length: float = 260.0
@export var beam_width: float = 7.0
@export var core_width: float = 3.0
@export var open_time: float = 0.06
@export var retract_time: float = 0.12
## 开火那一下的重震、扫的过程中一直抖的小震、开火闪屏
@export var fire_shake: float = 3.5
@export var sweep_rumble: float = 0.8
@export var fire_flash: float = 0.15
@export var flash_color: Color = Color(1.6, 1.4, 0.7, 0.4)
## 地面高度(主束打到这里喷火花)
@export var ground_y: float = 80.0

var _dir := Vector2.LEFT
var _fired := false
var _sweeping := false
var _hot := false
var _damage_done := false
var _from_angle := 0.0
var _to_angle := 0.0
var _sweep_time := 0.3
var _elapsed := 0.0
var _pulse: Tween = null

@onready var aim_lines: Array[Line2D] = [$AimA, $AimB]
@onready var beams: Array[Line2D] = [$BeamA, $BeamB]
@onready var cores: Array[Line2D] = [$CoreA, $CoreB]
@onready var sparks: Array[GPUParticles2D] = [$SparksA, $SparksB]


func _ready() -> void:
	set_physics_process(false)
	for line in aim_lines:
		line.modulate.a = 0.0
	for line in beams + cores:
		line.width = 0.0


## 摆预警线(center = 交点的世界坐标,dir = 第一根的方向);第一次调时渐显,之后每帧调只更新角度
func aim(center: Vector2, dir: Vector2) -> void:
	global_position = center
	_set_dir(dir)
	if _pulse == null and not _fired:
		_pulse = create_tween()
		_pulse.tween_method(_set_aim_alpha, 0.0, 0.8, 0.4)
		_pulse.tween_callback(_start_pulse)


func _start_pulse() -> void:
	if _fired or not is_inside_tree():
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_method(_set_aim_alpha, 0.95, 0.4, 0.35)
	_pulse.tween_method(_set_aim_alpha, 0.4, 0.95, 0.35)


func _set_aim_alpha(a: float) -> void:
	for line in aim_lines:
		line.modulate.a = a


## 开火:从现在的角度转到 to_dir,转完收束
func fire(to_dir: Vector2, sweep_time: float) -> void:
	if _fired:
		return
	_fired = true
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	for line in aim_lines:
		line.visible = false
	Game.shake_camera(fire_shake)
	if fire_flash > 0.0:
		Game.flash(fire_flash, flash_color)
	_from_angle = _dir.angle()
	_to_angle = to_dir.angle()
	_sweep_time = maxf(sweep_time, 0.01)
	_elapsed = 0.0
	_sweeping = true
	_hot = true
	_damage_done = false
	for s in sparks:
		s.emitting = true
	var open := create_tween().set_parallel(true)
	for line in beams:
		open.tween_property(line, "width", beam_width, open_time)
	for line in cores:
		open.tween_property(line, "width", core_width, open_time)
	set_physics_process(true)


## 没开火就要撤:预警线淡出走人
func cancel() -> void:
	if _fired:
		return
	_fired = true
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	var from_a := aim_lines[0].modulate.a
	var tw := create_tween()
	tw.tween_method(_set_aim_alpha, from_a, 0.0, 0.2)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if not _sweeping:
		return
	_elapsed += delta
	var k := clampf(_elapsed / _sweep_time, 0.0, 1.0)
	_set_dir(Vector2.from_angle(lerp_angle(_from_angle, _to_angle, k)))
	Game.shake_camera(sweep_rumble)
	_try_damage()
	if k >= 1.0:
		_finish()


# 转完:直接变细收掉,火花停发后飘完再删(不凭空消失)
func _finish() -> void:
	_sweeping = false
	_hot = false
	set_physics_process(false)
	for s in sparks:
		s.emitting = false
	var close := create_tween().set_parallel(true)
	for line in beams + cores:
		close.tween_property(line, "width", 0.0, retract_time)
	close.chain().tween_interval(0.6)
	close.chain().tween_callback(queue_free)


func _try_damage() -> void:
	if not _hot or _damage_done:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node2D
	var body := player.global_position + Vector2(0.0, -3.5) - global_position
	var reach := beam_width * 0.5 + 2.0
	for d: Vector2 in [_dir, _dir.orthogonal()]:
		if absf(body.cross(d)) < reach and player.has_method("take_damage"):
			player.call("take_damage", damage)
			_damage_done = true
			return


func _set_dir(dir: Vector2) -> void:
	_dir = dir.normalized() if dir.length() > 0.001 else Vector2.LEFT
	var dirs := [_dir, _dir.orthogonal()]
	for i in 2:
		var d: Vector2 = dirs[i]
		var pts := PackedVector2Array([-d * length, d * length])
		aim_lines[i].points = pts
		beams[i].points = pts
		cores[i].points = pts
		# 火花放在这根朝下那一头打到地面的地方(只平移,不转)
		var down := d if d.y > 0.0 else -d
		if down.y > 0.05:
			var t := (ground_y - global_position.y) / down.y
			sparks[i].position = down * minf(t, length)
			sparks[i].visible = true
		else:
			sparks[i].visible = false

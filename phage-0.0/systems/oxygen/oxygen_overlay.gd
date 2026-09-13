# res://systems/oxygen/oxygen_overlay.gd
# 水下氧气视觉:一层浅蓝滤镜 + 缓缓上浮的方形气泡 + 可以被"排干"的水面。
# 只管画面,不管掉氧气的数值。
# 用法:实例进关卡根节点(房间1 要放在 DreamIntro 前面)。整个节点跟着相机走,
# 所以摆在哪个坐标无所谓。以后氧气机制可以调 set_intensity(0~1)。
# 排水:drain(秒数) —— 屏幕顶上出现带波纹的水面线,越退越快地落到屏幕底下,
#       水面以下才有滤镜,水面上有白色泡沫点,气泡在退水时全部破掉;退完 drained 信号。
extends Node2D

signal drained

## 滤镜颜色(alpha 就是浓度)。
@export var tint_color := Color(0.55, 0.8, 1.0, 0.13)
## 水面那一行像素的颜色,和它下面一行的余光。
@export var surface_color := Color(0.85, 0.97, 1.0, 0.9)
@export var surface_glow := Color(0.7, 0.9, 1.0, 0.35)
## 地面焦散光斑所在的世界 y(走廊地面 80);<0 = 关掉焦散。22 房这种多层地面的按主地面填。
@export var caustic_y := 80.0
## 呼吸气泡间隔(秒)的随机范围。
@export var breath_interval := Vector2(1.4, 2.6)
## 0 = 关掉滤镜和气泡,1 = 满强度。
@export_range(0.0, 1.0) var intensity := 1.0:
	set(value):
		intensity = clampf(value, 0.0, 1.0)
		_apply()

# 画布比屏幕(160×90)四边各多出来一些,盖住相机比本节点晚一帧的位移
const HALF_W := 110.0
const HALF_H := 70.0
const VIEW_BOTTOM := 45.0
const LEVEL_FULL := -60.0        # 满水:水面在屏幕上方看不见
const LEVEL_EMPTY := VIEW_BOTTOM + 6.0

var _level := LEVEL_FULL         # 水面在本节点坐标系里的 y
var _draining := false
var _drain_t := 0.0
var _drain_dur := 1.0
var _water_gone := false
var _time := 0.0

@onready var _emitters: Array[GPUParticles2D] = [$Bubbles2px, $Bubbles1px]
@onready var _breath: GPUParticles2D = $Breath
@onready var _landing: GPUParticles2D = $Landing
@onready var _caustics: GPUParticles2D = $Caustics

var _player: CharacterBody2D = null
var _breath_left := 1.0
var _was_on_floor := true


func _ready() -> void:
	top_level = true   # 跟相机走的东西不能被关卡根的变换带着跑
	z_index = 30
	# 材质是场景里共用的资源,别的实例/以后的参数改动互不干扰
	for e in _emitters + [_breath, _landing, _caustics]:
		e.process_material = e.process_material.duplicate()
	# Actinos 死后水不回来:任何房间都按"已排干"开场(没滤镜没气泡,不掉氧气)
	if Story.actinos_defeated:
		_water_gone = true
		_level = LEVEL_EMPTY
	_apply()
	_follow_camera()
	queue_redraw()
	# 挂上"水下"强制 buff(氧气开始流逝);排干时摘掉
	Story.set_underwater(not _water_gone and intensity > 0.0)


func _process(delta: float) -> void:
	_follow_camera()
	_time += delta
	_update_player_effects(delta)
	if _draining:
		_drain_t += delta
		var k := clampf(_drain_t / _drain_dur, 0.0, 1.0)
		k = pow(k, 1.7)   # 先慢后快:三段震动一段比一段猛,水也越退越急
		_level = lerpf(LEVEL_FULL, LEVEL_EMPTY, k)
		if k >= 1.0:
			_draining = false
			_water_gone = true
			_apply()
			Story.set_underwater(false)
			drained.emit()
		queue_redraw()


func set_intensity(value: float) -> void:
	intensity = value


## 把水排干:水面从屏幕顶退到屏幕底,用时 duration 秒。气泡立刻停发并在 0.8s 内破光。
func drain(duration: float) -> void:
	if _water_gone:
		return
	_draining = true
	_drain_t = 0.0
	_drain_dur = maxf(duration, 0.1)
	for e in _emitters:
		e.emitting = false
		var tw := create_tween()
		tw.tween_property(e, "modulate:a", 0.0, 0.8)


## 水回来(死亡重试等场合关卡自己决定要不要叫)。
func refill() -> void:
	_water_gone = false
	_draining = false
	_level = LEVEL_FULL
	_apply()
	queue_redraw()
	Story.set_underwater(intensity > 0.0)


func _follow_camera() -> void:
	if Game == null:
		return
	global_position = Game.get_screen_center_position()


func _apply() -> void:
	if not is_node_ready():
		return
	var alive := intensity > 0.0 and not _water_gone
	for e in _emitters:
		e.emitting = alive and not _draining
		e.modulate.a = intensity
	_caustics.visible = alive and caustic_y >= 0.0
	_caustics.emitting = _caustics.visible
	for e in [_breath, _landing, _caustics]:
		e.modulate.a = intensity
	queue_redraw()


# 主角贴身效果:头顶隔一阵冒一小串呼吸气泡,落地时脚下炸一小圈;地面焦散贴在 caustic_y。
func _update_player_effects(delta: float) -> void:
	if _caustics.visible:
		_caustics.global_position = Vector2(global_position.x, caustic_y)
	if intensity <= 0.0 or _water_gone:
		return
	if not is_instance_valid(_player):
		var players := get_tree().get_nodes_in_group("player")
		_player = players[0] as CharacterBody2D if not players.is_empty() else null
		if _player == null:
			return
		_was_on_floor = _player.is_on_floor()
	# 主角身体 4×7 站在原点上:头顶 (0,-8),脚 (0,0)
	_breath.global_position = _player.global_position + Vector2(0, -8)
	_breath_left -= delta
	if _breath_left <= 0.0:
		_breath_left = randf_range(breath_interval.x, breath_interval.y)
		_breath.restart()
	var on_floor := _player.is_on_floor()
	if on_floor and not _was_on_floor:
		_landing.global_position = _player.global_position
		_landing.restart()
	_was_on_floor = on_floor


func _draw() -> void:
	if intensity <= 0.0 or _water_gone:
		return
	var c := tint_color
	c.a *= intensity
	# 满水:整块画布铺滤镜,一次画完
	if _level <= LEVEL_FULL + 0.01:
		draw_rect(Rect2(-HALF_W, -HALF_H, HALF_W * 2.0, HALF_H * 2.0), c)
		return
	# 退水:逐列画"水面以下",水面按世界 x 起波纹并锁到整数格(像素画笔式线条)
	var t8 := int(_time * 8.0)
	for i in range(int(HALF_W * 2.0)):
		var x := -HALF_W + float(i)
		var wx := global_position.x + x
		var wave := sin(wx * 0.26 + _time * 2.2) * 1.2 + sin(wx * 0.09 - _time * 1.4) * 0.8
		var y := floorf(_level + wave)
		if y >= HALF_H:
			continue
		draw_rect(Rect2(x, y, 1.0, HALF_H - y), c)
		draw_rect(Rect2(x, y, 1.0, 1.0), surface_color)
		draw_rect(Rect2(x, y + 1.0, 1.0, 1.0), surface_glow)
		# 泡沫:沿水面撒伪随机白点,每 1/8 秒换一批
		if (int(wx) * 7919 + t8 * 104729) % 11 == 0:
			draw_rect(Rect2(x, y - 1.0, 1.0, 1.0), Color(1, 1, 1, 0.85))

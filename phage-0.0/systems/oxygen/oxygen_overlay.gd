# res://systems/oxygen/oxygen_overlay.gd
# 水下氧气视觉:一层浅蓝滤镜 + 缓缓上浮的方形气泡。只管画面,不管掉氧气的数值。
# 用法:实例进关卡根节点(房间1 要放在 DreamIntro 前面)。滤镜和气泡都跟着相机走,
# 所以摆在哪个坐标无所谓。以后氧气机制可以调 set_intensity(0~1) 让画面随氧气变化。
extends Node2D

## 滤镜颜色(alpha 就是浓度)。
@export var tint_color := Color(0.55, 0.8, 1.0, 0.13)
## 0 = 关掉滤镜和气泡,1 = 满强度。
@export_range(0.0, 1.0) var intensity := 1.0:
	set(value):
		intensity = clampf(value, 0.0, 1.0)
		_apply()

@onready var _tint: ColorRect = $Tint
@onready var _emitters: Array[GPUParticles2D] = [$Bubbles2px, $Bubbles1px]


func _ready() -> void:
	# 跟相机走的东西不能被关卡根的变换带着跑
	top_level = true
	z_index = 30
	_apply()
	_follow_camera()


func _process(_delta: float) -> void:
	_follow_camera()


func set_intensity(value: float) -> void:
	intensity = value


func _follow_camera() -> void:
	if Game == null:
		return
	# 相机在 _process 里才挪到位,本节点可能先跑一帧:滤镜和发射盒都留了余量盖住这一帧的差。
	global_position = Game.get_screen_center_position()


func _apply() -> void:
	if _tint == null:
		return
	var c := tint_color
	c.a = tint_color.a * intensity
	_tint.color = c
	_tint.visible = intensity > 0.0
	for e in _emitters:
		e.emitting = intensity > 0.0
		e.modulate.a = intensity

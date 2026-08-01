#SpiderLegs 程序化蜘蛛腿：IK 算关节，绘制时全部取整到游戏像素格(viewport 式)，不含任何旋转
extends Node2D

@export var leg_count: int = 6
@export var upper_len: float = 4.0
@export var lower_len_ratio: float = 1.15
@export var spread: float = 3.5
@export var gap: float = 2.0
@export var stride: float = 3.0
@export var step_time: float = 0.1
@export var thickness: int = 1
@export var hip_offset: Vector2 = Vector2.ZERO
@export var foot_y_offset: float = 0.0
@export var velocity_lead: float = 0.05
@export var leg_color: Color = Color(0.137, 0.137, 0.169)
@export var foot_color: Color = Color(0.545, 0.878, 0.541)

var _legs: Array[Dictionary] = []

@onready var _body: CharacterBody2D = get_parent() as CharacterBody2D

func _ready() -> void:
	var half: int = maxi(leg_count / 2, 1)
	for i in leg_count:
		var side: float = -1.0 if i < half else 1.0
		var leg_spread: float = side * (spread + float(i % half) * gap)
		_legs.append({
			"spread": leg_spread,
			"foot": global_position + Vector2(leg_spread, foot_y_offset),
			"from": Vector2.ZERO,
			"to": Vector2.ZERO,
			"step": -1.0,
			"group": i % 2,
		})

func _physics_process(delta: float) -> void:
	var vel_x: float = 0.0
	if _body != null:
		vel_x = _body.velocity.x
	var stepping: int = 0
	for leg in _legs:
		if float(leg["step"]) >= 0.0:
			stepping += 1
	for leg in _legs:
		var ideal: Vector2 = Vector2(
			global_position.x + float(leg["spread"]) + vel_x * velocity_lead,
			global_position.y + foot_y_offset)
		if float(leg["step"]) < 0.0:
			if stepping >= maxi(leg_count / 2, 1):
				continue
			if absf(ideal.x - (leg["foot"] as Vector2).x) <= stride:
				continue
			var group_free: bool = true
			for other in _legs:
				if other != leg and float(other["step"]) >= 0.0 and int(other["group"]) == int(leg["group"]):
					group_free = false
					break
			if group_free:
				leg["step"] = 0.0
				leg["from"] = leg["foot"]
				leg["to"] = ideal
				stepping += 1
		else:
			var p: float = minf(float(leg["step"]) + delta / step_time, 1.0)
			leg["step"] = p
			leg["foot"] = (leg["from"] as Vector2).lerp(leg["to"] as Vector2, p)
			if p >= 1.0:
				leg["step"] = -1.0
	queue_redraw()

func _draw() -> void:
	for leg in _legs:
		var hip: Vector2 = global_position + hip_offset + Vector2(float(leg["spread"]) * 0.35, 0.0)
		var foot_top: Vector2 = (leg["foot"] as Vector2) - Vector2(0.0, float(thickness) - 1.0)
		var knee: Vector2 = _solve_knee(hip, foot_top)
		_raster_line(hip, knee, leg_color)
		_raster_line(knee, foot_top, leg_color)
		_draw_cell(floori(foot_top.x), floori(foot_top.y), foot_color)

# 两段腿解析IK，返回膝盖位置(取偏上方的解)
func _solve_knee(hip: Vector2, foot: Vector2) -> Vector2:
	var l1: float = upper_len
	var l2: float = upper_len * lower_len_ratio
	var diff: Vector2 = foot - hip
	var d: float = clampf(diff.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var a: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(0.0, l1 * l1 - a * a))
	var u: Vector2 = diff.normalized()
	var k1: Vector2 = hip + u * a + Vector2(-u.y, u.x) * h
	var k2: Vector2 = hip + u * a - Vector2(-u.y, u.x) * h
	return k1 if k1.y < k2.y else k2

# Bresenham 铺格子：端点是浮点全局坐标，格子取整对齐世界像素网格
func _raster_line(from_point: Vector2, to_point: Vector2, color: Color) -> void:
	var cx: int = floori(from_point.x)
	var cy: int = floori(from_point.y)
	var ex: int = floori(to_point.x)
	var ey: int = floori(to_point.y)
	var dx: int = absi(ex - cx)
	var dy: int = -absi(ey - cy)
	var sx: int = 1 if cx < ex else -1
	var sy: int = 1 if cy < ey else -1
	var err: int = dx + dy
	for i in 256:
		_draw_cell(cx, cy, color)
		if cx == ex and cy == ey:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			cx += sx
		if e2 <= dx:
			err += dx
			cy += sy

func _draw_cell(cx: int, cy: int, color: Color) -> void:
	draw_rect(Rect2(Vector2(float(cx), float(cy)) - global_position, Vector2(float(thickness), float(thickness))), color)

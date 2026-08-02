#WebWall 从右往左封锁的蛛网墙：丝线一根根"绷紧"出现后钉死不动
#斜线全部 Bresenham 锁格光栅化(阶梯像素)，同列连续格合并成竖条 run 批量绘制
#三个伪视差层(背景/主层/前景)：绘制时按深度系数偏移镜头位移，偏移取整保持锁格
extends Node2D

const TOP_Y: int = -20
const BOTTOM_Y: int = 110
const STRAND_COLOR: Color = Color(0.909, 0.894, 0.917)
const BG_COLOR: Color = Color(0.72, 0.71, 0.75)
const FLASH_COLOR: Color = Color(1.0, 1.0, 1.0)
const SNAP_TIME: float = 0.15
const FLASH_TIME: float = 0.1
const SPACING: float = 5.0
const SLOPE_MAX: float = 16.0
const CULL_RANGE: float = 120.0

# 每层: depth 视差深度 / 透明度区间 / 粗细候选 / 底色 / 伴随主层的生成概率
const LAYERS: Array[Dictionary] = [
	{"depth": 0.82, "a_min": 0.30, "a_max": 0.50, "thicks": [1], "color": BG_COLOR, "chance": 0.65},
	{"depth": 1.00, "a_min": 0.65, "a_max": 1.00, "thicks": [1, 1, 2], "color": STRAND_COLOR, "chance": 1.0},
	{"depth": 1.15, "a_min": 0.70, "a_max": 0.95, "thicks": [2], "color": STRAND_COLOR, "chance": 0.35},
]

var front_x: float = 0.0
var _next_spawn_x: float = 0.0
var _strands: Array = []
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0

func setup(start_x: float) -> void:
	front_x = start_x
	_next_spawn_x = start_x
	_rng.randomize()

func _process(delta: float) -> void:
	_time += delta
	while _next_spawn_x >= front_x:
		for layer in LAYERS.size():
			var conf: Dictionary = LAYERS[layer]
			if _rng.randf() <= float(conf["chance"]):
				_spawn_strand(_next_spawn_x + _rng.randf_range(-3.0, 3.0), layer)
		_next_spawn_x -= SPACING
	queue_redraw()

func _spawn_strand(x: float, layer: int) -> void:
	var conf: Dictionary = LAYERS[layer]
	var top_x: int = int(x)
	var bot_x: int = int(x + _rng.randf_range(-SLOPE_MAX, SLOPE_MAX))
	var thicks: Array = conf["thicks"]
	_strands.append({
		"runs": _raster_runs(top_x, TOP_Y, bot_x, BOTTOM_Y),
		"born": _time,
		"x": top_x,
		"layer": layer,
		"alpha": _rng.randf_range(float(conf["a_min"]), float(conf["a_max"])),
		"thick": int(thicks[_rng.randi_range(0, thicks.size() - 1)]),
	})

# Bresenham 走格子，同一列的连续格合并成 Vector3i(x, y起, y止)
func _raster_runs(x0: int, y0: int, x1: int, y1: int) -> Array:
	var runs: Array = []
	var cx: int = x0
	var cy: int = y0
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var run_x: int = cx
	var run_y0: int = cy
	var prev_cy: int = cy
	for i in 512:
		if cx != run_x:
			runs.append(Vector3i(run_x, run_y0, prev_cy))
			run_x = cx
			run_y0 = cy
		prev_cy = cy
		if cx == x1 and cy == y1:
			runs.append(Vector3i(run_x, run_y0, cy))
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			cx += sx
		if e2 <= dx:
			err += dx
			cy += sy
	return runs

func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var cam_x: float = cam.global_position.x if cam != null else front_x
	# 背景 -> 主层 -> 前景 依次绘制
	for layer in LAYERS.size():
		var conf: Dictionary = LAYERS[layer]
		var depth: float = float(conf["depth"])
		var base_color: Color = conf["color"]
		# 视差偏移：screen = world - cam*depth，等价于绘制坐标整体平移 cam*(1-depth)；取整保持锁格
		var off_x: float = floorf(cam_x * (1.0 - depth))
		for s in _strands:
			if int(s["layer"]) != layer:
				continue
			if absf(float(s["x"]) + off_x - cam_x) > CULL_RANGE:
				continue
			var age: float = _time - float(s["born"])
			var prog: float = clampf(age / SNAP_TIME, 0.0, 1.0)
			var y_limit: float = float(TOP_Y) + float(BOTTOM_Y - TOP_Y) * prog
			var color: Color = FLASH_COLOR if age < SNAP_TIME + FLASH_TIME else base_color
			color.a = float(s["alpha"])
			var thick: float = float(s["thick"])
			for r in s["runs"]:
				var run: Vector3i = r
				var y0: int = mini(run.y, run.z)
				var y1: int = maxi(run.y, run.z)
				if float(y0) > y_limit:
					break
				var y_end: float = minf(float(y1) + 1.0, y_limit)
				draw_rect(Rect2(float(run.x) + off_x, float(y0), thick, y_end - float(y0)), color)

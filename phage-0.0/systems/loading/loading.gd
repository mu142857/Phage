# res://systems/loading/loading.tscn
# 开机加载屏:黑底 + "加载中...",趁黑把项目里所有"第一次用会卡一下"的东西各画一遍:
#   · 全部 GPUParticles2D(每种材质开关组合一个粒子 shader)
#   · 全部 ShaderMaterial(受击闪白、护盾壳、DreamIntro 镂空、屏幕滤镜、房间高亮…)
#   · 全部 CanvasItemMaterial(加法混合、粒子动画帧等,引擎按开关生成不同 shader)
# 每样东西在 PointLight2D 底下和没光的地方各画一份,因为 GL Compatibility 的
# canvas shader 有"有光/无光"两套特化,各自第一次画都要编译。
# 顺序:先把"加载中..."画出来 → 再加载这些场景(不能 preload,否则字还没画就先卡在加载上)
# → 预热画几帧 → 一切就绪后才淡掉"加载中",在全黑里切进房间,房间接 wake_kind="boot" 做窗户先亮的开场。
#
# 原理:Compatibility 渲染器没有预编译,shader 只在"第一次真正画到屏幕"时由驱动
# 同步编译,主线程停一下。visible=false 不会触发编译,所以用黑 ColorRect 盖住真画。
# macOS 的 OpenGL 存不了 shader 缓存,每次启动都得跑一遍,好在总共一两秒。
extends Node2D

const ROOM_SCENE := "res://levels/remi's_room/remi's_room.tscn"
## 至少画这么多帧再切场景,保证每样东西都被处理+绘制过
const WARM_FRAMES := 4
## 加载屏最短停留(秒),免得"加载中"只闪一下
const MIN_SHOW_TIME := 0.4
## "加载中..."淡出成全黑的时长
const FADE_OUT_TIME := 0.5

## 所有带粒子/材质的场景(路径,加载屏画出来之后才 load)。不进树实例化,把粒子节点和材质抠出来复制一份画,原场景脚本不会跑。
## 新做的怪/子弹/特效只要带 GPUParticles2D 或 ShaderMaterial 就往这里补一行;
## 编辑器里跑会扫 entities/interactive/systems/asstes 目录提醒漏掉的。
## levels/ 里的常驻粒子和关卡专用 shader 随关卡在 DreamIntro 黑幕下加载编译,不登记。
const WARM_SCENE_PATHS: Array[String] = [
	# 独立粒子特效
	# 珊瑚摇篮杂兵(cradle_mobs)
	"res://entities/cradle_mobs/worm_wall/worm_wall_death.tscn",
	"res://entities/cradle_mobs/anemone/anemone_death.tscn",
	"res://entities/cradle_mobs/anemone/anemone_bullet_explosion.tscn",
	"res://entities/cradle_mobs/earthworm/earthworm_death.tscn",
	"res://entities/cradle_mobs/earthworm/earthworm_stomp.tscn",
	"res://entities/cradle_mobs/splitter/splitter_death.tscn",
	"res://entities/cradle_mobs/splitter/splitter_bullet_explosion.tscn",
	"res://entities/cradle_mobs/sprayer/sprayer_death.tscn",
	"res://systems/oxygen/oxygen_overlay.tscn",
	"res://entities/actinos/actinos_death_effect.tscn",
	"res://entities/actinos/actinos_jump_effect.tscn",
	"res://entities/octopus/octopus_bullet_land.tscn",
	"res://entities/azure_warlord/azure_bullet_effects.tscn",
	"res://entities/azure_warlord/azure_warlord_death_effect.tscn",
	"res://entities/bloodworm/bloodworm_death.tscn",
	"res://entities/cox/cox_death.tscn",
	"res://entities/cursed_stone/cursed_stone_death.tscn",
	"res://entities/wooden_man/wooden_man_death.tscn",
	"res://entities/penitent/big_sickle_effect.tscn",
	"res://entities/penitent/mid_sickle_effect.tscn",
	"res://entities/penitent/small_sickle_effect.tscn",
	"res://entities/player/BuffEffect/crystal_dash_effect.tscn",
	"res://entities/player/BuffEffect/fire_aura_effect.tscn",
	"res://entities/player/BuffEffect/green_shield_break_effect.tscn",
	"res://entities/player/BuffEffect/lamp_ignite_effect.tscn",
	"res://entities/player/BuffEffect/muzi_revive_effect.tscn",
	"res://entities/player/BuffEffect/shield_ready_effect.tscn",
	"res://entities/player/BuffEffect/table_aura_effect.tscn",
	"res://entities/player/BuffEffect/tide_aura_effect.tscn",
	"res://entities/player/attack_effect.tscn",
	"res://entities/player/jump_attack_effect.tscn",
	"res://entities/player/player_death_effect.tscn",
	"res://entities/player/player_jumping_effect.tscn",
	"res://entities/player/player_walking_effect.tscn",
	"res://entities/player/shield_player_jumping_effect.tscn",
	"res://entities/pop_tops/pop_tops_bullet_effects.tscn",
	"res://entities/pop_tops/pop_tops_death.tscn",
	"res://entities/rust_goat/basketball_land.tscn",
	"res://entities/slime/big_slime_death.tscn",
	"res://entities/slime/mid_slime_death.tscn",
	"res://entities/slime/mini_slime_death.tscn",
	"res://entities/spider/spider_1_death.tscn",
	"res://entities/spider/spider_2_death.tscn",
	"res://entities/spider/spider_3_death.tscn",
	"res://entities/spider/spider_spit_effect.tscn",
	"res://entities/wound_mobs/blood_mage/blood_mage_death.tscn",
	"res://entities/wound_mobs/blood_maggot/blood_maggot_death.tscn",
	"res://entities/wound_mobs/blood_spider/blood_spider_death.tscn",
	"res://entities/wound_mobs/spike_tentacle/spike_tentacle_death.tscn",
	"res://entities/wound_mobs/spitter_tentacle/spitter_tentacle_bullet_explosion.tscn",
	"res://entities/wound_mobs/spitter_tentacle/spitter_tentacle_death.tscn",
	"res://entities/wowen/wowen_death.tscn",
	"res://levels/silvaron/leaf_1.tscn",
	# 子弹 / 道具(内嵌粒子)
	"res://entities/actinos/actinos_bullet.tscn",
	"res://entities/octopus/octopus_bullet.tscn",
	"res://entities/octopus/octopus_laser.tscn",
	"res://entities/azure_warlord/azure_bullet.tscn",
	"res://entities/bloodworm/bloodworm_laser.tscn",
	"res://entities/broken_wall/broken_wall_001.tscn",
	"res://entities/cox/cox_bullet.tscn",
	"res://entities/pop_tops/pop_tops_bullet.tscn",
	"res://entities/rust_goat/basket_ball.tscn",
	"res://entities/spider/spider_spit.tscn",
	"res://entities/wound_mobs/blood_mage/blood_mage_bolt.tscn",
	"res://entities/wound_mobs/blood_mage/blood_mage_heal_bolt.tscn",
	"res://interactive/Bonfire/bonfire.tscn",
	# 主角 / 怪 / Boss(受击闪白等 ShaderMaterial,部分内嵌粒子)
	"res://entities/player/player.tscn",
	"res://entities/actinos/actinos.tscn",
	"res://entities/octopus/octopus.tscn",
	"res://entities/azure_warlord/azure_warlord.tscn",
	"res://entities/bloodworm/bloodworm.tscn",
	"res://entities/calendula/calendula.tscn",
	"res://entities/cox/cox.tscn",
	"res://entities/cox/pinkland_cox.tscn",
	"res://entities/cox/week_cox.tscn",
	"res://entities/cursed_stone/cursed_stone.tscn",
	"res://entities/penitent/penitent.tscn",
	"res://entities/pop_tops/pop_tops.tscn",
	"res://entities/rust_goat/rust_goat.tscn",
	"res://entities/slime/big_slime.tscn",
	"res://entities/slime/mid_slime.tscn",
	"res://entities/slime/mini_slime.tscn",
	"res://entities/spider/spider_1.tscn",
	"res://entities/spider/spider_2.tscn",
	"res://entities/spider/spider_3.tscn",
	"res://entities/wound_mobs/blood_mage/blood_mage.tscn",
	"res://entities/wound_mobs/blood_maggot/blood_maggot.tscn",
	"res://entities/wound_mobs/blood_spider/blood_spider.tscn",
	"res://entities/wound_mobs/spike_tentacle/spike_tentacle.tscn",
	"res://entities/wound_mobs/spitter_tentacle/spitter_tentacle.tscn",
	"res://entities/wowen/wowen.tscn",
	# 系统 / 屏幕效果
	"res://systems/game.tscn",
	"res://systems/dream_intro/dream_intro.tscn",
	"res://asstes/shaders/screen_filters/screen_frame.tscn",
	"res://asstes/shaders/smokes/back_ground_smoke.tscn",
]

## 只在代码里临时 new 出来用的 shader(场景里搜不到),这里直接登记 .gdshader 路径
const WARM_SHADER_PATHS: Array[String] = [
	"res://levels/remi's_room/highlight.gdshader",
]

@onready var _warm_lit: Node2D = $WarmLit
@onready var _warm_unlit: Node2D = $WarmUnlit
@onready var _label: Label = $Cover/Label

var _white_tex: ImageTexture


func _ready() -> void:
	# 先让"加载中..."真的画到屏幕上(两帧),后面的加载和编译都会卡主线程,字得先在
	await get_tree().process_frame
	await get_tree().process_frame
	var start_ms := Time.get_ticks_msec()
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white_tex = ImageTexture.create_from_image(img)

	# ① 加载:所有要预热的场景 + 房间本身(切场景时就不用再读盘)
	var scenes: Array[PackedScene] = []
	for path in WARM_SCENE_PATHS:
		var scene := load(path) as PackedScene
		if scene != null:
			scenes.append(scene)
	var shaders: Array[Shader] = []
	for path in WARM_SHADER_PATHS:
		var shader := load(path) as Shader
		if shader != null:
			shaders.append(shader)
	var room := load(ROOM_SCENE) as PackedScene
	var load_ms := Time.get_ticks_msec() - start_ms

	# ② 预热:画几帧让 shader 编译
	var counts := _spawn_all(scenes, shaders)
	for i in WARM_FRAMES:
		await get_tree().process_frame
	print("[Loading] 加载 %d 个场景 %d ms;预热 %d 个粒子 + %d 个材质(有光/无光各一份),共 %d ms" % [
		scenes.size(), load_ms, counts[0], counts[1], Time.get_ticks_msec() - start_ms])
	if OS.has_feature("editor"):
		_report_missing_scenes()
	_warm_lit.queue_free()
	_warm_unlit.queue_free()

	# ③ 全部就绪,才开始渐变:"加载中..."淡成全黑 → 黑里切房间,房间接 boot 让窗户先亮
	if Time.get_ticks_msec() - start_ms < MIN_SHOW_TIME * 1000.0:
		await get_tree().create_timer(MIN_SHOW_TIME - float(Time.get_ticks_msec() - start_ms) / 1000.0).timeout
	var fade := create_tween()
	fade.tween_property(_label, "modulate:a", 0.0, FADE_OUT_TIME)
	await fade.finished
	Game.buff_hold.hide_now()  # 左上角 HUD 跟房间一起从黑里浮现,不能先亮
	# Godot 换场景有一帧"旧场景已卸、新场景还没挂",会露出视口清屏色(灰)。
	# 用 Game 常驻的黑遮罩盖过这一帧(梦→房间同一套),房间摆好黑之后由 Story.release_cover() 撤掉。
	await Game.fade_cover(1.0, 0.0)
	Story.wake_kind = "boot"
	if room != null:
		get_tree().change_scene_to_packed(room)
	else:
		get_tree().change_scene_to_file(ROOM_SCENE)


## 把每个场景里的粒子和材质抠出来,在有光/无光两个容器里各画一份。返回 [粒子数, 材质数]。
func _spawn_all(scenes: Array[PackedScene], shaders: Array[Shader]) -> Array[int]:
	var particles: Array[GPUParticles2D] = []
	var materials: Array[Material] = []
	var seen := {}  # 同一个 Shader 资源只需编译一次,按 shader/材质去重
	var instances: Array[Node] = []
	for scene in scenes:
		var inst := scene.instantiate()  # 不进树 → 脚本 _ready 不跑
		instances.append(inst)
		_collect(inst, particles, materials, seen)
	for shader in shaders:
		if seen.has(shader):
			continue
		seen[shader] = true
		var mat := ShaderMaterial.new()
		mat.shader = shader
		materials.append(mat)

	for container in [_warm_lit, _warm_unlit]:
		for p in particles:
			# flags=0:不带脚本/信号/分组,只剩引擎属性,拿到和原件一模一样的材质组合
			var copy := p.duplicate(0) as GPUParticles2D
			if copy == null:
				continue
			copy.visible = true
			copy.position = Vector2.ZERO
			copy.process_mode = Node.PROCESS_MODE_INHERIT
			container.add_child(copy)
			copy.emitting = true
		for mat in materials:
			var sprite := Sprite2D.new()
			sprite.texture = _white_tex
			sprite.material = mat
			container.add_child(sprite)
	for inst in instances:
		inst.free()
	return [particles.size(), materials.size()]


func _collect(node: Node, particles: Array[GPUParticles2D], materials: Array[Material], seen: Dictionary) -> void:
	if node is GPUParticles2D:
		particles.append(node as GPUParticles2D)
	elif node is CanvasItem:
		var mat := (node as CanvasItem).material
		if mat != null:
			var key: Variant = (mat as ShaderMaterial).shader if mat is ShaderMaterial else mat
			if key != null and not seen.has(key):
				seen[key] = true
				materials.append(mat)
	for child in node.get_children():
		_collect(child, particles, materials, seen)


## 仅编辑器:扫目录找带粒子/材质但没登记进 WARM_SCENE_PATHS 的场景,提醒补上。
func _report_missing_scenes() -> void:
	var known := {}
	for path in WARM_SCENE_PATHS:
		known[path] = true
	known["res://systems/loading/loading.tscn"] = true
	var missing: Array[String] = []
	for dir in ["res://entities", "res://interactive", "res://systems", "res://asstes"]:
		_scan_dir(dir, known, missing)
	if not missing.is_empty():
		push_warning("[Loading] 这些场景带粒子/材质但没登记进 loading.gd 的 WARM_SCENE_PATHS,第一次用会卡:\n  " + "\n  ".join(missing))


func _scan_dir(path: String, known: Dictionary, missing: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_scan_dir(full, known, missing)
		elif name.ends_with(".tscn") and not known.has(full):
			var text := FileAccess.get_file_as_string(full)
			if text.contains("Particles2D") or text.contains("ShaderMaterial") or text.contains("CanvasItemMaterial"):
				missing.append(full)
		name = dir.get_next()
	dir.list_dir_end()

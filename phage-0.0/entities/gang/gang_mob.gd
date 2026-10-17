# 奥斯卡帮(黑衣人)小怪的公共底子(收钱小弟/刀仔/井盖盾兵/扔瓶子的/大块头/放哨的都从这儿派生)。
# 红眼睛和红围巾在单独的 Glow 层(不吃灯光、按场景压暗补亮),黑的地方也一眼看得见。
# 喊话:shout(事件) 从 _lines() / COMMON_LINES 里挑一句,同时最多两个人在说话,字不叠在一起。
# 贴图朝右画,翻面 = AnimatedSprite2D 和 AttackCheck 的 scale.x 一起取反(判定跟着镜像)。
# 原点在脚底,贴图最后一行落在地面线上面一行。
# 状态:FALL(从天上掉下来)→ LAND(落地蹲一下)→ ENGAGE(各怪自己的打法,_engage 里写)
#      ATTACK(播一段攻击动画,hit_frames 那几帧用 AttackCheck 判定一次)/ CUSTOM(子类自己管)。
# 动画都是 10 帧/秒等长(奥斯卡的节奏),没导帧的动画名一律跳过不报错。
# 阵营:奥斯卡帮(gang)和管道局(bureau,BureauMob 从这儿派生)水火不容——foe() 在主角和对面阵营的人里
# 挑最近的打;近战砍到对面的人走 take_hit,对面的投射物打到也走 take_hit(不算队友伤害)。
class_name GangMob
extends CharacterBody2D

signal died(mob: GangMob)

const DEATH_SCENE: PackedScene = preload("res://entities/gang/gang_death.tscn")
const COIN_SCENE: PackedScene = preload("res://entities/gang/coin/coin_pickup.tscn")
const FONT: FontFile = preload("res://asstes/fonts/PixelFont.ttf")
const BARK_COLOR := Color(0.95, 0.86, 0.78)

# 所有黑衣人都会说的;子类 _lines() 里同名的事件会盖掉这里的
const COMMON_LINES := {
	"spot": ["站住！", "交钱！", "奥斯卡帮！", "哪来的？"],
	"attack": ["看招！", "嘿！"],
	"hurt": ["哎哟！", "敢打我？", "疼！"],
	"die": ["呃啊——", "记住你了……", "告诉老大……", "我的钱……"],
	"buddy_down": ["兄弟！", "你完了！", "给我上！"],
	"player_hit": ["交不交？", "服不服？", "哈！"],
	"friendly_hit": ["喂！看着点！", "打我干嘛？！", "瞎了啊？！", "自己人！"],
	"friendly_reply": ["让开！", "谁让你站那！", "……手滑。", "活该。"],
	"chat": ["好无聊……", "钱真难收。", "哈——欠", "下雨了？", "黑衣服显脏。"],
	"foe_spot": ["铁罐头！", "管道局的狗！", "砸罐头！", "是管道局！"],
}
# 两个黑衣人蹲在一起时的闲聊(甲说一句,乙接一句)。主角走到看得见、还没惊动他们的距离就能听到。
const CHATS := [
	["今天收了几个？", "一个都没。"],
	["老大说加班。", "又加班……"],
	["这袍子好热。", "帅就行。"],
	["我们叫啥来着？", "奥斯卡帮。"],
	["为啥穿黑的？", "显瘦。"],
	["围巾歪了。", "……谢了。"],
	["那边有人。", "……别看他。"],
	["下水道那帮又涨价了。", "一群死板的。"],
	["那帮人走路一个步子。", "……怪吓人的。"],
	["他们老大是粉头发？", "别提她。"],
]
const MAX_TALKING := 2
static var _talking := {}   # 正在说话的:实例 id → 说到什么时候(毫秒)

@export var max_health: int = 300
@export var gravity: float = 850.0
@export var move_speed: float = 30.0
## 离主角多远就开始找他(伏击巷是封闭的,默认整条巷子都算)
@export var aggro_range: float = 400.0
@export var attack_range: float = 22.0
@export var attack_cooldown: float = 1.2
@export var attack_anim: StringName = &"Attack"
## Attack 动画里哪几帧有判定(0 起数),一次攻击只打中一下
@export var hit_frames: PackedInt32Array = PackedInt32Array([7, 8])
@export var knockback_speed: float = 70.0
@export var knockback_duration: float = 0.1
## 大块头:挨打不后退
@export var heavy: bool = false
## 从屏幕上面掉下来出场
@export var drop_in: bool = false
## 空降时落在消防梯这种单向平台上(默认穿过去落到地面)
@export var land_on_platforms: bool = false
@export var edge_probe_distance: float = 8.0
## 前面往下落差不超过这么多就照走(从木托盘、箱子上走下来),再高就站住
@export var max_step_down: float = 14.0
## 死亡方块粒子数量(体型大就多给点)
@export var death_amount: int = 18
@export var death_height: float = 10.0
## 头顶冒字的高度
@export var bark_height: float = 26.0
## 蹲在巷子角落的:只在出生点左右这么远里活动,主角走出 aggro_range 就回原地(0 = 不管,伏击战用)
@export var leash: float = 0.0
## 死了掉几个铜板
@export var coins: int = 0
## 近战砍到对面阵营的人扣多少血(打主角永远是 1 下)
@export var mob_damage: int = 50

enum S { FALL, LAND, ENGAGE, ATTACK, CUSTOM }

## 小游戏进行时(赛跑/陪练…)角落里的怪全都不理人,免得半路杀出来
static var truce := false

var state: S = S.ENGAGE
var health: int = 0
var facing: float = 1.0
var cooldown: float = 0.0
var _hit_done: bool = false
var _knock_left: float = 0.0
var _knock_vx: float = 0.0
var _once_anim: StringName = &""
var _once_then: Callable = Callable()
var _bark: Label = null
var _bark_tween: Tween = null
var _passed_platforms: Array = []
var home_x: float = 0.0
var _shout_cd := 0.0
var _chat_cd := 0.0
var _spotted := false
var _foe: Node2D = null
var _foe_hold := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_player: AnimationPlayer = get_node_or_null("HitEffectPlayer") as AnimationPlayer
@onready var attack_check: Area2D = get_node_or_null("AttackCheck") as Area2D
@onready var glow: AnimatedSprite2D = get_node_or_null("Glow") as AnimatedSprite2D


func _ready() -> void:
	add_to_group("monster")
	add_to_group(faction())
	health = max_health
	home_x = global_position.x
	if sprite.material != null:
		sprite.material = sprite.material.duplicate()
		if sprite.material is ShaderMaterial:
			(sprite.material as ShaderMaterial).set_shader_parameter("Enabled", false)
	sprite.animation_finished.connect(_on_animation_finished)
	_make_bark()
	if glow != null:
		glow.stop()
		glow.modulate = Color(_ambient_comp(0.95), _ambient_comp(0.95), _ambient_comp(0.95), 1.0)
	_chat_cd = randf_range(1.0, 4.0)
	var p := player()
	if p != null:
		face(signf(p.global_position.x - global_position.x))
	if drop_in:
		state = S.FALL
		play(&"Fall")
		if not land_on_platforms:
			_pass_platforms(true)
	else:
		_start()


## 子类:不是空降时一开场干什么(默认直接开打)
func _start() -> void:
	state = S.ENGAGE


func _process(delta: float) -> void:
	# 发光层跟着本体的动画/帧/朝向走
	if glow != null:
		if glow.animation != sprite.animation:
			glow.animation = sprite.animation
		glow.frame = sprite.frame
		glow.scale = sprite.scale
		glow.visible = sprite.visible
	_shout_cd = maxf(0.0, _shout_cd - delta)
	if _bark != null and _bark.visible:
		_keep_bark_on_screen()


# 人在屏幕外说话:字贴着屏幕边出来(像拐角那边有人在聊天),不会被切掉
func _keep_bark_on_screen() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var inv := vp.get_canvas_transform().affine_inverse()
	var left := (inv * Vector2.ZERO).x + 1.0
	var right := (inv * vp.get_visible_rect().size).x - 1.0
	var w := FONT.get_string_size(_bark.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var cx := global_position.x
	var half := w / 2.0
	cx = clampf(cx, left + half, right - half)
	_bark.global_position.x = roundf(cx - 40.0)


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 420.0)
	cooldown = maxf(0.0, cooldown - delta)
	_foe_hold = maxf(0.0, _foe_hold - delta)
	if _knock_left > 0.0:
		_knock_left = maxf(0.0, _knock_left - delta)
		velocity.x = _knock_vx
		if _knock_left <= 0.0:
			velocity.x = 0.0
	else:
		match state:
			S.FALL:
				velocity.x = 0.0
				if is_on_floor():
					_land()
			S.LAND:
				velocity.x = 0.0
			S.ENGAGE:
				if _asleep():
					_go_home()
					_chat_tick(delta)
				else:
					if not _spotted:
						_spotted = true
						_on_spotted()
					_engage(delta)
			S.ATTACK:
				_attack_tick(delta)
			S.CUSTOM:
				_custom_tick(delta)
	# 角落里的怪不离开自己那一块
	if leash > 0.0 and state != S.FALL:
		var off := global_position.x - home_x
		if (off > leash and velocity.x > 0.0) or (off < -leash and velocity.x < 0.0):
			velocity.x = 0.0
	move_and_slide()


## 第一次发现要打的人时喊一声
func _on_spotted() -> void:
	shout("spot", 0.85)


## 角落里的怪:主角不在跟前就不理他
func _asleep() -> bool:
	if leash <= 0.0:
		return false
	if truce:
		return true
	var p := player()
	if p == null:
		return true
	return absf(p.global_position.x - home_x) > aggro_range or absf(p.global_position.y - global_position.y) > 40.0


func _go_home() -> void:
	var dx := home_x - global_position.x
	if absf(dx) > 3.0:
		face(signf(dx))
		walk(facing, move_speed)
	else:
		velocity.x = 0.0
		play(&"Idle")


# ------------------------------------------------------------------ 出场
func _land() -> void:
	_pass_platforms(false)
	state = S.LAND
	# 伏击战每波第一个落地的喊一句(back_alley_ambush 设的)
	if has_meta("entry_line"):
		_spotted = true
		say(String(get_meta("entry_line")))
	_on_landed()
	play_once(&"Land", _after_land)


## 子类:落地那一下(大块头震屏)
func _on_landed() -> void:
	pass


## 子类:落地站稳以后(小弟先喊一声"交钱!")
func _after_land() -> void:
	state = S.ENGAGE


## 下落时穿过单向平台(drop_through_platform 那种 StaticBody2D),落地后恢复
func _pass_platforms(on: bool) -> void:
	if on:
		var scene := get_tree().current_scene
		if scene == null:
			return
		for n in scene.find_children("*", "StaticBody2D", true, false):
			if n.has_method("_drop"):
				add_collision_exception_with(n)
				_passed_platforms.append(n)
	else:
		for n in _passed_platforms:
			if is_instance_valid(n):
				remove_collision_exception_with(n)
		_passed_platforms.clear()


# ------------------------------------------------------------------ 打法(子类覆盖)
## 默认:走到跟前,冷却好了就打。
func _engage(_delta: float) -> void:
	var p := foe()
	if p == null:
		velocity.x = 0.0
		play(&"Idle")
		return
	var dx := p.global_position.x - global_position.x
	if absf(dx) > aggro_range:
		velocity.x = 0.0
		play(&"Idle")
		return
	if absf(dx) > 2.0:
		face(signf(dx))
	if absf(dx) <= attack_range:
		velocity.x = 0.0
		if cooldown <= 0.0:
			start_attack()
		else:
			play(&"Idle")
		return
	walk(facing, move_speed)


func _custom_tick(_delta: float) -> void:
	pass


## 往 dir 走;前面没地就站住。前面贴着同伙就排队等着,不挤成一坨。
func walk(dir: float, speed: float, anim: StringName = &"Walk") -> void:
	if floor_ahead(dir) and not buddy_ahead(dir):
		velocity.x = dir * speed + _separation()
		play(anim)
	else:
		velocity.x = _separation()
		play(&"Idle")


## 正前方 gap 格以内有没有站在地上的同伙
func buddy_ahead(dir: float, gap: float = 10.0) -> bool:
	for n in get_tree().get_nodes_in_group(faction()):
		if n == self or not (n is GangMob):
			continue
		var m := n as GangMob
		var dx := (m.global_position.x - global_position.x) * dir
		if dx > 0.0 and dx < gap and absf(m.global_position.y - global_position.y) < 6.0:
			return true
	return false


## 叠在一起(掉在同一个地方)时慢慢错开
func _separation() -> float:
	var push := 0.0
	for n in get_tree().get_nodes_in_group(faction()):
		if n == self or not (n is Node2D):
			continue
		var dx := global_position.x - (n as Node2D).global_position.x
		if absf(dx) < 4.0:
			push += (1.0 if dx > 0.0 or (dx == 0.0 and get_instance_id() > n.get_instance_id()) else -1.0) * 12.0
	return push


# ------------------------------------------------------------------ 攻击
func start_attack(anim: StringName = &"") -> void:
	if anim == &"":
		anim = attack_anim
	state = S.ATTACK
	_hit_done = false
	velocity.x = 0.0
	shout("attack", 0.35)
	_on_attack_started()
	play_once(anim, _end_attack)


func _on_attack_started() -> void:
	pass


func _attack_tick(_delta: float) -> void:
	velocity.x = 0.0
	if sprite.animation == attack_anim and sprite.frame in hit_frames:
		try_hit()


## AttackCheck 里的主角挨一下、对面阵营的人各挨一下(一次攻击只结算一次)
func try_hit() -> bool:
	if _hit_done or attack_check == null:
		return false
	var hit := false
	for body in attack_check.get_overlapping_bodies():
		if body == null or body == self:
			continue
		if body.is_in_group("player"):
			if hostile_to_player() and body.has_method("take_damage"):
				body.call("take_damage", 1)
				hit = true
				shout("player_hit", 0.6)
		elif is_enemy(body):
			(body as GangMob).take_hit(mob_damage, global_position.x, self)
			hit = true
	if hit:
		_hit_done = true
	return hit


func _end_attack() -> void:
	cooldown = attack_cooldown
	state = S.ENGAGE


# ------------------------------------------------------------------ 挨打 / 死
func take_damage(value: int) -> void:
	if health <= 0:
		return
	if _blocks(value):
		return
	health = maxi(health - value, 0)
	if hit_player != null:
		if not hit_player.active:
			hit_player.active = true
		hit_player.play(&"HitFlash")
	_on_hurt()
	if health <= 0:
		_die()
		return
	shout("hurt", 0.3)
	if not heavy:
		_knockback()


## 子类:要不要挡下这一刀(井盖盾兵)
func _blocks(_value: int) -> bool:
	return false


## 子类:从 from_x 那边打过来的东西挡不挡得住(队友伤害用)
func _blocks_from(_from_x: float) -> bool:
	return false


## 被对面阵营的人砍/射/砸到(两帮打架)。挡得住就挡;被谁打了就先回头打谁。
func take_hit(value: int, from_x: float, attacker: Node = null) -> void:
	if health <= 0 or _blocks_from(from_x):
		return
	health = maxi(health - value, 0)
	if hit_player != null:
		if not hit_player.active:
			hit_player.active = true
		hit_player.play(&"HitFlash")
	_on_hurt()
	if health <= 0:
		_die()
		return
	shout("hurt", 0.25)
	if not heavy:
		var dir := signf(global_position.x - from_x)
		_knock_left = knockback_duration
		_knock_vx = knockback_speed * (dir if dir != 0.0 else 1.0)
	if is_instance_valid(attacker) and attacker is GangMob:
		_foe = attacker as Node2D
		_foe_hold = 1.5


## 被自己人扔的瓶子/射的箭/踹的桶/砸的震波打到。奥斯卡帮是混乱邪恶:队友伤害开着。
## 挨打的骂一句,动手的回一句。(动手的是对面阵营的人 = 正常挨打,走 take_hit)
func take_friendly(value: int, from_x: float, attacker: Node = null) -> void:
	if is_instance_valid(attacker) and is_enemy(attacker):
		take_hit(value, from_x, attacker)
		return
	if health <= 0 or _blocks_from(from_x):
		return
	health = maxi(health - value, 0)
	if hit_player != null:
		if not hit_player.active:
			hit_player.active = true
		hit_player.play(&"HitFlash")
	if health <= 0:
		if is_instance_valid(attacker) and attacker is GangMob:
			(attacker as GangMob).say_later(["……手滑。", "……", "他自己撞上来的！"][randi() % 3], 0.5)
		_die()
		return
	if not heavy:
		var dir := signf(global_position.x - from_x)
		_knock_left = knockback_duration
		_knock_vx = knockback_speed * (dir if dir != 0.0 else 1.0)
	shout("friendly_hit", 0.85, true)
	if is_instance_valid(attacker) and attacker is GangMob and attacker != self:
		var a := attacker as GangMob
		get_tree().create_timer(1.1).timeout.connect(func() -> void:
			if is_instance_valid(a):
				a.shout("friendly_reply", 0.7))


## 隔一会儿再说(死人的同伙接话之类)
func say_later(text: String, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_instance_valid(self) and health > 0:
			say(text))


func _on_hurt() -> void:
	pass


func _knockback() -> void:
	if Game.suppress_hit_knockback:
		return
	var p := player()
	var dir := -facing
	if p != null:
		dir = signf(global_position.x - p.global_position.x)
		if dir == 0.0:
			dir = -facing
	_knock_left = knockback_duration
	_knock_vx = knockback_speed * dir


func _die() -> void:
	died.emit(self)
	_talking.erase(get_instance_id())
	_last_words()
	# 旁边的同伙喊一声
	var best: GangMob = null
	for n in get_tree().get_nodes_in_group(faction()):
		if n != self and n is GangMob and (n as GangMob).health > 0:
			var d := absf((n as Node2D).global_position.x - global_position.x)
			if d < 110.0 and (best == null or d < absf(best.global_position.x - global_position.x)):
				best = n
	if best != null:
		best.shout("buddy_down", 0.75)
	var scene := get_tree().current_scene
	if scene != null and _death_scene() != null:
		var fx := _death_scene().instantiate() as GPUParticles2D
		scene.add_child(fx)
		fx.global_position = global_position
		fx.amount = death_amount
		var mat := fx.process_material as ParticleProcessMaterial
		if mat != null:
			mat = mat.duplicate() as ParticleProcessMaterial
			mat.emission_shape_offset = Vector3(0.0, -death_height, 0.0)
			mat.emission_box_extents = Vector3(death_height * 0.5, death_height, 1.0)
			fx.process_material = mat
		fx.emitting = true
	if scene != null and coins > 0:
		for i in coins:
			var c := COIN_SCENE.instantiate() as Node2D
			c.position = global_position + Vector2(0.0, -8.0)
			c.set("velocity", Vector2(randf_range(-45.0, 45.0), randf_range(-150.0, -90.0)))
			# 可能是在物理回调里死的(被弩箭/瓶子打死):铜板是 Area2D,下一帧再放进场景
			scene.add_child.call_deferred(c)
	queue_free()


# ------------------------------------------------------------------ 喊话
func _death_scene() -> PackedScene:
	return DEATH_SCENE


## 子类:自己的台词,{事件: [句子...]};没写的事件用 _common_lines()
func _lines() -> Dictionary:
	return {}


## 阵营通用台词(管道局换一套)
func _common_lines() -> Dictionary:
	return COMMON_LINES


## 两人闲聊的一问一答
func _chats() -> Array:
	return CHATS


func lines_for(event: String) -> Array:
	var own := _lines()
	if own.has(event):
		return own[event]
	return _common_lines().get(event, [])


## 按事件喊一句。chance = 这次喊不喊的概率;force = 不管冷却和"同时最多两个人说话"
func shout(event: String, chance := 1.0, force := false) -> bool:
	if health <= 0:
		return false
	if not force and (_shout_cd > 0.0 or randf() > chance):
		return false
	var pool := lines_for(event)
	if pool.is_empty():
		return false
	return say(String(pool[randi() % pool.size()]), force)


## 直接喊这句(受"同时最多两个人说话"管,force 除外)。对话框开着的时候谁都不喊(字会叠在对话框上)
func say(text: String, force := true) -> bool:
	if Dialogue.is_open:
		return false
	var now := Time.get_ticks_msec()
	var busy := 0
	for k in _talking.keys():
		if int(_talking[k]) > now and k != get_instance_id():
			busy += 1
		elif int(_talking[k]) <= now:
			_talking.erase(k)
	if busy >= MAX_TALKING and not force:
		return false
	bark(text, 1.1)
	_talking[get_instance_id()] = now + 1400
	_shout_cd = 2.2
	return true


# 角落里没惊动的时候:主角在看得见的地方,就听得到他们聊天
func _chat_tick(delta: float) -> void:
	if truce or not _can_chat():
		return
	var p := player()
	if p == null:
		return
	var dx := absf(p.global_position.x - global_position.x)
	if dx > 150.0 or dx < aggro_range * 0.6:
		return
	_chat_cd -= delta
	if _chat_cd > 0.0:
		return
	_chat_cd = randf_range(4.5, 7.5)
	# 旁边有同伙就俩人一问一答,没有就自己嘀咕
	var buddy: GangMob = null
	for n in get_tree().get_nodes_in_group(faction()):
		# 只找站着闲着的同伙(还装成垃圾袋的放哨的不算,一接话就露馅了)
		if n != self and n is GangMob and (n as GangMob).health > 0 and (n as GangMob)._can_chat() \
				and (n as GangMob).state == S.ENGAGE and (n as GangMob)._asleep() \
				and absf((n as Node2D).global_position.x - global_position.x) < 50.0:
			buddy = n
			break
	if buddy != null:
		var pair: Array = _chats()[randi() % _chats().size()]
		if not say(String(pair[0]), false):
			return
		buddy._chat_cd = maxf(buddy._chat_cd, 3.0)
		get_tree().create_timer(1.4).timeout.connect(func() -> void:
			if is_instance_valid(buddy) and buddy.health > 0 and buddy.state != S.ATTACK:
				buddy.say(String(pair[1])))
	else:
		shout("chat", 0.8)


## 角落里蹲着的(有 leash)才闲聊;管道局站岗的也聊
func _can_chat() -> bool:
	return leash > 0.0


# 死的时候最后一句话:人没了字还在,飘一下淡掉
func _last_words() -> void:
	if randf() > 0.6:
		return
	var pool := lines_for("die")
	if pool.is_empty():
		return
	var parent := get_parent()
	if parent == null:
		return
	var l := Label.new()
	l.text = String(pool[randi() % pool.size()])
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", BARK_COLOR)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(80, 12)
	l.z_index = 30
	l.light_mask = 0
	var k := _ambient_comp(0.9)
	l.modulate = Color(k, k, k, 1.0)
	parent.add_child(l)
	# 比头顶的话高一截,不和别人正在喊的叠在一起
	l.global_position = global_position + Vector2(-40, -bark_height - 24.0)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 6.0, 1.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.tween_callback(l.queue_free)


## 场景压暗(CanvasModulate)补偿:让不吃灯光的东西(字、红眼睛)最后亮到 target 左右
func _ambient_comp(target: float) -> float:
	var scene: Node = self
	while scene.get_parent() != null and scene.get_parent() != get_tree().root:
		scene = scene.get_parent()
	for c in scene.get_children():
		if c is CanvasModulate:
			return clampf(target / maxf((c as CanvasModulate).color.r, 0.2), 1.0, 3.0)
	return 1.0


# ------------------------------------------------------------------ 阵营
func faction() -> StringName:
	return &"gang"


func enemy_faction() -> StringName:
	return &"bureau" if faction() == &"gang" else &"gang"


## 主角算不算敌人(管道局交过钱就不算)
func hostile_to_player() -> bool:
	return true


func is_enemy(n: Variant) -> bool:
	return is_instance_valid(n) and n is GangMob and (n as GangMob).faction() != faction() \
		and (n as GangMob).health > 0


## 现在要打谁:主角或对面阵营的人,挑离得近的;选中了先盯一秒,不来回换。
## 主角只看左右距离(和以前一样);对面阵营的人要差不多一样高才算。
func foe() -> Node2D:
	if _foe_hold > 0.0 and _foe_ok(_foe):
		return _foe
	var best: Node2D = null
	var best_d := INF
	var p := player()
	if p != null and hostile_to_player():
		var d := absf(p.global_position.x - global_position.x)
		if d <= aggro_range:
			best = p
			best_d = d
	for n in get_tree().get_nodes_in_group(enemy_faction()):
		var m := n as GangMob
		if m == null or m.health <= 0 or m.state == S.FALL:
			continue
		var d := absf(m.global_position.x - global_position.x)
		if d > aggro_range or d >= best_d or absf(m.global_position.y - global_position.y) > 40.0:
			continue
		best = m
		best_d = d
	if best != null and best != _foe and best is GangMob:
		shout("foe_spot", 0.5)
	_foe = best
	_foe_hold = 1.0
	return best


func _foe_ok(n: Variant) -> bool:
	if not is_instance_valid(n):
		return false
	if n is GangMob:
		return (n as GangMob).health > 0
	return n.is_in_group("player") and hostile_to_player() and n.get("is_dying") != true


# ------------------------------------------------------------------ 小工具
func player() -> Node2D:
	var list := get_tree().get_nodes_in_group("player")
	if list.is_empty():
		return null
	var p := list[0] as Node2D
	if p != null and p.get("is_dying") == true:
		return null
	return p


func face(dir: float) -> void:
	if dir == 0.0:
		return
	facing = signf(dir)
	sprite.scale.x = absf(sprite.scale.x) * facing
	if attack_check != null:
		attack_check.scale.x = absf(attack_check.scale.x) * facing
	_on_faced()


func _on_faced() -> void:
	pass


## 前下方探地(只查世界层 1),max_step_down 以内探不到 = 前面是坑/高台边
func floor_ahead(dir: float) -> bool:
	if not is_on_floor():
		return true
	var space := get_world_2d().direct_space_state
	var origin := global_position + Vector2(dir * edge_probe_distance, -1.0)
	var query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(0.0, max_step_down + 1.0), 1)
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


func has_anim(anim: StringName) -> bool:
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim) \
		and sprite.sprite_frames.get_frame_count(anim) > 0


func play(anim: StringName) -> void:
	if not has_anim(anim):
		return
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


## 播一遍(不循环的动画),播完调 then;没这段动画就下一帧直接调
func play_once(anim: StringName, then: Callable = Callable()) -> void:
	_once_anim = anim
	_once_then = then
	if has_anim(anim):
		sprite.play(anim)
		sprite.frame = 0
	else:
		_once_anim = &""
		if then.is_valid():
			then.call_deferred()


func _on_animation_finished() -> void:
	if sprite.animation != _once_anim or _once_anim == &"":
		return
	_once_anim = &""
	var then := _once_then
	_once_then = Callable()
	if then.is_valid():
		then.call()


func _make_bark() -> void:
	_bark = Label.new()
	_bark.add_theme_font_override("font", FONT)
	_bark.add_theme_font_size_override("font_size", 12)
	_bark.add_theme_color_override("font_color", BARK_COLOR)
	_bark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_bark.add_theme_constant_override("shadow_offset_x", 1)
	_bark.add_theme_constant_override("shadow_offset_y", 1)
	_bark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bark.size = Vector2(80, 12)
	_bark.position = Vector2(-40, -bark_height - 13.0)
	_bark.visible = false
	_bark.z_index = 30
	_bark.light_mask = 0
	# 字不吃灯光,场景压暗(CanvasModulate)会把它压成灰的:按压暗程度补回来,补到 0.9 左右不发光
	var k := _ambient_comp(0.9)
	_bark.modulate = Color(k, k, k, 1.0)
	add_child(_bark)


## 头顶冒一句(最多五六个字)
func bark(text: String, duration := 1.2) -> void:
	if _bark == null:
		return
	if is_instance_valid(_bark_tween):
		_bark_tween.kill()
	_bark.text = text
	_bark.modulate.a = 1.0
	_bark.visible = true
	_bark_tween = create_tween()
	_bark_tween.tween_interval(duration)
	_bark_tween.tween_property(_bark, "modulate:a", 0.0, 0.25)
	_bark_tween.tween_callback(func() -> void: _bark.visible = false)

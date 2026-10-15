# 管道局(守序邪恶)小兵的公共底子:浑身铜金板甲、不露脸、绝不打自己人(没有队友伤害)。
# 和奥斯卡帮见面就打(阵营/挑目标见 GangMob.foe());交过钱(pass_ok)就不把主角当敌人:
# 站岗、主角路过敬礼;主角一动手 → provoke() 全体翻脸。
# 上一级节点是 BureauSquad 就听队伍的:按队形站位、齐步走(走路帧全队对齐)、队长喊"放"弩手齐射;
# 队长死了队伍就乱(各打各的,出手变慢)。
class_name BureauMob
extends GangMob

const BUREAU_DEATH: PackedScene = preload("res://entities/bureau/bureau_death.tscn")

const BUREAU_LINES := {
	"spot": ["站住。", "出示收据。", "例行检查。", "管道局办事。"],
	"attack": ["执法。", "依规处理。", "按章办事。"],
	"hurt": ["妨碍公务。", "记下了。", "编号多少？"],
	"die": ["……工伤。", "报告……", "盖……章……", "我要……请假……"],
	"buddy_down": ["补位！", "收拢！", "同僚倒下！"],
	"player_hit": ["罚款。", "下一位。", "签收。"],
	"foe_spot": ["奥斯卡帮！", "非法聚集！", "黑衣服的，清理。", "无证经营！"],
	"chat": ["……", "表格又改了。", "盖章，盖章。", "站好。"],
	"salute": ["请通行。", "下一位。", "收据拿好。", "祝您通行愉快。"],
	"provoked": ["袭击公务人员！", "全体注意！", "他动手了！"],
	"broken": ["队长？！", "……谁下令？", "乱了！乱了！", "按……按章程……"],
	"form_up": ["列阵！", "举盾！", "全体——前进！"],
	"turn": ["向后——转！"],
	"patrol_turn": ["向后——转！", "掉头。"],
}
const BUREAU_CHATS := [
	["今天第几个了？", "第三百零二个。"],
	["奥斯卡帮又来闹。", "按章处理。"],
	["这身甲好重。", "规定要穿。"],
	["上面又涨价了。", "不归我们管。"],
	["你盖章了吗？", "盖了三遍。"],
	["几点下班？", "……没有下班。"],
	["那帮黑衣服的……", "非法聚集。"],
	["头盔里好闷。", "规定要戴。"],
]

## 交了过路费/过段费:不把主角当敌人。主角一动手就没了(见 provoke)。房间脚本进场时按标记设。
static var pass_ok := false

var squad: BureauSquad = null
var _saluted := false
var _broken := false


func _ready() -> void:
	super._ready()
	squad = get_parent() as BureauSquad


func faction() -> StringName:
	return &"bureau"


func hostile_to_player() -> bool:
	return not pass_ok


func _common_lines() -> Dictionary:
	return BUREAU_LINES


func _chats() -> Array:
	return BUREAU_CHATS


func _death_scene() -> PackedScene:
	return BUREAU_DEATH


func _can_chat() -> bool:
	return true


## 发现主角才喊"站住";看见奥斯卡帮喊 foe_spot(foe() 里喊过了)
func _on_spotted() -> void:
	var f := foe()
	if f != null and f.is_in_group("player"):
		shout("spot", 0.85)


## 没有要打的人 = 站岗(或者跟着队伍巡逻)
func _asleep() -> bool:
	if truce:
		return true
	return foe() == null


# ------------------------------------------------------------------ 站岗 / 敬礼
func _go_home() -> void:
	_keep_slot()
	_salute_tick()


## 走到/跟住自己在队形里的位置。队伍在齐步走时跟着走(只调快慢,不掉头),停了就站好朝队伍的方向。
func _keep_slot() -> void:
	var dx := post_x() - global_position.x
	var moving := squad != null and not _broken and squad.marching
	if moving and absf(dx) < 6.0:
		var dir := squad.move_dir
		face(dir)
		walk(dir, clampf(march_speed() + dx * dir * 3.0, 0.0, march_speed() * 2.0), &"Walk")
	elif absf(dx) > 2.0:
		face(signf(dx))
		walk(facing, march_speed() * 1.6, &"Walk")
	else:
		velocity.x = 0.0
		face(rest_facing())
		if state == S.ENGAGE:
			play(&"Idle")


## 队形里的人靠站位错开,不用排队等前面的人
func buddy_ahead(dir: float, gap: float = 10.0) -> bool:
	if squad != null and not _broken:
		return false
	return super.buddy_ahead(dir, gap)


## 交过钱的主角走过身边:敬个礼(走远了再回来再敬一次)
func _salute_tick() -> void:
	if not pass_ok or state != S.ENGAGE:
		return
	var p := player()
	if p == null:
		return
	var d := absf(p.global_position.x - global_position.x)
	if d > 70.0:
		_saluted = false
	elif d < 26.0 and not _saluted and absf(p.global_position.y - global_position.y) < 30.0:
		_saluted = true
		face(signf(p.global_position.x - global_position.x))
		state = S.CUSTOM
		velocity.x = 0.0
		shout("salute", 0.8, true)
		play_once(&"Salute", func() -> void:
			if state == S.CUSTOM:
				state = S.ENGAGE)


## 站岗的位置:有队伍听队伍的,没有就出生点
func post_x() -> float:
	if squad != null and not _broken:
		return squad.slot_x(self)
	return home_x


func rest_facing() -> float:
	if squad != null and not _broken:
		return squad.facing
	return facing


func march_speed() -> float:
	if squad != null and not _broken:
		return squad.march_speed
	return move_speed


func _process(delta: float) -> void:
	super._process(delta)
	# 齐步走:同一队的人走路帧对齐(奥斯卡帮说"那帮人走路一个步子")
	if squad != null and not _broken and sprite.animation == &"Walk" and sprite.is_playing():
		var n := sprite.sprite_frames.get_frame_count(&"Walk")
		var f := squad.step_frame() % n
		if sprite.frame != f:
			sprite.frame = f


# ------------------------------------------------------------------ 打仗
## 在队伍里:够得着就打,够不着就回自己的位置(阵型由队伍往前推);不在队伍里:跟奥斯卡帮一样冲上去。
func _engage(delta: float) -> void:
	if squad == null or _broken:
		super._engage(delta)
		return
	var f := foe()
	if f == null:
		_go_home()
		return
	var dx := f.global_position.x - global_position.x
	if absf(dx) <= attack_range and _can_strike(f):
		face(signf(dx))
		velocity.x = 0.0
		if cooldown <= 0.0:
			start_attack()
		else:
			play(&"Idle")
		return
	var mx := post_x() - global_position.x
	if absf(mx) > 2.0 or squad.marching:
		_keep_slot()
	else:
		velocity.x = 0.0
		face(squad.facing)
		play(&"Idle")


## 子类:这个目标现在能不能出手(盾卫转身慢之类)
func _can_strike(_f: Node2D) -> bool:
	return true


## 主角砍的:交过钱的时候砍 = 袭击公务人员,全体翻脸
func take_damage(value: int) -> void:
	if pass_ok and health > 0:
		provoke(self)
	super.take_damage(value)


## 管道局不打自己人:能走到这里的只有对面阵营的东西(或者扔东西的人已经死了),一律当正常挨打
func take_friendly(value: int, from_x: float, attacker: Node = null) -> void:
	take_hit(value, from_x, attacker)


static func provoke(by: BureauMob) -> void:
	if not pass_ok:
		return
	pass_ok = false
	by.shout("provoked", 1.0, true)
	by.get_tree().call_group("bureau_listener", "on_bureau_provoked")


## 队伍散了(队长死了):各打各的,出手慢一点
func break_rank() -> void:
	if _broken or health <= 0:
		return
	_broken = true
	attack_cooldown *= 1.4
	if randf() < 0.6:
		say_later(String(BUREAU_LINES["broken"][randi() % BUREAU_LINES["broken"].size()]), randf_range(0.2, 1.0))


## 队长下令齐射(弩手覆盖)
func on_volley() -> void:
	pass


func _die() -> void:
	if squad != null and is_instance_valid(squad):
		squad.member_died(self)
	super._die()

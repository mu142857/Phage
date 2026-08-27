extends Area2D

## 空洞骑士式自动过门:玩家碰到区域立刻切换场景,不需要按交互键。
## 链路规则与 Teleport 相同:一条通道两端的节点用同一个 teleport_id,
## 落点是目标场景里同 id 节点的位置(可加 spawn_offset 偏移)。
@export_file("*.tscn") var scene_path: String = ""
@export var teleport_id: int = 0
@export var player_light: bool = false
## 落点偏移:玩家到达时落在本节点位置 + 此偏移。
## 用于把落点挪出触发区(比如下落洞口的落点要放在洞旁边的实地上),
## 否则玩家一落地又立刻踩进触发区。
@export var spawn_offset: Vector2 = Vector2.ZERO
## Boss 房出口设为 false,Boss 死后由外部调用 activate() 打开。
@export var active: bool = true
## 方向限制:非零时,玩家在区域内的任意一帧速度与该方向同向(点积>0)即触发。
## 例:顶部上行门设 (0,-1) 表示只在上跳时触发,下落穿过不会触发。
## 零向量 = 人在区域内就触发,不限方向。
@export var require_velocity: Vector2 = Vector2.ZERO

# 刚进场时玩家可能正好落在门口触发区内:先不武装,等玩家离开区域后
# 再生效,防止两个房间之间来回弹。
var _armed: bool = false
var _player_inside: Player = null


func _ready() -> void:
	add_to_group("teleport")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not _player_overlapping():
		_armed = true


# 持续判定而不是只在进入瞬间判定:玩家可能以不满足方向条件的方式进区
# (比如下穿单向平台时速度归零),之后条件满足的那一帧照样要触发。
func _physics_process(_delta: float) -> void:
	if not _armed or not active:
		return
	if not is_instance_valid(_player_inside):
		return
	if require_velocity != Vector2.ZERO and _player_inside.velocity.dot(require_velocity) <= 0.0:
		return
	# 自动过门只是走进隔壁房间:主角护盾/技能运行态原样继承,不重置。
	Game.change_scene(scene_path, teleport_id, player_light, true)


func activate() -> void:
	active = true


func deactivate() -> void:
	active = false


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_inside = body


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_inside = null
		_armed = true


func _player_overlapping() -> bool:
	for body in get_overlapping_bodies():
		if body is Player:
			return true
	return false

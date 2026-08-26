extends StaticBody2D

## 可上可下的单向平台:从下面跳能穿上来站住,站在上面按 下(move_down/S) 落下去。
## 结构要求:子节点 CollisionShape2D(勾 one_way_collision)是平台本体,
## Area2D(盖住平台上表面)用来检测玩家是否正站在平台上。
## 通用组件,任何关卡把平台碰撞挪到这样一个 StaticBody2D 下就能用。

## 按下后对玩家关闭碰撞的时长,够玩家整个身位落穿即可。
@export var drop_time: float = 0.3

var _player_on: Player = null


func _ready() -> void:
	var area: Area2D = $Area2D
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	if _player_on == null or not is_instance_valid(_player_on):
		return
	if _player_on.input_locked:
		return
	if not _player_on.is_on_floor():
		return
	if Input.is_action_just_pressed("move_down"):
		_drop(_player_on)


func _drop(player: Player) -> void:
	player.add_collision_exception_with(self)
	await get_tree().create_timer(drop_time).timeout
	if is_instance_valid(player):
		player.remove_collision_exception_with(self)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_on = body


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_on = null

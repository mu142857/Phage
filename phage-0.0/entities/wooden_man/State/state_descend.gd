# 木头人 飘下状态(3 号)：手把人偶从屏幕顶放下来到悬停高度(缓出)，
# 下来的路上打不到；到位 → Idle。木偶师登场/化开后补新人偶都走这里。
extends BasicState

@export var descend_time: float = 1.1
@export var settle_shake: float = 0.0    # 到位时的轻震(0=不震)

@onready var monster: CharacterBody2D = $"../.."

var _tween: Tween = null


func enter() -> void:
	monster.velocity = Vector2.ZERO
	monster.hittable = false
	monster.form = monster.FORM_BLANK
	monster.play_anim(&"Idle")
	monster.global_position.x = monster.slot_x
	monster.face_player()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(monster, "global_position:y", monster.hover_y, descend_time)
	_tween.tween_callback(_on_settled)


func process(_delta: float) -> void:
	pass


func exit() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	monster.hittable = true


func _on_settled() -> void:
	if settle_shake > 0.0:
		Game.shake_camera(settle_shake)
	change_state(monster.STATE_IDLE)

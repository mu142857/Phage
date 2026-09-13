# res://systems/dream_end.gd
# 梦完成触发器,两种用法:
# ① 终点区:实例放在关卡终点,玩家(碰撞层 2)走进 = 梦完成;
# ② 盯 boss:填 watch_path 指向 boss 节点,boss 被释放(死亡) = 梦完成。
# 没做完的关卡不用放,F9 一键通关(Story 里)兜底。
class_name DreamEnd
extends Area2D

@export var watch_path: NodePath
## 这一夜带回来的纪念品(buff id,如 &"Table")。主线首次通关时黑屏上报一句
## "把它带回去了"+图标+去哪找;回顾梦不报。空 = 直接天亮。
@export var reward_buff: StringName = &""
## 报纪念品前先自言自语的一句(比如 boss 溜走了),可空。
@export_multiline var ending_line := ""


func _ready() -> void:
	if not watch_path.is_empty():
		monitoring = false
		var target := get_node_or_null(watch_path)
		if target != null:
			target.tree_exited.connect(_on_target_gone)
		else:
			push_warning("DreamEnd: 找不到要盯的节点 %s" % watch_path)
		return
	body_entered.connect(_on_body_entered)


func _on_target_gone() -> void:
	# 场景正常卸载时也会走到这里,complete_dream 里的守卫会挡掉
	Story.complete_dream(reward_buff, ending_line)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		Story.complete_dream(reward_buff, ending_line)

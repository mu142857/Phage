# res://systems/npc/interact_focus.gd
# 按 Q 的东西(会说话的 NPC、按 Q 的门)同一时刻只让一个冒提示、接按键:离主角最近的那个。
# 参与者:加入 "interactable" 组,实现
#   interact_distance(player) -> float   够得着返回距离,够不着返回 INF
#   prompt_rect() -> Rect2               正在显示的提示框(世界坐标),没显示返回空 Rect2
# 头顶冒的话(Npc.bark)会躲开这些提示框和别人先冒的话。
class_name InteractFocus
extends RefCounted

const GROUP := &"interactable"


## node 是不是此刻离主角最近、可交互的那个(平手按实例 id 定,保证每个参与者算出来的结果一致)。
static func is_focused(node: Node, player: Node2D) -> bool:
	if player == null or not node.is_inside_tree():
		return false
	var mine: float = node.interact_distance(player)
	if is_inf(mine):
		return false
	for other in node.get_tree().get_nodes_in_group(GROUP):
		if other == node or not other.has_method("interact_distance"):
			continue
		var d: float = other.interact_distance(player)
		if d < mine or (d == mine and other.get_instance_id() < node.get_instance_id()):
			return false
	return true


## 现在屏幕上所有可交互提示的框(给冒的话让位用)。
static func prompt_rects(tree: SceneTree) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for n in tree.get_nodes_in_group(GROUP):
		if n.has_method("prompt_rect"):
			var r: Rect2 = n.prompt_rect()
			if r.has_area():
				out.append(r)
	return out

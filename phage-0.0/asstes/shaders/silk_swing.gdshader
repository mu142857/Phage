shader_type canvas_item;

// 悬挂蛛丝摇摆：与树木 swing 相反，顶端锚点不动，越往下摆得越多。
// 纯水平位移（剪切），无旋转。相位由节点世界坐标决定，各条丝不同步。
uniform float Strength : hint_range(0.0, 5.0) = 1.2;
uniform float Speed : hint_range(0.0, 10.0) = 1.5;

void vertex() {
	float phase = MODEL_MATRIX[3][0] * 0.13 + MODEL_MATRIX[3][1] * 0.07;
	VERTEX.x += sin(TIME * Speed + phase) * Strength * UV.y;
}

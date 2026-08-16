shader_type canvas_item;

// 悬停提亮/压暗:乘法调亮度(保饱和度,不发灰),逐通道 min 钳到 0.99 —
// 永远不进 HDR,过不了泛光(glow)阈值,阈值无需改动。
// highlight_amount: 0.3 = 提亮 30%; -0.25 = 压暗 25%(悬停别人时自己让位)。
uniform float highlight_amount : hint_range(-1.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = min(COLOR.rgb * (1.0 + highlight_amount), vec3(0.99));
}

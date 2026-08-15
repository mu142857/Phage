shader_type canvas_item;

// 入梦字卡的镂空黑幕:mask_enabled 关闭时是纯黑幕布;
// 打开时按遮罩(SubViewport 里渲染的标题文字)挖洞,字的内部透出后面的活场景。
// 遮罩做 0.5 阈值化:字体导入开了灰度抗锯齿,不阈值化会在字边缘漏出半透明灰阶,
// 破坏 160×90 巨像素的硬边风格。
// 场景普遍偏暗,只挖洞的话字形不明显——字的内部叠一层白色滤镜:
// glyph_white 从 0(全透明,字内是原样活场景)渐变到 0.8(八成白,
// 字形通体泛白发亮,底下仍透着两成活场景)。
uniform sampler2D mask_tex: filter_nearest;
uniform float mask_enabled = 0.0;
uniform float glyph_white = 0.0;

void fragment() {
	// COLOR 进来时已含 ColorRect.color 与 modulate(整体淡入淡出靠 modulate:a)
	float a_in = COLOR.a;
	vec3 rgb = vec3(0.0);
	float alpha = 1.0;
	if (mask_enabled > 0.5) {
		float m = texture(mask_tex, UV).a;
		if (m > 0.5) {
			// 字的内部:白色滤镜,浓度由 glyph_white 控制
			rgb = vec3(1.0);
			alpha = glyph_white;
		}
	}
	COLOR = vec4(rgb, alpha * a_in);
}

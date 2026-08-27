shader_type canvas_item;

// 盾壳 overlay:整体半透明 + 周期性斜向扫光,像玻璃护罩的反光。
// 扫光取值先 floor 到素材像素格,斜带只会以巨像素阶梯出现,不产生高分辨率斜线。

uniform float opacity : hint_range(0.0, 1.0) = 0.5; // 半透明,50/50
uniform vec4 sheen_color : source_color = vec4(0.85, 0.96, 1.0, 1.0);
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.75; // 扫光把颜色推向 sheen_color 的程度
uniform float sheen_alpha_boost : hint_range(0.0, 1.0) = 0.55; // 扫光处额外找回的不透明度
uniform float sweep_period : hint_range(0.5, 10.0) = 2.5; // 一轮扫光的秒数
uniform float band_width : hint_range(1.0, 8.0) = 3.0; // 亮芯宽度(素材像素)
uniform float travel = 128.0; // 扫光轨道长度(像素),远大于盾宽,留出两轮之间的停顿

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

void fragment() {
	vec4 base = COLOR; // 贴图 × modulate,受伤闪白等 modulate 效果照常生效

	// 盾壳素材整数尺寸+offset 半格补偿后,texel 边界都落在整数上,floor 即对齐像素格
	vec2 p = floor(local_px);

	// 「/」形斜带沿左上→右下匀速掠过,亮芯+暗拖尾两档亮度,保持像素感
	float band_pos = mod(p.x + p.y - TIME / sweep_period * travel, travel);
	float sheen = 0.0;
	if (band_pos < band_width) {
		sheen = 1.0;
	} else if (band_pos < band_width * 2.0) {
		sheen = 0.45;
	}

	base.rgb = mix(base.rgb, sheen_color.rgb, sheen * sheen_strength);
	base.a *= clamp(opacity + sheen * sheen_alpha_boost, 0.0, 1.0);
	COLOR = base;
}

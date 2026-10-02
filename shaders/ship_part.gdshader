shader_type canvas_item;
// Pièce de vaisseau : palette-swap des 3 couleurs « apprêt » réservées vers la rampe de la peinture
// choisie, puis calque d'usure (rouille, rayures…) découpé sur l'alpha de la pièce.
// Les couleurs sont comparées en sRGB brut (espace des textures 2D), sans conversion.

uniform vec4 src0 = vec4(0.235, 0.290, 0.243, 1.0);
uniform vec4 src1 = vec4(0.365, 0.431, 0.341, 1.0);
uniform vec4 src2 = vec4(0.541, 0.604, 0.478, 1.0);
uniform vec4 dst0 = vec4(0.235, 0.290, 0.243, 1.0);
uniform vec4 dst1 = vec4(0.365, 0.431, 0.341, 1.0);
uniform vec4 dst2 = vec4(0.541, 0.604, 0.478, 1.0);
uniform bool use_wear = false;
uniform sampler2D wear_tex : repeat_enable, filter_nearest;
uniform vec2 wear_tex_size = vec2(96.0, 48.0);
uniform vec2 wear_offset = vec2(0.0);
uniform float wear_amount = 0.0;
uniform vec4 outline_color = vec4(0.051, 0.055, 0.078, 1.0);
uniform vec4 tint = vec4(1.0);
uniform float flash = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (distance(c.rgb, src0.rgb) < 0.02) {
		c.rgb = dst0.rgb;
	} else if (distance(c.rgb, src1.rgb) < 0.02) {
		c.rgb = dst1.rgb;
	} else if (distance(c.rgb, src2.rgb) < 0.02) {
		c.rgb = dst2.rgb;
	}
	if (use_wear && c.a > 0.5 && distance(c.rgb, outline_color.rgb) > 0.05) {
		vec2 px = floor(UV / TEXTURE_PIXEL_SIZE) + wear_offset;
		vec4 w = texture(wear_tex, (px + 0.5) / wear_tex_size);
		vec2 blk = floor(px / 5.0);
		float h = fract(sin(dot(blk, vec2(12.9898, 78.233))) * 43758.5453);
		if (w.a > 0.5 && h < wear_amount) {
			c.rgb = w.rgb;
		}
	}
	c.rgb = mix(c.rgb, vec3(1.0), flash * step(0.5, c.a));
	COLOR = c * tint;
}

shader_type canvas_item;
// Pièce de vaisseau (2.5D) : les zones peintes (masque <pièce>_paint.png, rouge dans le rendu d'origine) prennent
// la rampe de la peinture choisie en gardant l'ombrage et les reflets du rendu, puis calque d'usure doux
// (rouille, rayures…) dosé par un bruit lissé selon l'usure du vaisseau.

uniform bool use_paint = false;
uniform sampler2D paint_mask : filter_linear_mipmap, hint_default_black;
uniform vec4 dst0 = vec4(0.235, 0.290, 0.243, 1.0);
uniform vec4 dst1 = vec4(0.365, 0.431, 0.341, 1.0);
uniform vec4 dst2 = vec4(0.541, 0.604, 0.478, 1.0);
uniform bool use_wear = false;
uniform sampler2D wear_tex : repeat_enable, filter_linear_mipmap;
// Taille logique de la pièce et du calque d'usure (pixels du jeu).
uniform vec2 part_size = vec2(80.0, 34.0);
uniform vec2 wear_tex_size = vec2(96.0, 48.0);
uniform vec2 wear_offset = vec2(0.0);
uniform float wear_amount = 0.0;
uniform vec4 tint = vec4(1.0);
uniform float flash = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (use_paint) {
		float m = texture(paint_mask, UV).r;
		// Ombrage de la peinture rouge d'origine : sa composante la plus forte.
		float v = max(c.r, max(c.g, c.b));
		float t = clamp((v - 0.12) / 0.83, 0.0, 1.0);
		vec3 p = t < 0.5 ? mix(dst0.rgb, dst1.rgb, t * 2.0) : mix(dst1.rgb, dst2.rgb, t * 2.0 - 1.0);
		// Reflets spéculaires (vert et bleu élevés sur une peinture rouge) : gardés en blanc.
		float spec = clamp(min(c.g, c.b) * 1.6 - 0.35, 0.0, 1.0);
		p = mix(p, vec3(1.0), spec * 0.7);
		c.rgb = mix(c.rgb, p, m);
	}
	if (use_wear && c.a > 0.02) {
		vec2 px = UV * part_size + wear_offset;
		vec4 w = texture(wear_tex, px / wear_tex_size);
		float n = value_noise(px / 6.0) * 0.65 + value_noise(px / 2.5) * 0.35;
		float k = w.a * smoothstep(n - 0.1, n + 0.1, wear_amount * 0.75);
		c.rgb = mix(c.rgb, w.rgb, k * 0.6);
	}
	c.rgb = mix(c.rgb, vec3(1.0), flash * c.a);
	COLOR = c * tint;
}

shader_type canvas_item;
// Stage 9.5 — 2px outline pulse for rare-tier+ ground items.
// Sampled around the texel; any neighbour-transparent texel inside
// the outline radius gets stamped with the outline colour. Cheap,
// reads at gameplay zoom, no second draw pass.
//
// Used by WorldItem when ItemData.glyph_color matches the rare or
// gold rarity tint. Pulsing alpha makes the loot legible without
// turning the item itself into an animation.

uniform vec4 outline_color : source_color = vec4(0.45, 0.65, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 4.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.4;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.55;
uniform float pulse_max : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// Stage 9.7 polish — Godot's shader language forbids `return` in
	// fragment(), so the source/neighbour/empty branches are folded
	// into a single nested if/else.
	vec4 src = texture(TEXTURE, UV);
	if (src.a > 0.02) {
		COLOR = src;
	} else {
		vec2 ts = TEXTURE_PIXEL_SIZE;
		float aN = texture(TEXTURE, UV + vec2(0.0, -outline_width) * ts).a;
		float aS = texture(TEXTURE, UV + vec2(0.0,  outline_width) * ts).a;
		float aE = texture(TEXTURE, UV + vec2( outline_width, 0.0) * ts).a;
		float aW = texture(TEXTURE, UV + vec2(-outline_width, 0.0) * ts).a;
		float neighbour = max(max(aN, aS), max(aE, aW));
		if (neighbour > 0.02) {
			float pulse = mix(pulse_min, pulse_max,
					0.5 + 0.5 * sin(TIME * pulse_speed));
			COLOR = vec4(outline_color.rgb, outline_color.a * pulse);
		} else {
			COLOR = vec4(0.0);
		}
	}
}

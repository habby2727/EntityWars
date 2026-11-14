shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 energy_left : source_color = vec4(0.13, 0.83, 0.95, 1.0);
uniform vec4 energy_right : source_color = vec4(0.83, 0.25, 1.0, 1.0);

void fragment() {
    vec2 uv = UV;
    float p = clamp(progress, 0.0, 1.0);
    // Clip to the real loading percentage. Shader TIME only animates decorative shimmer.
    float filled = 1.0 - smoothstep(p - 0.003, p + 0.003, uv.x);
    float running = step(0.0001, p);
    float pulse = 0.93 + 0.07 * sin(TIME * 3.0);
    float waves = 0.5 + 0.5 * sin(uv.x * 75.0 - TIME * 5.0);
    float scan = 0.5 + 0.5 * sin((uv.x * 8.0 - TIME * 0.48) * 6.2831853);
    float crest = pow(max(0.0, 1.0 - abs(uv.y - 0.36) * 2.9), 2.0);
    float sparkle = pow(scan, 11.0) * 0.34;
    vec3 base = mix(energy_left.rgb, energy_right.rgb, uv.x);
    vec3 glow = base * (0.72 + waves * 0.10 + crest * 0.28 + sparkle) * pulse;
    float tip = exp(-pow((uv.x-p) * 86.0, 2.0)) * step(0.015, p);
    glow += vec3(0.28, 0.24, 0.35) * tip;
    float edge_fade = smoothstep(0.0, 0.07, uv.y) * (1.0 - smoothstep(0.93, 1.0, uv.y));
    COLOR = vec4(glow, filled * running * edge_fade);
}

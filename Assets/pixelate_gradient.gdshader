shader_type canvas_item;

uniform float pixelation_amount : hint_range(1.0, 100.0) = 8.0;
uniform int color_steps : hint_range(2, 32) = 8;
uniform float breathe_speed : hint_range(0.1, 5.0) = 1.0;
uniform float breathe_intensity : hint_range(0.0, 0.5) = 0.1;

void fragment() {
    // Breathing effect - pulse from center
    vec2 center = vec2(0.5, 0.5);
    float pulse = sin(TIME * breathe_speed) * breathe_intensity;
    float scale = 1.0 + pulse;

    // Apply breathing scale
    vec2 uv = UV;
    uv = center + (uv - center) * scale;

    // Pixelate
    vec2 pixel_size = vec2(1.0) / (TEXTURE_PIXEL_SIZE * pixelation_amount);
    uv = floor(uv * pixel_size) / pixel_size;

    // Get color
    vec4 color = texture(TEXTURE, uv);

    // Posterize/quantize colors
    float steps = float(color_steps);
    color.rgb = floor(color.rgb * steps) / steps;

    COLOR = color;
}

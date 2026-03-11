shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D mask_texture;

uniform bool bypass_r = false;
uniform bool bypass_g = false;
uniform bool bypass_b = false;

uniform float saturation : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float brightness : hint_range(0.0, 2.0, 0.01) = 1.0;

void fragment() {
    vec4 screen = texture(SCREEN_TEXTURE, SCREEN_UV);
    vec4 mask = texture(mask_texture, UV);

    bool skip = false;
    if (bypass_r && mask.r > 0.5) skip = true;
    if (bypass_g && mask.g > 0.5) skip = true;
    if (bypass_b && mask.b > 0.5) skip = true;

    if (skip) {
        COLOR = screen;
    } else {
        float grey = dot(screen.rgb, vec3(0.299, 0.587, 0.114));
        vec3 result = mix(vec3(grey) * brightness, screen.rgb, saturation);
        COLOR = vec4(result, screen.a);
    }
}
#version 450

layout(set = 2, binding = 0) uniform sampler2D albedo;
layout(set = 2, binding = 1) uniform Lighting {
    vec4 light_position_range;
    vec4 light_color;
    vec4 ambient_color;
    vec4 water_time;
    vec4 water_style0;
    vec4 water_tint0;
    vec4 water_toon0;
    vec4 water_style1;
    vec4 water_tint1;
    vec4 water_toon1;
    vec4 water_style2;
    vec4 water_tint2;
    vec4 water_toon2;
    vec4 water_style3;
    vec4 water_tint3;
    vec4 water_toon3;
};
layout(location = 0) in vec2 texcoord;
layout(location = 1) in vec3 world_position;
layout(location = 0) out vec4 color;

void main() {
    const float water_marker_minimum = 1.4;
    const float water_marker_origin = 1.5;
    const float water_marker_stride = 0.01;
    float style_value = floor(
        (texcoord.x - water_marker_origin) / water_marker_stride + 0.5);
    int style_index = int(clamp(style_value, 0.0, 3.0));
    vec4 selected_style = water_style0;
    vec4 selected_tint = water_tint0;
    vec4 selected_toon = water_toon0;
    if (style_index == 1) {
        selected_style = water_style1;
        selected_tint = water_tint1;
        selected_toon = water_toon1;
    } else if (style_index == 2) {
        selected_style = water_style2;
        selected_tint = water_tint2;
        selected_toon = water_toon2;
    } else if (style_index == 3) {
        selected_style = water_style3;
        selected_tint = water_tint3;
        selected_toon = water_toon3;
    }
    bool water_vertex = texcoord.x > water_marker_minimum &&
        texcoord.y > water_marker_minimum &&
        selected_style.x > 0.5;
    if (water_vertex) {
        float phase = world_position.x * selected_style.y +
            world_position.z * selected_style.y +
            water_time.x * selected_style.z;
        float wave = sin(phase) *
            sin(phase * 0.73 + water_time.x);
        float caustic = step(0.0, wave) * selected_style.w;
        float toon_light = selected_toon.x + caustic * selected_toon.y;
        color = vec4(selected_tint.rgb * toon_light, selected_toon.z);
        return;
    }
    vec4 base = texture(albedo, texcoord);
    float range = max(light_position_range.w, 1.0);
    float distance_to_light = distance(light_position_range.xyz, world_position);
    float attenuation = clamp(1.0 - distance_to_light / range, 0.0, 1.0);
    float height_light = clamp(0.75 + world_position.y / 96.0, 0.75, 1.0);
    vec3 lighting = ambient_color.rgb +
        light_color.rgb * attenuation * height_light;
    color = vec4(base.rgb * lighting, base.a);
}

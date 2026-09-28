#version 450

layout(set = 2, binding = 0) uniform sampler2D albedo;
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 color;

void main() {
    color = texture(albedo, uv);
}

#version 450

layout(location = 0) in vec3 position;
layout(location = 1) in vec2 uv;

layout(set = 1, binding = 0) uniform Camera {
    mat4 view_projection;
};

layout(location = 0) out vec2 texcoord;

void main() {
    gl_Position = view_projection * vec4(position, 1.0);
    texcoord = uv;
}

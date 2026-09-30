#version 450

layout(location = 0) in vec4 vertex_zero;
layout(location = 1) in vec4 vertex_one;
layout(location = 2) in vec4 vertex_two;
layout(location = 0) out vec2 uv;

void main() {
    vec4 vertex = vertex_zero;
    if (gl_VertexIndex == 1) {
        vertex = vertex_one;
    } else if (gl_VertexIndex == 2) {
        vertex = vertex_two;
    }
    gl_Position = vec4(vertex.xy, 0.0, 1.0);
    uv = vertex.zw;
}

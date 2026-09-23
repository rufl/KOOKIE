#version 450

layout(location = 0) out vec2 uv;

void main() {
    const vec2 positions[6] = vec2[6](
        vec2(-0.8, -0.8),
        vec2(0.8, -0.8),
        vec2(0.8, 0.8),
        vec2(-0.8, -0.8),
        vec2(0.8, 0.8),
        vec2(-0.8, 0.8)
    );
    const vec2 coordinates[6] = vec2[6](
        vec2(0.0, 1.0),
        vec2(1.0, 1.0),
        vec2(1.0, 0.0),
        vec2(0.0, 1.0),
        vec2(1.0, 0.0),
        vec2(0.0, 0.0)
    );
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    uv = coordinates[gl_VertexIndex];
}

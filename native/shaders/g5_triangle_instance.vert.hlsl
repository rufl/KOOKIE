struct VertexInput {
    float4 vertex_zero : TEXCOORD0;
    float4 vertex_one : TEXCOORD1;
    float4 vertex_two : TEXCOORD2;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

VertexOutput main(VertexInput input, uint vertex_index : SV_VertexID) {
    float4 vertex = input.vertex_zero;
    if (vertex_index == 1) {
        vertex = input.vertex_one;
    } else if (vertex_index == 2) {
        vertex = input.vertex_two;
    }
    VertexOutput output;
    output.position = float4(vertex.xy, 0.0, 1.0);
    output.uv = vertex.zw;
    return output;
}

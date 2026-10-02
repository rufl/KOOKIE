struct VertexInput {
    float4 vertex_zero : TEXCOORD0;
    float4 vertex_one : TEXCOORD1;
    float4 vertex_two : TEXCOORD2;
};

struct VertexOutput {
    float2 uv : TEXCOORD0;
    float4 position : SV_Position;
};

VertexOutput main(VertexInput input, uint vertex_index : SV_VertexID) {
    float4 vertex = input.vertex_zero;
    if (vertex_index == 1) {
        vertex = input.vertex_one;
    } else if (vertex_index == 2) {
        vertex = input.vertex_two;
    }
    float encoded_v = floor(vertex.w / 256.0);
    float encoded_u = vertex.w - encoded_v * 256.0;
    VertexOutput output;
    output.uv = float2(encoded_u, encoded_v) / 255.0;
    output.position = float4(vertex.xy, vertex.z, 1.0);
    return output;
}

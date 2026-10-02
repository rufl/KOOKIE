cbuffer Camera : register(b0, space1) {
    float4x4 view_projection;
};

struct VertexInput {
    float3 position : TEXCOORD0;
    float2 uv : TEXCOORD1;
};

struct VertexOutput {
    float2 uv : TEXCOORD0;
    float4 position : SV_Position;
};

VertexOutput main(VertexInput input) {
    VertexOutput output;
    output.position = mul(view_projection, float4(input.position, 1.0));
    output.uv = input.uv;
    return output;
}

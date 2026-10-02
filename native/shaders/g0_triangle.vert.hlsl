struct VertexOutput {
    float2 uv : TEXCOORD0;
    float4 position : SV_Position;
};

VertexOutput main(float2 position : TEXCOORD0, float2 uv : TEXCOORD1) {
    VertexOutput output;
    output.uv = uv;
    output.position = float4(position, 0.0, 1.0);
    return output;
}

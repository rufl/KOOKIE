Texture2D<float4> albedo : register(t0, space2);
SamplerState albedo_sampler : register(s0, space2);

float4 main(float2 uv : TEXCOORD0) : SV_Target0 {
    return albedo.Sample(albedo_sampler, uv);
}

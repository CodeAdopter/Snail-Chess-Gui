// Brings the 3D board drawn above the screen's size down to it. Each pixel weighs every pixel of the
// larger picture its filter reaches, in linear light, so edges smoothed at the larger size stay smooth.

Texture2D<float4> big : register(t0, space2);
SamplerState big_sampler : register(s0, space2);

cbuffer ShrinkUniforms : register(b0, space3)
{
    // the larger picture's width and height, then how many of its pixels span one of ours each way
    float4 sizes;
};

struct FullscreenOut
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

// Mitchell and Netravali's cubic with B and C a third, x of our pixels from the centre
float mitchell(float x)
{
    x = abs(x);
    if (x < 1.0)
        return (7.0 * x * x * x - 12.0 * x * x + 16.0 / 3.0) / 6.0;
    if (x < 2.0)
        return (-7.0 / 3.0 * x * x * x + 12.0 * x * x - 20.0 * x + 32.0 / 3.0) / 6.0;
    return 0.0;
}

float3 to_linear(float3 c)
{
    return lerp(c / 12.92, pow((c + 0.055) / 1.055, 2.4), step(0.04045, c));
}

float3 to_srgb(float3 c)
{
    return lerp(c * 12.92, 1.055 * pow(max(c, 0.0), 1.0 / 2.4) - 0.055, step(0.0031308, c));
}

float4 shrink_ps(FullscreenOut i) : SV_Target0
{
    float2 span = sizes.zw;
    float2 centre = i.position.xy * span;
    int2 lo = max(int2(floor(centre - 2.0 * span)), 0);
    int2 hi = min(int2(ceil(centre + 2.0 * span)), int2(sizes.xy) - 1);
    float4 sum = 0.0;
    float total = 0.0;
    for (int y = lo.y; y <= hi.y; y++)
    {
        float wy = mitchell((y + 0.5 - centre.y) / span.y);
        for (int x = lo.x; x <= hi.x; x++)
        {
            float w = wy * mitchell((x + 0.5 - centre.x) / span.x);
            // through the sampler at the pixel's centre, since a texture read without one is bound
            // apart from the sampled ones
            float4 c = big.SampleLevel(big_sampler, (float2(x, y) + 0.5) / sizes.xy, 0.0);
            sum += float4(to_linear(c.rgb), c.a) * w;
            total += w;
        }
    }
    float4 c = sum / max(total, 1e-5);
    return float4(to_srgb(saturate(c.rgb)), saturate(c.a));
}

// Dust where a piece lands on the flat board, under the pieces: a ring of it running out from the
// square and puffs thrown out round it that swell, drift and thin away, lit from the top left, in a
// box three squares wide round the square. Values: strength, seconds since the move, seed, the
// effect's length in seconds.

#include "C:/Snail/Snail Engine/engine/shaders/ui_material.hlsli"

float dust_hash(float n)
{
    return frac(sin(n * 91.345) * 47453.5453);
}

float4 dust(UiPixel q)
{
    float strength = saturate(q.values.x);
    float t = q.values.y;
    float seed = q.values.z;
    float life = saturate(t / max(q.values.w, 0.01));
    float ease = 1.0 - pow(1.0 - life, 3.0);
    float2 d = (q.uv - 0.5) * 3.0;
    float r = length(d);
    float rough = ui_fbm(d * 5.0 + seed + t * 0.8);
    float ring_at = 0.42 + ease * 1.0;
    float ring = exp(-pow((r - ring_at + (rough - 0.5) * 0.12) / (0.05 + 0.14 * ease), 2.0)) * pow(1.0 - life, 1.6);
    float puff = 0.0;
    float lit = 0.0;
    [unroll] for (int k = 0; k < 10; k++)
    {
        float a = k * 0.6283 + dust_hash(k + seed) * 0.5;
        float far = 0.35 + ease * (0.45 + 0.4 * dust_hash(k * 3.0 + seed));
        float2 at = float2(cos(a), sin(a)) * far;
        float size = 0.1 + ease * (0.16 + 0.1 * dust_hash(k * 7.0 + seed));
        float2 o = d - at;
        float blob = smoothstep(size, size * 0.15, length(o) * (0.8 + 0.5 * rough));
        puff = max(puff, blob);
        lit = max(lit, blob * saturate(0.5 - dot(o / max(size, 0.01), float2(0.5, 0.6)) * 0.5));
    }
    puff *= pow(1.0 - life, 1.3);
    float k = saturate(ring * 0.35 + puff * 0.5) * strength * ui_cover(q.d, q.px);
    float3 c = lerp(float3(0.62, 0.56, 0.48), float3(0.9, 0.85, 0.76), lit);
    return float4(c * k, k);
}

UI_MATERIAL(dust)

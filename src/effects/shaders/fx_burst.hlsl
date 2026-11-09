// Embers drifting up from a piece burning away on the flat board, over the pieces, with a thin
// smoke rising behind them, in a box two squares wide and two and a half tall whose lowest square
// is the piece's. Values: strength, seconds since the move, seed, the effect's length in seconds.

#include "C:/Snail/Snail Engine/engine/shaders/ui_material.hlsli"

float burst_hash(float n)
{
    return frac(sin(n * 78.233) * 43758.5453);
}

float4 burst(UiPixel q)
{
    float strength = saturate(q.values.x);
    float t = q.values.y;
    float seed = q.values.z;
    float length_s = max(q.values.w, 0.01);
    // in squares from the piece's middle, up negative
    float2 p = float2((q.uv.x - 0.5) * 2.0, (q.uv.y - 0.8) * 2.5);
    float px = q.px / max(q.s.rect.z * 0.5, 1.0);
    float3 light = float3(0.0, 0.0, 0.0);
    float cover = 0.0;
    [unroll] for (int k = 0; k < 28; k++)
    {
        float h = burst_hash(k + seed * 17.0);
        float born = burst_hash(k * 3.1 + seed) * 0.35 * length_s;
        float life = (t - born) / (length_s * (0.55 + 0.45 * burst_hash(k * 5.7 + seed)));
        if (life <= 0.0 || life >= 1.0) continue;
        float2 start = float2((h - 0.5) * 0.5, -0.05 - burst_hash(k * 9.3 + seed) * 0.55);
        float2 drift = float2((burst_hash(k * 2.3 + seed) - 0.5) * 0.9, -0.7 - burst_hash(k * 4.9 + seed) * 0.9);
        float2 at = start + drift * life + float2(sin(life * 9.0 + h * 30.0) * 0.06, life * life * 0.25);
        float size = (0.022 + 0.02 * burst_hash(k * 6.1 + seed)) * (1.0 - life * 0.6);
        float dot_ = saturate(1.0 - length(p - at) / max(size, px * 1.5));
        float fade = smoothstep(0.0, 0.08, life) * (1.0 - life);
        float3 c = lerp(float3(1.0, 0.85, 0.45), float3(0.95, 0.22, 0.04), life);
        light += c * dot_ * fade * 1.4;
        cover = max(cover, dot_ * fade);
    }
    // a wisp of smoke rising off the square
    float life = saturate(t / length_s);
    float2 s = p - float2(0.0, -0.2 - life * 0.9);
    float smoke = smoothstep(0.45, 0.0, length(s * float2(1.6, 0.8))) * ui_fbm(p * 4.0 + float2(seed, t * 1.3));
    smoke *= smoothstep(0.0, 0.15, life) * pow(1.0 - life, 1.5) * 0.35;
    float k = saturate(cover + smoke) * strength * ui_cover(q.d, q.px);
    float3 c = light * strength + float3(0.25, 0.23, 0.22) * smoke * strength;
    return float4(c * ui_cover(q.d, q.px), k);
}

UI_MATERIAL(burst)

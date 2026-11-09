// Flames round a piece on the flat board, drawn as the piece's own image stretched over a box
// FlameLeft of a square wider each side, FlameUp taller above and FlameDown below, so the flames
// read the piece's shape from the sheet and rise off its outline, swaying, with sparks drifting up
// above them. Drawn once behind the piece and once in front, where only tongues licking up its
// lower part show. Values: strength, seconds of the burning clock, the hue (0 orange, 1 red, 2 gold)
// plus 4 for the front, seed. The box's sizes are twins of effects.snail's.

#include "C:/Snail/Snail Engine/engine/shaders/ui_material.hlsli"

static const float FlameLeft = 0.3;
static const float FlameUp = 0.8;
static const float FlameDown = 0.05;

// How much of the piece covers point c of its square, 0 outside the square
float flame_mask(UiPixel q, float2 c)
{
    if (any(c < 0.0) || any(c > 1.0)) return 0.0;
    return atlas.SampleLevel(atlas_linear, lerp(q.s.geo.xy, q.s.geo.zw, c), 0).a;
}

float flame_hash(float2 p)
{
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// The fire's colour at heat h from 0 to 1 in hue, dull red to a white hot core
float3 flame_ramp(float h, float hue)
{
    float3 deep = float3(0.5, 0.05, 0.02);
    float3 flame = float3(1.0, 0.42, 0.06);
    float3 tip = float3(1.0, 0.86, 0.48);
    if (hue > 1.5)
    {
        deep = float3(0.48, 0.26, 0.0);
        flame = float3(1.0, 0.72, 0.12);
        tip = float3(1.0, 0.96, 0.72);
    }
    else if (hue > 0.5)
    {
        deep = float3(0.4, 0.0, 0.03);
        flame = float3(0.95, 0.12, 0.06);
        tip = float3(1.0, 0.58, 0.4);
    }
    float3 c = lerp(deep, flame, smoothstep(0.0, 0.5, h));
    return lerp(c, tip, smoothstep(0.7, 1.0, h));
}

float4 flame(UiPixel q)
{
    float strength = saturate(q.values.x);
    float t = q.values.y;
    bool front = q.values.z > 3.5;
    float hue = front ? q.values.z - 4.0 : q.values.z;
    float seed = q.values.w;
    float2 p = q.uv * float2(1.0 + FlameLeft * 2.0, 1.0 + FlameUp + FlameDown) - float2(FlameLeft, FlameUp);
    float reach = 0.24 + 0.4 * strength;
    // how near the piece lies below the point, along three swaying lines fanning down, 1 on its
    // outline and 0 a reach away, so flames rise off its top and lick up its sides
    float below = 1.0;
    float jitter = ui_value_noise(p * 37.0 + t * 3.0);
    [unroll] for (int j = 1; j <= 10; j++)
    {
        float k = (j - jitter) / 10.0;
        float d = k * reach;
        float sway = (ui_fbm(float2(p.x * 5.0 + seed, (p.y + d) * 3.0 + t * 1.9)) - 0.5) * 0.35 * d;
        float m = max(flame_mask(q, p + float2(sway, d)), max(flame_mask(q, p + float2(sway - d * 0.6, d * 0.8)), flame_mask(q, p + float2(sway + d * 0.6, d * 0.8))));
        below = min(below, lerp(1.0, k, smoothstep(0.3, 0.7, m)));
    }
    float self = flame_mask(q, p);
    float heat = (1.0 - below) * (1.0 - self * 0.3);
    float2 warp = float2(ui_fbm(float2(p.x * 3.0 + seed, p.y * 2.0 + t * 1.3)), ui_fbm(float2(p.x * 3.0 - seed, p.y * 2.0 + t * 1.1))) - 0.5;
    float n1 = ui_fbm(float2(p.x * 7.0 - seed, p.y * 4.0 + t * 2.8) + warp * 1.6);
    float n2 = ui_fbm(float2(p.x * 16.0 + seed, p.y * 9.0 + t * 4.4) + warp);
    float f = heat * 1.35 - (1.0 - n1) * 0.85 + (n2 - 0.5) * 0.3;
    f = saturate(f * 1.7);
    if (front)
    {
        // tongues licking up over the piece's lower part, thin and bright
        float lick = saturate(n1 * 1.7 - 0.85 + (p.y - 0.45) * 1.4 + (n2 - 0.5) * 0.5);
        float k = lick * self * strength * 0.6 * ui_cover(q.d, q.px);
        return float4(flame_ramp(0.35 + lick * 0.6, hue) * k, k * 0.7);
    }
    // a glow round the piece's outline, warm on the squares round it
    float near = 0.0;
    [unroll] for (int s6 = 0; s6 < 6; s6++)
    {
        float ang = s6 * 1.0472 + 0.4;
        near += flame_mask(q, p + float2(cos(ang), sin(ang)) * 0.09);
    }
    float glow = near / 6.0 * (1.0 - self) * (0.25 + 0.15 * n1) * strength;
    // sparks drifting up out of the flames, each a cell of a grid scrolling up
    float2 g = float2(p.x * 10.0 + seed * 3.0, p.y * 7.0 + t * 1.8);
    float2 cell = floor(g);
    float h = flame_hash(cell + seed);
    float2 o = float2(flame_hash(cell + 7.1) - 0.5, flame_hash(cell + 3.3) - 0.5) * 0.5 + float2(sin(t * 3.0 + h * 20.0) * 0.12, 0.0);
    float spark = step(0.9 - strength * 0.06, h) * saturate(1.0 - length(frac(g) - 0.5 - o) * 7.0);
    spark *= smoothstep(-FlameUp, -0.3, p.y) * smoothstep(0.4, 0.0, p.y) * saturate(heat * 4.0 + 0.2 * (1.0 - below)) * strength * (1.0 - self);
    float3 c = flame_ramp(f * (0.55 + 0.45 * heat), hue);
    float a = smoothstep(0.0, 0.28, f) * (0.6 + 0.4 * strength);
    float k = saturate(a + glow) * ui_cover(q.d, q.px);
    float3 lit = c * a + flame_ramp(0.3, hue) * glow + flame_ramp(0.9, hue) * spark;
    return float4(lit * ui_cover(q.d, q.px), saturate(k * 0.8 + spark * 0.5));
}

UI_MATERIAL(flame)

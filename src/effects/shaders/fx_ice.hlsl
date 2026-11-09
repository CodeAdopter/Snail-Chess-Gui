// The last place's frost: ice creeping in from a box's edges over its fill for two seconds and
// holding there, its veins catching a few glints, and a cold tint over the rest. Values: intensity,
// seconds since it began, unused, seed.

#include "C:/Snail/Snail Engine/engine/shaders/ui_material.hlsli"

float4 ice(UiPixel q)
{
    float strength = saturate(q.values.x);
    float t = q.values.y;
    float grow = 1.0 - pow(1.0 - saturate(t / 2.0), 3.0);
    float inside = max(-q.d, 0.0);
    float2 p = q.p - q.s.rect.xy;
    float n = ui_fbm(p / 6.0 + q.values.w);
    float veins = 1.0 - abs(ui_fbm(p / 3.0 - q.values.w) * 2.0 - 1.0);
    float half = min(q.s.rect.z, q.s.rect.w) * 0.5;
    float front = half * (0.25 + 0.4 * strength) * grow * (0.6 + 0.8 * n);
    float frost = smoothstep(front, front * 0.4, inside);
    float a = frost * (0.45 + 0.55 * veins * veins * veins) * (0.35 + 0.35 * strength);
    float2 cell = floor(p / 5.0);
    float h = frac(sin(dot(cell + q.values.w, float2(12.9898, 78.233))) * 43758.5453);
    float2 f = frac(p / 5.0) - 0.5;
    float glint = step(0.93, h) * frost * saturate(1.0 - length(f) * 3.0) * (0.6 + 0.4 * sin(t * 6.0 + h * 40.0));
    float cover = ui_cover(q.d, q.px);
    float3 under = lerp(q.color.rgb, float3(0.55, 0.75, 0.95) * q.color.a, 0.12 * strength * grow);
    float k = a * cover;
    float3 c = float3(0.62, 0.84, 1.0) * k + under * (1.0 - k) + glint * 0.8 * cover;
    return float4(c, saturate(k + q.color.a * (1.0 - k) + glint * 0.5 * cover));
}

UI_MATERIAL(ice)

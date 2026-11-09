// Fire on a square: flames rising from the foot of a box over its own fill, kindled over half a
// second, what is drawn after it staying on top. A sacrifice's square burns gold.
// Values: intensity, seconds of the burning clock, the colours (0 orange, 1 red, 2 gold), seed.

#include "C:/Snail/Snail Engine/engine/shaders/ui_material.hlsli"

float4 fire(UiPixel q)
{
    float strength = saturate(q.values.x);
    float t = q.values.y;
    float2 p = q.p - q.s.rect.xy;
    float up = 1.0 - q.uv.y;
    float rise = t * 1.7;
    float body = ui_fbm(float2(p.x / 9.0 + q.values.w, p.y / 7.0 + rise));
    float tongues = ui_fbm(float2(p.x / 3.0 - q.values.w, p.y / 14.0 + rise * 1.2));
    float kindle = saturate(t / 0.5);
    float height = (0.35 + 0.45 * strength) * kindle;
    float ends = smoothstep(0.0, 0.06, q.uv.x) * smoothstep(1.0, 0.94, q.uv.x);
    float heat = saturate(body * 0.55 + tongues * tongues * 1.1 - up / max(height, 0.05) * 0.85) * ends;
    float3 deep = float3(0.55, 0.06, 0.02);
    float3 flame = float3(1.0, 0.42, 0.06);
    float3 tip = float3(1.0, 0.84, 0.36);
    if (q.values.z > 1.5)
    {
        deep = float3(0.5, 0.28, 0.0);
        flame = float3(1.0, 0.72, 0.12);
        tip = float3(1.0, 0.95, 0.62);
    }
    else if (q.values.z > 0.5)
    {
        deep = float3(0.45, 0.0, 0.02);
        flame = float3(0.95, 0.12, 0.08);
        tip = float3(1.0, 0.55, 0.35);
    }
    float3 c = lerp(deep, flame, smoothstep(0.1, 0.45, heat));
    c = lerp(c, tip, smoothstep(0.55, 0.85, heat));
    float ember = exp(-up * 9.0) * 0.5 * strength * kindle * ends;
    float a = saturate(smoothstep(0.05, 0.4, heat) * (0.45 + 0.4 * strength) + ember);
    float k = a * ui_cover(q.d, q.px);
    return float4(c * k + q.color.rgb * (1.0 - k), k + q.color.a * (1.0 - k));
}

UI_MATERIAL(fire)

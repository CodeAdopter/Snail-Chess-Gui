// A streak of light behind a piece crossing the flat board, under the pieces: a line from the
// square it left to the one it reaches, as bright as a thread at its middle with a soft glow
// round it, widest just behind the piece and thinning toward where it started, fading once the
// piece is down. Drawn as the line itself, whose ends the material reads. Values: strength,
// seconds since the move, how far along the piece is from 0 to 1, the effect's length in seconds.

#include "C:/Snail/Snail Engine/engine/shaders/ui_material.hlsli"

float4 trail(UiPixel q)
{
    float strength = saturate(q.values.x);
    float t = q.values.y;
    float head = saturate(q.values.z);
    float life = saturate(t / max(q.values.w, 0.01));
    float2 a = q.s.geo.xy;
    float2 b = q.s.geo.zw;
    float2 ab = b - a;
    float span = max(length(ab), 1.0);
    float2 way = ab / span;
    float along = dot(q.p - a, way) / span;
    float across = abs(dot(q.p - a, float2(-way.y, way.x)));
    float wide = q.s.look.x * 0.5;
    float behind = head - along;
    float shown = smoothstep(-0.02, 0.01, behind) * smoothstep(-0.12, 0.0, along);
    float tail = saturate(1.0 - behind * (0.6 + life * 2.4));
    float w = wide * (0.25 + 0.75 * tail);
    float core = exp(-pow(across / max(w * 0.28, 0.5), 2.0));
    float glow = exp(-pow(across / max(w, 0.5), 2.0)) * 0.45;
    float shimmer = 0.8 + 0.2 * ui_value_noise(float2(along * span / 6.0 - t * 9.0, 0.5));
    float fade = pow(1.0 - life, 1.4) * tail;
    float k = saturate((core + glow) * fade * shown * shimmer) * strength * ui_cover(q.d, q.px);
    float3 c = lerp(float3(1.0, 0.7, 0.32), float3(1.0, 0.95, 0.8), core);
    return float4(c * k, k * 0.6);
}

UI_MATERIAL(trail)

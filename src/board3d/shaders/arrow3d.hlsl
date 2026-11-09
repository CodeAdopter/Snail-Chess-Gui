// The 3D board's arcs in their own colour, shaded only enough to show their round: lighter where
// they face the sun or the sky, darker underneath, with a sheen along the top toward the eye, so
// they read on a light board or a dark one alike.

#include "C:/Snail/Snail Engine/engine/shaders/three.hlsli"

float4 arrow_ps(ThreeOut i) : SV_Target0
{
    float3 n = normalize(i.normal);
    float3 l = three_sun_way();
    float3 v = normalize(lights.eye.xyz - i.world);
    float sun = saturate(dot(n, l));
    float sky = 0.5 + 0.5 * n.y;
    float sheen = pow(saturate(dot(n, normalize(l + v))), 32.0);
    float3 c = i.color.rgb * (0.5 + 0.25 * sky + 0.4 * sun) + sheen * 0.3;
    return float4(c, i.depth);
}

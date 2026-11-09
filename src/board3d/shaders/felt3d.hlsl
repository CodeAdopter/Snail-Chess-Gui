// The felt glued under a piece's foot, its colour the tint as sRGB: soft fibres, lit mostly by the
// room since the foot overhangs it, with the sheen cloth shows where it turns from the eye. Its top
// lies against the underside, which the shadow map cannot tell from it, so it is shaded as covered,
// as it shows through a glass foot.

#include "wood3d.hlsl"

float4 felt_ps(WoodOut i) : SV_Target0
{
    float3 n = normalize(i.normal);
    float3 eye = three_eye();
    if (i.flip > 0.5) eye.y = -eye.y;
    float3 v = normalize(eye - i.world);
    float fibre = wood_noise(i.world * 1400.0) * 0.6 + wood_noise(i.world * 380.0) * 0.4;
    float sheen = pow(1.0 - saturate(dot(n, v)), 3.0);
    float3 c = three_srgb_to_linear(i.color.rgb) * (0.8 + 0.35 * fibre) * (1.0 + sheen * 0.7);
    float covered = smoothstep(0.3, 0.8, n.y);
    return wood_lit(i, n, c * (1.0 - 0.8 * covered), 1.0, 0.0, 1.0, 0.55, lerp(0.6, 0.1, covered));
}

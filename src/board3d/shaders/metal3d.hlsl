// Turned metal pieces for the 3D board, polished brass for white and pewter for black, mirroring
// the room and the board they stand on, with the fine rings the lathe leaves catching the light.

#include "pieces3d.hlsli"

// A metal piece. Values: white's metal as sRGB and its roughness, black's the same, then the
// board's squares.
float4 metal_piece_ps(WoodOut i) : SV_Target0
{
    PieceFx fx = piece_fx(i);
    float4 kind = piece_white(i) ? material[0] : material[1];
    float3 f0 = three_srgb_to_linear(kind.rgb);
    float3 p = i.local;
    float seed = wood_hash(float3(i.color.a * 97.0, 0.37, 1.3));
    float rings = p.y * 420.0;
    float fine = saturate(1.0 - fwidth(rings) * 0.6);
    float groove = (sin(rings) * 0.5 + 0.5) * fine;
    float rough = clamp(kind.w + groove * 0.05 + (wood_fbm(p * 30.0 + seed * 7.0) - 0.5) * 0.06, 0.04, 1.0);
    float3 n = wood_bump(normalize(i.normal), i.world, -groove * 0.0003);
    float3 v = normalize(piece_eye(i) - i.world);
    float3 l = three_sun_way();
    float nv = saturate(dot(n, v));
    float nl = saturate(dot(n, l));
    float3 sun = lights.sun_color.rgb * wood_shadow(i);
    float2 ab = wood_env_brdf(rough, nv);
    float ao = piece_foot(i);
    float3 c = sun * nl * THREE_PI * three_specular_ggx(l, v, n, f0, rough);
    c += piece_seen(i.world, i.seed.xz, reflect(-v, n), rough) * (f0 * ab.x + ab.y) * ao;
    c += (three_hemisphere(n) * THREE_RECIPROCAL_PI + sun * nl) * f0 * 0.04 * ao;
    return piece_fx_over(i, fx, piece_out(i, c, 1.0));
}

// Paper pieces for the 3D board, each folded from a sheet: cream cartridge paper for white and a
// deep indigo for black. The folded meshes give every triangle corners of its own, its face's
// normal and its place in the triangle as uv, so each flat facet catches the light on its own,
// pressed a shade lighter or darker than its neighbours, the creases along its edges whitened where
// the fibres were bent, and the paper's fibres and tooth show up close. Light glows a little
// through thin white paper turned from the sun. Values: white's paper as sRGB and how much light it
// lets through, black's the same, then the board's squares.

#include "pieces3d.hlsli"

float4 paper_piece_ps(WoodOut i) : SV_Target0
{
    PieceFx fx = piece_fx(i);
    bool white = piece_white(i);
    float4 kind = white ? material[0] : material[1];
    float3 paper = three_srgb_to_linear(kind.rgb);
    float seed = i.color.a;
    float3 n = normalize(i.normal);
    // each facet pressed its own shade, picked by the way it faces in the piece's own turn
    float face = wood_hash(round(n * 23.0) + seed * 7.0);
    float3 bary = float3(i.uv, 1.0 - i.uv.x - i.uv.y);
    float edge = min(bary.x, min(bary.y, bary.z));
    float w = fwidth(edge);
    float crease = 1.0 - smoothstep(w * 0.4, w * 1.6, edge);
    float3 p = i.local;
    float fine = saturate(1.0 - length(fwidth(p)) * 120.0);
    float fibre = (wood_noise(float3(p.x * 90.0, p.y * 30.0, p.z * 90.0)) - 0.5) * 0.08 + (wood_noise(p * 320.0) - 0.5) * 0.06 * fine;
    float3 albedo = paper * (0.93 + 0.1 * face + fibre) * (1.0 + crease * (white ? 0.08 : 0.35));
    float3 v = normalize(piece_eye(i) - i.world);
    float3 l = three_sun_way();
    float nl = dot(n, l);
    float3 sun = lights.sun_color.rgb * wood_shadow(i);
    float ao = piece_foot(i);
    float3 sky = three_hemisphere(n) * THREE_RECIPROCAL_PI;
    float3 c = albedo * (sky * ao + sun * (saturate(nl) + saturate(-nl) * kind.w));
    float rough = 0.62;
    float nv = saturate(dot(n, v));
    float2 ab = wood_env_brdf(rough, nv);
    c += piece_seen(i.world, i.seed.xz, reflect(-v, n), rough) * (0.03 * ab.x + ab.y) * ao;
    c += sun * saturate(nl) * THREE_PI * three_specular_ggx(l, v, n, float3(0.03, 0.03, 0.03), rough);
    return piece_fx_over(i, fx, piece_out(i, c, 1.0));
}

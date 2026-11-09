// Marble for the 3D board and its pieces, polished to a mirror: white Carrara and black Marquina
// squares cut each from its own part of the block, set with a fine dark seam, a deep green frame,
// and pieces turned from white and black stone, the white letting a little light through where it
// is thin. Veins are worked out in the stone's own space, so they run on through a piece.

#include "pieces3d.hlsli"

struct Stone
{
    float3 color;
    float vein;
};

// Marble at q: a cloudy ground of base mottled toward cloud, wandering veins of vein's colour about
// width wide, and a fainter web of hair veins as strong as hair, all bent by noise. What would be
// finer than a pixel fades to its average, so the veins never shimmer. Colours are sRGB.
Stone stone_at(float3 q, float3 base, float3 cloud, float3 vein, float width, float hair)
{
    float3 w = q + (float3(wood_fbm(q * 0.7), wood_fbm(q * 0.7 + 3.7), wood_fbm(q * 0.7 + 8.1)) - 0.5) * 1.8;
    float t = dot(w, float3(0.75, 0.3, 0.55)) * 0.55 + wood_fbm(w * 1.6) * 1.1;
    float d = abs(frac(t) - 0.5);
    float aa = fwidth(t);
    float vw = width * (0.4 + 1.2 * wood_fbm(w * 1.1 + 4.0));
    float v1 = 1.0 - smoothstep(vw, vw + aa + 0.003, d);
    float halo = (1.0 - smoothstep(0.0, vw * 5.0 + 0.04, d)) * 0.15;
    v1 = lerp(max(v1, halo), vw * 2.0 + 0.05, saturate(aa * 4.0 - 0.2));
    float t2 = dot(w, float3(-0.4, 0.7, 0.6)) * 1.6 + wood_fbm(w * 2.6 + 2.0) * 2.0;
    float d2 = abs(frac(t2) - 0.5);
    float aa2 = fwidth(t2);
    float v2 = (1.0 - smoothstep(0.006, 0.01 + aa2, d2)) * smoothstep(0.45, 0.75, wood_fbm(w * 1.2 + 9.0));
    v2 = lerp(v2, 0.02, saturate(aa2 * 4.0 - 0.2));
    float cl = smoothstep(0.25, 0.8, wood_fbm(w * 0.9 + 5.0));
    float3 c = lerp(three_srgb_to_linear(base), three_srgb_to_linear(cloud), cl * 0.7);
    Stone s;
    s.vein = saturate(v1 + v2 * hair);
    s.color = lerp(c, three_srgb_to_linear(vein), s.vein);
    return s;
}

Stone carrara(float3 q)
{
    return stone_at(q, float3(0.83, 0.83, 0.81), float3(0.74, 0.75, 0.77), float3(0.52, 0.54, 0.59), 0.012, 0.35);
}

Stone marquina(float3 q)
{
    return stone_at(q * 0.6 + 11.0, float3(0.045, 0.045, 0.05), float3(0.075, 0.075, 0.08), float3(0.42, 0.42, 0.41), 0.006, 0.15);
}

Stone verde(float3 q)
{
    return stone_at(q * 0.9 + 23.0, float3(0.05, 0.13, 0.09), float3(0.09, 0.22, 0.15), float3(0.3, 0.4, 0.34), 0.008, 0.4);
}

// The squares, uv across the field from 0 to 1 with a8 at its far left, white and black marble
// each turned its own way, their edges rounded into a fine dark seam, mirroring the pieces drawn
// under the board into the extra image. Values: x how strongly the pieces show mirrored, y the
// stone's roughness under its polish and z the polish's own.
float4 marble_board_ps(WoodOut i) : SV_Target0
{
    float2 at = i.uv * 8.0;
    float2 cell = min(floor(at), 7.0);
    float2 f = at - cell;
    float rank = 7.0 - cell.y;
    bool dark = fmod(cell.x + rank, 2.0) < 0.5;
    float seed = wood_hash(float3(cell, 3.0));
    float turn = seed * 6.2832;
    float2 g = f - 0.5;
    g = float2(g.x * cos(turn) - g.y * sin(turn), g.x * sin(turn) + g.y * cos(turn));
    float3 q = float3(g.x + seed * 31.0, seed * 7.0, g.y + wood_hash(float3(cell, 9.0)) * 17.0);
    Stone s = carrara(q);
    if (dark) s = marquina(q);
    float3 c = s.color;
    float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
    float seam = smoothstep(0.0, fwidth(at.x) + 0.005, edge);
    c *= lerp(0.3, 1.0, seam);
    float ao = field_marks(i, cell, f, edge, s.color, c);
    float2 toward = f.x < 0.5 ? float2(-1.0, 0.0) : float2(1.0, 0.0);
    if (min(f.y, 1.0 - f.y) < min(f.x, 1.0 - f.x)) toward = f.y < 0.5 ? float2(0.0, -1.0) : float2(0.0, 1.0);
    float round = 1.0 - smoothstep(0.0, 0.03, edge);
    float3 n = normalize(float3(toward.x * round * 0.6, 1.0, toward.y * round * 0.6));
    float4 seen = wood_mirror(i, n, 0.08) * material[0].x;
    return wood_lit_seen(i, n, c, material[0].y, 1.0, material[0].z, ao, lerp(0.75, 1.0, ao), seen);
}

// The frame, one slab of green marble round the field, its outer edge rounded down, mirroring the
// pieces near it. Values as the squares'.
float4 marble_frame_ps(WoodOut i) : SV_Target0
{
    float3 n = normalize(i.normal);
    Stone s = verde(i.world * 0.9);
    float4 seen = wood_mirror(i, n, 0.1) * material[0].x * step(0.9, n.y);
    return wood_lit_seen(i, n, s.color, material[0].y, 1.0, material[0].z, 1.0, 1.0, seen);
}

// A piece turned from stone, white Carrara or black Marquina as its tint says, each cut from its
// own part of the block, polished. Light comes through the white where it is thin, warm and soft,
// most where the sun lies behind it. Values: x the stone's roughness, y the polish's, z how much
// light the white lets through, then the board's squares.
float4 marble_piece_ps(WoodOut i) : SV_Target0
{
    PieceFx fx = piece_fx(i);
    float seed = wood_hash(float3(i.color.a * 97.0, 0.37, 1.3));
    float3 p = i.local;
    bool white = piece_white(i);
    float3 q = p * 1.7 + float3(seed * 13.0, seed * 5.0, seed * 29.0);
    Stone s = marquina(q);
    if (white) s = carrara(q);
    float ao = piece_foot(i);
    float3 n = normalize(i.normal);
    float4 o = wood_lit(i, n, s.color, material[0].x, 1.0, material[0].y, ao, 1.0);
    if (white)
    {
        float3 v = normalize(piece_eye(i) - i.world);
        float3 l = three_sun_way();
        float thin = 1.0 - smoothstep(0.06, 0.26, length(p.xz));
        float through = pow(saturate(dot(v, -l)), 3.0) * 0.8 + saturate(-dot(n, l)) * 0.35 + 0.08;
        o.rgb += lights.sun_color.rgb * s.color * float3(1.0, 0.92, 0.8) * thin * through * material[0].z * ao;
    }
    return piece_fx_over(i, fx, o);
}

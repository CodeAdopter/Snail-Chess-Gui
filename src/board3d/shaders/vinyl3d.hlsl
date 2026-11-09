// A club's roll up mat for the 3D board: green and buff squares printed on pebbled vinyl that
// still remembers being rolled, in long low waves across it, with its coordinates printed on its
// border in the green, each side's turned to read from that side.

#include "wood3d.hlsl"

// The normal of the mat's top at p, bent by the waves of its roll and its pebbled grain
float3 vinyl_normal(float3 p)
{
    float3 n = float3(0.0, 1.0, sin(p.z * 1.7 + 0.6) * 0.025 + sin(p.z * 4.3 + 2.0) * 0.008);
    float fine = saturate(1.5 - length(fwidth(p.xz * 220.0)) * 0.8);
    return wood_bump(normalize(n), p, wood_noise(float3(p.xz * 220.0, 0.5)) * 0.0005 * fine);
}

// The squares, uv across the field from 0 to 1 with a8 at its far left, flat print with a faint
// mottle. Values: the buff and the green as sRGB, then x the vinyl's roughness and y its sheen.
float4 vinyl_board_ps(WoodOut i) : SV_Target0
{
    float2 at = i.uv * 8.0;
    float2 cell = min(floor(at), 7.0);
    float2 f = at - cell;
    float rank = 7.0 - cell.y;
    bool dark = fmod(cell.x + rank, 2.0) < 0.5;
    float3 base = three_srgb_to_linear(dark ? material[1].rgb : material[0].rgb);
    float fine = saturate(1.5 - length(fwidth(i.world.xz * 40.0)));
    float3 c = base * (0.97 + 0.06 * (wood_noise(float3(i.world.xz * 40.0, 1.0)) - 0.5) * fine);
    float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
    float ao = field_marks(i, cell, f, edge, base, c);
    return wood_lit(i, vinyl_normal(i.world), c, material[2].x, 0.35, material[2].y, ao, lerp(0.75, 1.0, ao));
}

// The border, buff with the coordinates printed in the green, its cut edge a little darker.
// Values as the squares'.
float4 vinyl_frame_ps(WoodOut i) : SV_Target0
{
    float3 n = normalize(i.normal);
    float3 c = three_srgb_to_linear(material[0].rgb);
    if (n.y < 0.9) return wood_lit(i, n, c * 0.8, material[2].x, 0.2, material[2].y, 1.0, 1.0);
    float2 p = i.world.xz;
    float2 up = abs(p.y) > 4.0 && abs(p.x) < 4.0 ? float2(0.0, -sign(p.y)) : float2(-sign(p.x), 0.0);
    float2 right = float2(-up.y, up.x);
    float lod = max(log2(sqrt(length(ddx(p)) * length(ddy(p))) * 96.0 / CoordCell), 0.0);
    float d = coord_distance(p, up, right, lod);
    float aw = fwidth(d) + 0.0008;
    c = lerp(c, three_srgb_to_linear(material[1].rgb), smoothstep(aw, -aw, d));
    return wood_lit(i, vinyl_normal(i.world), c, material[2].x, 0.35, material[2].y, 1.0, 1.0);
}

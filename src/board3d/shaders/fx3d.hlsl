// The effects of the 3D board that stand in the air, each drawn on a quad: sheets of flame round a
// piece that burns and round a sacrifice's square, a glow round the fire, sparks drifting up from
// it, and puffs of dust where a piece lands, plus the moss's fuzz, shells of a mossy piece pushed
// out along its normals and cut to strands where the moss lies. Flames, glows and sparks add their
// light and keep the alpha, the depth the lens reads, and dust lays its colour over keeping it.
// Material values: time in x. A flame's or a spark's tint is its fire's colour as bright as it
// burns, and its alpha a seed.

#include "wood3d.hlsl"

// How far the outermost moss shell stands off the piece, in squares
static const float MossDepth = 0.018;

// A sheet of fire from its root at v 0 to its tip, a body wide at the root that narrows as it
// rises, torn into tongues by noise rising through it, a white core, then the hue, then dull red
float4 flame_fx_ps(WoodOut i) : SV_Target0
{
    float t = material[0].x;
    float seed = i.color.a * 40.0;
    float2 q = float2(i.uv.x * 2.0 - 1.0, i.uv.y);
    float rise = t * 1.6;
    float warp = wood_fbm(float3(q.x * 1.5 + seed, q.y * 1.2 - rise * 0.6, seed)) - 0.5;
    float n1 = wood_fbm(float3(q.x * 3.0 + warp * 1.4 + seed, q.y * 2.6 - rise, seed + t * 0.25));
    float n2 = wood_fbm(float3(q.x * 7.0 - seed, q.y * 6.0 - rise * 1.6, seed * 2.0 + t * 0.5));
    float width = lerp(0.9, 0.18, pow(q.y, 0.75));
    float body = 1.0 - smoothstep(width * 0.3, width, abs(q.x + (n1 - 0.5) * 0.7 * q.y));
    float heat = body * (1.1 - q.y * 0.9) + (n2 - 0.5) * 1.1 * (0.3 + q.y) + (n1 - 0.5) * 0.8 - q.y * 0.25;
    heat *= smoothstep(0.0, 0.22, q.y) * smoothstep(1.0, 0.7, q.y);
    heat = saturate(heat * 1.5);
    float bright = max(i.color.r, max(i.color.g, i.color.b));
    float3 hue = i.color.rgb / max(bright, 0.001);
    return float4(piece_fx_heat(hue, heat * 0.92) * pow(heat, 1.5) * bright * 3.4, 0.0);
}

// A soft glow round a fire facing the eye, brightest in its middle. Tint is its colour.
float4 halo_fx_ps(WoodOut i) : SV_Target0
{
    float2 d = i.uv * 2.0 - 1.0;
    float r = dot(d, d);
    float g = exp(-r * 3.0) * 0.6 + exp(-r * 14.0) * 0.4;
    g *= 1.0 - smoothstep(0.7, 1.0, r);
    float flicker = 0.85 + 0.15 * sin(material[0].x * 11.0 + i.color.a * 30.0);
    return float4(i.color.rgb * g * flicker, 0.0);
}

// Sparks drifting up from a fire over a sheet from its root at v 0, each a cell of a grid
// scrolling up, swaying, cooling from white to the fire's colour and dying as it rises
float4 spark_fx_ps(WoodOut i) : SV_Target0
{
    float t = material[0].x;
    float seed = i.color.a * 40.0;
    float2 g = float2(i.uv.x * 7.0 + seed, i.uv.y * 9.0 - t * 2.2);
    float2 cell = floor(g);
    float h = wood_hash(float3(cell, seed));
    float2 o = float2(wood_hash(float3(cell, 7.1)) - 0.5, wood_hash(float3(cell, 3.3)) - 0.5) * 0.5 + float2(sin(t * 3.0 + h * 20.0) * 0.15, 0.0);
    float spark = step(0.86, h) * saturate(1.0 - length(frac(g) - 0.5 - o) * 6.0);
    float up = i.uv.y;
    spark *= smoothstep(0.0, 0.15, up) * (1.0 - up) * smoothstep(1.0, 0.5, abs(i.uv.x * 2.0 - 1.0));
    float bright = max(i.color.r, max(i.color.g, i.color.b));
    float3 hue = i.color.rgb / max(bright, 0.001);
    return float4(piece_fx_heat(hue, 1.0 - up * 0.8) * spark * bright * 7.0, 0.0);
}

// A puff of dust facing the eye, a soft lumpy ball, lit from above by the sun and the sky. Tint
// is the dust's colour and how thick the puff is.
float4 dust_fx_ps(WoodOut i) : SV_Target0
{
    float2 d = i.uv * 2.0 - 1.0;
    float lump = wood_fbm(float3(d * 2.5, i.color.a * 9.0 + material[0].x * 0.4)) - 0.5;
    float r = length(d) + lump * 0.55;
    float puff = smoothstep(1.0, 0.25, r);
    float top = saturate(0.6 - d.y * 0.4 + lump);
    float3 light = lights.sun_color.rgb * saturate(three_sun_way().y) * 0.45 * top + three_hemisphere(float3(0.0, 1.0, 0.0)) * THREE_RECIPROCAL_PI;
    return float4(i.color.rgb * light, puff * i.color.a);
}

// A moss shell, the piece's own mesh pushed out along its normals as far as the tint's alpha says
// of MossDepth, its own place kept for the moss's noise
WoodOut moss_vs(ThreeIn i)
{
    float3 at = i.position;
    i.position += i.normal * (i.tint.a * MossDepth);
    WoodOut o = wood_vs(i);
    o.local = at;
    return o;
}

// A shell of moss, kept where a strand reaches as high as the shell stands, the strands thick in
// clumps, darker deep in the moss and yellower at its tips
float4 moss_shell_ps(WoodOut i) : SV_Target0
{
    PieceFx f = piece_fx_find(i);
    float shell = i.color.a;
    float3 p = i.local;
    float3 n = normalize(i.normal);
    float cover = moss_cover(p, n, f.moss, f.seed);
    float strand = wood_noise(p * 160.0 + f.seed * 7.0);
    float clump = wood_noise(p * 40.0 + f.seed);
    clip(cover * (0.3 + 0.7 * strand) * (0.55 + 0.6 * clump) - shell);
    return wood_lit(i, n, moss_colour(p, f.seed, shell), 0.95, 0.0, 0.6, 0.3 + 0.7 * shell, 1.0);
}

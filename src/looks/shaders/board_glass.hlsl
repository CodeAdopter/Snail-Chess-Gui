// Glass: each square a thick tile of stained glass on a plate lit from below, a narrow gap between
// them. A tile's colour is the light coming up through it, stained by how far it travels in the
// glass, so its rounded edges, where the light crosses more of it, run deeper than its face, and
// the stain thickens and thins in soft streaks as poured glass does. Light gathers inside along
// the edge away from the lamp and glows there, while the edge toward it catches a bright line.
// Each tile throws a shadow on the plate, coloured by its glass, and its face mirrors a crisp
// window of four panes, broken from tile to tile as each sits at its own slight tilt. Style 1 is
// lightly stained glass on a frosted plate, 2 deeply stained glass on a dark one.
// Values: the light glass and the dark glass as 0xRRGGBB, each as it looks over white through a
// tile's face, the style, unused.

#include "backdrop.hlsli"

// How far outside a box p is, the box centred on the origin, half wide half and its corners
// rounded by r.
float tile_sd(float2 p, float half_wide, float r)
{
    float2 d = abs(p) - (half_wide - r);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// The colour of the glass in the square holding u, in squares from the board's top left.
float3 stain_at(float2 u, float3 light, float3 dark)
{
    float2 cell = floor(u);
    return fmod(cell.x + cell.y, 2.0) < 0.5 ? light : dark;
}

float4 glass(UiPixel q)
{
    float2 uv = q.uv * 8.0;
    float2 cell = floor(uv);
    float2 f = uv - cell;
    float3 light_glass = looks_rgb(q.values.x);
    float3 dark_glass = looks_rgb(q.values.y);
    float style = q.values.z;
    bool deep_set = style > 1.5;
    float3 stain = stain_at(uv, light_glass, dark_glass);
    float2 h = bd_hash2(cell + float2(23.0 * style, 5.0));
    float sq_px = looks_size(q).x / 8.0;
    float px = 1.0 / max(sq_px, 1.0);
    float gap = max(0.022, 1.4 * px);
    float half_wide = 0.5 - gap;
    float corner = 0.04;
    float bevel = max(0.075, 4.0 * px);
    float2 c0 = f - 0.5;
    float sd = tile_sd(c0, half_wide, corner);
    // which way is out at this point, from the box's slope
    float2 e = float2(0.004, 0.0);
    float2 out_dir = float2(tile_sd(c0 + e.xy, half_wide, corner) - tile_sd(c0 - e.xy, half_wide, corner),
                            tile_sd(c0 + e.yx, half_wide, corner) - tile_sd(c0 - e.yx, half_wide, corner));
    out_dir /= max(length(out_dir), 1e-5);
    // the rounded edge: u runs from 0 at the tile's rim to 1 where its flat face begins
    float u = saturate(-sd / bevel);
    float rise = 1.0 - u;
    float3 n = normalize(float3(out_dir * rise * rise * 3.0, 1.0));
    float2 to_lamp = normalize(float2(-0.6, -0.8));
    float toward = saturate(dot(out_dir, to_lamp));
    float away = saturate(dot(out_dir, -to_lamp));
    // the light through the tile, stained by the glass it crosses
    float3 absorb = -log(max(stain, 0.02));
    float streak = bd_fbm(float2(f.x * 1.4 + h.x * 37.0, f.y * 2.2 + h.y * 29.0), 4);
    float thick = (1.0 + 2.2 * rise * rise) * (0.84 + 0.32 * streak);
    float3 c = (deep_set ? 0.95 : 1.0) * exp(-absorb * thick);
    // more of it reaches the face toward the far side, and gathers in a glow along that edge
    c *= 0.9 + 0.2 * smoothstep(-0.45, 0.45, dot(c0, -to_lamp));
    float pool = away * exp(-pow((-sd - bevel * 1.5) / (bevel * 0.6), 2.0));
    c += sqrt(stain) * stain * pool * (deep_set ? 0.38 : 0.3);
    // the edge toward the lamp catches a bright line, the far edge a faint one
    float rim = exp(-pow((u - 0.32) / 0.13, 2.0));
    c += rim * (toward * 0.55 + away * 0.08);
    // the room mirrored in the curve of the edge, as glass does more the more slant it sits
    float fresnel = pow(rise, 3.0);
    c = lerp(c, lerp(c, float3(1.0, 1.0, 1.0), 0.18 + 0.3 * toward), fresnel * 0.6);
    // a crisp window of four panes mirrored over the top right of the faces, each tile tilted a hair
    float aa = px * 0.2;
    float2 w = q.uv + (h - 0.5) * 0.012;
    float wx = w.x - 0.7 + w.y * 0.1;
    float wy = w.y - 0.22;
    float frame = max(abs(wx) - 0.17, abs(wy) - 0.3);
    float window = smoothstep(aa, -aa, frame) * smoothstep(0.012 - aa, 0.012 + aa, abs(wx)) * smoothstep(0.012 - aa, 0.012 + aa, abs(wy + 0.05));
    window *= 0.75 + 0.25 * saturate(-wy / 0.3 + 0.5);
    float sheen = exp(-pow((w.x * 0.8 + w.y * 0.6 - 0.42) / 0.22, 2.0));
    c += (window * (deep_set ? 0.14 : 0.1) + sheen * 0.04) * smoothstep(0.9, 1.0, u);
    // the plate between the tiles, in the shade of their sides and the coloured shadow each throws
    float2 su = uv - to_lamp * 0.07;
    float shadow = 1.0 - smoothstep(-0.05, 0.05, tile_sd(frac(su) - 0.5, half_wide, corner));
    float3 shadow_tint = lerp(float3(1.0, 1.0, 1.0), pow(stain_at(su, light_glass, dark_glass), 1.5) * 0.8, shadow);
    float3 plate = deep_set ? float3(0.06, 0.055, 0.07) : float3(0.82, 0.86, 0.87);
    plate *= shadow_tint * lerp(0.6, 1.0, smoothstep(0.0, gap, sd));
    c = lerp(plate, c, saturate(0.5 - sd / px));
    c *= 1.03 - 0.06 * length(q.uv - float2(0.3, 0.25));
    return looks_out(q, c);
}

UI_MATERIAL(glass)

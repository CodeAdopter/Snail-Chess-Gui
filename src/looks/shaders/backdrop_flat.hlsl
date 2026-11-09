// The flat backdrops, still and light to draw. Variants 0 to 2 are the person's own two colours:
// the first alone, the first fading down into the second, or the second glowing round the board
// out into the first. 3 is mist, cool greys lit softly behind the board, 4 midnight, deep blue
// darkening out, 5 paper, cold pressed with a raised tooth, 6 linen, woven threads, 7 concrete,
// cast and matte with grit and pores. Colours and gradients float off the board on a soft shadow,
// and the board lies on the textures, its shadow close under it.
// Values: the first colour as 0xRRGGBB for the person's own, else unused, then the board as every
// backdrop has it. The fill is the second colour.

#include "backdrop.hlsli"

// Where the light over the textures comes from, up and to the left, low enough to rake their relief.
static const float3 ToLamp = float3(-0.42, -0.62, 0.66);

float3 hex3(float v)
{
    return looks_rgb(v);
}

// Light that pools round the board, 1 at its middle falling to 0 well out.
float pool(float2 u, float reach)
{
    return exp(-dot(u, u) / (reach * reach));
}

// How much of a detail cells across a board half shows at pixels px wide: whole while a cell is
// several pixels, gone before one would be a pixel.
float shows(float cells, float px)
{
    return saturate((1.0 / (cells * px) - 2.0) * 0.5);
}

// Soft lumps, one at a random spot in each cell of a lattice cells to a board half, each a dome
// of its own height and width, drawn out along x by stretch. Their summed height, from 0 to about
// 1.5, then its slope in u's terms. Lumps that meet leave a crease between them.
float3 lumps(float2 u, float cells, float stretch, float seed)
{
    float2 scale = cells * float2(1.0 / stretch, 1.0);
    float2 p = u * scale;
    float2 base = floor(p);
    float3 h = float3(0.0, 0.0, 0.0);
    [unroll] for (int y = -1; y <= 1; y++)
    {
        [unroll] for (int x = -1; x <= 1; x++)
        {
            float2 id = base + float2(x, y);
            float2 k = bd_hash2(id + seed);
            float2 d = p - id - 0.1 - 0.8 * k;
            float wide = lerp(0.55, 1.1, frac(k.x * 7.3 + k.y));
            float high = lerp(0.6, 1.0, frac(k.y * 5.1));
            float f = saturate(1.0 - dot(d, d) / wide);
            h.x += high * f * f * f;
            h.yz -= high * 6.0 * f * f * d / wide;
        }
    }
    return float3(h.x, h.yz * scale);
}

// A surface of height slopes lit by the lamp, 1 where it lies flat. lift is how high a unit of
// height stands, in board halves.
float lamp_lit(float2 slope, float lift)
{
    float3 n = normalize(float3(-slope * lift, 1.0));
    return saturate(dot(n, normalize(ToLamp))) / normalize(ToLamp).z;
}

// Cold-pressed paper: a tooth of soft lumps parted by creases, drawn out a little along the felt's
// rows, raked by the lamp, a faint warm mottle and stains, and here and there a stray fibre.
float3 paper(float2 u, float px)
{
    float3 a = lumps(u, 34.0, 1.35, 3.0) * shows(34.0, px);
    float3 b = lumps(u, 95.0, 1.1, 9.0) * shows(95.0, px);
    float h = a.x * 0.7 + b.x * 0.3;
    float2 slope = a.yz * 0.7 + b.yz * 0.3;
    float3 c = float3(0.915, 0.89, 0.875);
    float mottle = bd_fbm(u * 2.4 + 7.0, 5);
    float stain = smoothstep(0.52, 0.78, bd_fbm(u * 1.3 + 31.0, 4));
    c *= 0.97 + 0.05 * mottle;
    c = lerp(c, c * float3(0.92, 0.91, 0.9), stain * 0.6);
    c *= lerp(1.0, lamp_lit(slope, 0.0026), 0.8);
    // the creases hold a little shade the lamp doesn't reach
    c *= 0.95 + 0.04 * saturate(h);
    // stray fibres, each a short thread in a cell of its own, most grey, a few blue
    float2 p = u * 22.0;
    float2 cell = floor(p);
    float2 k = bd_hash2(cell + 5.0);
    if (k.x > 0.93)
    {
        float2 mid = cell + 0.3 + 0.4 * k;
        float turn = k.y * 6.2831853;
        float2 along = float2(cos(turn), sin(turn)) * 0.22;
        float2 s = bd_segment(p, mid - along, mid + along);
        float thread = saturate(1.0 - s.x / max(px * 22.0 * 0.8, 0.015)) * shows(22.0 * 30.0, px);
        float3 tint = frac(k.x * 97.0) > 0.7 ? float3(0.62, 0.72, 0.86) : float3(0.7, 0.67, 0.64);
        c = lerp(c, c * tint, thread * 0.55);
    }
    return c;
}

float3 linen(float2 u, float px)
{
    float2 p = u * 260.0;
    float fine = saturate(1.6 - px * 260.0 * 1.2);
    float2 cell = floor(p);
    float2 f = p - cell;
    // over and under: in alternate cells the warp is on top, else the weft
    bool warp_up = fmod(cell.x + cell.y, 2.0) < 0.5;
    float along = warp_up ? f.x : f.y;
    float across = warp_up ? f.y : f.x;
    float thread = sin(across * 3.14159) * (0.75 + 0.25 * sin(along * 3.14159));
    float slub = bd_noise(float2(warp_up ? cell.y * 0.37 : cell.x * 0.37, (warp_up ? p.x : p.y) * 0.05));
    float3 c = float3(0.78, 0.74, 0.66) * (0.9 + 0.12 * slub);
    c *= lerp(1.0, 0.82 + 0.22 * thread, fine);
    c *= 0.96 + 0.06 * bd_fbm(u * 2.0, 3);
    return c;
}

// The pit of the lattice cell holding p, if it has one: how much of p it covers, and how far
// across it p lies toward the lamp, -1 to 1. A pit shows only where pick, from 0 to 1, falls under
// share, its radius from 0.1 to 0.34 of a cell.
float2 pit(float2 p, float share, float px_cells)
{
    float2 cell = floor(p);
    float2 h = bd_hash2(cell + 19.0);
    float pick = bd_hash(cell + 41.0);
    if (pick > share)
        return float2(0.0, 0.0);
    float r = lerp(0.1, 0.34, h.x * h.x);
    float2 mid = cell + r + (1.0 - 2.0 * r) * h;
    // pits are a little uneven, torn rather than round
    float2 v = (p - mid) * lerp(1.0, 1.5, frac(h.y * 7.1));
    float d = length(v) + 0.25 * r * (bd_noise(p * 3.0) - 0.5);
    float cover = saturate((r - d) / max(px_cells, 0.04) + 0.5);
    return float2(cover, dot(v / r, normalize(ToLamp.xy)));
}

// Cast concrete, cool and matte: soft clouds lighter and darker, a sandy grit raked by the lamp
// in tonal speckle, and pores pitting it, denser where it is darker. In a pore the wall toward the
// lamp falls into its own shade and the far wall catches the light, so the pits read as holes.
float3 concrete(float2 u, float px)
{
    float3 c = float3(0.64, 0.645, 0.65);
    float blot = bd_fbm(u * 1.2 + 3.0, 5);
    float cloud = bd_fbm(u * 3.6 + 11.0, 4);
    float dense = smoothstep(0.48, 0.72, bd_fbm(u * 1.9 + 17.0, 4));
    c *= 0.9 + 0.2 * blot;
    c *= 0.97 + 0.07 * cloud;
    c *= 1.0 - 0.07 * dense;
    // the crinkled skin and the grit in it, lit by their slopes, and the sand as tonal speckle
    float3 crinkle = lumps(u, 70.0, 1.0, 13.0) * shows(70.0, px);
    float3 grit = lumps(u, 170.0, 1.0, 29.0) * shows(170.0, px);
    c *= lerp(1.0, lamp_lit(crinkle.yz * 0.6 + grit.yz * 0.4, 0.0019), 0.9);
    float sand = (bd_noise(u * 300.0) - 0.5) * shows(300.0, px) + (bd_noise(bd_turn(u, 0.8) * 610.0) - 0.5) * shows(610.0, px);
    c *= 1.0 + 0.3 * sand + 0.08 * (grit.x - 0.6);
    // pores, and finer pinholes of sand
    float2 big = pit(u * 52.0, lerp(0.1, 0.4, dense), px * 52.0) * float2(shows(52.0 * 1.5, px), 1.0);
    float2 pin = pit(u * 120.0 + 0.5, lerp(0.2, 0.5, dense), px * 120.0) * float2(shows(120.0, px), 1.0);
    c *= 1.0 - big.x * lerp(0.6, 0.18, saturate(0.5 - 0.6 * big.y));
    c *= 1.0 - pin.x * 0.3;
    return c;
}

float4 flat_backdrop(UiPixel q)
{
    Stage s = stage_of(q);
    float2 u = s.u;
    float v = s.variant;
    float down = saturate((u.y - s.lo.y) / max(s.hi.y - s.lo.y, 1e-4));
    float3 c;
    bool lying = false;
    if (v < 0.5)
        c = hex3(s.t);
    else if (v < 1.5)
        c = lerp(hex3(s.t), q.color.rgb / max(q.color.a, 1e-4), smoothstep(0.0, 1.0, down));
    else if (v < 2.5)
        c = lerp(hex3(s.t), q.color.rgb / max(q.color.a, 1e-4), pool(u, 1.9));
    else if (v < 3.5)
    {
        c = lerp(float3(0.62, 0.66, 0.7), float3(0.4, 0.45, 0.5), down);
        c = lerp(c, float3(0.86, 0.88, 0.9), pool(u, 1.6) * 0.55);
    }
    else if (v < 4.5)
    {
        c = lerp(float3(0.05, 0.08, 0.16), float3(0.015, 0.02, 0.05), 1.0 - pool(u, 2.0));
        c += float3(0.05, 0.09, 0.2) * pool(u, 1.3) * 0.6;
    }
    else
    {
        if (v < 5.5)
            c = paper(u, s.px);
        else if (v < 6.5)
            c = linen(u, s.px);
        else
            c = concrete(u, s.px);
        lying = true;
    }
    if (lying)
    {
        // a lamp over the board, and the board's shadow close under it
        c *= 0.86 + 0.2 * pool(u - float2(-0.3, -0.4), 2.4);
        c *= 1.0 - 0.5 * bd_shadow(u, float2(0.012, 0.022), 0.025) - 0.2 * bd_shadow(u, float2(0.0, 0.0), 0.14);
    }
    else
    {
        c *= 1.0 - 0.38 * bd_shadow(u, float2(0.0, 0.05), 0.07) - 0.15 * bd_shadow(u, float2(0.0, 0.0), 0.02);
    }
    c += ui_dither(q.pixel) / 255.0;
    return bd_out(q, c);
}

UI_MATERIAL(flat_backdrop)

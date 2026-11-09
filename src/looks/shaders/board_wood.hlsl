// Wood: each square a piece of veneer, the grain running down the board as a marquetry board's
// strips do. Most pieces are quarter sawn, the cut crossing the growth rings so they run as fine
// straight lines, packed tighter here and looser there and drifting a little as the tree grew,
// with broad streaks of darker and paler wood along them. The rest are flat sawn, the cut passing
// near the log's heart so its rings arch as cathedrals. Each ring's late wood is a darker band
// with a sharp end, open woods carry pores along the grain as fine dark dashes, fibres streak it,
// a soft figure lies across it, and cherry holds small gum flecks. Each piece takes a tone of its
// own. A hairline joint parts the squares, their edges eased toward the light, and a satin lacquer
// holds a soft window over the whole board. Detail finer than a pixel fades to its average, so
// small boards stay calm.
// Values: the light wood and the dark wood as 0xRRGGBB, the style (1 maple and walnut, 2 boxwood
// and ebony, 3 cherry), unused.

#include "backdrop.hlsli"

struct Grain
{
    float lines;
    float rings;
    float flat;
    float contrast;
    float3 late;
    float streaks;
    float3 streak;
    float pores;
    float figure;
    float tone;
    float gum;
};

// lines: quarter sawn rings across a piece. rings: flat sawn ones. flat: the share of pieces flat
// sawn. late: a ring's late wood against the piece, mixed in by contrast. streak: a dark streak
// against the piece, mixed in by streaks, a pale one lifting the other way.
Grain grain_of(float style, bool light)
{
    Grain g;
    g.lines = 40.0;
    g.rings = 6.0;
    g.flat = 0.2;
    g.contrast = 0.4;
    g.late = float3(0.8, 0.72, 0.66);
    g.streaks = 0.1;
    g.streak = float3(0.88, 0.82, 0.78);
    g.pores = 0.0;
    g.figure = 0.0;
    g.tone = 0.06;
    g.gum = 0.0;
    if (style < 1.5)
    {
        if (light)
        {
            g.lines = 46.0; g.rings = 5.0; g.flat = 0.12; g.contrast = 0.42; g.late = float3(0.86, 0.79, 0.7);
            g.streaks = 0.35; g.streak = float3(0.9, 0.85, 0.78); g.figure = 0.008; g.tone = 0.05;
        }
        else
        {
            g.lines = 30.0; g.rings = 6.5; g.flat = 0.22; g.contrast = 0.62; g.late = float3(0.56, 0.48, 0.45);
            g.streaks = 0.75; g.streak = float3(0.64, 0.55, 0.52); g.pores = 0.4; g.tone = 0.1;
        }
    }
    else if (style < 2.5)
    {
        if (light)
        {
            g.lines = 64.0; g.rings = 8.0; g.flat = 0.0; g.contrast = 0.3; g.late = float3(0.88, 0.83, 0.72);
            g.streaks = 0.25; g.streak = float3(0.93, 0.9, 0.84); g.figure = 0.012; g.tone = 0.035;
        }
        else
        {
            // ebony's grain shows as faint brown lines and streaks in the black
            g.lines = 44.0; g.rings = 5.0; g.flat = 0.0; g.contrast = 0.5; g.late = float3(1.6, 1.38, 1.22);
            g.streaks = 0.7; g.streak = float3(1.8, 1.5, 1.28); g.pores = 0.15; g.tone = 0.08;
        }
    }
    else
    {
        if (light)
        {
            g.lines = 36.0; g.rings = 5.5; g.flat = 0.35; g.contrast = 0.45; g.late = float3(0.8, 0.7, 0.62);
            g.streaks = 0.4; g.streak = float3(0.88, 0.78, 0.7); g.pores = 0.08; g.figure = 0.02; g.tone = 0.1;
        }
        else
        {
            g.lines = 28.0; g.rings = 6.0; g.flat = 0.55; g.contrast = 0.5; g.late = float3(0.68, 0.58, 0.54);
            g.streaks = 0.6; g.streak = float3(0.7, 0.6, 0.57); g.pores = 0.12; g.figure = 0.03; g.tone = 0.13;
            g.gum = 0.7;
        }
    }
    return g;
}

float4 wood(UiPixel q)
{
    float2 uv = q.uv * 8.0;
    float2 cell = floor(uv);
    float2 f = uv - cell;
    bool light = fmod(cell.x + cell.y, 2.0) < 0.5;
    float style = q.values.z;
    float3 base = looks_rgb(light ? q.values.x : q.values.y);
    Grain gr = grain_of(style, light);
    float2 h = bd_hash2(cell + float2(31.0 * style, 7.0));
    float2 k = bd_hash2(cell + float2(77.0, 13.0 * style));
    float2 m = bd_hash2(cell + float2(5.0 * style, 59.0));
    float sq_px = looks_size(q).x / 8.0;
    float pxs = 1.0 / max(sq_px, 1.0);
    // along the grain in x, some pieces laid end for end
    float2 g = f.yx;
    if (k.x > 0.5)
        g.x = 1.0 - g.x;
    // the grain drifts across the piece as the tree grew, and slants with the cut
    float slant = (k.y - 0.5) * 0.1;
    float y = g.y + (bd_fbm(float2(g.x * 0.9 + h.x * 17.0, h.y * 13.0), 3) - 0.5) * 0.09 + (g.x - 0.5) * slant;
    float pos;
    if (m.x < gr.flat)
    {
        // the log's heart lies across the piece at y0 and under the cut at z0, the cut slanting along it
        float y0 = 0.5 + (h.x - 0.5) * 2.2;
        float z0 = 0.05 + h.y * 0.6;
        float warp = (bd_fbm(float2(g.x * 0.7 + h.x * 23.0, g.y * 1.2 + h.y * 19.0), 3) - 0.5) * 0.16;
        pos = length(float2(y - y0 + warp, z0 + g.x * (k.y - 0.5) * 0.4)) * gr.rings * (0.8 + 0.4 * m.y);
    }
    else
        pos = y * gr.lines * (0.85 + 0.3 * m.y) + bd_fbm(float2(y * 2.5 + h.x * 31.0, h.y * 7.0), 3) * 5.0;
    float ring = frac(pos);
    float id = floor(pos);
    float width = lerp(0.16, 0.5, bd_hash(float2(id + 3.0, h.x * 997.0)));
    float late = smoothstep(1.0 - width, 1.0 - width * 0.35, ring) * (1.0 - smoothstep(0.92, 1.0, ring));
    // rings packed tighter than a few pixels fade into their average
    float sharp = saturate(0.4 / max(fwidth(pos), 1e-4) - 0.3);
    late = lerp(0.22, late, sharp);
    float ring_tone = bd_hash(float2(id + 11.0, h.y * 613.0)) - 0.5;
    float3 c = base * (1.0 + gr.tone * (h.y - 0.5) * 2.0);
    // broad streaks along the grain, darker and paler runs of wood
    float s = bd_fbm(float2(y * 3.5 + h.y * 41.0, g.x * 0.3 + k.x * 7.0), 4);
    float s2 = bd_noise(float2(y * 13.0 + h.x * 13.0, g.x * 0.6 + k.y * 3.0));
    float streak = saturate((s - 0.32) * 2.8) * 0.7 + s2 * 0.3;
    float3 pale = c * (1.0 + (1.0 - gr.streak) * 0.45);
    c = lerp(c, lerp(pale, c * gr.streak, streak), gr.streaks);
    c *= 1.0 + 0.08 * ring_tone * sharp;
    c = lerp(c, c * gr.late, late * gr.contrast);
    // fibres and pores run with the grain
    float fine = saturate(1.4 - pxs * 60.0);
    float fibre = bd_noise(float2(g.x * 4.0 + h.y * 40.0, y * 95.0));
    c *= 1.0 + 0.07 * (fibre - 0.5) * fine;
    float pore = smoothstep(0.7, 0.86, bd_noise(float2(g.x * 26.0 + h.x * 50.0, y * 72.0)));
    c *= 1.0 - pore * gr.pores * 0.5 * fine;
    // gum flecks, short dark streaks in clusters
    float gum = smoothstep(0.8, 0.94, bd_noise(float2(g.x * 9.0 + h.x * 9.0, y * 34.0))) * smoothstep(0.55, 0.75, bd_noise(float2(g.x * 2.0 + k.y * 5.0, y * 3.0)));
    c = lerp(c, c * float3(0.5, 0.38, 0.34), gum * gr.gum * fine);
    // figure across the grain, as curl catching the light
    float figure = sin((g.x + bd_noise(g * float2(3.0, 2.0) + k.x * 9.0) * 0.35) * 34.0 + k.y * 6.0);
    c *= 1.0 + gr.figure * figure * saturate(1.5 - pxs * 34.0);
    // a joint between pieces, their edges eased, lit from the top left
    float2 e = float2(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * sq_px;
    c *= lerp(0.5, 1.0, smoothstep(0.0, 1.0, min(e.x, e.y)));
    float lit = saturate(1.0 - f.y * sq_px / 2.2) + saturate(1.0 - f.x * sq_px / 2.2);
    float shade = saturate(1.0 - (1.0 - f.y) * sq_px / 2.2) + saturate(1.0 - (1.0 - f.x) * sq_px / 2.2);
    c *= 1.0 + 0.06 * saturate(lit) - 0.08 * saturate(shade);
    // the lacquer: a broad soft window and the light falling off away from it
    float window = exp(-pow((q.uv.x * 0.85 + q.uv.y * 0.55 - 0.45) / 0.17, 2.0));
    float glint = exp(-pow((q.uv.x * 0.85 + q.uv.y * 0.55 - 0.72) / 0.05, 2.0));
    c *= 1.04 - 0.1 * length(q.uv - float2(0.28, 0.22));
    c += (window * 0.035 + glint * 0.015) * (0.5 + 0.5 * dot(c, float3(0.3, 0.5, 0.2)));
    return looks_out(q, c);
}

UI_MATERIAL(wood)

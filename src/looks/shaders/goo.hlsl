// The goo theme's materials. Panels and cards are a glossy slime whose edge wobbles, swells toward
// the pointer and ripples from a press, with drips swelling under them, snapping off and drawing
// back. The sheet the bars and side panes are is the same slime spread flat, stirring slowly, and
// the page laid back over it is rimmed by the sheet's edge spilling over, drips hanging off its top.
// Values: the seconds since the last press, or far below zero to hold still, then the pointer in the
// window's pixels. A panel's fourth is where the press was, packed as x * 4096 + y in steps of 2
// pixels, and the sheet's and the page's is the slime colour as 0xRRGGBB. A panel drips only when
// its box reaches past itself, and the page sees the sheet's colour as its border colour.

#include "touch.hlsli"

// The smooth minimum, which joins two shapes with a neck as liquid does.
float goo_smin(float a, float b, float k)
{
    float h = saturate(0.5 + 0.5 * (b - a) / k);
    return lerp(b, a, h) - k * h * (1.0 - h);
}

// A rounded rise over a depth into the goo, 0 at its edge and 1 from bevel in.
float goo_pillow(float depth, float bevel)
{
    float k = 1.0 - saturate(depth / bevel);
    return 1.0 - k * k;
}

// How far the edge stands out here, -0.5 to 0.5, from noise drifting slowly in screen place, so
// pieces side by side wobble as one.
float goo_wobble(float2 p, float t)
{
    float a = ui_value_noise(p * 0.045 + float2(t * 0.31, -t * 0.23));
    float b = ui_value_noise(p * 0.12 + float2(-t * 0.47, t * 0.37));
    return a * 0.65 + b * 0.35 - 0.5;
}

// A ring spreading from the last press and fading as it goes, -1 to 1.
float goo_ripple(float2 p, Touch g)
{
    if (g.age > 1.6 || g.age < 0.0)
        return 0.0;
    float r = length(p - g.press) - g.age * 240.0;
    return sin(r * 0.25) * exp(-r * r / 900.0) * exp(-g.age * 2.5);
}

// Drips hanging from the line at y between x0 and x1, kept margin off its ends, about one to every
// spacing at places hashed from seed. Each is a teardrop, wide where it leaves the edge, narrowing
// to a neck over a round bulb. It swells down toward most on a slow cycle of its own, then the bulb
// snaps off, falls a little as it shrinks away, and the neck draws back up.
float goo_drips(float2 p, float y, float x0, float x1, float margin, float most, float spacing, float t, float seed)
{
    float d = 1.0e5;
    float slot = floor((p.x - x0) / spacing);
    [unroll] for (int k = -1; k <= 1; k++)
    {
        float i = slot + (float)k;
        float h = looks_hash(float2(i, seed));
        if (h < 0.45)
            continue;
        float x = x0 + (i + 0.2 + 0.6 * looks_hash(float2(seed, i + 7.0))) * spacing;
        if (x < x0 + margin || x > x1 - margin)
            continue;
        float period = 6.0 + 7.0 * looks_hash(float2(i * 1.7, seed + 3.0));
        float phase = frac(t / period + h * 3.1);
        float grow = smoothstep(0.0, 0.7, phase);
        float snap = smoothstep(0.86, 1.0, phase);
        float len = most * (0.35 + 0.65 * looks_hash(float2(i, seed + 11.0))) * grow;
        float size = lerp(0.85, 1.2, h);
        float bulb = lerp(1.8, 3.8, grow) * size * (1.0 - snap);
        float2 tip = float2(x, y + len + snap * 6.0);
        float top = y - 2.0;
        float foot = y + len * (1.0 - snap);
        float along = saturate((p.y - top) / max(foot - top, 0.001));
        float width = lerp(lerp(5.0, 8.0, grow) * size, lerp(1.5, 0.6, snap), sqrt(along)) * (1.0 - 0.5 * snap);
        float neck = length(p - float2(x, clamp(p.y, top, foot))) - width;
        float drop = length(p - tip) - bulb;
        d = min(d, goo_smin(neck, drop, 2.5));
    }
    return d;
}

// The slime spread flat: its own colour stirring slowly, brighter threads of the slime where the
// stirring folds, and a little light where the pointer is near.
float3 goo_flat(float2 p, float3 base, float3 slime, Touch g)
{
    float a = ui_fbm(p * 0.005 + float2(g.t * 0.021, g.t * 0.014));
    float b = ui_fbm(p * 0.011 + a * 1.7 + float2(-g.t * 0.017, g.t * 0.02));
    float thread = 1.0 - smoothstep(0.0, 0.03, abs(b - 0.5));
    float3 c = base * (0.965 + 0.07 * b);
    c = lerp(c, slime, thread * 0.035);
    float2 to = p - g.pointer;
    return lerp(c, slime, exp(-dot(to, to) / 16000.0) * 0.05);
}

// Light on goo whose surface faces n: how much it is lit against flat, and its gloss.
float2 goo_light_n(float3 n)
{
    float3 l = normalize(float3(-0.42, -0.72, 0.55));
    float3 v = normalize(l + float3(0.0, 0.0, 1.0));
    float shade = 1.0 + 0.45 * (saturate(dot(n, l)) - l.z);
    float spec = pow(saturate(dot(n, v)), 40.0) * 0.9 + pow(saturate(dot(n, v)), 10.0) * 0.05;
    return float2(shade, spec);
}

// Light on goo whose height is given at the pixel and a step e right and down: how much the
// surface is lit against flat, and its gloss.
float2 goo_light(float h, float hx, float hy, float e)
{
    return goo_light_n(normalize(float3(-(hx - h) / e, -(hy - h) / e, 1.0)));
}

// The panel's edge as a distance, negative inside: its round box wobbling, swelling toward the
// pointer and rippling near its rim, with its drips joined on when it reaches past itself.
float goo_panel_field(float2 p, UiShape s, Touch g, float seed)
{
    float2 half = s.rect.zw * 0.5;
    float d = ui_round_box(p - s.rect.xy - half, half, s.radii);
    float edge = 1.0 - smoothstep(4.0, 16.0, abs(d));
    float2 to = p - g.pointer;
    if (edge > 0.0)
        d += (goo_wobble(p, g.t) * 2.2 - 4.0 * exp(-dot(to, to) / 1500.0) - goo_ripple(p, g) * 1.2) * edge;
    if (s.look.w > 0.5 && p.y > s.rect.y + s.rect.w - 8.0)
        d = goo_smin(d, goo_drips(p, s.rect.y + s.rect.w, s.rect.x, s.rect.x + s.rect.z, 14.0, s.look.w - 6.0, 72.0, g.t, seed), 3.0);
    return d;
}

// The panel's height: a pillow rising from its rim, with the press's ripple running over it.
float goo_panel_height(float2 p, UiShape s, Touch g, float seed, float bevel)
{
    float d = goo_panel_field(p, s, g, seed);
    return goo_pillow(-d, bevel) * bevel * 0.9 + goo_ripple(p, g) * 3.0;
}

float4 goo_panel(UiPixel q)
{
    Touch g = touch_of(q);
    UiShape s = q.s;
    float2 p = q.p;
    float seed = floor(s.rect.x * 0.37 + s.rect.z * 1.31 + s.rect.w * 0.73);
    float d = goo_panel_field(p, s, g, seed);
    float cover = ui_cover(d, q.px);
    if (cover <= 0.0)
        return float4(0.0, 0.0, 0.0, 0.0);
    float bevel = clamp(min(s.rect.z, s.rect.w) * 0.25, 4.0, 12.0);
    float e = max(q.px, 0.35);
    float h = goo_pillow(-d, bevel) * bevel * 0.9 + goo_ripple(p, g) * 3.0;
    float2 lit = goo_light(h, goo_panel_height(p + float2(e, 0.0), s, g, seed, bevel), goo_panel_height(p + float2(0.0, e), s, g, seed, bevel), e);
    float4 fill = ui_paint(s, p, q.pixel);
    float4 edge_ink = ui_premultiply(ui_unpack(s.stroke));
    float stir = ui_fbm(p * 0.01 + float2(g.t * 0.035, -g.t * 0.025));
    // thin goo at the rim lets more light through
    float rim = 1.0 - goo_pillow(-d, bevel);
    float3 body = fill.rgb * (0.95 + 0.1 * stir) * lit.x + fill.rgb * rim * 0.7;
    float inner = ui_cover(d + s.look.x, q.px);
    float4 c = lerp(float4(edge_ink.rgb * lit.x, edge_ink.a), float4(body, fill.a), inner);
    c.rgb += lit.y * c.a;
    return c * cover;
}

float4 goo_sheet(UiPixel q)
{
    Touch g = touch_of(q);
    float4 fill = ui_paint(q.s, q.p, q.pixel);
    float2 half = q.s.rect.zw * 0.5;
    float d = ui_round_box(q.p - q.s.rect.xy - half, half, q.s.radii);
    return float4(goo_flat(q.p, fill.rgb, looks_rgb(q.values.w), g), fill.a) * ui_cover(d, q.px);
}

// The sheet's goo over the page as a distance, negative where goo is: a band along the page's edges
// that face the sheet, wobbling and swelling toward the pointer, and drips off its top. depth is how
// far into the page the pixel lies.
float goo_page_field(float2 p, UiShape s, Touch g, out float depth)
{
    depth = page_depth(p, s);
    float2 to = p - g.pointer;
    float band = 2.5 + goo_wobble(p, g.t) * 3.0 + 5.0 * exp(-dot(to, to) / 1800.0);
    float corner = max(s.radii.x, s.radii.y) + 8.0;
    float drips = goo_drips(p, s.rect.y + 1.0, s.rect.x, s.rect.x + s.rect.z, corner, 30.0, 96.0, g.t, 5.0);
    return goo_smin(depth - band, drips, 4.0);
}

float4 goo_page(UiPixel q)
{
    Touch g = touch_of(q);
    UiShape s = q.s;
    float2 p = q.p;
    float4 fill = ui_paint(s, p, q.pixel);
    float depth;
    float gd = goo_page_field(p, s, g, depth);
    if (depth > 46.0)
        return fill;
    float e = max(q.px, 0.35);
    float unused;
    float gx = goo_page_field(p + float2(e, 0.0), s, g, unused);
    float gy = goo_page_field(p + float2(0.0, e), s, g, unused);
    float2 lit = goo_light(goo_pillow(-gd, 4.0) * 3.6, goo_pillow(-gx, 4.0) * 3.6, goo_pillow(-gy, 4.0) * 3.6, e);
    float3 sheet = ui_unpack(s.stroke).rgb;
    float3 slime = goo_flat(p, sheet, looks_rgb(q.values.w), g) * lit.x + lit.y;
    // the goo's soft shadow falls down and right onto the page
    float shadow = 1.0 - smoothstep(0.0, 5.0, goo_page_field(p - float2(0.8, 2.2), s, g, unused));
    float3 page = fill.rgb * (1.0 - 0.35 * shadow);
    float k = ui_cover(gd, q.px);
    float a = max(fill.a * ui_cover(-depth, q.px), k);
    return float4(lerp(page, slime, k), a);
}

float4 goo_panel_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, goo_panel(q));
}

float4 goo_sheet_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, goo_sheet(q));
}

float4 goo_page_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, goo_page(q));
}

static const float3 GooWhite = float3(1.0, 1.0, 1.0);

// How much of the piece covers point c of its square, read from its image.
float goo_cover_at(UiPixel q, float2 c)
{
    if (any(c < 0.0) || any(c > 1.0))
        return 0.0;
    return atlas.SampleLevel(atlas_linear, lerp(q.s.geo.xy, q.s.geo.zw, c), 0).a;
}

// How deep into the light squares' goo against the dark squares' a point p of the board lies, in
// squares, above 0 in the light. The checker's own wave, sin by sin, is 0 along every edge between
// squares. Near each corner a bias of its own swings slowly between the two goos, so one diagonal
// pair or the other joins there in a neck that swells, pinches off and hands the join across, and a
// slow warp lets every edge flow.
float goo_checker(float2 p, float t)
{
    float2 warp = float2(ui_value_noise(p * 0.9 + float2(t * 0.11, 3.7)), ui_value_noise(p * 0.9 + float2(5.2, -t * 0.09))) - 0.5;
    float2 u = p + warp * 0.08;
    float c = sin(u.x * 3.14159265) * sin(u.y * 3.14159265);
    float2 corner = round(u);
    float2 to = u - corner;
    float h = looks_hash(corner + 0.37);
    float bias = sin(t * (0.35 + 0.3 * h) + h * 6.2831853);
    // gone before the next corner takes over, so no seam shows where they meet
    float reach = exp(-dot(to, to) / 0.045) * smoothstep(0.5, 0.3, max(abs(to.x), abs(to.y)));
    return c + bias * 0.55 * reach;
}

// The goo board: the light squares and the dark ones are two goos poured together with nothing
// between them, each square a glossy swell whose edge flows slowly. At the corners the goos join
// one diagonal pair or the other and slowly trade the join, so the squares merge like blobs.
// Values: the light and dark squares and the slime as 0xRRGGBB, and the clock.
float4 goo_board(UiPixel q)
{
    float t = q.values.w;
    float3 slime = looks_rgb(q.values.z);
    float2 uv = q.uv * 8.0;
    float3 pale = lerp(looks_rgb(q.values.x), lerp(slime, GooWhite, 0.65), 0.5);
    float3 deep = lerp(looks_rgb(q.values.y), slime * 0.75, 0.55);
    float e = max(q.px / max(q.s.rect.z / 8.0, 0.001), 0.002);
    float c = goo_checker(uv, t);
    float2 grad = float2(goo_checker(uv + float2(e, 0.0), t) - c, goo_checker(uv + float2(0.0, e), t) - c) / e;
    // how far from where the goos meet, in squares, held near the corners where the wave is flat
    float g = max(length(grad), 1.2);
    float d = c / g;
    float2 way = grad / g * sign(c);
    // each goo swells from where they meet in a rounded valley, so the meeting reads as a soft
    // fold, never a gap
    float bevel = 0.22;
    float x = saturate(abs(d) / bevel);
    float k = 1.0 - x;
    float slope = 6.0 * x * k / bevel * 0.07;
    float2 lit = goo_light_n(normalize(float3(-way * slope, 1.0)));
    float stir = ui_fbm(uv * 1.3 + float2(t * 0.05, -t * 0.04));
    float light = saturate(0.5 + d / e);
    float3 base = lerp(deep, pale, light) * (0.95 + 0.1 * stir);
    // thin goo where the two meet and in the necks lets more light through
    float rim = k * k;
    float3 col = base * lit.x + base * rim * 0.25 + lit.y;
    col *= 1.0 - 0.1 * (1.0 - smoothstep(0.0, e * 1.6, abs(d)));
    return float4(col, 1.0) * ui_cover(q.d, q.px);
}

// A piece in goo's finish: wobbling as jelly does, coated in a glossy film of the slime, tinted at
// its rim, with a drip at its foot that swells, lets go and draws back. Values: the slime as
// 0xRRGGBB, and the clock.
float4 goo_piece(UiPixel q)
{
    float t = q.values.y;
    float3 slime = looks_rgb(q.values.x);
    float seed = looks_hash(floor(q.s.rect.xy / max(q.s.rect.zw, 1.0)));
    float2 c = q.uv;
    float2 warp = float2(ui_value_noise(c * 5.0 + float2(t * 0.6, seed * 9.0)) - 0.5, ui_value_noise(c * 5.0 + float2(seed * 7.0, t * 0.5)) - 0.5) * 0.025 * (1.2 - c.y);
    float2 cw = c + warp;
    float4 here = atlas.SampleLevel(atlas_linear, lerp(q.s.geo.xy, q.s.geo.zw, c), 0);
    float tint = here.a > 0.01 ? q.color.a / here.a : 1.0;
    float4 o = any(cw < 0.0) || any(cw > 1.0) ? float4(0.0, 0.0, 0.0, 0.0) : atlas.SampleLevel(atlas_linear, lerp(q.s.geo.xy, q.s.geo.zw, cw), 0);
    float a = o.a;
    // the film's gloss where the outline turns toward the light
    float r = 0.03;
    float gx = goo_cover_at(q, cw + float2(r, 0.0)) - goo_cover_at(q, cw - float2(r, 0.0));
    float gy = goo_cover_at(q, cw + float2(0.0, r)) - goo_cover_at(q, cw - float2(0.0, r));
    float3 n = normalize(float3(-gx, -gy, 0.7));
    float3 hv = normalize(normalize(float3(-0.42, -0.72, 0.55)) + float3(0.0, 0.0, 1.0));
    float spec = pow(saturate(dot(n, hv)), 28.0) * 0.75 + pow(saturate(dot(n, hv)), 6.0) * 0.06;
    float edge = saturate(abs(gx) + abs(gy));
    float3 col = o.rgb;
    col = lerp(col, col * 0.7 + slime * 0.3 * a, 0.4);
    col = lerp(col, slime * a, edge * 0.35);
    col += spec * a;
    // the drip at its foot, from the lowest point the piece covers near its middle
    float x0 = 0.5 + (seed - 0.5) * 0.3;
    float foot = 0.0;
    [unroll] for (int k = 0; k < 10; k++)
    {
        float y = 0.98 - (float)k * 0.04;
        if (foot == 0.0 && goo_cover_at(q, float2(x0, y)) > 0.5)
            foot = y;
    }
    if (foot > 0.0)
    {
        float phase = frac(t / (5.0 + 3.0 * seed) + seed);
        float grow = smoothstep(0.0, 0.7, phase);
        float snap = smoothstep(0.86, 1.0, phase);
        float len = 0.07 * grow;
        float bulb = lerp(0.012, 0.026, grow) * (1.0 - snap);
        float2 tip = float2(x0, foot + len + snap * 0.04);
        float neck = length(c - float2(x0, clamp(c.y, foot - 0.02, foot + len * (1.0 - snap)))) - lerp(0.016, 0.006, sqrt(saturate((c.y - foot) / max(len, 0.001)))) * (1.0 - 0.6 * snap);
        float drop = goo_smin(neck, length(c - tip) - bulb, 0.012);
        float held = 1.0 - smoothstep(-0.004, 0.004, drop);
        float3 drip = lerp(slime * 0.6, slime, 0.5) + 0.5 * exp(-dot(c - tip + float2(0.006, 0.008), c - tip + float2(0.006, 0.008)) / 0.00006);
        col = lerp(col, drip, held * (1.0 - a));
        a = max(a, held);
    }
    return float4(col, a) * tint * ui_cover(q.d, q.px);
}

float4 goo_board_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, goo_board(q));
}

float4 goo_piece_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, goo_piece(q));
}

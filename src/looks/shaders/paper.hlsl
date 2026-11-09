// The paper theme's materials, washi and sumi. Panels and cards are paper with long fibres, their
// edges torn and wetted: ragged, a line of ink pooled just inside, fibres and dry streaks reaching
// past, and a little ink bled beyond. The sheet the bars and side panes are is a pale wash brushed
// over the paper, and the page laid back over it meets the wash at the same torn edge, spattered
// along its top. Where the pointer is the paper is damp, and the edges creep and bleed toward it.
// Values: as touch.hlsli reads them, the sheet's and the page's fourth the accent as 0xRRGGBB. A
// panel's border shows as the pooled line, in the border's own colour when it is 1.5 wide or more,
// as a chosen panel's is. The page sees the sheet's colour as its border colour.

#include "touch.hlsli"

static const float3 Sumi = float3(0.105, 0.1, 0.095);

// Washi, about 1: long fibres lying every way over a soft cloud in the pulp. place is in the
// paper's own units, so a card's fibres keep to it as it scrolls.
float paper_grain(float2 place)
{
    float v = 0.0;
    [unroll] for (int i = 0; i < 3; i++)
    {
        float a = 0.7 + (float)i * 2.1;
        float2 r = float2(cos(a) * place.x + sin(a) * place.y, cos(a) * place.y - sin(a) * place.x);
        float n = ui_value_noise(r * float2(0.045, 0.9) + (float)i * 13.7);
        v += pow(1.0 - abs(n * 2.0 - 1.0), 12.0);
    }
    return 1.0 + 0.03 * v - 0.035 * (ui_fbm(place * 0.02) - 0.5);
}

// A torn, wetted edge where one sheet lies over another, out_by how far outside the upper sheet's
// straight edge p lies, below zero inside, and reach how much further the damp lets it creep. The
// tear wanders out a few units, fibres feather it, and past it the dry brush leaves broken streaks.
// Gives how much the upper sheet covers here, how much ink pooled just inside its edge, and how
// much bled past it.
float3 paper_tear(float2 p, float out_by, float reach, float damp, float px)
{
    float edge = out_by - (1.5 + 4.0 * (ui_fbm(p * 0.035) - 0.35) + reach);
    float feather = (ui_value_noise(p * 0.8) - 0.5) * 1.6;
    float dry = smoothstep(0.7, 0.82, ui_value_noise(float2(p.x * 0.08, p.y * 0.7))) * exp(-max(edge, 0.0) / 2.5);
    float cover = max(ui_cover(edge + feather * 0.5, px), dry * 0.6);
    float pooled = exp(-(edge + 0.6) * (edge + 0.6) / 0.25);
    float bleed = 0.07 * exp(-max(edge + feather, 0.0) / (1.8 + damp * 4.0));
    return float3(cover, pooled, bleed);
}

// A pale wash brushed over the paper, as how far it darkens toward sumi: broad strokes laid across,
// each its own tone, darker in a line where each dried at its edge, faint streaks of the brush
// along them, and damp and darker by the pointer.
float paper_wash(float2 p, float damp)
{
    float lane = p.y / 52.0 + (ui_value_noise(float2(p.x * 0.004, p.y * 0.01)) - 0.5) * 0.7;
    float f = frac(lane);
    float tone = 0.07 + 0.045 * looks_hash(float2(floor(lane), 1.7));
    tone += 0.035 * exp(-f * f / 0.003);
    tone += 0.03 * (ui_value_noise(float2(p.x * 0.012, p.y * 0.5)) - 0.5);
    tone += 0.03 * (ui_fbm(p * 0.006) - 0.5);
    return tone + 0.04 * damp;
}

// The spatter flung along the page's top edge as the wash was brushed on: dots, most small, fewer
// and smaller further down, none near the ends. How much ink it leaves here.
float paper_spatter(float2 p, float top, float x0, float x1)
{
    float y = p.y - top;
    if (y < 0.0 || y > 56.0 || p.x < x0 + 20.0 || p.x > x1 - 20.0)
        return 0.0;
    float2 cell = floor(p / 14.0);
    if (looks_hash(cell + 31.7) < 0.84)
        return 0.0;
    float2 c = (cell + 0.25 + 0.5 * float2(looks_hash(cell + 3.1), looks_hash(cell + 7.9))) * 14.0;
    float rad = (0.5 + 2.4 * pow(looks_hash(cell + 5.5), 3.0)) * (1.0 - saturate((c.y - top) / 56.0));
    float sd = length(p - c) - rad + (ui_value_noise(p * 1.4) - 0.5) * 0.5;
    return 1.0 - smoothstep(-0.5, 0.5, sd);
}

float4 paper_panel(UiPixel q)
{
    Touch g = touch_of(q);
    UiShape s = q.s;
    float2 p = q.p;
    // the card's own place, so its tear and fibres keep to it as it scrolls
    float2 place = p - s.rect.xy;
    float2 half = s.rect.zw * 0.5;
    float d = ui_round_box(place - half, half, s.radii);
    float4 fill = ui_paint(s, p, q.pixel);
    float2 to = p - g.pointer;
    float damp = exp(-dot(to, to) / 3000.0);
    float3 tear = paper_tear(place + s.rect.zw * 0.37, d, damp * 3.0, damp, q.px);
    float3 col = fill.rgb / max(fill.a, 0.001) * paper_grain(place) * (1.0 - 0.04 * damp);
    if (s.look.x >= 1.45)
        col = lerp(col, ui_unpack(s.stroke).rgb, saturate(tear.y * 0.8));
    else
        col = lerp(col, Sumi, tear.y * 0.18);
    float a = tear.x * fill.a;
    float4 c = float4(Sumi * tear.z, tear.z);
    return c * (1.0 - a) + float4(col * a, a);
}

float4 paper_sheet(UiPixel q)
{
    Touch g = touch_of(q);
    float4 fill = ui_paint(q.s, q.p, q.pixel);
    float2 to = q.p - g.pointer;
    float tone = paper_wash(q.p, exp(-dot(to, to) / 5000.0));
    float3 c = lerp(fill.rgb * paper_grain(q.p), Sumi, tone);
    float2 half = q.s.rect.zw * 0.5;
    float d = ui_round_box(q.p - q.s.rect.xy - half, half, q.s.radii);
    return float4(c, fill.a) * ui_cover(d, q.px);
}

float4 paper_page(UiPixel q)
{
    Touch g = touch_of(q);
    UiShape s = q.s;
    float2 p = q.p;
    float4 fill = ui_paint(s, p, q.pixel);
    float3 page = fill.rgb * paper_grain(p);
    float depth = page_depth(p, s);
    if (depth > 60.0)
        return float4(page, fill.a);
    float2 to = p - g.pointer;
    float damp = exp(-dot(to, to) / 5000.0);
    // the wash lies over the page, so the page's inside is the wash's outside
    float3 tear = paper_tear(p, depth, damp * 7.0, damp, q.px);
    float3 washed = lerp(ui_unpack(s.stroke).rgb * paper_grain(p), Sumi, paper_wash(p, damp) + 0.13 * tear.y);
    float spatter = paper_spatter(p, s.rect.y, s.rect.x, s.rect.x + s.rect.z);
    float3 c = lerp(lerp(page, Sumi, saturate(tear.z + spatter * 0.85)), washed, tear.x);
    float a = max(fill.a * ui_cover(-depth, q.px), tear.x);
    return float4(c * a, a);
}

// How much of the piece covers point c of its square, read from its image.
float paper_cover_at(UiPixel q, float2 c)
{
    if (any(c < 0.0) || any(c > 1.0))
        return 0.0;
    return atlas.SampleLevel(atlas_linear, lerp(q.s.geo.xy, q.s.geo.zw, c), 0).a;
}

// The paper board's squares: washi for the light ones, and for the dark ones a wash of ink brushed
// in, each square its own tone, its edge torn and wetted as a card's, the ink pooled along it and
// bled a little past. Everything is measured against a square 60 units across, so a small board
// looks as a big one does. Values: the light and dark squares as 0xRRGGBB.
float4 paper_board(UiPixel q)
{
    float2 uv = q.uv * 8.0;
    float2 cell = floor(uv);
    float2 f = uv - cell;
    bool light = fmod(cell.x + cell.y, 2.0) < 0.5;
    float2 p = uv * 60.0;
    float px = q.px * 60.0 / max(q.s.rect.z / 8.0, 0.001);
    // the dark square this pixel answers to: its own, or the one across its nearest edge
    float2 dark = cell;
    if (light)
    {
        float2 to = f - 0.5;
        dark += abs(to.x) > abs(to.y) ? float2(sign(to.x), 0.0) : float2(0.0, sign(to.y));
    }
    float2 half_sq = float2(30.0, 30.0);
    float out_by = ui_round_box(p - (dark + 0.5) * 60.0, half_sq, float4(0.0, 0.0, 0.0, 0.0));
    float3 tear = paper_tear(p, out_by, -1.0, 0.0, px);
    float3 paper = looks_rgb(q.values.x) * paper_grain(p);
    float tone = 0.12 + 0.12 * looks_hash(dark + 4.0) + 2.0 * (paper_wash(p.yx * float2(1.0, 0.7) + dark * 37.0, 0.0) - 0.07);
    float3 wash = lerp(looks_rgb(q.values.y) * paper_grain(p + 7.0), Sumi, saturate(tone));
    wash = lerp(wash, Sumi, tear.y * 0.3);
    float3 col = lerp(lerp(paper, Sumi, tear.z), wash, tear.x);
    return float4(col, 1.0) * ui_cover(q.d, q.px);
}

// A piece in paper's finish, painted in sumi: ink where its set draws dark, running dry in streaks,
// paper where it draws light, its outline pooled darker, and a little ink bled past it.
float4 paper_piece(UiPixel q)
{
    float2 c = q.uv;
    float4 o = q.color;
    float a = o.a;
    float blur = 0.0;
    [unroll] for (int k = 0; k < 8; k++)
    {
        float ang = (float)k * 0.7854;
        blur += paper_cover_at(q, c + float2(cos(ang), sin(ang)) * 0.03);
    }
    blur /= 8.0;
    float seed = looks_hash(floor(q.s.rect.xy / max(q.s.rect.zw, 1.0)));
    float luma = a > 0.001 ? dot(o.rgb / a, float3(0.299, 0.587, 0.114)) : 1.0;
    float ink = 1.0 - smoothstep(0.25, 0.75, luma);
    float streak = ui_value_noise(float2((c.x + c.y) * 5.0, (c.x - c.y) * 55.0) + seed * 13.0);
    ink *= 1.0 - 0.55 * smoothstep(0.62, 0.8, streak) * ink;
    ink *= 0.86 + 0.14 * ui_fbm(c * 9.0 + seed);
    float3 col = lerp(float3(0.955, 0.93, 0.87) * paper_grain(c * 120.0), Sumi, ink);
    col = lerp(col, Sumi, saturate((a - blur) * 2.5) * 0.7);
    float bleed = blur * (1.0 - a) * 0.15;
    return (float4(col * a, a) + float4(Sumi * bleed, bleed) * (1.0 - a)) * ui_cover(q.d, q.px);
}

// How light the piece's image is at point c of its square, or fallback where nothing covers it.
float fold_light_at(UiPixel q, float2 c, float fallback)
{
    float4 t = atlas.SampleLevel(atlas_linear, lerp(q.s.geo.xy, q.s.geo.zw, saturate(c)), 0);
    return t.a > 0.05 ? dot(t.rgb / t.a, float3(0.299, 0.587, 0.114)) : fallback;
}

// A piece folded from washi, as the origami set draws one: each facet keeps the tone its set gives
// it, the paper's fibres and the cloud in its pulp lie over every facet alike, and where two facets
// meet the fold is creased, its paler side catching a hairline of light and its deeper side a
// little shade. The fibres keep to the piece's own square, so a carried piece takes them along.
float4 fold_piece(UiPixel q)
{
    float2 c = q.uv;
    float4 o = q.color;
    float a = o.a;
    float3 col = a > 0.001 ? o.rgb / a : float3(0.0, 0.0, 0.0);
    float light = dot(col, float3(0.299, 0.587, 0.114));
    float step = 0.7 / max(q.s.rect.z, 1.0);
    float x0 = fold_light_at(q, c - float2(step, 0.0), light);
    float x1 = fold_light_at(q, c + float2(step, 0.0), light);
    float y0 = fold_light_at(q, c - float2(0.0, step), light);
    float y1 = fold_light_at(q, c + float2(0.0, step), light);
    float crease = smoothstep(0.03, 0.1, length(float2(x1 - x0, y1 - y0)));
    float side = light - (x0 + x1 + y0 + y1) * 0.25;
    col *= 1.0 + crease * clamp(side * 6.0, -0.12, 0.1);
    col *= 1.0 + (paper_grain(c * 150.0) - 1.0) * 1.6;
    col *= 0.98 + 0.04 * ui_fbm(c * 6.0);
    return float4(col * a, a) * ui_cover(q.d, q.px);
}

float4 fold_piece_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, fold_piece(q));
}

float4 paper_board_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, paper_board(q));
}

float4 paper_piece_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, paper_piece(q));
}

float4 paper_panel_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, paper_panel(q));
}

float4 paper_sheet_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, paper_sheet(q));
}

float4 paper_page_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, paper_page(q));
}

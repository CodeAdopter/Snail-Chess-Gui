// The neon circuit theme's materials. Panels and cards are dark boards with two corners cut across,
// edged by a neon tube whose glow spills round them, pulses of light racing round the tube, and
// circuit traces etched in from the edges with data flowing through them. Small cards, as the many
// in a shelf, keep only the tube, so a page of them stays quiet. Near the pointer the
// traces power up, and a press sends a surge out through every board. The sheet the bars and side panes are is
// the same board with its traces faint, and the page laid back over it is edged by a tube with
// pulses running along it.
// Values: as touch.hlsli reads them, the sheet's and the page's fourth the accent as 0xRRGGBB. A
// panel's solid fill carries the accent as its second colour, its tube burns brighter when its
// border is 1.5 wide or more, as a chosen panel's is, and it glows past its box only when it
// reaches past it. The page reaches past itself so its tube glows both ways. Light outside a shape
// is added to what lies behind, with no cover of its own.

#include "touch.hlsli"

static const float3 White = float3(1.0, 1.0, 1.0);

// The traces' grid, in units.
static const float NeonGrid = 14.0;

// A box of half size b about the origin with its top left and bottom right corners cut across by
// cut and the other two by a little, as a distance.
float neon_box(float2 p, float2 b, float cut)
{
    float2 q = abs(p) - b;
    float box = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
    float c = p.x * p.y > 0.0 ? cut : 3.0;
    return max(box, (abs(p.x) + abs(p.y) - (b.x + b.y - c)) * 0.70711);
}

// Whether the edge between two cells carries a trace, the edge named by its place on a doubled grid.
bool neon_link(float2 edge, float seed)
{
    return looks_hash(edge + seed * 7.0) > 0.52;
}

// Circuit traces on a grid in the board's own place. Each cell joins its middle to the edges whose
// link is on, so traces run on from cell to cell and turn square, with a ringed pad where one ends.
// The distance to the nearest trace or pad, in units.
float neon_traces(float2 p, float seed)
{
    float2 cell = floor(p / NeonGrid);
    float2 f = p / NeonGrid - cell - 0.5;
    float2 e = cell * 2.0;
    bool right = neon_link(e + float2(2.0, 1.0), seed);
    bool left = neon_link(e + float2(0.0, 1.0), seed);
    bool down = neon_link(e + float2(1.0, 2.0), seed);
    bool up = neon_link(e + float2(1.0, 0.0), seed);
    float d = 1.0e3;
    if (right)
        d = min(d, f.x >= 0.0 ? abs(f.y) : length(f));
    if (left)
        d = min(d, f.x <= 0.0 ? abs(f.y) : length(f));
    if (down)
        d = min(d, f.y >= 0.0 ? abs(f.x) : length(f));
    if (up)
        d = min(d, f.y <= 0.0 ? abs(f.x) : length(f));
    if ((float)right + (float)left + (float)down + (float)up == 1.0)
        d = min(d, abs(length(f) - 0.16));
    return d * NeonGrid;
}

// Bright bands of data sweeping across the traces, 0 to 1.
float neon_flow(float2 p, float t, float seed)
{
    return pow(frac((p.x + p.y) / 70.0 - t * 0.55 + seed), 10.0);
}

// Pulses racing along a line from where along lies on it, count of them each with a bright head and
// a tail of length tail, wrapping every loop units.
float neon_pulses(float along, float loop, float t, float seed, int count, float tail)
{
    float v = 0.0;
    for (int k = 0; k < count; k++)
    {
        float speed = 150.0 + 70.0 * looks_hash(float2(seed, (float)k));
        float head = frac(t * speed / loop + looks_hash(float2((float)k, seed + 3.0))) * loop;
        float behind = head - along;
        behind -= loop * floor(behind / loop);
        v += exp(-behind / tail) * smoothstep(0.0, 5.0, behind);
    }
    return v;
}

// The tube at distance tube from its line, burning at power: its white hot core and a soft glow,
// fading out by reach, as far as the shape draws. A pulse is a line of energy along the core alone,
// with a tight halo, so it never floods the glow.
float3 neon_tube(float tube, float power, float pulse, float3 neon, float reach)
{
    float core = (1.0 - smoothstep(0.35, 1.1, tube)) * (power + pulse);
    float halo = exp(-tube / 1.2) * pulse * 0.35;
    float glow = (exp(-tube / 3.0) * 0.32 + exp(-tube / 11.0) * 0.07) * power * (1.0 - smoothstep(reach * 0.4, reach, tube));
    return neon * (glow + halo) + lerp(neon, White, 0.65) * core;
}

float4 neon_panel(UiPixel q)
{
    Touch g = touch_of(q);
    UiShape s = q.s;
    float2 p = q.p;
    float2 place = p - s.rect.xy;
    float2 half = s.rect.zw * 0.5;
    float seed = floor(s.rect.z * 1.31 + s.rect.w * 0.73);
    float d = neon_box(place - half, half, clamp(min(half.x, half.y) * 0.5, 4.0, 14.0));
    float4 fill = ui_paint(s, p, q.pixel);
    float3 neon = ui_unpack(s.fill2).rgb;
    float2 to = p - g.pointer;
    float near = exp(-dot(to, to) / 6400.0);
    // the surge a press sends out, a ring running through every board
    float surge = 0.0;
    if (g.age >= 0.0 && g.age < 1.4)
    {
        float r = length(p - g.press) - g.age * 520.0;
        surge = exp(-r * r / 400.0) * exp(-g.age * 2.0);
    }
    // how much of the board's life a card this size shows: all of it on big ones, none on small
    float busy = smoothstep(30000.0, 70000.0, s.rect.z * s.rect.w) * smoothstep(80.0, 120.0, min(s.rect.z, s.rect.w));
    float pulse = busy > 0.0 ? neon_pulses(looks_around(p, s.rect), 2.0 * (s.rect.z + s.rect.w), g.t, seed, 2, 34.0) * busy : 0.0;
    float power = (s.look.x >= 1.45 ? 1.0 : 0.5) + 0.5 * near + surge;
    float3 tube = neon_tube(abs(d + 1.5), power, 1.2 * pulse, neon, max(s.look.w, 2.0) + 1.5);
    float inside = ui_cover(d, q.px);
    if (inside <= 0.0)
        return float4(tube, 0.0);
    // the board: a faint grid of dots, and traces etched in from its edges, lit by the data flowing
    // through them, the pointer and a surge
    float2 dot_at = frac(place / 8.0) - 0.5;
    float dots = 1.0 - smoothstep(0.06, 0.12, length(dot_at));
    float trace = 1.0 - smoothstep(0.45, 1.15, neon_traces(place, seed));
    float rim = 1.0 - smoothstep(16.0, 52.0, -d);
    float lit = trace * rim * busy * (0.12 + 0.25 * neon_flow(place, g.t, looks_hash(float2(seed, 9.0))) + 1.4 * near + 2.5 * surge);
    float3 col = fill.rgb / max(fill.a, 0.001) + neon * (dots * 0.035 + lit * 0.5);
    float a = fill.a * inside;
    return float4((col + tube) * a + tube * (1.0 - inside), a);
}

float4 neon_sheet(UiPixel q)
{
    Touch g = touch_of(q);
    float4 fill = ui_paint(q.s, q.p, q.pixel);
    float3 neon = looks_rgb(q.values.w);
    float2 p = q.p;
    float trace = 1.0 - smoothstep(0.45, 1.15, neon_traces(p, 3.0));
    float2 to = p - g.pointer;
    float near = exp(-dot(to, to) / 9000.0);
    float2 dot_at = frac(p / 8.0) - 0.5;
    float dots = 1.0 - smoothstep(0.06, 0.12, length(dot_at));
    float3 c = fill.rgb + neon * (trace * (0.05 + 0.18 * neon_flow(p, g.t, 0.3) + 0.3 * near) + dots * 0.025);
    float2 half = q.s.rect.zw * 0.5;
    float d = ui_round_box(p - q.s.rect.xy - half, half, q.s.radii);
    return float4(c, fill.a) * ui_cover(d, q.px);
}

float4 neon_page(UiPixel q)
{
    Touch g = touch_of(q);
    UiShape s = q.s;
    float2 p = q.p;
    float4 fill = ui_paint(s, p, q.pixel);
    float depth = page_depth(p, s);
    float inside = ui_cover(-depth, q.px);
    if (depth > 40.0)
        return fill * inside;
    float3 neon = looks_rgb(q.values.w);
    // how far along the edge, which turns down the side the page's round corner is on
    float along = s.radii.y > s.radii.x ? p.x + p.y : (s.radii.x > s.radii.y ? p.x - p.y : p.x);
    float pulse = neon_pulses(along, 2400.0, g.t, 7.0, 3, 60.0);
    float2 to = p - g.pointer;
    float power = 0.55 + 0.6 * exp(-dot(to, to) / 6400.0);
    float3 tube = neon_tube(abs(depth - 1.0), power, 1.4 * pulse, neon, depth < 0.0 ? max(s.look.w, 2.0) + 1.0 : 40.0);
    return float4(fill.rgb * inside + tube, fill.a * inside);
}

float4 neon_panel_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, neon_panel(q));
}

float4 neon_sheet_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, neon_sheet(q));
}

float4 neon_page_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, neon_page(q));
}

// How much of the piece covers point c of its square, read from its image.
float neon_cover_at(UiPixel q, float2 c)
{
    if (any(c < 0.0) || any(c > 1.0))
        return 0.0;
    return atlas.SampleLevel(atlas_linear, lerp(q.s.geo.xy, q.s.geo.zw, c), 0).a;
}

// The hue a signal runs in from a hash of it: most often the theme's own neon, else cyan, magenta,
// amber or lime.
float3 circuit_hue(float h, float3 neon)
{
    if (h < 0.36) return neon;
    if (h < 0.52) return float3(0.2, 0.88, 1.0);
    if (h < 0.68) return float3(1.0, 0.26, 0.78);
    if (h < 0.84) return float3(1.0, 0.68, 0.22);
    return float3(0.5, 1.0, 0.38);
}

// The nearest trace to p, as neon_traces lays them out: its distance in units, how far along its
// lane it lies in cells, its lane, each row of cells one and each column another from 4096 on, how
// far p is from its cell's middle in units, and 1 where the trace ends there in a pad.
struct CircuitTrace
{
    float d;
    float along;
    float lane;
    float mid;
    float ends;
};

CircuitTrace circuit_trace(float2 p, float seed)
{
    float2 cell = floor(p / NeonGrid);
    float2 f = p / NeonGrid - cell - 0.5;
    float2 e = cell * 2.0;
    bool right = neon_link(e + float2(2.0, 1.0), seed);
    bool left = neon_link(e + float2(0.0, 1.0), seed);
    bool down = neon_link(e + float2(1.0, 2.0), seed);
    bool up = neon_link(e + float2(1.0, 0.0), seed);
    CircuitTrace o;
    o.d = 1.0e3;
    o.along = 0.0;
    o.lane = 0.0;
    if (right || left)
    {
        float lo = left ? -0.5 : 0.0;
        float hi = right ? 0.5 : 0.0;
        o.d = length(float2(max(max(lo - f.x, f.x - hi), 0.0), f.y));
        o.along = p.x / NeonGrid;
        o.lane = cell.y;
    }
    if (down || up)
    {
        float lo = up ? -0.5 : 0.0;
        float hi = down ? 0.5 : 0.0;
        float d = length(float2(f.x, max(max(lo - f.y, f.y - hi), 0.0)));
        if (d < o.d)
        {
            o.d = d;
            o.along = p.y / NeonGrid;
            o.lane = 4096.0 + cell.x;
        }
    }
    o.d *= NeonGrid;
    o.mid = length(f) * NeonGrid;
    o.ends = (float)right + (float)left + (float)down + (float)up == 1.0 ? 1.0 : 0.0;
    return o;
}

// Packets of data running along a lane, at along on it in cells: each lane sends them one way at
// a speed and spacing of its own, a bright head with a short tail behind it.
float circuit_packet(float along, float lane, float t)
{
    float h = looks_hash(float2(lane, 17.0));
    float dir = h > 0.5 ? 1.0 : -1.0;
    float speed = 1.4 + 1.8 * looks_hash(float2(lane, 5.0));
    float spacing = 6.0 + 10.0 * looks_hash(float2(lane, 9.0));
    float behind = frac((t * speed - along * dir) / spacing + h * 7.0) * spacing;
    return exp(-behind / 0.7) * smoothstep(0.0, 0.06, behind);
}

// A chip on a square, f the place in it: a black body, silver pins down its long sides, a silkscreen
// outline round it, a dot by pin one and an LED by its corner blinking in a hue of its own.
// Gives the colour over the square and how much of it covers.
float4 circuit_chip(float2 f, float2 cell, float t, float px, float3 neon)
{
    bool wide = looks_hash(cell + 4.1) > 0.5;
    float2 half = wide ? float2(0.21, 0.13) : float2(0.13, 0.21);
    float2 p = f - 0.5;
    float body = ui_round_box(p, half, float4(0.012, 0.012, 0.012, 0.012));
    // pins every 0.06 along the long sides, standing out past the body
    float2 along = wide ? p : p.yx;
    float2 side = wide ? half : half.yx;
    float slot = clamp(floor(along.x / 0.06), -3.0, 2.0) + 0.5;
    float2 pin_at = float2(along.x - slot * 0.06, abs(along.y) - side.y - 0.012);
    float pin = ui_round_box(pin_at, float2(0.013, 0.022), float4(0.004, 0.004, 0.004, 0.004));
    float outline = abs(ui_round_box(p, half + 0.05, float4(0.02, 0.02, 0.02, 0.02))) - 0.0035;
    float3 col = float3(0.0, 0.0, 0.0);
    float a = 0.0;
    float k = 1.0 - smoothstep(-px, px, outline);
    col = lerp(col, float3(0.86, 0.9, 0.88), k * 0.55);
    a = max(a, k * 0.55);
    k = 1.0 - smoothstep(-px, px, pin);
    float shine = 0.75 + 0.25 * saturate(1.0 - abs(pin_at.x) / 0.013);
    col = lerp(col, float3(0.78, 0.8, 0.84) * shine, k);
    a = max(a, k);
    k = 1.0 - smoothstep(-px, px, body);
    float top = 0.05 + 0.04 * saturate(-p.y / half.y);
    float dent = 1.0 - smoothstep(0.0, px * 1.2, length(p + half - 0.04) - 0.018);
    col = lerp(col, float3(top, top, top * 1.15) + 0.06 * dent, k);
    a = max(a, k);
    // the LED off the chip's corner, blinking as the chip works
    float h = looks_hash(cell + 9.3);
    float2 led = p - (half + 0.085) * float2(1.0, -1.0);
    float on = step(0.45, frac(t * (0.6 + 1.6 * h) + h)) * (0.7 + 0.3 * step(0.5, frac(t * 7.3 + h * 5.0)));
    float3 hue = circuit_hue(looks_hash(cell + 2.7), neon);
    float r = length(led);
    k = 1.0 - smoothstep(0.018 - px, 0.018 + px, r);
    col = lerp(col, lerp(hue * 0.25, lerp(hue, White, 0.55), on), k);
    a = max(a, k);
    col += hue * on * exp(-r * r / 0.0025) * 0.9 * (1.0 - k);
    a = max(a, on * exp(-r * r / 0.0025) * 0.9);
    return float4(col, a);
}

// The circuit board: a printed circuit whose copper traces run on under every square, bare on the
// dark ones, set in a green solder mask, and dim under the smoked glass of the light ones. Packets
// of data in many hues run along the traces and light the pads where they end, chips sit on some
// dark squares with an LED blinking by each, thin neon lines part the squares, a pulse runs down a
// file or along a rank now and then, and a tube runs round the edge.
// Values: the light and dark squares and the neon as 0xRRGGBB, and the clock.
float4 neon_board(UiPixel q)
{
    float t = q.values.w;
    float3 neon = looks_rgb(q.values.z);
    float2 uv = q.uv * 8.0;
    float2 cell = floor(uv);
    float2 f = uv - cell;
    float sq = q.s.rect.z / 8.0;
    float px = q.px / max(sq, 0.001);
    // four trace cells to a square, whatever its size, so a pixel is this many units
    float2 at = uv * 4.0 * NeonGrid;
    float pxu = px * 4.0 * NeonGrid;
    CircuitTrace tr = circuit_trace(at, 5.0);
    float packet = circuit_packet(tr.along, tr.lane, t);
    float3 hue = circuit_hue(looks_hash(float2(tr.lane, 23.0)), neon);
    float copper = 1.0 - smoothstep(1.5 - pxu * 0.5, 1.5 + pxu * 0.5, tr.d);
    float core = 1.0 - smoothstep(0.6 - pxu * 0.5, 0.6 + pxu * 0.5, tr.d);
    float ring = tr.ends * (1.0 - smoothstep(-pxu * 0.5, pxu * 0.5, abs(tr.mid - 2.5) - 0.9));
    float hole = tr.ends * (1.0 - smoothstep(1.3 - pxu * 0.5, 1.3 + pxu * 0.5, tr.mid));
    // a pad lights up as a packet comes in
    float pad_glow = tr.ends * packet * exp(-tr.mid / 3.0);
    float3 col;
    if (fmod(cell.x + cell.y, 2.0) < 0.5)
    {
        // smoked glass with the circuit dim beneath it
        float sheen = 1.0 - saturate(abs(f.x + f.y - 0.7) * 1.4);
        // the glass tinted from cyan toward lilac across the board
        float3 tint = lerp(float3(0.93, 1.0, 1.05), float3(1.04, 0.95, 1.05), saturate((uv.x + uv.y) / 16.0));
        col = looks_rgb(q.values.x) * (0.93 + 0.07 * sheen) * tint;
        float under = 1.0 - smoothstep(1.0, 2.5 + pxu, tr.d);
        col = lerp(col, col * float3(0.8, 0.86, 0.84), under * 0.35);
        col += hue * (packet * exp(-tr.d / 1.6) * 0.3 + pad_glow * 0.3);
    }
    else
    {
        float3 dark = looks_rgb(q.values.y);
        float3 mask = lerp(dark, float3(0.03, 0.13, 0.1), 0.5);
        // the solder mask's fine weave
        float weave = (sin(at.x * 0.9) * sin(at.y * 0.9)) * saturate(1.0 - pxu * 0.6);
        col = mask * (1.0 + 0.05 * weave);
        float3 metal = float3(0.72, 0.46, 0.22);
        col = lerp(col, lerp(mask, metal, 0.45), copper);
        col = lerp(col, float3(0.9, 0.7, 0.34), ring);
        col = lerp(col, mask * 0.4, hole);
        col += hue * (packet * (core * 1.1 + exp(-tr.d / 1.6) * 0.35) + pad_glow * 0.8);
        if (looks_hash(cell + 31.7) > 0.58)
        {
            float4 chip = circuit_chip(f, cell, t, px, neon);
            col = lerp(col, chip.rgb / max(chip.a, 0.001), chip.a);
        }
    }
    float2 edge = min(f, 1.0 - f);
    float grid = 1.0 - smoothstep(0.0, px * 1.3, min(edge.x, edge.y));
    col += neon * grid * 0.3;
    // a pulse along one line between the squares, a new one every few seconds
    float n = floor(t / 2.6);
    float which = floor(looks_hash(float2(n, 3.0)) * 7.0) + 1.0;
    bool down = looks_hash(float2(n, 7.0)) > 0.5;
    float off = down ? abs(uv.x - which) : abs(uv.y - which);
    float behind = frac(t / 2.6) * 10.0 - 1.0 - (down ? uv.y : uv.x);
    float pulse = behind > 0.0 ? exp(-behind / 1.4) * smoothstep(0.0, 0.08, behind) : 0.0;
    col += lerp(circuit_hue(looks_hash(float2(n, 11.0)), neon), White, 0.6) * pulse * (1.0 - smoothstep(0.0, px * 1.6, off));
    // the frame's tube
    float rim = min(min(q.uv.x, 1.0 - q.uv.x), min(q.uv.y, 1.0 - q.uv.y)) * q.s.rect.z;
    col += lerp(neon, White, 0.5) * (1.0 - smoothstep(0.4, 1.4, abs(rim - 1.0))) * 0.7;
    return float4(col, 1.0) * ui_cover(q.d, q.px);
}

// A piece in the circuit's finish: smoked glass, dark or pale as its set draws it so the sides still
// read, a neon rim round its outline with a tight halo, and a band of light sweeping up it now and
// then. Values: the neon as 0xRRGGBB, and the clock.
float4 neon_piece(UiPixel q)
{
    float2 c = q.uv;
    float4 o = q.color;
    float a = o.a;
    float3 neon = looks_rgb(q.values.x);
    float blur = 0.0;
    [unroll] for (int k = 0; k < 8; k++)
    {
        float ang = (float)k * 0.7854;
        blur += neon_cover_at(q, c + float2(cos(ang), sin(ang)) * 0.035);
    }
    blur /= 8.0;
    float luma = a > 0.001 ? dot(o.rgb / a, float3(0.299, 0.587, 0.114)) : 0.0;
    float3 body = lerp(float3(0.05, 0.07, 0.1), float3(0.78, 0.86, 0.95), smoothstep(0.15, 0.85, luma));
    body = lerp(body, neon, 0.12);
    float rim = saturate((a - blur) * 3.0);
    float seed = looks_hash(floor(q.s.rect.xy / max(q.s.rect.zw, 1.0)));
    float band_d = (1.0 - c.y) - (frac(q.values.y * 0.25 + seed) * 2.4 - 0.7);
    float band = exp(-band_d * band_d / 0.004);
    float3 col = body * a + lerp(neon, White, 0.6) * rim * a * (0.8 + 1.5 * band) + neon * band * a * 0.12;
    col += neon * blur * (1.0 - a) * 0.5;
    return float4(col, a) * ui_cover(q.d, q.px);
}

float4 neon_board_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, neon_board(q));
}

float4 neon_piece_ps(ShapeOut i) : SV_Target0
{
    UiPixel q = ui_shape(i);
    return ui_finish(q, neon_piece(q));
}

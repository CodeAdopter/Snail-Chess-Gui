// The cozy room round the 3D board: oak boards, green walls over walnut panelling, brick round the
// fire, a Persian rug, shelves of books, a leather chair, brass, a lamp's linen shade, a night
// window, velvet curtains, a painting, candles, and the fire itself, its logs, its coals and its
// flames. Everything is worked out in metres from the board's middle at 16.4 squares a metre and
// lit by the lamps. Each returns how far ahead of the eye it is as its alpha, for the lens.

#include "wood3d.hlsl"

#define ROOM_METRE 16.4

float3 room_linear(float3 c)
{
    return three_srgb_to_linear(c);
}

// A surface of colour c facing n, rough and as metallic as metal, its open light shaded by ao, lit
// by the lamps but the one numbered skip, the sky and ground light and the lamp room it mirrors,
// cloth brighter at its rim by sheen. The fire's own logs and coals skip the fire's lamp, which
// burns among them.
float4 room_lit_but(WoodOut i, float3 n, float3 c, float rough, float metal, float ao, float sheen, int skip)
{
    float3 v = normalize(three_eye() - i.world);
    float nv = saturate(dot(n, v));
    float3 f0 = lerp(float3(0.04, 0.04, 0.04), c, metal);
    float3 diffuse = c * (1.0 - metal) * (1.0 + pow(1.0 - nv, 3.0) * sheen);
    float3 lit = three_hemisphere(n) * THREE_RECIPROCAL_PI * diffuse * ao;
    for (int k = 0; k < lamp_count(); k++)
    {
        if (k == skip) continue;
        float3 l;
        float3 e = lamp_light(k, i.world, i.shadow0, i.shadow1, i.shadow2, l) * saturate(dot(n, l));
        lit += e * diffuse + e * THREE_PI * three_specular_ggx(l, v, n, f0, max(rough, 0.04));
    }
    float2 ab = wood_env_brdf(rough, nv);
    lit += wood_room(reflect(-v, n), rough) * (f0 * ab.x + ab.y) * ao;
    return float4(lit, i.depth);
}

float4 room_lit(WoodOut i, float3 n, float3 c, float rough, float metal, float ao, float sheen)
{
    return room_lit_but(i, n, c, rough, metal, ao, sheen, -1);
}

// A band from a to b along x with edges a pixel soft
float room_band(float x, float a, float b)
{
    float w = max(fwidth(x), 1e-5);
    return smoothstep(a - w, a + w, x) * (1.0 - smoothstep(b - w, b + w, x));
}

// How open a point p of the room is, darker where walls, floor and ceiling meet, leaving out the
// plane the point lies on. Box is the walls west, east, north and south, rest the floor and
// ceiling, all in metres.
float room_corner(float3 p, float3 n, float4 box, float2 rest)
{
    float wx = smoothstep(0.0, 0.5, min(p.x - box.x, box.y - p.x));
    float wz = smoothstep(0.0, 0.5, min(p.z - box.z, box.w - p.z));
    float wy = smoothstep(0.0, 0.5, min(p.y - rest.x, rest.y - p.y));
    float ax = 1.0 - (1.0 - wx) * (1.0 - abs(n.x)) * 0.55;
    float az = 1.0 - (1.0 - wz) * (1.0 - abs(n.z)) * 0.55;
    float ay = 1.0 - (1.0 - wy) * (1.0 - abs(n.y)) * 0.55;
    return ax * az * ay;
}

// Oak boards 14 cm wide running toward the fire, each its own length cut from its own log, with
// fine dark joints and eased edges under a satin varnish. Values: the oak with rings in w, then
// roughness, strength, coat and gloss, then the walls and the floor and ceiling for the corners.
float4 floor_ps(WoodOut i) : SV_Target0
{
    float3 p = i.world / ROOM_METRE;
    float wide = 0.14;
    float col = floor(p.x / wide);
    float fx = frac(p.x / wide);
    float len = lerp(0.9, 1.9, wood_hash(float3(col, 3.1, 0.7)));
    float off = wood_hash(float3(col, 9.7, 2.3)) * 2.0;
    float zz = (p.z + off) / len;
    float row = floor(zz);
    float fz = frac(zz);
    float id = wood_hash(float3(col, row, 5.3));
    float joint = min(min(fx, 1.0 - fx) * wide, min(fz, 1.0 - fz) * len);
    float gap = 1.0 - smoothstep(0.0004, 0.0014, joint);
    float eased = smoothstep(0.0, 0.003, joint);
    float3 q = float3((p.z + off + id * 7.0) * ROOM_METRE, (fx - 0.5) * wide * ROOM_METRE + lerp(-3.0, 3.0, id), lerp(1.2, 4.0, frac(id * 7.3)));
    float3 oak = room_linear(material[0].rgb) * lerp(0.78, 1.16, frac(id * 13.1));
    Wood w = wood_at(q, oak, material[0].w, material[1].y);
    float worn = wood_fbm(float3(p.x * 1.5, 0.0, p.z * 1.5));
    float3 c = w.color * (1.0 - gap * 0.8) * lerp(0.92, 1.06, worn);
    float high = (eased - 1.0) * 0.0015 * ROOM_METRE - w.low * 0.00025 * ROOM_METRE;
    float3 n = wood_bump(normalize(i.normal), i.world, high);
    float ao = room_corner(p, n, material[2], material[3].xy);
    return wood_lit(i, n, c, material[1].x + w.rough + worn * 0.1, material[1].z, material[1].w, ao, 1.0);
}

// Walls painted deep green over walnut panelling to 0.98 m: a skirting board, raised panels in
// frames of stiles and rails, and a rounded rail on top. Values: the paint, the walnut with rings
// in w, the walls, and the floor and ceiling.
float4 wall_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    float y = p.y - material[3].x;
    float along = abs(n0.x) > 0.5 ? p.z : p.x;
    float ao = room_corner(p, n0, material[2], material[3].xy);
    if (y > 0.98)
    {
        float mottle = wood_fbm(p * 2.5);
        float3 paint = room_linear(material[0].rgb) * (0.9 + 0.2 * mottle);
        float high = (wood_noise(p * 320.0) - 0.5) * 0.00012 * ROOM_METRE;
        float3 n = wood_bump(n0, i.world, high);
        return room_lit(i, n, paint, 0.7 + 0.1 * mottle, 0.0, ao, 0.0);
    }
    float cell = along / 0.62;
    float cx = frac(cell) * 0.62;
    float panel_x = min(cx - 0.08, 0.54 - cx);
    float panel_y = min(y - 0.24, 0.84 - y);
    float inside = min(panel_x, panel_y);
    float raised = smoothstep(0.0, 0.035, inside);
    float frame_rim = 1.0 - smoothstep(0.0, 0.004, abs(inside));
    float high = raised * 0.008;
    float skirting = 1.0 - smoothstep(0.155, 0.16, y);
    high += skirting * (0.014 + 0.004 * smoothstep(0.13, 0.155, y) * -1.0);
    float rail = room_band(y, 0.9, 0.98);
    float t = saturate((y - 0.9) / 0.08);
    high += rail * (0.006 + 0.01 * sin(t * 3.14159));
    bool across = inside < 0.0 && (panel_y < 0.0 || rail > 0.5 || skirting > 0.5);
    float3 q = across ? float3(along * ROOM_METRE, y * ROOM_METRE + 2.0, 3.0 + floor(y * 4.0)) : float3(y * ROOM_METRE, cx * ROOM_METRE + 2.5, 2.2 + floor(cell) * 0.7);
    Wood w = wood_at(q, room_linear(material[1].rgb), material[1].w, 0.7);
    float3 c = w.color * (1.0 - frame_rim * 0.35) * (1.0 - skirting * 0.15);
    float3 n = wood_bump(n0, i.world, high * ROOM_METRE - w.low * 0.0002 * ROOM_METRE);
    return wood_lit(i, n, c, 0.5 + w.rough, 0.5, 0.25, ao, 1.0);
}

// Plaster above, warm cream, darker where it meets the walls. Values: the plaster, unused, the
// walls, the floor and ceiling.
float4 ceiling_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    float ao = room_corner(p, n0, material[2], material[3].xy);
    float3 c = room_linear(material[0].rgb) * (0.9 + 0.2 * wood_fbm(p * 2.0));
    return room_lit(i, n0, c, 0.85, 0.0, ao, 0.0);
}

// Old red brick in a running bond with grey mortar, laid on whichever plane a face lies most in,
// each brick its own fired colour, pitted, the mortar sunk, sooted toward the fire. Values: x how
// sooted it all is, yzw where the soot gathers in metres.
float4 brick_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    float3 an = abs(n0);
    float2 uv = an.x > an.y && an.x > an.z ? p.zy : (an.z > an.y ? p.xy : p.xz);
    float course = floor(uv.y / 0.075);
    float shift = frac(course * 0.5) * 2.0 * 0.5;
    float bx = uv.x / 0.225 + shift;
    float brick = floor(bx);
    float fx = frac(bx) * 0.225;
    float fy = frac(uv.y / 0.075) * 0.075;
    float mortar_x = min(fx, 0.225 - fx);
    float mortar_y = min(fy, 0.075 - fy);
    float edge = min(mortar_x, mortar_y);
    float mortar = 1.0 - smoothstep(0.004, 0.0062, edge);
    float id = wood_hash(float3(brick, course, 1.3));
    float id2 = wood_hash(float3(brick, course, 7.9));
    float3 red = lerp(float3(0.52, 0.2, 0.12), float3(0.66, 0.3, 0.18), id);
    red = lerp(red, float3(0.3, 0.13, 0.09), step(0.82, id2));
    red = lerp(red, float3(0.62, 0.42, 0.3), step(0.93, id2) * 0.6);
    float speck = wood_noise(p * 260.0);
    float pits = smoothstep(0.72, 0.85, wood_noise(p * 140.0 + id * 9.0));
    float3 c = room_linear(red) * (0.66 + 0.24 * wood_fbm(p * 30.0 + id * 5.0)) * (1.0 - pits * 0.3);
    float3 grey = room_linear(float3(0.46, 0.43, 0.39)) * (0.8 + 0.3 * speck);
    c = lerp(c, grey, mortar);
    float3 sp = material[0].yzw;
    float soot = saturate(material[0].x + (1.0 - smoothstep(0.1, 0.65, length((p - sp) * float3(1.0, 0.7, 1.0)))) * 0.85);
    soot = max(soot, step(p.z, sp.z + 0.14) * 0.92);
    soot *= 0.75 + 0.25 * wood_fbm(p * 8.0);
    c *= 1.0 - soot * 0.9;
    float round_off = smoothstep(0.0, 0.012, edge);
    float high = (round_off - 1.0) * 0.005 - pits * 0.0012 + speck * 0.0003;
    float3 n = wood_bump(n0, i.world, high * ROOM_METRE);
    return room_lit(i, n, c, lerp(0.82, 0.95, mortar), 0.0, lerp(1.0, 0.6, mortar), 0.0);
}

// Dark slate, honed, faintly cleft in layers, for the hearth. Values: the stone in rgb.
float4 slate_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    float layers = wood_fbm(float3(p.x * 3.0, p.y * 40.0, p.z * 3.0));
    float3 c = room_linear(material[0].rgb) * (0.8 + 0.35 * layers + 0.1 * wood_noise(p * 200.0));
    float3 n = wood_bump(n0, i.world, (layers - 0.5) * 0.0006 * ROOM_METRE);
    return room_lit(i, n, c, 0.7 + layers * 0.2, 0.0, 1.0, 0.0);
}

// Woodwork baked where it stands, the grain along the axis its vertex colour names, red x, green y
// and blue z, each part cut from its own log by its vertex alpha. Values: the wood with rings in
// w, then strength, roughness, coat and gloss.
float4 woodwork_ps(WoodOut i) : SV_Target0
{
    float3 lp = i.local;
    float3 ax = i.color.rgb;
    float seed = i.color.a * 31.0;
    float3 q = ax.x > 0.5 ? lp.xyz : (ax.y > 0.5 ? lp.yzx : lp.zxy);
    float board = floor(q.z / 2.0);
    seed += wood_hash(float3(board, seed, 3.7)) * 17.0;
    q += float3(seed * 5.0, 2.0 + frac(seed * 0.37) * 4.0, 1.5 + frac(seed * 0.61) * 4.0);
    q.y += q.x * (frac(seed * 0.91) - 0.5) * 0.14;
    float3 early = room_linear(material[0].rgb) * (0.9 + 0.2 * frac(seed * 0.73));
    Wood w = wood_at(q, early, material[0].w, material[1].x);
    float3 n = wood_bump(normalize(i.normal), i.world, -w.low * 0.004);
    return wood_lit(i, n, w.color, material[1].y + w.rough, material[1].z, material[1].w, 1.0, 1.0);
}

// How far outside a flower of radius r with so many rounded petals a point p is, below 0 inside
float rug_flower(float2 p, float r, float petals)
{
    float a = atan2(p.y, p.x);
    return length(p) - r * (0.62 + 0.38 * abs(cos(a * petals * 0.5)));
}

// Inside a shape whose distance is sd, its edge aa soft
float rug_fill(float sd, float aa)
{
    return 1.0 - smoothstep(-aa, aa, sd);
}

// One of the field's small flowers in a diamond lattice, in its own colours over ground
float3 rug_lattice(float2 q, float3 ground, float3 vine, float aa, float3 one, float3 two, float3 three, float3 dark)
{
    float2 r = float2(q.x + q.y, q.x - q.y) * 0.7071;
    float cell = 0.1;
    float2 id = floor(r / cell);
    float2 f = (frac(r / cell) - 0.5) * cell;
    float pick = wood_hash(float3(id, 2.3));
    float3 c = ground;
    float line_ = min(cell * 0.5 - abs(f.x), cell * 0.5 - abs(f.y));
    c = lerp(c, vine, rug_fill(line_ - 0.0035, aa));
    float2 leaf = abs(f) - cell * 0.25;
    c = lerp(c, vine, rug_fill(length(float2(leaf.x + leaf.y, (leaf.x - leaf.y) * 2.6) * 0.7071) - 0.011, aa));
    float flower = rug_flower(f, 0.024, 6.0);
    float3 petal = pick < 0.4 ? one : (pick < 0.7 ? two : three);
    c = lerp(c, dark, rug_fill(flower - 0.003, aa));
    c = lerp(c, petal, rug_fill(flower, aa));
    c = lerp(c, ground, rug_fill(length(f) - 0.007, aa));
    return c;
}

// A Persian rug lying on the floor, woven knot by knot: a madder red field of small flowers in a
// diamond lattice round a lobed navy medallion with pendants, navy corners, a navy border of
// palmettes on a vine between ivory and red guards, an overcast edge, the dyes wandering row by
// row as hand dyed wool does, its pile worn paler where feet go, soft at the rim of the light.
// Values: its size in metres in xy and its middle in zw.
float4 rug_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    float2 h = material[0].xy * 0.5;
    float2 d = p.xz - material[0].zw;
    float aa = max(length(fwidth(d)), 0.002);
    float2 dq = (floor(d / 0.004) + 0.5) * 0.004;
    float2 a = abs(dq);
    float edge = min(h.x - a.x, h.y - a.y);
    float3 red = float3(0.5, 0.14, 0.11);
    float3 navy = float3(0.11, 0.14, 0.24);
    float3 ivory = float3(0.78, 0.71, 0.57);
    float3 gold = float3(0.66, 0.5, 0.3);
    float3 rose = float3(0.66, 0.36, 0.3);
    float3 green = float3(0.24, 0.32, 0.27);
    float3 brown = float3(0.12, 0.08, 0.06);
    float3 c;
    if (edge < 0.29)
    {
        float s = h.x - a.x < h.y - a.y ? dq.y : dq.x;
        c = brown;
        c = lerp(c, ivory, room_band(edge, 0.02, 0.05));
        float rec = step(0.5, frac(s / 0.05 + step(0.035, edge) * 0.5));
        c = lerp(c, lerp(red, navy, rec), room_band(edge, 0.027, 0.043) * 0.85);
        float3 m = navy;
        float t = (edge - 0.05) / 0.2 - 0.5;
        float cell = s / 0.24;
        float2 pc = float2((frac(cell) - 0.5) * 0.24, t * 0.2);
        bool alt = frac(floor(cell) * 0.5) > 0.25;
        float vine = abs(t - 0.32 * sin(cell * 6.2832)) * 0.2;
        m = lerp(m, gold, rug_fill(vine - 0.005, aa));
        float palm = rug_flower(pc, 0.07, 8.0);
        m = lerp(m, brown, rug_fill(palm - 0.004, aa));
        m = lerp(m, alt ? red : ivory, rug_fill(palm, aa));
        float heart = rug_flower(pc, 0.032, 6.0);
        m = lerp(m, alt ? ivory : rose, rug_fill(heart, aa));
        m = lerp(m, navy, rug_fill(length(pc) - 0.01, aa));
        c = lerp(c, m, room_band(edge, 0.05, 0.25));
        float2 dot_at = float2((frac(s / 0.03) - 0.5) * 0.03, edge - 0.267);
        float3 guard = lerp(red, ivory, rug_fill(length(dot_at) - 0.005, aa));
        c = lerp(c, guard, room_band(edge, 0.252, 0.282));
        c = lerp(c, brown, room_band(edge, 0.248, 0.254) + room_band(edge, 0.28, 0.29));
    }
    else
    {
        float2 inner = h - 0.29;
        float2 m = dq / inner;
        float an = aa / inner.x;
        c = rug_lattice(dq, red, green, aa, ivory, navy, gold, brown);
        float ang = atan2(m.y, m.x);
        float md = abs(m.x) / 0.5 + abs(m.y) / 0.62 + 0.06 * sin(ang * 16.0);
        float pend = abs(m.x) / 0.07 + (abs(m.y) - 0.74) / 0.11 * sign(abs(m.y) - 0.74) * 1.0;
        float corner = abs(m.x) + abs(m.y);
        float3 navy_field = rug_lattice(dq, navy, green * 0.8, aa, ivory, rose, gold, brown);
        float in_corner = rug_fill(1.55 - corner, an * 2.0);
        c = lerp(c, navy_field, in_corner);
        c = lerp(c, gold, rug_fill(abs(corner - 1.53) - 0.012, an * 2.0));
        float in_med = rug_fill(md - 1.0, an * 3.0);
        float in_pend = rug_fill(abs(m.x) / 0.07 + abs(abs(m.y) - 0.72) / 0.1 - 1.0, an * 10.0);
        c = lerp(c, navy_field, max(in_med, in_pend));
        c = lerp(c, brown, rug_fill(abs(md - 1.0) - 0.02, an * 3.0));
        float3 heart = rug_lattice(dq * 1.3, red, navy, aa, ivory, gold, ivory, brown);
        c = lerp(c, heart, rug_fill(md - 0.55, an * 3.0));
        c = lerp(c, gold, rug_fill(abs(md - 0.55) - 0.015, an * 3.0));
        float star = abs(m.x) / 0.1 + abs(m.y) / 0.14 + 0.25 * cos(ang * 8.0);
        c = lerp(c, ivory, rug_fill(star - 1.0, an * 8.0));
        c = lerp(c, navy, rug_fill(star - 0.45, an * 8.0));
    }
    float abrash = lerp(0.84, 1.06, wood_noise(float3(0.0, dq.y * 1.7 + 3.0, 1.0)));
    float wear = smoothstep(0.45, 0.8, wood_fbm(float3(d.x * 2.2, 0.0, d.y * 2.2) + 7.0)) * (1.0 - smoothstep(0.3, 1.2, length(d)));
    float knot = wood_hash(float3(floor(d / 0.004), 1.0));
    float fine = saturate(1.0 - aa / 0.008);
    c = room_linear(c) * abrash * (1.0 + (knot - 0.5) * 0.25 * fine);
    c = lerp(c, room_linear(float3(0.6, 0.53, 0.44)) * 0.75, wear * 0.25);
    if (n0.y < 0.5) c = room_linear(brown) * 1.5;
    float3 n = wood_bump(n0, i.world, (knot - 0.5) * fine * 0.0008 * ROOM_METRE);
    float ao = room_corner(p, n, material[2], material[3].xy) * (0.8 + 0.2 * smoothstep(0.0, 0.03, edge));
    return room_lit(i, n, c, 0.95, 0.0, ao, 0.9);
}

// Letters as small gold blocks in rows, for titles at book scale
float room_letters(float2 at, float rows)
{
    float2 cell = floor(at * float2(rows * 1.6, rows));
    float2 f = frac(at * float2(rows * 1.6, rows));
    float on = step(0.3, wood_hash(float3(cell, 4.7)));
    return on * room_band(f.x, 0.12, 0.85) * room_band(f.y, 0.2, 0.8);
}

// A book on a shelf, a box of one square scaled to its size, its spine toward +z, its page block
// showing on top, below and at the fore edge inside the boards. Tint is the cover's colour with
// the book's seed in alpha, which picks leather with raised bands and a title label, cloth with a
// gold title, or a paper jacket with a printed band.
float4 book_ps(WoodOut i) : SV_Target0
{
    float3 lp = i.local;
    float3 a = abs(lp);
    float seed = i.color.a;
    float kind = frac(seed * 7.13);
    float3 n0 = normalize(i.normal);
    float3 c = i.color.rgb;
    float rough = 0.55;
    float metal = 0.0;
    float high = 0.0;
    float3 goldc = float3(0.95, 0.68, 0.3);
    bool spine = lp.z > 0.497;
    bool ends = a.y > 0.497 || lp.z < -0.497;
    float inside = 0.5 - a.x;
    if (!spine && ends && inside > 0.06 && lp.z < 0.44)
    {
        float leaves = wood_noise(float3(lp.x * 90.0, seed * 50.0, lp.y * 2.0 + lp.z * 2.0));
        float3 paper = lerp(float3(0.8, 0.74, 0.6), float3(0.65, 0.56, 0.4), frac(seed * 3.7));
        c = room_linear(paper) * (0.85 + 0.2 * leaves);
        rough = 0.8;
        high = -0.02 + leaves * 0.004;
    }
    else if (spine)
    {
        float v = lp.y + 0.5;
        float x = lp.x;
        high = sqrt(saturate(1.0 - 4.0 * x * x)) * 0.05;
        float grain = wood_noise(float3(lp.x * 40.0, lp.y * 60.0, seed * 30.0));
        if (kind < 0.45)
        {
            rough = 0.4 + 0.2 * grain;
            c *= 0.85 + 0.25 * grain;
            float gilt = 0.0;
            for (int b = 1; b <= 4; b++)
            {
                float at = b * 0.18 + 0.02;
                float band = exp(-pow((v - at) / 0.012, 2.0));
                high += band * 0.03;
                gilt += room_band(abs(v - at), 0.022, 0.028);
            }
            float label = room_band(v, 0.6, 0.69) * room_band(x, -0.38, 0.38);
            c = lerp(c, frac(seed * 11.0) > 0.5 ? float3(0.02, 0.015, 0.012) : float3(0.18, 0.02, 0.02), label);
            gilt = max(gilt, label * room_letters(float2(x + 0.5, (v - 0.6) / 0.09), 2.0));
            c = lerp(c, goldc, gilt);
            metal = gilt;
            rough = lerp(rough, 0.3, gilt);
        }
        else if (kind < 0.8)
        {
            float weave = wood_noise(float3(lp.x * 120.0, lp.y * 300.0, seed)) * wood_noise(float3(lp.x * 300.0, lp.y * 120.0, seed + 3.0));
            c *= 0.8 + 0.5 * weave;
            rough = 0.75;
            float gilt = room_band(v, 0.78, 0.9) * room_letters(float2(x + 0.5, (v - 0.78) / 0.12), 3.0);
            gilt = max(gilt, room_band(v, 0.05, 0.06) + room_band(v, 0.94, 0.95));
            gilt = max(gilt, room_band(length(float2(x, (v - 0.22) * 2.0)), -1.0, 0.12) * step(0.5, frac(seed * 5.0)));
            c = lerp(c, goldc, gilt);
            metal = gilt;
            rough = lerp(rough, 0.35, gilt);
        }
        else
        {
            float printed = room_band(v, 0.55, 0.78);
            float3 band = frac(seed * 13.0) > 0.5 ? float3(0.85, 0.8, 0.7) : float3(0.03, 0.03, 0.035);
            c = lerp(c, band, printed);
            float ink = room_letters(float2(x + 0.5, (v - 0.58) / 0.16), 3.0) * printed;
            c = lerp(c, frac(seed * 13.0) > 0.5 ? float3(0.05, 0.04, 0.04) : float3(0.8, 0.75, 0.65), ink);
            rough = 0.45;
        }
    }
    else
    {
        float grain = wood_noise(float3(lp.y * 50.0, lp.z * 50.0, seed * 30.0));
        c *= 0.85 + 0.25 * grain;
        rough = kind < 0.45 ? 0.45 : 0.75;
    }
    float worn = smoothstep(0.42, 0.5, max(a.y, a.z)) * smoothstep(0.38, 0.5, a.x) * 0.25;
    c = lerp(c, c * 1.6 + 0.02, worn);
    float3 n = wood_bump(n0, i.world, high);
    return room_lit(i, n, c, rough, metal, 1.0, kind > 0.45 && kind < 0.8 ? 0.4 : 0.15);
}

// Oxblood leather on the chair, finely grained and creased, its back's face buttoned in a diamond
// tufting with pleats between the buttons, worn paler where hands rest. The chair is drawn in its
// own frame, metres times the room's scale. Values: the leather, then the tufted face's front in
// z, the seat's height above which it tufts and its half width.
float4 leather_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 lp = i.local / ROOM_METRE;
    float grain = wood_noise(lp * 900.0) * 0.6 + wood_noise(lp * 300.0) * 0.4;
    float crease = 1.0 - abs(wood_fbm(lp * float3(9.0, 4.0, 9.0)) * 2.0 - 1.0);
    crease = smoothstep(0.8, 1.0, crease);
    float3 c = room_linear(material[0].rgb) * (0.85 + 0.25 * grain) * (1.0 - crease * 0.25);
    float high = grain * 0.00025 - crease * 0.0006;
    float tuft = room_band(lp.z, material[1].x - 0.1, material[1].x + 0.05) * smoothstep(material[1].y, material[1].y + 0.05, lp.y) * (1.0 - smoothstep(material[1].z - 0.05, material[1].z, abs(lp.x)));
    float2 lat = float2(lp.x + lp.y, lp.x - lp.y) / 0.13;
    float2 lc = frac(lat) - 0.5;
    float2 button = frac(lat + 0.5) - 0.5;
    float bd = length(button);
    float dimple = exp(-bd * bd / 0.02);
    float pleat = 1.0 - smoothstep(0.0, 0.06, min(abs(lc.x), abs(lc.y)));
    high -= tuft * (dimple * 0.012 + pleat * 0.002 * (1.0 - dimple));
    c *= 1.0 - tuft * (dimple * 0.45 + pleat * 0.15);
    c = lerp(c, c * 1.5, saturate(n0.y) * 0.25 * (1.0 - tuft));
    float3 n = wood_bump(n0, i.world, high * ROOM_METRE);
    return room_lit(i, n, c, 0.38 + 0.25 * grain + crease * 0.2, 0.0, 1.0, 0.25);
}

// Brass, polished where it is handled and tarnished browner elsewhere. Values: its colour with
// its roughness in w.
float4 brass_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    float tarnish = wood_fbm(p * 12.0);
    float3 c = room_linear(material[0].rgb) * lerp(1.0, 0.55, tarnish * 0.7);
    return room_lit(i, n0, c, material[0].w + tarnish * 0.15, 1.0, 1.0, 0.0);
}

// A lamp's linen shade lit through by the bulb inside, drawn from both sides, the inside glowing
// brighter and the weave showing against the light. Values: the linen, then the glow it lets
// through in rgb.
float4 shade_ps(WoodOut i, bool front : SV_IsFrontFace) : SV_Target0
{
    float3 n = normalize(i.normal) * (front ? 1.0 : -1.0);
    float3 lp = i.local / ROOM_METRE;
    float weave = wood_noise(float3(atan2(lp.z, lp.x) * 120.0, lp.y * 700.0, 0.0)) * wood_noise(float3(atan2(lp.z, lp.x) * 400.0, lp.y * 200.0, 3.0));
    float3 linen = room_linear(material[0].rgb);
    float4 lit = room_lit(i, n, linen, 0.9, 0.0, 1.0, 0.3);
    float3 glow = material[1].rgb * (0.75 + 0.5 * weave) * (front ? 1.0 : 2.2);
    return float4(lit.rgb + glow, i.depth);
}

// The window's glass on an October night: deep blue sky with stars, a faint glow low down, black
// tree tops along the horizon, the moon with its halo, and the warm room mirrored faintly. Values:
// the way to the moon, then how bright the night is in x.
float4 night_ps(WoodOut i) : SV_Target0
{
    float3 n = normalize(i.normal);
    float3 v = normalize(three_eye() - i.world);
    float3 rd = -v;
    float up = rd.y;
    float3 sky = lerp(float3(0.025, 0.04, 0.09), float3(0.002, 0.004, 0.014), saturate(up * 1.6 + 0.2));
    float3 moon = normalize(material[0].xyz);
    float md = dot(rd, moon);
    sky += float3(0.9, 0.92, 1.0) * smoothstep(0.99985, 0.9999, md) * 2.5;
    sky += float3(0.25, 0.3, 0.45) * pow(saturate(md), 600.0) * 0.6 + float3(0.05, 0.07, 0.12) * pow(saturate(md), 18.0) * 0.4;
    float3 cell = floor(rd * 260.0);
    float star = step(0.9965, wood_hash(cell)) * smoothstep(0.0, 0.15, up);
    sky += star * float3(0.5, 0.55, 0.7) * wood_hash(cell + 3.1);
    float az = atan2(rd.z, rd.x);
    float tops = 0.03 + wood_fbm(float3(az * 9.0, 0.0, 1.0)) * 0.13 + wood_noise(float3(az * 60.0, 2.0, 0.0)) * 0.03;
    float tree = 1.0 - smoothstep(tops - 0.004, tops + 0.004, up);
    sky = lerp(sky, float3(0.002, 0.003, 0.004), tree);
    sky *= material[1].x;
    float nv = saturate(dot(n, v));
    float fresnel = 0.04 + 0.96 * pow(1.0 - nv, 5.0);
    float3 mirrored = wood_room(reflect(-v, n), 0.05) * fresnel;
    return float4(sky + mirrored, i.depth);
}

// Velvet, its pile catching the light at the rim, drawn from both sides. Values: its colour.
float4 velvet_ps(WoodOut i, bool front : SV_IsFrontFace) : SV_Target0
{
    float3 n = normalize(i.normal) * (front ? 1.0 : -1.0);
    float3 p = i.world / ROOM_METRE;
    float3 c = room_linear(material[0].rgb) * (0.9 + 0.15 * wood_noise(p * 150.0));
    return room_lit(i, n, c, 0.85, 0.0, 1.0, 2.2);
}

// An oil painting in its frame, uv across the canvas: a dusk over hills and a still lake, a dark
// wood on the left, laid in with strokes and under an old varnish
float4 painting_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float x = i.uv.x;
    float y = 1.0 - i.uv.y;
    float stroke = wood_noise(float3(x * 90.0, y * 30.0, 0.0)) * 0.6 + wood_noise(float3(x * 30.0, y * 140.0, 1.0)) * 0.4;
    float3 c = lerp(float3(0.85, 0.55, 0.28), float3(0.2, 0.25, 0.38), smoothstep(0.35, 0.95, y));
    c += float3(0.4, 0.25, 0.08) * exp(-pow(length(float2((x - 0.7) * 1.4, y - 0.42)) / 0.12, 2.0));
    float far = 0.4 + 0.06 * wood_fbm(float3(x * 3.0, 1.0, 0.0));
    c = lerp(c, float3(0.38, 0.33, 0.38), 1.0 - smoothstep(far - 0.005, far + 0.005, y));
    float mid = 0.3 + 0.08 * wood_fbm(float3(x * 5.0 + 3.0, 2.0, 0.0)) - x * 0.05;
    c = lerp(c, float3(0.16, 0.17, 0.1), 1.0 - smoothstep(mid - 0.005, mid + 0.005, y));
    float lake = 1.0 - smoothstep(0.2, 0.21, y);
    float3 mirror = lerp(float3(0.75, 0.5, 0.27), float3(0.25, 0.28, 0.38), smoothstep(0.2, 0.0, y)) * (0.8 + 0.2 * wood_noise(float3(x * 4.0, y * 200.0, 0.0)));
    c = lerp(c, mirror, lake * room_band(x, 0.18, 1.1));
    float wood = 0.75 - x * 2.2 + wood_fbm(float3(x * 12.0, y * 8.0, 4.0)) * 0.35;
    c = lerp(c, float3(0.05, 0.06, 0.035), smoothstep(y - 0.02, y + 0.02, wood));
    c = room_linear(c * (0.85 + 0.25 * stroke) * float3(1.0, 0.95, 0.82));
    if (n0.z < 0.5) c = room_linear(float3(0.5, 0.45, 0.35));
    float3 n = wood_bump(n0, i.world, stroke * 0.004);
    return room_lit(i, n, c, 0.4, 0.0, 1.0, 0.0);
}

// Ivory wax lit through from its flame near the top, along y in the candle's own frame. Values:
// the wax, then the flame's glow with the top's height in w.
float4 wax_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float y = i.local.y;
    float3 c = room_linear(material[0].rgb);
    float4 lit = room_lit(i, n0, c, 0.5, 0.0, 1.0, 0.4);
    float glow = exp(-(material[1].w - y) / 0.25);
    return float4(lit.rgb + material[1].rgb * glow, i.depth);
}

// The colour of something as hot as h from 0 to 1, deep red to orange to yellow white, in light
// far above 1
float3 room_heat(float h)
{
    h = saturate(h);
    return float3(1.0, 0.32 + 0.6 * h * h, 0.04 + 0.5 * pow(h, 5.0)) * (h * h * 9.0);
}

// A log on the fire, a cylinder of one along y scaled to its size: grey brown bark split in long
// fissures, black where the fire has taken it, its char cracked in squares that glow and breathe,
// and pale cut ends with rings. Values: time in x, the fire's middle in metres in yzw.
float4 log_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float t = material[0].x;
    float3 fire = material[0].yzw;
    float3 lp = i.local;
    float seed = i.color.a * 20.0;
    float3 p = i.world / ROOM_METRE;
    bool cap = abs(lp.y) > 0.495;
    float ang = atan2(lp.z, lp.x);
    float fiss = 1.0 - abs(wood_noise(float3(ang * 4.0 + seed, lp.y * 5.0, seed)) * 2.0 - 1.0);
    float split = smoothstep(0.82, 0.95, fiss);
    float near = 1.0 - smoothstep(0.12, 0.42, length((p - fire) * float3(1.0, 1.6, 1.4)));
    float charred = saturate(near * 1.8 + (wood_fbm(p * 18.0) - 0.5) * 0.8 - saturate(n0.y) * 0.25);
    float3 bark = room_linear(lerp(float3(0.22, 0.18, 0.14), float3(0.36, 0.31, 0.25), wood_noise(p * 60.0)));
    float3 c = bark * (1.0 - split * 0.6);
    if (cap)
    {
        float r = length(lp.xz);
        float rings = frac(r * 9.0 + wood_noise(float3(lp.xz * 6.0, seed)) * 0.5);
        c = room_linear(lerp(float3(0.62, 0.48, 0.32), float3(0.45, 0.32, 0.2), smoothstep(0.6, 0.9, rings)));
        c = lerp(c, bark * 0.4, smoothstep(0.85, 0.95, r));
    }
    c = lerp(c, float3(0.006, 0.005, 0.0045), charred);
    float cracks = 1.0 - smoothstep(0.0, 0.025, abs(wood_fbm(p * 60.0 + seed) - 0.5));
    cracks *= smoothstep(0.4, 0.7, wood_noise(p * 25.0 + seed));
    float breathe = 0.5 + 0.5 * wood_noise(float3(p.x * 20.0, p.z * 20.0, t * 0.8 + seed));
    float under = 0.15 + 0.85 * saturate(-n0.y + 0.1);
    float3 glow = room_heat(0.12 + 0.22 * breathe * near) * cracks * charred * charred * near * breathe * under * 0.5;
    float4 lit = room_lit_but(i, n0, c, 0.9, 0.0, 1.0, 0.0, 1);
    return float4(lit.rgb + glow, i.depth);
}

// The bed of coals under the logs: lumps of charcoal crusted black and grey with ash, glowing
// through cracks that brighten and dim, hottest in the middle. Values: time in x, the fire's
// middle in metres in yzw.
float4 ember_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float t = material[0].x;
    float3 fire = material[0].yzw;
    float3 p = i.world / ROOM_METRE;
    float heat = 1.0 - smoothstep(0.05, 0.34, length((p - fire).xz * float2(1.0, 1.5)));
    float ash = smoothstep(0.45, 0.75, wood_fbm(p * 50.0)) * saturate(n0.y + 0.2);
    float3 c = lerp(float3(0.015, 0.013, 0.012), room_linear(float3(0.45, 0.43, 0.4)), ash * (1.0 - heat * 0.6));
    float vein = 1.0 - smoothstep(0.0, 0.09, abs(wood_fbm(p * 70.0 + float3(0.0, t * 0.05, 0.0)) - 0.5));
    float pulse = 0.5 + 0.5 * wood_noise(float3(p.x * 25.0, t * 0.9, p.z * 25.0));
    float hot = saturate(vein * 0.8 + heat * 0.35) * (1.0 - ash * 0.8) * heat * (0.45 + 0.55 * pulse);
    float4 lit = room_lit_but(i, n0, c, 0.9, 0.0, 1.0, 0.0, 1);
    return float4(lit.rgb + room_heat(0.25 + 0.5 * hot) * hot * 1.3, i.depth);
}

// A sheet of flame drawn adding its light, uv across it from its root at v 0 to its tip. Tongues
// lick up from noise rising through it, yellow white at the root, orange, then dull red where they
// tear off. Values: time in x, brightness in y. Tint alpha is its seed.
float4 flame_ps(WoodOut i) : SV_Target0
{
    float t = material[0].x;
    float seed = i.color.a * 40.0;
    float2 q = float2(i.uv.x * 2.0 - 1.0, i.uv.y);
    float rise = t * 1.7;
    float n1 = wood_fbm(float3(q.x * 2.0 + seed, q.y * 2.4 - rise, seed + t * 0.3));
    float n2 = wood_fbm(float3(q.x * 4.5 - seed, q.y * 5.0 - rise * 1.5, seed * 2.0 + t * 0.55));
    float x = q.x + (n1 - 0.5) * 0.9 * q.y;
    float width = lerp(0.8, 0.12, pow(q.y, 0.7));
    float body = 1.0 - abs(x) / width;
    float heat = body * (1.0 - q.y * 0.5) + (n2 - 0.5) * 1.1 * q.y - q.y * 0.45;
    heat *= smoothstep(0.0, 0.12, q.y) * (1.0 - smoothstep(0.85, 1.0, q.y)) * smoothstep(1.0, 0.75, abs(q.x));
    heat = saturate(heat * 1.5);
    return float4(room_heat(heat) * heat * material[0].y, 0.0);
}

// A soft glow round a bright light, a quad facing the eye drawn adding its light, brightest in its
// middle and falling off as a lens's veil does. Tint is the glow's colour and its strength.
float4 halo_ps(WoodOut i) : SV_Target0
{
    float2 d = i.uv * 2.0 - 1.0;
    float r = dot(d, d);
    float g = exp(-r * 3.0) * 0.6 + exp(-r * 14.0) * 0.4;
    g *= 1.0 - smoothstep(0.7, 1.0, r);
    return float4(i.color.rgb * g * material[0].y, 0.0);
}

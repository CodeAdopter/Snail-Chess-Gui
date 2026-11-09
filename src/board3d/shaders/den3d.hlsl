// The bedroom of about 2003 round the beige monitor: carpet, painted walls, beige plastic, the
// keyboard's keys, the monitor's glass showing the chess program, a window on a suburban night,
// cloth, posters, paper, a disc, a lava lamp, a TV showing snow, cork and small lights. Worked
// out in metres at 16.4 squares a metre, lit by the lamps, each returning how far ahead of the eye
// it is as its alpha, for the lens.

#include "room3d.hlsl"

// A letter of the 5 by 7 font from five columns, the top row in the low bit, at p from its top left
// in cells, or nothing outside
float den_glyph(uint a, uint b, uint c, uint d, uint e, float2 p)
{
    if (p.x < 0.0 || p.y < 0.0 || p.x >= 5.0 || p.y >= 7.0) return 0.0;
    uint col = (uint)p.x;
    uint bits = col == 0 ? a : col == 1 ? b : col == 2 ? c : col == 3 ? d : e;
    return (float)((bits >> (uint)p.y) & 1u);
}

// A word of up to four letters of the font, given as columns, cell size s, at p from its top left
float den_word4(float2 p, float s, uint4 l0, uint l0e, uint4 l1, uint l1e, uint4 l2, uint l2e, uint4 l3, uint l3e)
{
    float2 q = p / s;
    float v = den_glyph(l0.x, l0.y, l0.z, l0.w, l0e, q);
    v = max(v, den_glyph(l1.x, l1.y, l1.z, l1.w, l1e, q - float2(6.0, 0.0)));
    v = max(v, den_glyph(l2.x, l2.y, l2.z, l2.w, l2e, q - float2(12.0, 0.0)));
    v = max(v, den_glyph(l3.x, l3.y, l3.z, l3.w, l3e, q - float2(18.0, 0.0)));
    return v;
}

// A box from lo to hi in uv, a pixel soft
float den_rect(float2 uv, float2 lo, float2 hi)
{
    return room_band(uv.x, lo.x, hi.x) * room_band(uv.y, lo.y, hi.y);
}

// Short pile carpet, blue grey, worn paths a little paler. Values: the carpet, unused, the walls,
// the floor and ceiling.
float4 carpet_ps(WoodOut i) : SV_Target0
{
    float3 p = i.world / ROOM_METRE;
    float3 n0 = normalize(i.normal);
    float fade = saturate(1.5 - length(fwidth(p.xz * 700.0)));
    float pile = lerp(0.5, wood_noise(p * 700.0) * 0.6 + wood_noise(p * 230.0 + 3.1) * 0.4, fade);
    float blot = wood_fbm(p * 2.5);
    float3 c = room_linear(material[0].rgb) * (0.8 + 0.35 * pile) * (0.9 + 0.2 * blot);
    float3 n = wood_bump(n0, i.world, (pile - 0.5) * 0.0015 * ROOM_METRE * fade);
    float ao = room_corner(p, n0, material[2], material[3].xy);
    return room_lit(i, n, c, 0.95, 0.0, ao, 0.8);
}

// Walls in builder's cream, rolled on with a little orange peel, over a white skirting board.
// Values: the paint, the skirting, the walls, the floor and ceiling.
float4 paint_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    float y = p.y - material[3].x;
    float ao = room_corner(p, n0, material[2], material[3].xy);
    if (y < 0.09 && abs(n0.y) < 0.5)
    {
        float lip = smoothstep(0.075, 0.09, y);
        return room_lit(i, n0, room_linear(material[1].rgb) * (1.0 - lip * 0.25), 0.35, 0.0, ao, 0.0);
    }
    float fade = saturate(1.5 - length(fwidth(p * 260.0)));
    float peel = lerp(0.5, wood_noise(p * 260.0), fade);
    float mottle = wood_fbm(p * 1.8);
    float3 c = room_linear(material[0].rgb) * (0.93 + 0.09 * mottle);
    float3 n = wood_bump(n0, i.world, (peel - 0.5) * 0.0001 * ROOM_METRE);
    return room_lit(i, n, c, 0.78, 0.0, ao, 0.0);
}

// Moulded plastic, its colour in the vertex colour as sRGB and how rough it is in alpha, with a fine
// speckle and the yellowing beige plastic took on. Values: x how yellowed.
float4 plastic_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    float fade = saturate(1.5 - length(fwidth(p * 500.0)));
    float speck = lerp(0.5, wood_noise(p * 500.0), fade);
    float age = wood_fbm(p * 3.0);
    float3 c = room_linear(i.color.rgb) * (0.95 + 0.07 * speck);
    c = lerp(c, c * float3(1.0, 0.95, 0.82), age * material[0].x);
    float3 n = wood_bump(n0, i.world, (speck - 0.5) * 0.00012 * ROOM_METRE);
    return room_lit(i, n, c, lerp(0.2, 0.8, i.color.a), 0.0, 1.0, 0.0);
}

// Painted or plated metal, its colour in rgb and how metallic in alpha. Values: x roughness.
float4 metal_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 c = room_linear(i.color.rgb);
    return room_lit(i, n0, c, material[0].x, i.color.a, 1.0, 0.0);
}

// The desk lamp's shade, green enamel outside and white inside where the bulb lights it. Values:
// the glow inside in rgb.
float4 enamel_ps(WoodOut i, bool front : SV_IsFrontFace) : SV_Target0
{
    float3 n = normalize(i.normal) * (front ? 1.0 : -1.0);
    if (front) return room_lit(i, n, room_linear(i.color.rgb), 0.28, 0.0, 1.0, 0.0);
    float4 lit = room_lit(i, n, float3(0.8, 0.8, 0.78), 0.5, 0.0, 1.0, 0.0);
    return float4(lit.rgb + material[0].rgb, i.depth);
}

// The keyboard's keys on its top, uv across it and from the back row toward you: a function row,
// the five rows of letters with the space bar, the arrows and the number pad, lettering marked on
// each cap, and three small lights. The sides are the case.
float den_key(float2 uv, float2 lo, float2 hi, float2 cells, out float2 id, out float2 f)
{
    float2 q = (uv - lo) / (hi - lo) * cells;
    id = floor(q);
    f = frac(q) - 0.5;
    float inside = step(lo.x, uv.x) * step(uv.x, hi.x) * step(lo.y, uv.y) * step(uv.y, hi.y);
    float2 w = fwidth(q) + 0.01;
    float2 k = smoothstep(0.43 + w, 0.39 - w, abs(f));
    return inside * k.x * k.y;
}

float4 keys_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 cap = room_linear(float3(0.89, 0.86, 0.79));
    if (n0.y < 0.7) return room_lit(i, n0, cap * 0.85, 0.55, 0.0, 1.0, 0.0);
    float2 uv = i.uv;
    float2 id;
    float2 f;
    float key = 0.0;
    float mark = 0.0;
    float k = den_key(uv, float2(0.0, 0.03), float2(0.66, 0.15), float2(15.0, 1.0), id, f);
    if (id.x == 1.0 || id.x == 6.0 || id.x == 11.0) k = 0.0;
    key = max(key, k);
    mark = max(mark, k * den_rect(f, float2(-0.28, -0.25), float2(-0.08, -0.1)));
    float2 sid;
    float2 sf;
    k = den_key(uv, float2(0.0, 0.2), float2(0.66, 0.98), float2(15.0, 5.0), sid, sf);
    if (sid.y == 4.0 && sid.x >= 4.0 && sid.x <= 10.0)
    {
        float sx = (uv.x / 0.66 * 15.0 - 4.0) / 7.0 - 0.5;
        float w = fwidth(uv.x) * 22.0;
        k = smoothstep(0.495 + w, 0.47 - w, abs(sx)) * smoothstep(0.43, 0.39, abs(sf.y));
        sf = float2(1.0, 1.0);
    }
    key = max(key, k);
    float glyph = step(0.5, wood_hash(float3(sid, 4.2))) ? den_rect(sf, float2(-0.3, -0.28), float2(-0.1, -0.06)) : den_rect(sf, float2(-0.3, -0.28), float2(-0.14, -0.2)) + den_rect(sf, float2(-0.3, -0.16), float2(-0.08, -0.12));
    mark = max(mark, k * saturate(glyph));
    k = den_key(uv, float2(0.68, 0.2), float2(0.79, 0.51), float2(3.0, 2.0), id, f);
    key = max(key, k);
    k = den_key(uv, float2(0.68, 0.67), float2(0.79, 0.98), float2(3.0, 2.0), id, f);
    if (id.y == 0.0 && id.x != 1.0) k = 0.0;
    key = max(key, k);
    k = den_key(uv, float2(0.81, 0.2), float2(1.0, 0.98), float2(4.0, 5.0), id, f);
    key = max(key, k);
    mark = max(mark, k * den_rect(f, float2(-0.28, -0.26), float2(-0.1, -0.08)));
    float3 c = lerp(room_linear(float3(0.42, 0.4, 0.36)), cap, key);
    c = lerp(c, room_linear(float3(0.2, 0.19, 0.17)), mark * 0.8);
    float3 lights = 0.0;
    for (int l = 0; l < 3; l++)
    {
        float2 d = (uv - float2(0.86 + l * 0.05, 0.09)) * float2(1.0, 0.4);
        float dot_ = 1.0 - smoothstep(0.004, 0.006, length(d));
        c = lerp(c, room_linear(float3(0.2, 0.25, 0.2)), dot_);
        if (l == 0) lights += float3(0.2, 2.5, 0.3) * dot_;
    }
    float3 n = wood_bump(n0, i.world, key * 0.004 * ROOM_METRE);
    float4 lit = room_lit(i, n, c, 0.5, 0.0, lerp(0.6, 1.0, key), 0.0);
    return float4(lit.rgb + lights, i.depth);
}

// The monitor's glass showing the picture, uv over the glass from its top left. The picture is
// bent as the tube's face bends it, every line of it drawn by a beam a little wider where it is
// brighter, columns kept crisp, the phosphor's dots shown only when close enough to see, light
// spreading in the glass round what is bright, the edges darker, a faint hum rolling down, and the
// room mirrored in the glass over all. Values: x and y how much it bends, z how much of the glass
// the picture fills, w the time, then x how bright.
float3 crt_fetch(float2 uv, float lod)
{
    float3 c = material_texture.SampleLevel(material_sampler, uv, lod).rgb;
    return pow(c, 2.2);
}

float2 crt_warp(float2 g)
{
    float2 c = g * 2.0 - 1.0;
    c *= 1.0 + material[0].xy * c.yx * c.yx;
    c /= material[0].z;
    return c * 0.5 + 0.5;
}

float4 crt_ps(WoodOut i) : SV_Target0
{
    float3 n = normalize(i.normal);
    float2 uv = crt_warp(i.uv);
    float2 size = float2(800.0, 600.0);
    float2 edge = min(uv, 1.0 - uv) * size;
    float inside = saturate(min(edge.x, edge.y) * 0.7);
    float x = uv.x * size.x - 0.5;
    float sx = (floor(x) + 0.5 + smoothstep(0.2, 0.8, frac(x))) / size.x;
    float y = uv.y * size.y - 0.5;
    float row = floor(y);
    float fy = y - row;
    float3 a = crt_fetch(float2(sx, (row + 0.5) / size.y), 0.0);
    float3 b = crt_fetch(float2(sx, (row + 1.5) / size.y), 0.0);
    float wa = lerp(0.26, 0.42, sqrt(max(a.r, max(a.g, a.b))));
    float wb = lerp(0.26, 0.42, sqrt(max(b.r, max(b.g, b.b))));
    float3 beam = a * exp(-fy * fy / (2.0 * wa * wa)) / (wa * 2.5066) + b * exp(-(1.0 - fy) * (1.0 - fy) / (2.0 * wb * wb)) / (wb * 2.5066);
    float3 flat = crt_fetch(float2(sx, uv.y), 0.0);
    float3 c = lerp(beam, flat, smoothstep(0.35, 0.8, fwidth(y)));
    float triad = uv.x * 1100.0;
    float seen = saturate(1.6 - fwidth(triad) * 2.5);
    float ph = frac(triad) * 6.2832;
    c *= 1.0 + seen * 0.4 * float3(cos(ph), cos(ph - 2.094), cos(ph - 4.189));
    c += crt_fetch(uv, 3.0) * 0.1 + crt_fetch(uv, 5.0) * 0.07;
    float2 cc = uv * 2.0 - 1.0;
    c *= 1.0 - 0.22 * pow(saturate(dot(cc, cc) * 0.5), 1.5);
    c *= 1.0 + 0.018 * sin(uv.y * 5.0 - material[0].w * 1.7);
    c *= inside * material[1].x;
    c += crt_fetch(saturate(uv), 6.0) * 0.035 * material[1].x;
    float4 lit = room_lit_but(i, n, float3(0.018, 0.02, 0.019), 0.06, 0.0, 1.0, 0.0, 0);
    return float4(c + lit.rgb, i.depth);
}

// The window on a suburban night: a deep sky going orange low down where the town's lights reach,
// the houses across the road with a few windows lit, a tree, the street lamp and its glow, and the
// room mirrored faintly. Values: the way from the window to the street lamp.
float4 window_ps(WoodOut i) : SV_Target0
{
    float3 n = normalize(i.normal);
    float3 v = normalize(three_eye() - i.world);
    float3 rd = -v;
    float up = rd.y / max(length(rd.xz), 0.05);
    float az = atan2(rd.z, -rd.x);
    float3 sky = lerp(float3(0.07, 0.04, 0.025), float3(0.004, 0.006, 0.018), saturate(up * 2.2 + 0.15));
    float3 cell = floor(rd * 180.0);
    sky += step(0.997, wood_hash(cell)) * smoothstep(0.15, 0.4, up) * float3(0.3, 0.32, 0.4);
    float lot = floor(az * 3.0 + 0.3);
    float fx = frac(az * 3.0 + 0.3);
    float roof = 0.05 + 0.07 * wood_hash(float3(lot, 1.0, 2.0));
    roof += 0.07 * (1.0 - abs(fx - 0.5) * 2.0) * step(0.4, wood_hash(float3(lot, 3.0, 1.0)));
    float gap = step(0.08, fx) * step(fx, 0.92);
    float house = step(up, roof) * gap * step(-0.12, up);
    float3 wall = float3(0.012, 0.01, 0.012) + float3(0.05, 0.025, 0.008) * saturate(0.05 - up) * 6.0;
    float2 win = float2(az * 30.0, up * 26.0);
    float lit = step(0.83, wood_hash(float3(floor(win), lot))) * step(0.25, frac(win.x)) * step(0.3, frac(win.y)) * step(up, roof - 0.03);
    wall += lit * float3(0.5, 0.33, 0.12) * 0.5;
    sky = lerp(sky, wall, house);
    float tree = step(up, 0.05 + wood_fbm(float3(az * 6.0, up * 6.0, 1.0)) * 0.5 - abs(az + 0.35) * 1.6);
    sky = lerp(sky, float3(0.004, 0.005, 0.006), saturate(tree));
    float road = step(up, -0.12);
    sky = lerp(sky, float3(0.03, 0.018, 0.01), road);
    float3 lamp = normalize(material[0].xyz);
    float ld = dot(rd, lamp);
    sky += float3(1.0, 0.55, 0.2) * (smoothstep(0.9995, 0.9999, ld) * 30.0 + pow(saturate(ld), 300.0) * 1.5 + pow(saturate(ld), 20.0) * 0.12);
    float pole = step(abs(az - atan2(lamp.z, -lamp.x)), 0.004) * step(up, lamp.y / max(length(lamp.xz), 0.05) - 0.01);
    sky = lerp(sky, float3(0.01, 0.008, 0.008), pole);
    float nv = saturate(dot(n, v));
    float fresnel = 0.04 + 0.96 * pow(1.0 - nv, 5.0);
    return float4(sky + wood_room(reflect(-v, n), 0.05) * fresnel, i.depth);
}

// Cloth, its colour in rgb and its weave in alpha as a sixteenth: plain, a plaid cover, a mouse
// pad's woven top
float4 fabric_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    int kind = (int)(i.color.a * 16.0);
    float3 c = room_linear(i.color.rgb);
    float fade = saturate(1.5 - length(fwidth(p * 600.0)));
    float weave = lerp(0.5, wood_noise(p * 600.0), fade);
    if (kind == 1)
    {
        float2 q = p.xz * 9.0;
        float a = room_band(frac(q.x), 0.0, 0.3) + room_band(frac(q.y), 0.0, 0.3);
        float thin = room_band(frac(q.x * 2.0 + 0.5), 0.0, 0.06) + room_band(frac(q.y * 2.0 + 0.5), 0.0, 0.06);
        c = c * (0.75 + 0.25 * a) + float3(0.25, 0.05, 0.03) * saturate(thin) * 0.4;
    }
    c *= 0.9 + 0.2 * weave;
    float3 n = wood_bump(n0, i.world, (weave - 0.5) * 0.0004 * ROOM_METRE);
    return room_lit(i, n, c, 0.92, 0.0, 1.0, kind == 0 ? 1.4 : 1.0);
}

// The letters in the posters and the magazine
float den_mars(float2 p, float s)
{
    return den_word4(p, s, uint4(0x7F, 0x02, 0x04, 0x02), 0x7F, uint4(0x7E, 0x11, 0x11, 0x11), 0x7E, uint4(0x7F, 0x09, 0x19, 0x29), 0x46, uint4(0x46, 0x49, 0x49, 0x49), 0x31);
}

float den_bits(float2 p, float s)
{
    return den_word4(p, s, uint4(0x7F, 0x49, 0x49, 0x49), 0x36, uint4(0x00, 0x41, 0x7F, 0x41), 0x00, uint4(0x01, 0x01, 0x7F, 0x01), 0x01, uint4(0x46, 0x49, 0x49, 0x49), 0x31);
}

float den_free(float2 p, float s)
{
    return den_word4(p, s, uint4(0x7F, 0x09, 0x09, 0x01), 0x01, uint4(0x7F, 0x09, 0x19, 0x29), 0x46, uint4(0x7F, 0x49, 0x49, 0x49), 0x41, uint4(0x7F, 0x49, 0x49, 0x49), 0x41);
}

// The red planet hanging in black with its ice cap, dark lands, a long canyon and craters, lit from
// the left, over stars, its name along the foot
float3 den_mars_poster(float2 uv)
{
    float3 c = float3(0.004, 0.004, 0.008);
    float3 cell = floor(float3(uv * 140.0, 1.0));
    c += step(0.985, wood_hash(cell)) * float3(0.7, 0.72, 0.8) * wood_hash(cell + 2.0);
    float2 d = (uv - float2(0.5, 0.56)) * float2(0.6 / 0.86, 1.0) / 0.3;
    float r = length(d);
    if (r < 1.0)
    {
        float3 s = float3(d.x, d.y, sqrt(1.0 - r * r));
        float3 q = s * 3.0;
        float lands = wood_fbm(q * 1.3 + 1.7);
        float3 rock = lerp(float3(0.72, 0.3, 0.12), float3(0.38, 0.14, 0.07), smoothstep(0.45, 0.7, lands));
        float canyon = 1.0 - smoothstep(0.0, 0.04, abs(s.y + 0.12 + 0.15 * sin(s.x * 3.0)) + step(0.55, abs(s.x)) * 0.1);
        rock *= 1.0 - canyon * 0.5;
        float crater = smoothstep(0.75, 0.8, wood_noise(q * 6.0)) * 0.25;
        rock *= 1.0 - crater;
        rock = lerp(rock, float3(0.95, 0.93, 0.9), smoothstep(0.82, 0.86, s.y));
        float light = saturate(dot(s, normalize(float3(-0.6, 0.35, 0.7))));
        c = rock * (0.06 + light * 1.1) + float3(0.5, 0.25, 0.15) * pow(1.0 - s.z, 3.0) * 0.4 * light;
    }
    c += float3(0.6, 0.25, 0.1) * exp(-max(r - 1.0, 0.0) * 25.0) * step(1.0, r) * 0.15;
    c = max(c, float3(0.85, 0.8, 0.72) * den_mars(uv * float2(0.6, -0.86) - float2(0.145, -0.15), 0.0115));
    return c;
}

// The periodic table on a pale ground, its blocks in the colours such posters used, with a title
float3 den_table_poster(float2 uv)
{
    float3 c = float3(0.92, 0.92, 0.88);
    if (uv.y > 0.88) c = lerp(float3(0.1, 0.18, 0.42), float3(1.0, 1.0, 1.0), den_rect(uv, float2(0.3, 0.92), float2(0.7, 0.95)));
    float2 q = (uv - float2(0.04, 0.27)) / float2(0.92, 0.58) * float2(18.0, 7.0);
    float2 id = floor(q);
    float2 f = frac(q);
    int col = (int)id.x;
    int row = 6 - (int)id.y;
    bool there = id.x >= 0.0 && id.x < 18.0 && id.y >= 0.0 && id.y < 7.0;
    if (row == 0) there = there && (col == 0 || col == 17);
    if (row == 1 || row == 2) there = there && (col < 2 || col > 11);
    if (there)
    {
        float3 tone = col == 0 ? float3(0.95, 0.45, 0.4) : col == 1 ? float3(0.98, 0.7, 0.4) : col < 12 ? float3(0.98, 0.88, 0.5) : col == 17 ? float3(0.7, 0.6, 0.95) : col == 16 ? float3(0.55, 0.85, 0.95) : float3(0.6, 0.9, 0.6);
        float inner = room_band(f.x, 0.06, 0.94) * room_band(f.y, 0.06, 0.94);
        float mark = room_band(f.x, 0.25, 0.6) * room_band(f.y, 0.35, 0.65);
        c = lerp(float3(0.3, 0.3, 0.3), tone, inner);
        c = lerp(c, float3(0.15, 0.15, 0.15), mark * step(0.3, wood_hash(float3(id, 1.0))));
    }
    float2 l = (uv - float2(0.04 + 0.92 / 18.0 * 3.0, 0.05)) / float2(0.92 / 18.0 * 14.0, 0.17) * float2(14.0, 2.0);
    if (l.x >= 0.0 && l.x < 14.0 && l.y >= 0.0 && l.y < 2.0)
    {
        float2 f2 = frac(l);
        float inner = room_band(f2.x, 0.06, 0.94) * room_band(f2.y, 0.06, 0.94);
        c = lerp(float3(0.3, 0.3, 0.3), l.y > 1.0 ? float3(0.95, 0.75, 0.85) : float3(0.98, 0.75, 0.65), inner);
    }
    return c;
}

float4 poster_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    int design = (int)(i.color.a * 16.0);
    float3 c = design == 0 ? den_mars_poster(i.uv) : den_table_poster(i.uv);
    float ripple = wood_noise(float3(i.uv * 6.0, 1.0));
    float3 n = wood_bump(n0, i.world, ripple * 0.0006 * ROOM_METRE);
    return room_lit(i, n, room_linear(c), 0.35, 0.0, 1.0, 0.0);
}

// Lines of type as grey bars, rows tall, with ragged ends
float den_lines(float2 uv, float2 lo, float2 hi, float rows, float seed)
{
    float2 q = (uv - lo) / (hi - lo);
    if (q.x < 0.0 || q.x > 1.0 || q.y < 0.0 || q.y > 1.0) return 0.0;
    float r = floor(q.y * rows);
    float end = 0.55 + 0.45 * wood_hash(float3(r, seed, 3.0));
    float word = step(0.12, frac(q.x * 9.0 + wood_hash(float3(r, seed, 7.0)) * 3.0));
    return room_band(frac(q.y * rows), 0.25, 0.75) * step(q.x, end) * word;
}

// Printed paper, uv from its bottom left, the design in the alpha as a sixteenth: the magazine's
// cover, the floppy's label, the cover disc's sleeve, a printout, a photo, a printed chess diagram,
// a sticky note, a ticket
float4 paper_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    int design = (int)(i.color.a * 16.0);
    float2 uv = i.uv;
    float3 c = i.color.rgb;
    float gloss = 0.75;
    float seed = floor(i.world.x * 3.0 + i.world.y * 7.0 + i.world.z * 5.0);
    if (design == 2)
    {
        gloss = 0.35;
        c = float3(0.95, 0.94, 0.9);
        float3 sky = lerp(float3(0.1, 0.12, 0.3), float3(0.45, 0.2, 0.45), uv.y);
        c = lerp(c, sky, den_rect(uv, float2(0.0, 0.0), float2(1.0, 0.84)));
        float2 b = float2((uv.x - 0.5) / max(0.62 - uv.y, 0.05), 0.4 / max(0.62 - uv.y, 0.05));
        float check = fmod(floor(b.x * 2.0) + floor(b.y * 2.0), 2.0);
        c = lerp(c, check > 0.5 ? float3(0.85, 0.8, 0.7) : float3(0.15, 0.12, 0.1), step(uv.y, 0.4) * step(0.05, uv.y));
        float2 k = (uv - float2(0.52, 0.3)) / float2(0.3, 0.42);
        float knight = step(length(k - float2(0.0, 0.62)), 0.32) + den_rect(k, float2(-0.28, 0.0), float2(0.28, 0.6)) + step(length((k - float2(-0.3, 0.7)) * float2(1.0, 1.6)), 0.25);
        c = lerp(c, float3(0.9, 0.82, 0.3), saturate(knight) * 0.9);
        c = lerp(c, float3(0.85, 0.1, 0.1), den_rect(uv, float2(0.0, 0.84), float2(1.0, 1.0)));
        c = lerp(c, float3(1.0, 1.0, 1.0), den_bits(uv * float2(1.0, -1.0) - float2(0.08, -0.98), 0.033));
        c = lerp(c, float3(1.0, 1.0, 1.0), den_lines(uv, float2(0.06, 0.5), float2(0.4, 0.78), 6.0, 2.0));
        float2 s = (uv - float2(0.8, 0.68)) * float2(1.0, 0.75);
        float star = length(s) - 0.13 - 0.015 * sin(atan2(s.y, s.x) * 14.0);
        c = lerp(c, float3(1.0, 0.85, 0.1), 1.0 - smoothstep(0.0, 0.004, star));
        c = lerp(c, float3(0.8, 0.05, 0.05), den_free(uv * float2(1.0, -1.0) - float2(0.705, -0.715), 0.0075) * step(star, 0.0));
        c = lerp(c, float3(0.0, 0.0, 0.0), den_rect(uv, float2(0.75, 0.02), float2(0.95, 0.08)) * step(0.5, frac(uv.x * 140.0)));
    }
    else if (design == 3)
    {
        c = float3(0.95, 0.95, 0.92);
        c = lerp(c, float3(0.2, 0.35, 0.8), den_rect(uv, float2(0.0, 0.8), float2(1.0, 1.0)));
        c = lerp(c, float3(0.55, 0.6, 0.85), den_lines(uv, float2(0.05, 0.1), float2(0.95, 0.7), 4.0, 9.0) * 0.4);
        float2 h = uv * float2(26.0, 18.0);
        float pen = smoothstep(0.35, 0.0, abs(frac(h.y * 0.22) - 0.5 - 0.25 * sin(h.x * 1.7))) * step(0.08, uv.x) * step(uv.x, 0.7) * room_band(uv.y, 0.35, 0.62);
        c = lerp(c, float3(0.05, 0.05, 0.25), pen);
    }
    else if (design == 4)
    {
        c = float3(0.9, 0.9, 0.9);
        float2 d = uv - 0.5;
        c = lerp(c, float3(0.1, 0.45, 0.8), den_rect(uv, float2(0.0, 0.0), float2(1.0, 0.18)));
        c = lerp(c, float3(0.35, 0.35, 0.4), den_lines(uv, float2(0.08, 0.04), float2(0.9, 0.14), 2.0, 4.0));
        float window = 1.0 - smoothstep(0.32, 0.325, length(d));
        c = lerp(c, float3(0.8, 0.85, 0.9), window * 0.5);
    }
    else if (design == 5)
    {
        c = float3(0.96, 0.96, 0.94);
        c = lerp(c, float3(0.15, 0.15, 0.15), den_lines(uv, float2(0.1, 0.08), float2(0.9, 0.82), 22.0, seed) * 0.8);
        c = lerp(c, float3(0.1, 0.1, 0.1), den_rect(uv, float2(0.1, 0.87), float2(0.6, 0.92)));
    }
    else if (design == 6)
    {
        gloss = 0.3;
        c = float3(0.95, 0.95, 0.93);
        float2 q = (uv - 0.06) / 0.88;
        if (q.x > 0.0 && q.x < 1.0 && q.y > 0.0 && q.y < 1.0)
        {
            float3 sky = lerp(float3(0.9, 0.7, 0.45), float3(0.3, 0.5, 0.85), q.y);
            float hill = 0.4 + 0.1 * sin(q.x * 5.0 + seed);
            c = q.y < hill ? lerp(float3(0.15, 0.35, 0.12), float3(0.3, 0.5, 0.2), q.y / hill) : sky;
            c = lerp(c, float3(1.0, 0.9, 0.6), 1.0 - smoothstep(0.06, 0.08, length(q - float2(0.7, 0.75))));
            float body = step(length((q - float2(0.35, 0.45)) * float2(1.6, 1.0)), 0.18) + step(length(q - float2(0.35, 0.68)), 0.07);
            c = lerp(c, float3(0.25, 0.15, 0.2), saturate(body) * step(0.5, frac(seed * 0.37)));
        }
    }
    else if (design == 7)
    {
        c = float3(0.97, 0.97, 0.95);
        c = lerp(c, float3(0.1, 0.1, 0.1), den_rect(uv, float2(0.12, 0.88), float2(0.7, 0.93)));
        float2 q = (uv - float2(0.12, 0.2)) / 0.76 * float2(8.0, 8.0 * 0.76 / 0.62);
        if (q.x > 0.0 && q.x < 8.0 && q.y > 0.0 && q.y < 8.0)
        {
            float2 id = floor(q);
            float dark = fmod(id.x + id.y, 2.0);
            c = lerp(float3(0.95, 0.95, 0.93), float3(0.62, 0.62, 0.6), dark);
            float h = wood_hash(float3(id, 5.0));
            float man = step(length(frac(q) - 0.5), 0.28) * step(0.72, h);
            c = lerp(c, h > 0.86 ? float3(0.05, 0.05, 0.05) : float3(1.0, 1.0, 1.0), man);
            c = lerp(c, float3(0.05, 0.05, 0.05), man * (1.0 - step(length(frac(q) - 0.5), 0.22)));
        }
        c = lerp(c, float3(0.2, 0.2, 0.2), den_lines(uv, float2(0.12, 0.05), float2(0.88, 0.15), 3.0, 7.0));
    }
    else if (design == 8)
    {
        float2 h = uv * float2(20.0, 5.0);
        float pen = smoothstep(0.12, 0.0, abs(frac(h.y) - 0.5 - 0.22 * sin(h.x * 2.3 + floor(h.y) * 1.7))) * room_band(uv.x, 0.12, 0.88) * room_band(uv.y, 0.2, 0.85);
        c = lerp(c, float3(0.05, 0.08, 0.35), pen * step(0.3, frac(h.x * 0.37 + floor(h.y) * 0.21)));
    }
    else if (design == 9)
    {
        c = float3(0.95, 0.85, 0.55);
        c = lerp(c, float3(0.75, 0.2, 0.15), den_rect(uv, float2(0.0, 0.0), float2(0.28, 1.0)));
        c = lerp(c, float3(0.3, 0.2, 0.1), den_lines(uv, float2(0.35, 0.2), float2(0.95, 0.8), 3.0, seed));
        c = lerp(c, float3(0.6, 0.5, 0.3), step(length(float2(frac(uv.y * 10.0) - 0.5, (uv.x - 0.3) * 30.0)), 0.25));
    }
    return room_lit(i, n0, room_linear(c), gloss, 0.0, 1.0, 0.0);
}

// A spectrum hue at h from red to violet
float3 den_rainbow(float h)
{
    return saturate(float3(1.5 - abs(h * 4.0 - 1.0) * 1.5, 1.5 - abs(h * 4.0 - 2.0) * 1.5, 1.5 - abs(h * 4.0 - 3.0) * 1.5));
}

// A disc lying shiny side up: the clear hub, the silver of its data split into rainbows round
// every light by the fine track, and the hole through its middle. Values: its middle in metres.
float4 disc_ps(WoodOut i) : SV_Target0
{
    float3 p = i.world / ROOM_METRE;
    float2 d = p.xz - material[0].xz;
    float r = length(d);
    if (r < 0.0075) discard;
    float3 n = normalize(i.normal);
    float3 v = normalize(three_eye() - i.world);
    float hub = 1.0 - smoothstep(0.0225, 0.0235, r);
    float3 base = lerp(float3(0.75, 0.76, 0.78), float3(0.35, 0.36, 0.38), hub);
    if (n.y < 0.5) base = float3(0.6, 0.6, 0.62);
    float4 lit = room_lit(i, n, base, lerp(0.12, 0.3, hub), 1.0 - hub * 0.7, 1.0, 0.0);
    float3 along = normalize(float3(-d.y, 0.0, d.x));
    float3 rainbow = 0.0;
    for (int k = 0; k < lamp_count(); k++)
    {
        float3 l;
        float3 e = lamp_light(k, i.world, i.shadow0, i.shadow1, i.shadow2, l) * saturate(dot(n, l));
        float3 h = normalize(l + v);
        float s = abs(dot(h, along));
        rainbow += e * den_rainbow(frac(s * 2.2)) * smoothstep(0.75, 0.98, dot(h, n)) * 0.6;
    }
    float3 rv = reflect(-v, n);
    rainbow += wood_room(rv, 0.2) * den_rainbow(frac(abs(dot(normalize(rv + v), along)) * 2.2)) * 0.5;
    return float4(lit.rgb + rainbow * (1.0 - hub) * step(0.5, n.y), i.depth);
}

// The lava lamp's bottle: wax rising and falling through glowing liquid, followed a little way into
// the glass along the eye's ray, the wax pooled at the bottom, then the glass's own shine. Values:
// the time and the lamp's foot in metres, then how bright.
float den_lava_field(float3 q, float t)
{
    float f = exp(-(q.y - 0.135) * 70.0) * 1.3;
    for (int b = 0; b < 5; b++)
    {
        float speed = 0.09 + b * 0.031;
        float y = 0.16 + 0.2 * (0.5 + 0.5 * sin(t * speed + b * 1.7));
        float3 c = float3(0.012 * sin(t * 0.3 + b * 2.0), y, 0.012 * cos(t * 0.37 + b));
        float r = 0.013 + 0.007 * frac(b * 0.618);
        float3 e = q - c;
        e.y *= 0.8;
        f += r * r / max(dot(e, e), 1e-6);
    }
    return f;
}

float4 lava_ps(WoodOut i) : SV_Target0
{
    float t = material[0].x;
    float3 p = i.world / ROOM_METRE - material[0].yzw;
    float3 v = normalize(three_eye() - i.world);
    float3 n = normalize(i.normal);
    float3 rd = -v;
    float3 q = p;
    float hit = 0.0;
    for (int k = 0; k < 12; k++)
    {
        q += rd * 0.008;
        if (den_lava_field(q, t) > 1.0)
        {
            hit = 1.0;
            break;
        }
    }
    float h = saturate((q.y - 0.13) / 0.27);
    float3 liquid = float3(0.9, 0.1, 0.3) * (0.15 + 0.55 * (1.0 - h));
    float3 wax = float3(1.0, 0.4, 0.07) * (1.4 - 0.7 * h) * (0.75 + 0.25 * saturate(dot(n, v)));
    float3 c = lerp(liquid, wax, hit) * material[1].x;
    float4 lit = room_lit_but(i, n, float3(0.01, 0.01, 0.01), 0.05, 0.0, 1.0, 0.0, 3);
    return float4(c + lit.rgb, i.depth);
}

// A small light's lens, its colour in rgb, the drive light flickering as it reads when its alpha is
// low. Values: the time.
float4 led_ps(WoodOut i) : SV_Target0
{
    float3 c = room_linear(i.color.rgb) * 6.0;
    if (i.color.a < 0.5)
    {
        float on = step(0.6, wood_hash(float3(floor(material[0].x * 11.0), 1.0, 2.0)));
        c *= 0.05 + on;
    }
    return float4(c, i.depth);
}

// The little TV on a dead channel: snow, its scanlines, the edges darker, and its glass's shine.
// Values: the time, then how bright.
float4 tv_ps(WoodOut i) : SV_Target0
{
    float3 n = normalize(i.normal);
    float2 uv = i.uv;
    float2 px = floor(uv * float2(220.0, 160.0));
    float frame = floor(material[0].x * 30.0);
    float s = wood_hash(float3(px, frame));
    s = s * s;
    float roll = 0.85 + 0.15 * sin(uv.y * 9.0 + material[0].x * 3.0);
    float2 c = uv * 2.0 - 1.0;
    float3 snow = s * roll * float3(0.85, 0.9, 1.0) * (1.0 - 0.35 * dot(c, c)) * material[1].x;
    float4 lit = room_lit(i, n, float3(0.02, 0.022, 0.02), 0.06, 0.0, 1.0, 0.0);
    return float4(snow + lit.rgb, i.depth);
}

// Cork, pressed granules in warm browns
float4 cork_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    float g = wood_noise(p * 420.0);
    float g2 = wood_noise(p * 150.0 + 4.0);
    float3 c = lerp(float3(0.42, 0.26, 0.13), float3(0.72, 0.52, 0.3), g * 0.7 + g2 * 0.3);
    c *= 0.85 + 0.3 * step(0.8, wood_noise(p * 900.0));
    float3 n = wood_bump(n0, i.world, (g - 0.5) * 0.0008 * ROOM_METRE);
    return room_lit(i, n, c, 0.95, 0.0, 1.0, 0.0);
}

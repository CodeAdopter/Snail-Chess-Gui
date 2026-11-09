// What stands on the table beside the 3D board, lit as the board is: the players' folded cards,
// printed from a texture the GUI draws, and the chess clock, a lacquered wooden case with a
// reflective display for each side under glass.

#include "wood3d.hlsl"

float3 card_stuff(WoodOut i, float3 c);

// A folded card, its printed face read from the material's texture at uv and its inside, whose uv
// is below 0, plain card of the colour in the first value. Values: the inside's colour, then x
// the card's stuff, 0 paper, 1 slate and 2 kraft, y its roughness and z its sheen.
float4 card_ps(WoodOut i) : SV_Target0
{
    float3 c = three_srgb_to_linear(material[0].rgb);
    if (i.uv.x >= 0.0) c = three_srgb_to_linear(material_texture.Sample(material_sampler, i.uv).rgb);
    c = card_stuff(i, c);
    return wood_lit(i, normalize(i.normal), c, material[1].y, material[1].z, 0.45, 1.0, 1.0);
}

// The clock's case or a button, wood whose log runs along the case, its tint the early wood. Values
// as a piece's: x roughness, y rings to a square, z how strongly the grain shows, w how deep the
// grain sits, then the lacquer's weight and roughness.
float4 case_ps(WoodOut i) : SV_Target0
{
    float3 p = i.local;
    float seed = wood_hash(float3(i.color.a * 53.0, 0.71, 2.9));
    float3 q = float3(p.z * 0.8 + seed * 11.0, p.x - 1.9 - seed * 0.4, p.y + 0.7);
    Wood w = wood_at(q, i.color.rgb, material[0].y, material[0].z);
    float3 n = wood_bump(normalize(i.normal), i.world, -w.low * material[0].w);
    return wood_lit(i, n, w.color, material[0].x + w.rough, material[1].x, material[1].y, 1.0, 1.0);
}

// A bar of a digit from a to b, its ends pointed, t half its width: how far p lies outside it.
float lcd_bar(float2 p, float2 a, float2 b, float t)
{
    float2 d = b - a;
    float len = length(d);
    float2 u = d / len;
    float2 q = p - (a + b) * 0.5;
    float along = abs(dot(q, u));
    float across = abs(dot(q, float2(-u.y, u.x)));
    return max(across - t, along + across - len * 0.5 + 0.015);
}

// Which of a digit's seven bars show, top, top right, bottom right, bottom, bottom left, top left
// and middle as bits 0 to 6, for the codes 0 to 9, then colon, point, nothing and a dash.
static const uint LcdBars[14] = { 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0, 0, 0, 0x40 };

float lcd_code(int k)
{
    float4 m = material[k / 4];
    int c = k % 4;
    return c == 0 ? m.x : c == 1 ? m.y : c == 2 ? m.z : m.w;
}

float lcd_advance(float code)
{
    if (code == 10.0) return 0.3;
    if (code == 11.0) return 0.24;
    return 0.68;
}

// One side's display, a grey green reflective LCD with its digits dark, slanted a little, their
// unlit bars faint, right aligned with a margin. uv runs along it from 0 to 1 and down it. Values:
// eight character codes across the first two, then x how many, y how wide the display is for its
// height, z whether it is on and w 1 for a backlit display whose digits glow.

float4 lcd_ps(WoodOut i) : SV_Target0
{
    int count = (int)material[2].x;
    float aspect = material[2].y;
    float on = material[2].z;
    float width = 0.0;
    for (int k = 0; k < count; k++) width += lcd_advance(lcd_code(k));
    float margin = 0.14;
    float tall = min(0.62, (aspect - margin * 2.0) / max(width, 0.001));
    float2 w = float2(i.uv.x * aspect, 1.0 - i.uv.y);
    float2 p = float2((w.x - (aspect - margin - width * tall)) / tall, (w.y - 0.5) / tall + 0.5);
    p.x -= (p.y - 0.5) * 0.1;
    float lit = 1.0e3;
    float ghost = 1.0e3;
    float at = 0.0;
    for (int j = 0; j < count; j++)
    {
        float code = lcd_code(j);
        float adv = lcd_advance(code);
        if (p.x >= at - 0.05 && p.x < at + adv + 0.05)
        {
            float2 q = float2(p.x - at, p.y);
            if (code == 10.0)
            {
                float dots = min(length(q - float2(0.15, 0.3)), length(q - float2(0.15, 0.7))) - 0.065;
                lit = min(lit, dots);
            }
            else if (code == 11.0) lit = min(lit, length(q - float2(0.12, 0.07)) - 0.065);
            else if (code != 12.0)
            {
                uint bars = LcdBars[(int)code];
                float2 c[6] = { float2(0.08, 0.93), float2(0.5, 0.93), float2(0.5, 0.5), float2(0.5, 0.07), float2(0.08, 0.07), float2(0.08, 0.5) };
                float d[7];
                d[0] = lcd_bar(q, c[0], c[1], 0.065);
                d[1] = lcd_bar(q, c[1], c[2], 0.065);
                d[2] = lcd_bar(q, c[2], c[3], 0.065);
                d[3] = lcd_bar(q, c[3], c[4], 0.065);
                d[4] = lcd_bar(q, c[4], c[5], 0.065);
                d[5] = lcd_bar(q, c[5], c[0], 0.065);
                d[6] = lcd_bar(q, c[5], c[2], 0.065);
                for (int b = 0; b < 7; b++)
                {
                    ghost = min(ghost, d[b]);
                    if ((bars >> b) & 1) lit = min(lit, d[b]);
                }
            }
        }
        at += adv;
    }
    float aa = fwidth(p.y) * 0.8 + 0.002;
    float edge = min(min(i.uv.x, 1.0 - i.uv.x) * aspect, min(i.uv.y, 1.0 - i.uv.y));
    float frame = lerp(0.55, 1.0, smoothstep(0.0, 0.05, edge));
    if (material[2].w > 0.5)
    {
        // a backlit display, dark glass with its digits glowing a cool white
        float3 dim = three_srgb_to_linear(float3(0.05, 0.06, 0.08)) * frame;
        float4 o = wood_lit(i, normalize(i.normal), dim, 0.6, 1.0, 0.03, 1.0, 1.0);
        float3 glow = three_srgb_to_linear(float3(0.72, 0.84, 1.0)) * 1.4;
        o.rgb += glow * (smoothstep(aa, -aa, lit) + smoothstep(aa, -aa, ghost) * 0.04) * on * frame;
        return o;
    }
    float3 back = three_srgb_to_linear(float3(0.6, 0.64, 0.56)) * lerp(0.55, 1.0, on);
    float3 ink = three_srgb_to_linear(float3(0.07, 0.08, 0.07));
    float3 c = back;
    c = lerp(c, back * 0.86, smoothstep(aa, -aa, ghost) * on);
    c = lerp(c, ink, smoothstep(aa, -aa, lit) * on);
    c *= frame;
    return wood_lit(i, normalize(i.normal), c, 0.7, 0.85, 0.04, 1.0, 1.0);
}

// Black plastic, its tint its colour, with a fine grain moulded into it. Values: x roughness, y the
// weight of its sheen and z the sheen's roughness.
float4 plastic_ps(WoodOut i) : SV_Target0
{
    float3 p = i.local * 300.0;
    float fine = saturate(1.5 - length(fwidth(p)) * 0.7);
    float grain = (wood_noise(p) - 0.5) * fine;
    float3 c = i.color.rgb * (1.0 + grain * 0.12);
    float3 n = wood_bump(normalize(i.normal), i.world, grain * 0.0002);
    return wood_lit(i, n, c, material[0].x, material[0].y, material[0].z, 1.0, 1.0);
}

// How far p lies from the stroke a to b
float dial_seg(float2 p, float2 a, float2 b)
{
    float2 pa = p - a;
    float2 ba = b - a;
    return length(pa - ba * saturate(dot(pa, ba) / dot(ba, ba)));
}

// The Roman hours as their letters, two bits each from the first, 1 an I, 2 a V and 3 an X, for I
// to XII, four as IIII the way clockmakers write it
static const uint DialNumerals[12] = { 1, 5, 21, 85, 2, 6, 22, 86, 13, 3, 7, 23 };

float dial_width(uint k)
{
    return k == 1 ? 0.22 : 0.62;
}

// How far p, in a letter's own space a unit tall from its foot, lies outside letter k, w wide, its
// strokes thick and thin as a serif face cuts them, with a serif along its top and its foot
float dial_letter(float2 p, uint k, float w)
{
    float thick = 0.1;
    float thin = 0.045;
    float d;
    if (k == 1) d = dial_seg(p, float2(w * 0.5, 0.0), float2(w * 0.5, 1.0)) - thick;
    else if (k == 2) d = min(dial_seg(p, float2(0.0, 1.0), float2(w * 0.5, 0.0)) - thick, dial_seg(p, float2(w, 1.0), float2(w * 0.5, 0.0)) - thin);
    else d = min(dial_seg(p, float2(0.0, 1.0), float2(w, 0.0)) - thick, dial_seg(p, float2(0.0, 0.0), float2(w, 1.0)) - thin);
    d = min(d, dial_seg(p, float2(-0.06, 1.0), float2(w + 0.06, 1.0)) - 0.03);
    return min(d, dial_seg(p, float2(-0.06, 0.0), float2(w + 0.06, 0.0)) - 0.03);
}

// How far p on the dial lies outside the hour figure nearest it, each set round the dial with its
// top toward the rim
float dial_hours(float2 p)
{
    float turn = atan2(p.x, p.y);
    int h = (int)round(turn / 0.5236);
    if (h <= 0) h += 12;
    float a = h * 0.5236;
    float2 up = float2(sin(a), cos(a));
    float2 right = float2(cos(a), -sin(a));
    float tall = 0.16;
    uint code = DialNumerals[h - 1];
    float wide = 0.0;
    for (int k = 0; k < 4; k++)
    {
        uint letter = (code >> (k * 2)) & 3;
        if (letter == 0) break;
        wide += dial_width(letter) + (k > 0 ? 0.06 : 0.0);
    }
    float2 c = up * 0.68;
    float2 q = float2(dot(p - c, right), dot(p - c, up)) / tall + float2(wide * 0.5, 0.5);
    float d = 1.0e3;
    float at = 0.0;
    for (int j = 0; j < 4; j++)
    {
        uint letter = (code >> (j * 2)) & 3;
        if (letter == 0) break;
        float w = dial_width(letter);
        d = min(d, dial_letter(q - float2(at, 0.0), letter, w));
        at += w + 0.06;
    }
    return d * tall;
}

// How far p lies outside a hand at angle a from twelve, reaching so far and tapering from wide to narrow, with
// a short tail behind the middle
float dial_hand(float2 p, float a, float reach, float wide, float narrow)
{
    float2 way = float2(sin(a), cos(a));
    float t = dot(p, way);
    float s = abs(dot(p, float2(way.y, -way.x)));
    return max(s - lerp(wide, narrow, saturate(t / reach)), max(-t - 0.1, t - reach));
}

// The red flag on its pin beside twelve, a thin arm with a wider blade at its end, hanging down
// until the minute hand lifts it toward twelve as lift says
float dial_flag(float2 p, float lift)
{
    float2 pin = float2(0.13, 0.5);
    float2 way = normalize(float2(lerp(-0.25, -0.75, lift), lerp(-0.97, 0.66, lift)));
    return min(dial_seg(p, pin, pin + way * 0.22) - 0.014, dial_seg(p, pin + way * 0.12, pin + way * 0.21) - 0.04);
}

// One of the analog clock's dials, uv across it from -1 to 1 under glass: a cream enamel face with
// Roman hours and a minute track, blued hands throwing a soft shadow on it, the red flag the minute
// hand lifts as the hour runs out, which falls at twelve, a brass cap and a brass bezel. Values:
// the hour hand's angle from twelve, the minute hand's and how far the flag is lifted.
float4 dial_ps(WoodOut i) : SV_Target0
{
    float2 p = i.uv;
    float r = length(p);
    float aa = fwidth(r) * 1.2 + 0.002;
    float3 face = three_srgb_to_linear(float3(0.93, 0.9, 0.82));
    float3 ink = three_srgb_to_linear(float3(0.08, 0.07, 0.06));
    float3 c = face * (1.0 - 0.12 * smoothstep(0.6, 0.93, r));
    c = lerp(c, ink, smoothstep(aa, -aa, dial_hours(p)));
    float turn = atan2(p.x, p.y);
    float minute = abs(frac(turn / 6.2832 * 60.0 + 0.5) - 0.5) * 6.2832 / 60.0 * r;
    float five = abs(frac(turn / 6.2832 * 12.0 + 0.5) - 0.5) * 6.2832 / 12.0 * r;
    float track = max(abs(r - 0.865) - 0.025, min(minute - 0.005, five - 0.012));
    track = min(track, abs(r - 0.84) - 0.003);
    track = min(track, abs(r - 0.89) - 0.003);
    c = lerp(c, ink, smoothstep(aa, -aa, track));
    float lift = material[0].z;
    float hands = min(dial_hand(p, material[0].x, 0.46, 0.05, 0.022), dial_hand(p, material[0].y, 0.78, 0.034, 0.012));
    float2 off = float2(0.025, -0.035);
    float shade = min(min(dial_hand(p - off, material[0].x, 0.46, 0.05, 0.022), dial_hand(p - off, material[0].y, 0.78, 0.034, 0.012)), dial_flag(p - off, lift));
    c *= 1.0 - 0.35 * smoothstep(0.03, -0.01, shade);
    c = lerp(c, three_srgb_to_linear(float3(0.72, 0.06, 0.04)), smoothstep(aa, -aa, dial_flag(p, lift)));
    c = lerp(c, three_srgb_to_linear(float3(0.06, 0.08, 0.16)), smoothstep(aa, -aa, hands));
    float3 brass = three_srgb_to_linear(float3(0.78, 0.6, 0.3));
    float cap = min(r - 0.045, length(p - float2(0.13, 0.5)) - 0.025);
    c = lerp(c, brass * (0.8 + 0.4 * p.y), smoothstep(aa, -aa, cap));
    float bezel = smoothstep(0.925 - aa, 0.925 + aa, r);
    c = lerp(c, brass * (0.55 + 0.6 * saturate(0.5 + 0.5 * dot(normalize(p + 0.0001), float2(-0.5, 0.86)))), bezel);
    return wood_lit(i, normalize(i.normal), c, lerp(0.5, 0.25, bezel), 0.9, 0.02, 1.0, 1.0);
}

// A folded card's own stuff under its print, as the card's style asks: smooth paper with a faint
// sheen, matt slate with a fine speckle, or kraft paper with its fibres
float3 card_stuff(WoodOut i, float3 c)
{
    float kind = material[1].x;
    float3 p = i.local * 260.0;
    float fine = saturate(1.5 - length(fwidth(p)) * 0.7);
    if (kind > 1.5)
    {
        float fibre = wood_noise(float3(p.x * 0.25, p.y * 2.5, p.z * 0.25)) - 0.5;
        return c * (1.0 + (fibre * 0.18 + (wood_noise(p * 0.5) - 0.5) * 0.1) * fine);
    }
    if (kind > 0.5) return c * (1.0 + (wood_noise(p * 1.5) - 0.5) * 0.25 * fine);
    return c;
}

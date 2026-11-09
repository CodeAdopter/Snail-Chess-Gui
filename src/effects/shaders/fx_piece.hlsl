// A piece on the flat board as what it has been through leaves it, read from its own image in the
// sheet so each effect follows its shape: moss gathered from its foot up and on what faces up,
// fuzzy past its outline, soot and glowing cracks where it burns, a band of light passing over it
// once it moved, or, taken, burning away from its edges in a glowing line. Values: the moss from 0
// to 1, or below 0 how far it has burnt away, how hot it burns, the glint's share of its pass
// (none at or below 0), and seconds of the burning clock.

#include "C:/Snail/Snail Engine/engine/shaders/ui_material.hlsli"

// How much of the piece covers point c of its square
float piece_mask(UiPixel q, float2 c)
{
    if (any(c < 0.0) || any(c > 1.0)) return 0.0;
    return atlas.SampleLevel(atlas_linear, lerp(q.s.geo.xy, q.s.geo.zw, c), 0).a;
}

float piece_hash(float2 p)
{
    return frac(sin(dot(p, float2(41.3, 289.1))) * 43758.5453);
}

float4 piece_fx(UiPixel q)
{
    float2 c = q.uv;
    float4 o = q.color;
    float seed = piece_hash(floor(q.s.rect.xy / max(q.s.rect.zw, 1.0)));
    float t = q.values.w;
    float a0 = o.a;
    // the piece's cover blurred round the point, for its edges and the fuzz past them
    float r = 0.03;
    float blur = 0.0;
    [unroll] for (int k = 0; k < 8; k++)
    {
        float ang = k * 0.7854;
        blur += piece_mask(q, c + float2(cos(ang), sin(ang)) * r);
    }
    blur /= 8.0;
    float cover = ui_cover(q.d, q.px);
    if (q.values.x < 0.0)
    {
        // burning away from its edges, the line where it goes glowing and the wood beside it charred
        float cut = saturate(-q.values.x);
        float n = ui_fbm(c * 9.0 + seed * 13.0);
        float d = blur * 0.55 + n * 0.45 + (1.0 - c.y) * 0.08;
        float left = cut * 1.1 - 0.05;
        float alive = smoothstep(left, left + 0.02, d);
        float rim = smoothstep(left + 0.11, left + 0.02, d) * alive;
        float3 hot = lerp(float3(1.0, 0.35, 0.05), float3(1.0, 0.9, 0.55), smoothstep(left + 0.06, left + 0.01, d));
        float4 burnt = float4(o.rgb * alive * (1.0 - rim * 0.7), a0 * alive);
        burnt.rgb += hot * rim * a0 * 1.2;
        return burnt * cover;
    }
    float moss = saturate(q.values.x);
    if (moss > 0.0)
    {
        // moss climbs from the foot and settles on what faces up, the outline above the point clear
        float above = piece_mask(q, c - float2(0.0, 0.04));
        float faces_up = saturate(max(a0, blur) - above);
        float foot = smoothstep(0.5, 0.92, c.y);
        float n = ui_fbm(c * 13.0 + seed * 7.0);
        float fine = ui_value_noise(c * 70.0 + seed * 3.0);
        float lay = foot * 0.95 + faces_up * 0.75 + n * 0.3 + fine * 0.12;
        float grow = smoothstep(1.32 - moss * 1.15, 1.42 - moss * 1.15, lay);
        float tuft = ui_value_noise(c * 150.0 + seed);
        float3 deep = float3(0.1, 0.2, 0.05);
        float3 bright = float3(0.4, 0.56, 0.14);
        float3 green = lerp(deep, bright, saturate(fine * 0.8 + faces_up * 0.5 + tuft * 0.35));
        green = lerp(green, float3(0.62, 0.66, 0.24), step(0.93, tuft) * 0.6);
        green *= 0.8 + 0.3 * (1.0 - c.y) - step(0.9, piece_hash(floor(c * 90.0) + seed)) * 0.35;
        // on the piece the moss lies over its colour, past its outline it frays into fuzz
        float on = grow * a0;
        float fuzz = grow * smoothstep(0.08, 0.5, blur) * (1.0 - a0) * smoothstep(0.35, 0.7, tuft) * (0.5 + 0.5 * foot);
        o.rgb = lerp(o.rgb, green * a0, on);
        o.rgb += green * fuzz;
        o.a = saturate(a0 + fuzz);
    }
    float heat = saturate(q.values.y);
    if (heat > 0.0)
    {
        // soot creeping up from the foot, charring the piece, and cracks glowing through it that breathe
        float n = ui_fbm(c * 8.0 + seed * 5.0);
        float soot = smoothstep(0.15, 0.95, c.y + n * 0.45) * saturate(heat * 1.4);
        o.rgb = lerp(o.rgb, float3(0.09, 0.06, 0.045) * a0, soot * 0.82);
        float vein = 1.0 - abs(ui_fbm(c * 10.0 + float2(seed, t * 0.12)) * 2.0 - 1.0);
        float breathe = 0.6 + 0.4 * sin(t * 3.5 + n * 9.0);
        float ember = pow(saturate(vein), 16.0) * smoothstep(0.3, 0.75, soot) * 2.0 * breathe;
        o.rgb += lerp(float3(0.9, 0.18, 0.02), float3(1.0, 0.62, 0.15), saturate(ember)) * ember * a0;
    }
    float glint = q.values.z;
    if (glint > 0.0)
    {
        float at = saturate(glint) * 1.8 - 0.4;
        float along = (c.x + 1.0 - c.y) * 0.5;
        float band = exp(-pow((along - at) / 0.09, 2.0));
        o.rgb = lerp(o.rgb, float3(1.0, 0.82, 0.38) * o.a, band * 0.7);
    }
    return o * cover;
}

UI_MATERIAL(piece_fx)

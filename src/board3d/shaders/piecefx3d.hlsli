// What the effects do to a piece on the 3D board, shared by every set: the field holds one entry
// for each piece something shows on, found by where the piece stands, the instance's origin, with
// its moss, how charred it is, its glint and how far it has burnt away, and the colour of its fire.
// A piece shader finds its entry first, which drops what has burnt away, and lays the rest over its
// own lit colour last: moss lit as moss, soot lit as soot, glowing cracks, the glint and the
// glowing line where it burns away. The moss shells in fx3d read the same cover, so the fuzz
// stands just where the moss lies.

#ifndef PIECEFX3D_HLSLI
#define PIECEFX3D_HLSLI

struct PieceFx
{
    bool found;
    float moss;
    float charred;
    float glint;
    float cut;
    float flame;
    float3 hue;
    float seed;
};

// The entry of the piece standing at the instance's origin, mirrored back for a mirrored piece
PieceFx piece_fx_find(WoodOut i)
{
    PieceFx f = (PieceFx)0;
    float3 origin = i.seed;
    if (i.flip > 0.5) origin.y = -origin.y;
    for (int k = 0; k < (int)field_counts.z; k++)
    {
        float4 s = field_spots[k];
        if (dot(s.xyz - origin, s.xyz - origin) < 0.0004)
        {
            float4 w = field_wear[k];
            f.found = true;
            f.moss = s.w;
            f.charred = w.x;
            f.glint = w.y;
            f.cut = w.z;
            f.flame = w.w;
            f.hue = field_hues[k].rgb;
        }
    }
    // seeded by where it stands, as the moss shells' tints hold their height, not the piece's grain
    f.seed = wood_hash(float3(origin.x * 3.1, origin.z * 1.7, 2.9));
    return f;
}

// How far the point is from burning away, 0 at the head where it goes first
float piece_fx_burn(float3 p, float seed)
{
    return wood_fbm(p * 6.0 + seed * 9.0) * 0.6 + (1.0 - saturate(p.y / 1.7)) * 0.4;
}

// The entry of the piece at the pixel, the part of it burnt away dropped
PieceFx piece_fx(WoodOut i)
{
    PieceFx f = piece_fx_find(i);
    if (f.cut > 0.0) clip(piece_fx_burn(i.local, f.seed) - f.cut * 1.05 + 0.02);
    return f;
}

// How much moss covers point p of a piece facing n, amount from 0 to 1: it climbs from the foot,
// higher on what faces up, in patches
float moss_cover(float3 p, float3 n, float amount, float seed)
{
    if (amount <= 0.0) return 0.0;
    float up = saturate(n.y);
    float big = wood_fbm(p * 7.0 + seed * 11.0);
    float fine = wood_noise(p * 45.0 + seed * 3.0);
    float lay = (amount * 0.8 - p.y) / 0.22 + up * amount * 1.3 + (big - 0.5) * 1.8 + (fine - 0.5) * 0.5;
    return smoothstep(0.0, 0.3, lay) * smoothstep(0.0, 0.1, amount);
}

// Moss's colour at p, deep green in its hollows, yellower at its tips
float3 moss_colour(float3 p, float seed, float tip)
{
    float n = wood_noise(p * 60.0 + seed * 5.0);
    float3 deep = three_srgb_to_linear(float3(0.07, 0.12, 0.03));
    float3 bright = three_srgb_to_linear(float3(0.25, 0.33, 0.08));
    float3 c = lerp(deep, bright, saturate(n * 0.7 + tip * 0.6));
    return lerp(c, three_srgb_to_linear(float3(0.4, 0.42, 0.13)), step(0.88, n) * tip * 0.5);
}

// The colour fire glows with at heat h from 0 to 1, from the hue's own colour to a white core
float3 piece_fx_heat(float3 hue, float h)
{
    float3 deep = hue * float3(0.55, 0.25, 0.2);
    float3 c = lerp(deep, hue, smoothstep(0.0, 0.5, h));
    return lerp(c, float3(1.0, 0.85, 0.55), smoothstep(0.8, 1.0, h));
}

// The piece's lit colour o with what its entry shows laid over it
float4 piece_fx_over(WoodOut i, PieceFx f, float4 o)
{
    if (!f.found) return o;
    float3 p = i.local;
    float3 n = normalize(i.normal);
    float t = field_counts.w;
    if (f.moss > 0.0)
    {
        float cover = moss_cover(p, n, f.moss, f.seed);
        if (cover > 0.0)
        {
            float3 bump = normalize(n + (float3(wood_noise(p * 90.0), wood_noise(p * 90.0 + 3.1), wood_noise(p * 90.0 + 6.7)) - 0.5) * 0.9);
            float4 m = wood_lit(i, bump, moss_colour(p, f.seed, 0.0), 0.95, 0.0, 0.6, 0.55 + 0.45 * saturate(n.y), 1.0);
            o.rgb = lerp(o.rgb, m.rgb, cover);
            if (i.flip > 0.5) o.a = lerp(o.a, 1.0, cover);
        }
    }
    if (f.charred > 0.0)
    {
        // soot from the foot up, and cracks glowing through it that breathe
        float nz = wood_fbm(p * 8.0 + f.seed * 5.0);
        float soot = smoothstep(0.85, 0.0, p.y + (nz - 0.5) * 0.5) * saturate(f.charred * 1.4);
        float4 ch = wood_lit(i, n, float3(0.025, 0.02, 0.016), 0.85, 0.0, 0.5, 1.0, 1.0);
        o.rgb = lerp(o.rgb, ch.rgb, soot * 0.85);
        float vein = 1.0 - abs(wood_fbm(p * 14.0 + float3(f.seed, t * 0.1, 0.0)) * 2.0 - 1.0);
        float breathe = 0.6 + 0.4 * sin(t * 3.5 + nz * 9.0);
        float ember = pow(saturate(vein), 14.0) * smoothstep(0.3, 0.75, soot) * breathe * 3.0;
        o.rgb += piece_fx_heat(f.hue, saturate(ember)) * ember;
    }
    if (f.glint > 0.0)
    {
        // a band of light running up the piece once
        float at = f.glint * 2.2 - 0.3;
        float band = exp(-pow((p.y - at) / 0.12, 2.0));
        o.rgb += float3(1.0, 0.82, 0.45) * band * 0.9;
    }
    if (f.cut > 0.0)
    {
        float d = piece_fx_burn(p, f.seed) - (f.cut * 1.05 - 0.02);
        float rim = smoothstep(0.1, 0.0, d);
        o.rgb = lerp(o.rgb, float3(0.02, 0.015, 0.01), smoothstep(0.16, 0.04, d) * 0.8);
        o.rgb += piece_fx_heat(float3(1.0, 0.42, 0.06), rim) * rim * 2.5;
    }
    return o;
}

#endif

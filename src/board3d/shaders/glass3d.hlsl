// Glass for the 3D board and its pieces. A piece is solid crystal: what lies behind it, drawn
// before it and kept in the extra image, is seen bent through its body, the way into it and out of
// its far side worked out as a column round its axis as wide as its surface lies from it, darkened
// by its tint along the way, blurred where it is frosted, and the room and the board mirrored in
// its face. The board is a plate of glass over a dark mirror, its light squares etched frosted.

#include "pieces3d.hlsli"

// How the scene is seen, for a piece to find where on screen what lies behind it shows
cbuffer GlassView : register(b3, space3)
{
    float4x4 glass_view_projection;
};

float2 glass_screen(float3 p)
{
    float4 c = mul(glass_view_projection, float4(p, 1.0));
    float2 ndc = c.xy / max(c.w, 0.0001);
    return float2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
}

// What lies behind at uv, read over a disc as wide as frost asks
float3 glass_behind(float2 uv, float frost)
{
    float3 sum = extra_texture.SampleLevel(extra_sampler, uv, 0.0).rgb;
    if (frost <= 0.0) return sum;
    float2 size;
    extra_texture.GetDimensions(size.x, size.y);
    float2 spread = frost * 0.035 * float2(size.y / size.x, 1.0);
    for (int k = 1; k < 12; k++)
    {
        float a = k * 2.39996;
        sum += extra_texture.SampleLevel(extra_sampler, uv + float2(cos(a), sin(a)) * sqrt(k / 12.0) * spread, 0.0).rgb;
    }
    return sum / 12.0;
}

// A glass piece, crystal for white and smoked for black as its tint says. Values: white's tint
// as sRGB and how frosted it is, black's the same, then the board's squares, the dark one's w how
// thickly the tint gathers along a square's length of glass.
float4 glass_piece_ps(WoodOut i) : SV_Target0
{
    PieceFx fx = piece_fx(i);
    bool white = piece_white(i);
    float4 kind = white ? material[0] : material[1];
    float3 tint = three_srgb_to_linear(kind.rgb);
    float frost = kind.w;
    float3 n = normalize(i.normal);
    float3 v = normalize(piece_eye(i) - i.world);
    float nv = saturate(dot(n, v));
    float3 l = three_sun_way();
    float nl = saturate(dot(n, l));
    float rough = 0.03 + frost * 0.35;
    float3 t = refract(-v, n, 1.0 / 1.5);
    float2 off = i.world.xz - i.seed.xz;
    float a = dot(t.xz, t.xz);
    float through = a > 0.00001 ? max(-2.0 * dot(off, t.xz) / a, 0.0) : 0.3;
    through = clamp(through, 0.03, 0.8);
    float3 exit = i.world + t * through;
    float3 out_n = normalize(float3(exit.x - i.seed.x, n.y * 0.6, exit.z - i.seed.z));
    float3 o = refract(t, -out_n, 1.5);
    if (dot(o, o) < 0.0001) o = reflect(t, -out_n);
    float travel = o.y < -0.05 ? clamp(-exit.y / o.y, 0.05, 3.0) : 1.2;
    float3 far = exit + o * travel;
    // a way in low on the foot that meets its underside before the far side sees what the piece
    // stands on there, its felt or the board in its shade, never the lit board beyond it
    float sole = i.world.y - i.local.y;
    float down = t.y < -0.0001 ? (i.world.y - sole) / -t.y : through + 1.0;
    float floored = down < through ? smoothstep(0.09, 0.04, i.local.y) : 0.0;
    float3 under = i.world + t * min(down, through);
    if (i.flip > 0.5)
    {
        far.y = -far.y;
        under.y = -under.y;
    }
    float3 behind = glass_behind(glass_screen(far), frost);
    if (floored > 0.0) behind = lerp(behind, glass_behind(glass_screen(under), frost), floored);
    float3 absorb = exp(-(1.0 - tint) * lerp(through, min(down, through), floored) * material[3].w);
    float3 seen = behind * absorb * lerp(1.0, tint, 0.35);
    float3 sun = lights.sun_color.rgb * wood_shadow(i);
    float3 milk = tint * (three_hemisphere(n) * THREE_RECIPROCAL_PI + sun * (nl * 0.6 + 0.25)) * 0.85;
    seen = lerp(seen, milk, frost * 0.65);
    float fresnel = 0.04 + 0.96 * pow(1.0 - nv, 5.0);
    float3 r = reflect(-v, n);
    float2 ab = wood_env_brdf(rough, nv);
    float3 mirrored = piece_seen(i.world, i.seed.xz, r, rough) * (0.04 * ab.x + ab.y);
    float3 spec = sun * nl * THREE_PI * three_specular_ggx(l, v, n, float3(0.04, 0.04, 0.04), rough);
    float rim = smoothstep(0.35, 0.0, nv) * 0.25;
    float3 c = seen * (1.0 - fresnel) * (1.0 - rim) + mirrored + spec;
    // mirrored in a polished board nothing lies behind, so only what the glass gives back shows
    if (i.flip > 0.5) return piece_fx_over(i, fx, float4(mirrored + spec + milk * frost * 0.65, saturate(fresnel + frost * 0.7 + 0.15)));
    return piece_fx_over(i, fx, piece_out(i, c, 1.0));
}

// The plate's squares, uv across the field from 0 to 1 with a8 at its far left: the light ones
// etched frosted, the dark ones clear over the dark mirror beneath, which shows the pieces
// mirrored. Values: the etched glass as sRGB, the mirror beneath as sRGB with how strongly it
// mirrors.
float4 glass_board_ps(WoodOut i) : SV_Target0
{
    float2 at = i.uv * 8.0;
    float2 cell = min(floor(at), 7.0);
    float2 f = at - cell;
    float rank = 7.0 - cell.y;
    bool dark = fmod(cell.x + rank, 2.0) < 0.5;
    float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
    float3 n = float3(0.0, 1.0, 0.0);
    float fine = saturate(1.5 - length(fwidth(i.world.xz * 160.0)));
    if (!dark)
    {
        float3 c = three_srgb_to_linear(material[0].rgb) * (0.94 + 0.12 * (wood_noise(float3(i.world.xz * 160.0, 2.0)) - 0.5) * fine);
        c *= lerp(0.8, 1.0, smoothstep(0.0, fwidth(at.x) + 0.004, edge));
        float ao = field_marks(i, cell, f, edge, c, c);
        return wood_lit(i, n, c, 0.7, 0.12, 0.3, ao, lerp(0.75, 1.0, ao));
    }
    float3 base = three_srgb_to_linear(material[1].rgb);
    float3 c = base;
    float ao = field_marks(i, cell, f, edge, base, c);
    float4 seen = wood_mirror(i, n, 0.02);
    float4 o = wood_lit_seen(i, n, c, 0.2, 1.0, 0.02, ao, lerp(0.75, 1.0, ao), seen);
    float3 v = normalize(three_eye() - i.world);
    o.rgb += (seen.rgb + wood_room(reflect(-v, n), 0.05) * (1.0 - seen.a) * 0.4) * material[1].w * ao;
    return o;
}

// The plate beyond the squares, clear over the mirror with an etched line round the field and the
// coordinates etched into it, each side's turned to read from that side, and its cut edges green
// with the light the glass carries along. Values as the squares'.
float4 glass_frame_ps(WoodOut i) : SV_Target0
{
    float3 n = normalize(i.normal);
    float3 v = normalize(three_eye() - i.world);
    if (n.y < 0.9)
    {
        float3 green = three_srgb_to_linear(float3(0.32, 0.62, 0.5));
        float4 o = wood_lit(i, n, green * 0.25, 0.08, 1.0, 0.02, 1.0, 1.0);
        o.rgb += green * (three_hemisphere(float3(0.0, 1.0, 0.0)) * THREE_RECIPROCAL_PI + lights.sun_color.rgb * 0.15) * (n.y < -0.5 ? 0.1 : 0.6);
        return o;
    }
    float2 p = i.world.xz;
    float2 up = abs(p.y) > 4.0 && abs(p.x) < 4.0 ? float2(0.0, -sign(p.y)) : float2(-sign(p.x), 0.0);
    float2 right = float2(-up.y, up.x);
    float lod = max(log2(sqrt(length(ddx(p)) * length(ddy(p))) * 96.0 / CoordCell), 0.0);
    float d = coord_distance(p, up, right, lod);
    float aw = fwidth(d) + 0.0008;
    float etched = smoothstep(aw, -aw, d);
    float aa = fwidth(i.uv.y) + 0.002;
    etched = max(etched, smoothstep(0.07 - aa, 0.07, i.uv.y) - smoothstep(0.085, 0.085 + aa, i.uv.y));
    float3 frosted = three_srgb_to_linear(material[0].rgb);
    float3 base = three_srgb_to_linear(material[1].rgb);
    float4 seen = wood_mirror(i, n, 0.02) * (1.0 - etched);
    float4 o = wood_lit_seen(i, n, lerp(base, frosted, etched), lerp(0.2, 0.7, etched), 1.0 - etched * 0.85, 0.02, 1.0, 1.0, seen);
    o.rgb += (seen.rgb + wood_room(reflect(-v, n), 0.05) * (1.0 - seen.a) * 0.4) * material[1].w * (1.0 - etched);
    return o;
}

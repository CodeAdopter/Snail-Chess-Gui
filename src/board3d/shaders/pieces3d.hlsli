// What the pieces cut from other than wood share: which side a piece is on, the shade round its
// foot, and what a polished piece mirrors below the horizon, the board it stands on with its
// squares where they lie, so metal and glass show the board under them. Such a piece's values end
// with the board's light square and its dark one as sRGB, the first's w how far the frame's colour
// lies from the dark square's toward the light's.

#ifndef PIECES3D_HLSLI
#define PIECES3D_HLSLI

#include "wood3d.hlsl"

// Whether the piece is white's, whose tint is light
bool piece_white(WoodOut i)
{
    return dot(i.color.rgb, float3(0.3, 0.55, 0.15)) > 0.25;
}

// The shade where the piece meets the board, less the higher it is held
float piece_foot(WoodOut i)
{
    float lift = max(i.world.y - i.local.y, 0.0);
    return 1.0 - 0.45 * exp(-i.local.y / 0.05) / (1.0 + lift * 8.0);
}

// The eye, mirrored under the board for a mirrored piece
float3 piece_eye(WoodOut i)
{
    float3 eye = three_eye();
    if (i.flip > 0.5) eye.y = -eye.y;
    return eye;
}

// What a surface at p sees the way r points, as blurred as rough: the board lit by the sun and
// the sky where r meets it, its squares running together the rougher the surface and the farther
// off they lie, its frame beyond them and the table past that, else the room. The board darkens
// toward the foot of the piece standing at axis, which shades it, so a foot's lower edge never
// mirrors a lit board where the board beneath it lies in its shade.
float3 piece_seen(float3 p, float2 axis, float3 r, float rough)
{
    if (r.y > -0.02) return wood_room(r, rough);
    float t = -p.y / r.y;
    float2 h = p.xz + r.xz * t;
    float reach = length(p.xz - axis);
    float shade = lerp(1.0, smoothstep(reach, reach + 0.25, length(h - axis)), smoothstep(-0.02, -0.08, r.y));
    float3 light = three_srgb_to_linear(material[2].rgb);
    float3 dark = three_srgb_to_linear(material[3].rgb);
    float3 c;
    if (abs(h.x) > 4.62 || abs(h.y) > 4.62) c = float3(0.02, 0.018, 0.016);
    else if (abs(h.x) > 4.0 || abs(h.y) > 4.0) c = lerp(dark, light, material[2].w);
    else
    {
        float2 cell = floor(float2(h.x + 4.0, 4.0 - h.y));
        bool black = fmod(cell.x + cell.y, 2.0) < 0.5;
        float blur = saturate(rough * 4.0 + t * 0.15);
        c = lerp(black ? dark : light, (light + dark) * 0.5, blur);
    }
    float3 up = float3(0.0, 1.0, 0.0);
    float3 room = wood_room(r, rough);
    float far = smoothstep(0.0, -0.25, r.y);
    return lerp(room, c * (lights.sun_color.rgb * saturate(three_sun_way().y) + three_hemisphere(up) * THREE_RECIPROCAL_PI), far) * shade;
}

// A lit colour fogged, its alpha the depth ahead of the eye, or a mirrored piece's cover
float4 piece_out(WoodOut i, float3 c, float cover)
{
    return float4(three_fog_at(c + fx_glow, i.depth, i.world), i.flip > 0.5 ? cover : i.depth);
}

#endif

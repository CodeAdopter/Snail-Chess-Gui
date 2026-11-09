// Lamps for the 3D board's rooms, the lights at a point Lighting holds. Each fades with the square
// of how far it is, softened close by as a lamp as wide as the lamp room's w would be, to nothing
// at its reach, and out of its cone where it has one, and is shaded by
// the shadow map it casts through, read soft on a spiral. The sun's shadow is read the same way.

#ifndef LAMPS3D_HLSLI
#define LAMPS3D_HLSLI

float lamp_read(int k, float2 uv, float z)
{
    if (k == 0) return three_compare(shadow_map0, shadow_sampler0, uv, z);
    if (k == 1) return three_compare(shadow_map1, shadow_sampler1, uv, z);
    return three_compare(shadow_map2, shadow_sampler2, uv, z);
}

// Map k at uv, blended between the four texels round it, so a shadow's edge goes soft
float lamp_compare(int k, float2 uv, float z, float2 texel, float2 size)
{
    float2 f = frac(uv * size + 0.5);
    uv -= f * texel;
    float a = lamp_read(k, uv, z);
    float b = lamp_read(k, uv + float2(texel.x, 0.0), z);
    float c = lamp_read(k, uv + float2(0.0, texel.y), z);
    float d = lamp_read(k, uv + texel, z);
    return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}

// The light map k lets through to a point at coord in it, sixteen reads on a spiral as wide as the
// map's radius asks, lit outside the map
float lamp_shadow(int k, float4 coord)
{
    float4 info = lights.shadow[k];
    if (info.x < 0.5) return 1.0;
    float3 c = coord.xyz / coord.w;
    c.z += info.z;
    if (c.x < 0.0 || c.x > 1.0 || c.y < 0.0 || c.y > 1.0 || c.z > 1.0) return 1.0;
    float2 texel = 1.0 / info.xy;
    float spread = info.w * 2.25;
    float sum = 0.0;
    for (int s = 0; s < 16; s++)
    {
        float a = s * 2.39996;
        float2 o = float2(cos(a), sin(a)) * sqrt((s + 0.5) / 16.0) * spread;
        sum += lamp_compare(k, c.xy + o * texel, c.z, texel, info.xy);
    }
    return sum / 16.0;
}

// Map 1 or 2 at uv, blended between the four texels round it like lamp_compare but from one
// gather, so its shadows go soft without stepping in texels
float lamp_gather(int k, float2 uv, float z, float2 size)
{
    float4 d = k == 1 ? shadow_map1.GatherRed(shadow_sampler1, uv) : shadow_map2.GatherRed(shadow_sampler2, uv);
    float4 lit = step(z, 1.0 - d);
    float2 f = frac(uv * size - 0.5);
    return lerp(lerp(lit.w, lit.z, f.x), lerp(lit.x, lit.y, f.x), f.y);
}

// The light map 1 or 2 lets through, eight blended reads on a spiral as wide as its radius asks,
// for a soft or a wide map where the board's own sixteen would cost too much
float lamp_shadow_soft(int k, float4 coord)
{
    float4 info = lights.shadow[k];
    if (info.x < 0.5) return 1.0;
    float3 c = coord.xyz / coord.w;
    c.z += info.z;
    if (c.x < 0.0 || c.x > 1.0 || c.y < 0.0 || c.y > 1.0 || c.z > 1.0) return 1.0;
    float2 texel = 1.0 / info.xy;
    float spread = info.w * 2.25;
    float sum = 0.0;
    for (int s = 0; s < 8; s++)
    {
        float a = s * 2.39996;
        float2 o = float2(cos(a), sin(a)) * sqrt((s + 0.5) / 8.0) * spread;
        sum += lamp_gather(k, c.xy + o * texel, c.z, info.xy);
    }
    return sum / 8.0;
}

int lamp_count()
{
    return (int)lights.lamp_room.x;
}

// The way from p to lamp k and the light it brings there, faded by distance, cone and shadow
float3 lamp_light(int k, float3 p, float4 c0, float4 c1, float4 c2, out float3 l)
{
    float4 at = lights.lamps[k];
    float3 d = at.xyz - p;
    float far = max(dot(d, d), 1e-4);
    float wide = lights.lamp_room.w;
    l = d * rsqrt(far);
    if (at.w <= 0.0) return 0.0;
    float edge = saturate(1.0 - far * far / (at.w * at.w * at.w * at.w));
    float4 aim = lights.lamp_aims[k];
    float cone = aim.w < -0.99 ? 1.0 : smoothstep(aim.w, lerp(aim.w, 1.0, 0.45), dot(-l, aim.xyz));
    float4 c = lights.lamp_colors[k];
    float shade = 1.0;
    int map = (int)c.w - 1;
    if (map == 0) shade = lamp_shadow(0, c0);
    if (map == 1) shade = lamp_shadow_soft(1, c1);
    if (map == 2) shade = lamp_shadow_soft(2, c2);
    return c.rgb * (edge * edge * cone * shade / (far + wide * wide));
}

// How much lamp k shines at p from far off, as a room's mirror sees it, with no shadow
float3 lamp_glow(int k, float3 p)
{
    float4 at = lights.lamps[k];
    float3 d = at.xyz - p;
    return lights.lamp_colors[k].rgb / max(dot(d, d) + lights.lamp_room.w * lights.lamp_room.w, 1.0);
}

// The sun's light let through map 0 and the maps whose bits sun_through's x holds besides, the
// leaves of those letting some through still, as sun_through's z says for map 1 and w for map 2
float sun_shadow(float4 c0, float4 c1, float4 c2)
{
    int bits = (int)lights.sun_through.x;
    float lit = lamp_shadow(0, c0);
    if ((bits & 2) != 0) lit *= lerp(lights.sun_through.z, 1.0, lamp_shadow_soft(1, c1));
    if ((bits & 4) != 0) lit *= lerp(lights.sun_through.w, 1.0, lamp_shadow_soft(2, c2));
    return lit;
}

// The open sky and the ground under it, as a mirror sees them the way r points, as blurred as
// rough: the ground's colour below, the sky's above, brighter toward the horizon, and a glow toward
// the sun, all at sun_through's y
float3 sky_room(float3 r, float rough)
{
    float soft = 0.05 + rough * 0.6;
    float3 c = lerp(lights.ground_color.rgb, lights.sky_color.rgb * (1.0 + 0.6 * (1.0 - saturate(r.y))), smoothstep(-soft, soft, r.y));
    float sharp = lerp(300.0, 3.0, rough);
    float3 sun = -lights.sun_direction.xyz;
    c += lights.sun_color.rgb * pow(saturate(dot(r, sun)), sharp) * (sharp + 1.0) * 0.02;
    return c * lights.sun_through.y;
}

#endif

// The surface of Mars round the 3D board at dusk: rust regolith rippled by the wind with rover
// tracks across it, basalt rocks dusted on top, the flat boulder the board sits on, the crater's rim
// in the haze, the sky going from butterscotch to dusk with the sun's blue glow, Earth and Phobos,
// the rover's white paint, gold foil and solar cells, the habitat's lit windows and a dust devil.
// Worked out in metres at 16.4 squares a metre, lit by the low sun through its shadow maps, the sky
// and the rover's light, hazed with distance, each returning how far ahead of the eye it is as its
// alpha, for the lens.

#include "park3d.hlsl"

// The park's light, then the lamps besides, as the rover's mast light
float4 mars_lit(WoodOut i, float3 n, float3 c, float rough, float metal, float ao)
{
    float4 base = park_lit(i, n, c, rough, metal, ao, 0.0);
    float3 v = normalize(three_eye() - i.world);
    float3 f0 = lerp(float3(0.04, 0.04, 0.04), c, metal);
    float3 diffuse = c * (1.0 - metal);
    float3 add = 0.0;
    for (int k = 0; k < lamp_count(); k++)
    {
        float3 l;
        float3 e = lamp_light(k, i.world, i.shadow0, i.shadow1, i.shadow2, l) * saturate(dot(n, l));
        add += e * diffuse + e * THREE_PI * three_specular_ggx(l, v, n, f0, max(rough, 0.04));
    }
    return float4(base.rgb + add, base.a);
}

static const float3 MARS_DUST = float3(0.6, 0.31, 0.16);

// The plain: fine dust and darker basaltic sand in patches, ripples the wind laid every ten
// centimetres, pebbles, and the treads of the rover's six wheels running back from where it stands.
// Values: the rover's x and z in metres and which way it faces.
float4 mars_ground_ps(WoodOut i) : SV_Target0
{
    float3 p = i.world / ROOM_METRE;
    float3 n0 = normalize(i.normal);
    float fine = saturate(1.5 - length(fwidth(p.xz * 40.0)));
    float bend = wood_fbm(float3(p.xz * 0.4, 1.0)) * 6.0;
    float rip = sin((p.x * 0.8 + p.z * 0.6) * 55.0 + bend);
    float peb = smoothstep(0.74, 0.8, wood_noise(float3(p.xz * 28.0, 2.0))) * fine;
    float grit = lerp(0.5, wood_noise(float3(p.xz * 150.0, 5.0)), fine);
    float patch = wood_fbm(float3(p.xz * 0.12, 3.0));
    float3 sand = float3(0.28, 0.16, 0.1);
    float3 c = lerp(sand, MARS_DUST, smoothstep(0.3, 0.7, patch + rip * 0.06 * fine));
    c *= 0.88 + 0.22 * grit;
    c = lerp(c, float3(0.15, 0.1, 0.08), peb * 0.75);
    float a = material[0].z;
    float2 q = p.xz - material[0].xy;
    float u = dot(q, float2(cos(a), -sin(a)));
    float w = dot(q, float2(sin(a), cos(a))) + u * u * 0.004;
    float tread = smoothstep(0.14, 0.1, abs(abs(w) - 0.78)) * step(u, 0.4) * smoothstep(-90.0, -60.0, u);
    float lugs = step(0.5, frac(u * 9.0 + abs(w) * 3.0));
    c *= 1.0 - tread * (0.18 + 0.08 * lugs);
    float high = rip * 0.004 * fine + peb * 0.006 - tread * (0.01 - lugs * 0.003 * fine);
    float3 n = wood_bump(n0, i.world, high * ROOM_METRE);
    return mars_lit(i, n, c, 0.95, 0.0, 1.0);
}

// Basalt: dark and faceted where the rocks broke, pitted with gas holes, dust settled on what faces
// up. The slab the board sits on is smooth, banded where its layers were laid. Values: x 1 for the
// slab.
float4 mars_rock_ps(WoodOut i) : SV_Target0
{
    float3 p = i.world / ROOM_METRE;
    float3 n0 = normalize(i.normal);
    bool slab = material[0].x > 0.5;
    float3 facet = normalize(cross(ddy(i.world), ddx(i.world)));
    if (dot(facet, n0) < 0.0) facet = -facet;
    float3 nr = slab ? n0 : normalize(lerp(n0, facet, 0.75));
    float3 c = slab ? float3(0.24, 0.18, 0.15) : i.color.rgb;
    float fine = saturate(1.5 - length(fwidth(p * 220.0)));
    float pits = smoothstep(0.8, 0.86, wood_noise(p * 220.0)) * fine * (slab ? 0.5 : 1.0);
    float rough = wood_fbm(p * 18.0);
    if (slab) c *= 0.85 + 0.25 * (sin(p.y * 45.0 + rough * 5.0) * 0.5 + 0.5);
    c *= 0.85 + 0.3 * rough;
    c = lerp(c, c * 0.55, pits);
    float dust = smoothstep(0.35, 0.9, nr.y) * (0.45 + 0.55 * wood_fbm(p * 7.0 + 2.0));
    if (slab) dust *= 0.45;
    c = lerp(c, MARS_DUST * 0.9, saturate(dust));
    float3 n = wood_bump(nr, i.world, ((rough - 0.5) * (slab ? 0.003 : 0.008) - pits * 0.0015) * ROOM_METRE);
    return mars_lit(i, n, c, lerp(0.7, 0.95, dust), 0.0, 1.0);
}

// The crater's rim far off, layered rock in rust and ochre, its shading broad
float4 mars_ridge_ps(WoodOut i) : SV_Target0
{
    float3 p = i.world / ROOM_METRE;
    float3 n0 = normalize(i.normal);
    float layers = sin(p.y * 0.3 + wood_fbm(p * 0.01) * 5.0) * 0.5 + 0.5;
    float3 c = lerp(float3(0.36, 0.19, 0.11), float3(0.6, 0.36, 0.2), layers) * (0.75 + 0.35 * wood_fbm(p * 0.015));
    float3 n = wood_bump(n0, i.world, wood_fbm(p * 0.025) * 18.0 * ROOM_METRE);
    return mars_lit(i, n, c, 0.95, 0.0, 1.0);
}

// The sky at dusk: butterscotch along the horizon darkening to a dusky rose overhead and away from
// the sun, the cold blue glow Mars has round its setting sun, the small white sun, Earth shining as
// the evening star above it, Phobos lit from the sun's side, and the first stars
float4 mars_sky_ps(WoodOut i) : SV_Target0
{
    float3 rd = normalize(i.world - three_eye());
    float3 sun = three_sun_way();
    float h = saturate(rd.y);
    float mu = dot(rd, sun);
    float3 c = lerp(float3(0.62, 0.42, 0.28), float3(0.1, 0.07, 0.08), pow(h, 0.45));
    c *= 0.5 + 0.5 * saturate(mu * 0.5 + 0.5);
    float glow = pow(saturate(mu), 7.0) * (1.0 - smoothstep(0.0, 0.45, h));
    c = lerp(c, float3(0.4, 0.58, 0.95), saturate(glow * 1.3));
    c += float3(0.55, 0.72, 1.0) * pow(saturate(mu), 70.0) * 1.4;
    c += float3(1.0, 0.98, 0.95) * smoothstep(0.99994, 0.99997, mu) * 30.0;
    float3 side = normalize(cross(sun, float3(0.0, 1.0, 0.0)));
    float3 earth = normalize(sun + float3(0.0, 0.17, 0.0) - side * 0.07);
    c += float3(0.65, 0.78, 1.0) * smoothstep(0.999993, 0.999998, dot(rd, earth)) * 10.0;
    float3 phobos = normalize(float3(0.5, 0.45, 0.55));
    float3 ps = normalize(cross(phobos, float3(0.0, 1.0, 0.0)));
    float3 pu = cross(ps, phobos);
    float2 q = float2(dot(rd, ps), dot(rd, pu)) / 0.012;
    float edge = 1.0 + 0.14 * sin(atan2(q.y, q.x) * 3.0 + 0.5) + 0.06 * sin(atan2(q.y, q.x) * 7.0);
    if (dot(rd, phobos) > 0.0 && length(q) < edge)
    {
        float3 m = normalize(ps * q.x + pu * q.y + phobos * -sqrt(saturate(1.0 - dot(q, q) / (edge * edge))));
        float lit = saturate(dot(-m, sun) * 0.9 + 0.1);
        float crater = 0.8 + 0.2 * wood_noise(float3(q * 6.0, 4.0));
        c = lerp(c, float3(0.42, 0.36, 0.32) * lit * crater + c * 0.15, smoothstep(edge, edge * 0.9, length(q)));
    }
    float3 cell = floor(rd * 320.0);
    float star = step(0.9975, wood_hash(cell)) * smoothstep(0.3, 0.85, h) * saturate(0.4 - mu * 0.8);
    c += star * 0.4 * wood_hash(cell + 1.7);
    return float4(c, i.depth);
}

// Painted or bare metal, its colour in rgb and how metallic in alpha, dust settled on what faces up
float4 mars_metal_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    float3 c = room_linear(i.color.rgb);
    float dust = smoothstep(0.6, 0.95, n0.y) * (0.25 + 0.3 * wood_fbm(p * 8.0));
    c = lerp(c, MARS_DUST, dust);
    return mars_lit(i, n0, c, lerp(0.55, 0.3, i.color.a), i.color.a * (1.0 - dust), 1.0);
}

// Gold foil wrapped round the rover's body, crinkled
float4 mars_foil_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    float crinkle = wood_noise(p * 55.0) * 0.6 + wood_noise(p * 170.0) * 0.4;
    float3 n = wood_bump(n0, i.world, crinkle * 0.004 * ROOM_METRE);
    return mars_lit(i, n, float3(0.95, 0.66, 0.24), 0.22, 1.0, 1.0);
}

// The deck of solar cells, dark blue in a silver grid, filmed with dust
float4 mars_panel_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    if (n0.y < 0.7) return mars_lit(i, n0, float3(0.06, 0.06, 0.07), 0.5, 0.3, 1.0);
    float2 g = frac(p.xz * 9.0);
    float line_ = 1.0 - room_band(g.x, 0.04, 0.96) * room_band(g.y, 0.04, 0.96);
    float3 c = lerp(float3(0.02, 0.035, 0.1), float3(0.6, 0.62, 0.66), line_);
    float dust = 0.25 + 0.35 * wood_fbm(p * 5.0);
    c = lerp(c, MARS_DUST, dust);
    return mars_lit(i, n0, c, lerp(0.15, 0.8, dust), line_ * 0.8, 1.0);
}

// The habitat's white shell in panels, a ring of windows lit warm low round it. Values: the time.
float4 mars_dome_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / ROOM_METRE;
    float az = atan2(n0.z, n0.x);
    float seam = 1.0 - room_band(frac(az * 3.82), 0.02, 0.98) * room_band(frac(n0.y * 6.0), 0.03, 0.97);
    float3 c = float3(0.82, 0.8, 0.76) * (1.0 - seam * 0.35);
    c = lerp(c, MARS_DUST, smoothstep(0.6, 1.0, 1.0 - n0.y) * 0.4);
    float4 lit = mars_lit(i, n0, c, 0.5, 0.0, 1.0);
    float pane = room_band(n0.y, 0.12, 0.3) * room_band(frac(az * 7.64), 0.25, 0.75);
    float on = step(0.25, wood_hash(float3(floor(az * 7.64), 3.0, 1.0)));
    return float4(lit.rgb + float3(1.0, 0.68, 0.38) * pane * on * 3.0, lit.a);
}

// A small light's lens shining, its colour in rgb
float4 mars_glow_ps(WoodOut i) : SV_Target0
{
    return float4(i.color.rgb * 12.0, i.depth);
}

// The dust devil, a funnel of dust lifted turning on the horizon, thickest low down and fading as it
// climbs, laid over what is behind it without touching the depth it holds. Values: the time.
float4 mars_devil_ps(WoodOut i) : SV_Target0
{
    float t = material[0].x;
    float3 p = i.world / ROOM_METRE;
    float3 n = normalize(i.normal);
    float3 v = normalize(three_eye() - i.world);
    float a = atan2(p.z + 420.0, p.x + 260.0);
    float h = saturate((p.y + 0.62) / 300.0);
    float swirl = wood_fbm(float3(a * 3.0 + t * 0.9 - h * 7.0, h * 9.0 - t * 0.4, 1.0));
    float dense = smoothstep(0.3, 0.75, swirl) * (1.0 - h) * smoothstep(0.0, 0.04, h) * (0.3 + 0.7 * abs(dot(n, v)));
    float3 c = float3(0.6, 0.4, 0.27) * (0.55 + 0.45 * saturate(dot(n, three_sun_way())));
    return float4(three_fog_at(c, i.depth, i.world), dense * 0.5);
}

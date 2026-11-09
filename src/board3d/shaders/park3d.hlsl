// The park round the 3D board on an October afternoon: a concrete chess table under a tree whose
// leaves dapple the board, a mown lawn with a gravel path and fallen leaves, trees turning, a bench
// and a lamp post, far woods and the sky. Everything is worked out in metres from the board's
// middle at 16.4 squares a metre, lit by a low golden sun through the shadow maps it passes and by
// the sky, hazed with distance. Each returns how far ahead of the eye it is as its alpha, for the
// lens.

#include "room3d.hlsl"

#define PARK_METRE ROOM_METRE

// A surface of colour c facing n, rough and as metallic as metal, its open light shaded by ao, lit
// by the sun through its shadow maps, by the sky and the ground and the sky it mirrors, and for a
// leaf or a blade the sun coming through it from behind at transmit, brightest looking into the
// sun. Hazed with distance.
float4 park_lit(WoodOut i, float3 n, float3 c, float rough, float metal, float ao, float transmit)
{
    float3 v = normalize(three_eye() - i.world);
    float3 l = three_sun_way();
    float nv = saturate(dot(n, v));
    float3 f0 = lerp(float3(0.04, 0.04, 0.04), c, metal);
    float3 diffuse = c * (1.0 - metal);
    float3 sun = lights.sun_color.rgb * sun_shadow(i.shadow0, i.shadow1, i.shadow2);
    float nl = saturate(dot(n, l));
    float3 lit = sun * nl * diffuse + sun * nl * THREE_PI * three_specular_ggx(l, v, n, f0, max(rough, 0.04));
    float through = saturate(-dot(n, l)) * (1.0 + 3.0 * pow(saturate(dot(-v, l)), 6.0));
    lit += sun * c * transmit * through;
    lit += three_hemisphere(n) * THREE_RECIPROCAL_PI * diffuse * ao;
    float2 ab = wood_env_brdf(rough, nv);
    lit += sky_room(reflect(-v, n), rough) * (f0 * ab.x + ab.y) * ao;
    return float4(three_fog_at(lit, i.depth, i.world), i.depth);
}

// The park's light for leaves and grass, too matt to mirror anything: the sun on them and through
// them from behind, and the open light, hazed with distance
float4 park_lit_matte(WoodOut i, float3 n, float3 c, float ao, float transmit)
{
    float3 v = normalize(three_eye() - i.world);
    float3 l = three_sun_way();
    float3 sun = lights.sun_color.rgb * sun_shadow(i.shadow0, i.shadow1, i.shadow2);
    float through = saturate(-dot(n, l)) * (1.0 + 3.0 * pow(saturate(dot(-v, l)), 6.0));
    float3 lit = sun * c * (saturate(dot(n, l)) + transmit * through);
    lit += three_hemisphere(n) * THREE_RECIPROCAL_PI * c * ao;
    return float4(three_fog_at(lit, i.depth, i.world), i.depth);
}

// The open sky on a dome far round the park: deep blue overhead paling to a warm haze at the
// horizon, the sun's disc and its glow, and a few fair weather clouds lit gold on the sun's side.
// Values: x how bright it is.
float4 sky_ps(WoodOut i) : SV_Target0
{
    float3 rd = normalize(i.world - three_eye());
    float3 sun = -lights.sun_direction.xyz;
    float up = saturate(rd.y);
    float mu = dot(rd, sun);
    float3 c = lerp(float3(0.55, 0.58, 0.62), float3(0.07, 0.17, 0.48), pow(up, 0.5));
    c = lerp(c, float3(0.85, 0.66, 0.45), (1.0 - smoothstep(0.0, 0.3, up)) * (0.25 + 0.45 * saturate(mu)));
    c += float3(1.0, 0.7, 0.4) * pow(saturate(mu), 10.0) * 0.7;
    c += float3(1.0, 0.85, 0.6) * pow(saturate(mu), 120.0) * 2.0;
    c += float3(1.0, 0.95, 0.85) * smoothstep(0.99985, 0.9999, mu) * 40.0;
    if (rd.y > 0.005)
    {
        float2 q = rd.xz / (rd.y + 0.08) * 1.3;
        float cloud = wood_fbm(float3(q * 0.7, 3.0)) + wood_fbm(float3(q * 2.1, 7.0)) * 0.35;
        cloud = smoothstep(0.62, 0.95, cloud) * smoothstep(0.01, 0.12, rd.y);
        float3 lit = lerp(float3(0.78, 0.76, 0.78), float3(1.35, 1.05, 0.75), pow(saturate(mu * 0.5 + 0.5), 3.0));
        c = lerp(c, lit, cloud * 0.85);
    }
    return float4(c * material[0].x, i.depth);
}

// Where the gravel path runs, its middle's z at x, in metres
float park_path(float x)
{
    return -6.6 + 1.6 * sin(x * 0.11 + 0.6) + 0.5 * sin(x * 0.29);
}

// How worn the lawn is at p by feet, round the table and its stools and along the line walked to
// it from the path, as park_shapes' park_worn
float park_worn(float2 p)
{
    float ring = 1.0 - smoothstep(0.75, 1.25, length(float2(p.x, p.y / 1.35)));
    float walk = 0.0;
    if (p.y < -0.5 && p.y > park_path(p.x)) walk = 1.0 - smoothstep(0.16, 0.42, abs(p.x - 0.25 * sin(p.y * 0.9)));
    return max(ring, walk);
}

// The mown lawn in mottled greens yellowing in patches, faint mowing stripes, dark clover, fallen
// leaves scattered over it, and the gravel path's pale stones with grass creeping at its edges.
float4 ground_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / PARK_METRE;
    float aa = length(fwidth(p.xz));
    float fine = saturate(1.0 - aa * 40.0);
    float patches = wood_fbm(float3(p.x * 0.35, 1.0, p.z * 0.35));
    float dry = smoothstep(0.5, 0.75, wood_fbm(float3(p.x * 0.8 + 4.0, 2.0, p.z * 0.8)));
    float3 lawn = lerp(float3(0.13, 0.22, 0.05), float3(0.3, 0.38, 0.11), patches);
    lawn = lerp(lawn, float3(0.45, 0.42, 0.2), dry * 0.55);
    lawn *= 1.0 + 0.05 * (step(0.5, frac(p.x / 1.1)) - 0.5);
    float clover = smoothstep(0.7, 0.8, wood_noise(float3(p.x * 9.0, 0.0, p.z * 9.0)));
    lawn *= 1.0 - clover * 0.25;
    float blades = wood_noise(float3(p.x * 220.0, 0.0, p.z * 220.0));
    lawn *= 1.0 + (blades - 0.5) * 0.5 * fine;
    float3 c = room_linear(lawn);
    float2 ragged = p.xz + (float2(wood_fbm(float3(p.x * 2.5, 6.0, p.z * 2.5)), wood_fbm(float3(p.x * 2.5, 9.0, p.z * 2.5))) - 0.5) * 0.5;
    float worn = saturate(park_worn(ragged) * (0.55 + 0.8 * wood_fbm(float3(p.x * 4.0, 3.0, p.z * 4.0))));
    float3 dirt = room_linear(lerp(float3(0.34, 0.27, 0.19), float3(0.46, 0.39, 0.28), wood_noise(float3(p.x * 30.0, 1.0, p.z * 30.0))));
    dirt = lerp(dirt, room_linear(float3(0.42, 0.42, 0.2)), smoothstep(0.55, 0.75, blades) * 0.5);
    c = lerp(c, dirt, smoothstep(0.25, 0.75, worn));
    float edge = abs(p.z - park_path(p.x)) - 0.8 - (wood_noise(float3(p.x * 6.0, 5.0, p.z * 6.0)) - 0.5) * 0.18;
    float gravel = 1.0 - smoothstep(-0.05, 0.05, edge);
    float stones = wood_noise(float3(p.x * 70.0, 9.0, p.z * 70.0));
    float3 grit = room_linear(lerp(float3(0.5, 0.46, 0.4), float3(0.68, 0.64, 0.57), stones)) * (0.85 + 0.2 * wood_noise(p * 300.0) * fine);
    c = lerp(c, grit, gravel);
    float2 cell = floor(p.xz / 0.3);
    float2 f = frac(p.xz / 0.3) - 0.5;
    float pick = wood_hash(float3(cell, 11.0));
    float under = 1.0 - smoothstep(4.0, 9.0, length(p.xz - float2(-5.4, 5.6)));
    if (pick < 0.03 + 0.12 * under)
    {
        float a = pick * 40.0;
        float2 r = float2(f.x * cos(a) - f.y * sin(a), f.x * sin(a) + f.y * cos(a)) + (float2(wood_hash(float3(cell, 3.0)), wood_hash(float3(cell, 5.0))) - 0.5) * 0.4;
        float leaf = length(r * float2(1.0, 1.7)) - 0.08 - 0.06 * wood_hash(float3(cell, 13.0));
        float3 tone = lerp(float3(0.62, 0.32, 0.1), float3(0.75, 0.55, 0.15), wood_hash(float3(cell, 7.0)));
        tone = lerp(tone, float3(0.42, 0.24, 0.12), step(0.7, wood_hash(float3(cell, 9.0))));
        c = lerp(c, room_linear(tone), (1.0 - smoothstep(-aa * 3.0, aa * 3.0, leaf)) * (1.0 - gravel * 0.6));
    }
    float3 n = wood_bump(n0, i.world, (blades - 0.5) * 0.0008 * PARK_METRE * fine + stones * gravel * 0.002 * PARK_METRE);
    return park_lit(i, n, c, lerp(0.95, 0.85, gravel), 0.0, 1.0, 0.0);
}

// A blade of grass, its colour in its vertices and how far up the blade in their alpha, darker
// toward the root, lit from either side and through when the sun is behind it
float4 blade_ps(WoodOut i, bool front : SV_IsFrontFace) : SV_Target0
{
    float3 n = normalize(normalize(i.normal) * (front ? 1.0 : -1.0) + float3(0.0, 0.7, 0.0));
    float h = i.color.a;
    float3 c = i.color.rgb * lerp(0.3, 1.15, h);
    return park_lit_matte(i, n, c, lerp(0.25, 1.0, h), 0.5 * h);
}

// Bark in long grey brown ridges, moss on its shaded side
float4 bark_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / PARK_METRE;
    float ridges = wood_noise(float3(p.x * 30.0, p.y * 3.5, p.z * 30.0)) * 0.7 + wood_noise(float3(p.x * 70.0, p.y * 9.0, p.z * 70.0)) * 0.3;
    float fissure = smoothstep(0.35, 0.62, ridges);
    float3 c = room_linear(lerp(float3(0.17, 0.14, 0.11), float3(0.42, 0.38, 0.33), fissure)) * (0.85 + 0.3 * wood_noise(p * 80.0));
    float moss = saturate(-n0.x * 0.7 + n0.z * 0.3) * smoothstep(0.45, 0.7, wood_fbm(p * 6.0));
    c = lerp(c, room_linear(float3(0.25, 0.32, 0.1)), moss * 0.7);
    float3 n = wood_bump(n0, i.world, fissure * 0.012 * PARK_METRE);
    return park_lit(i, n, c, 0.92, 0.0, lerp(0.55, 1.0, fissure), 0.0);
}

// A leaf, uv across it from its edge to its midrib in x and from stalk to tip in y, its colour in
// its vertices with how far out of its clump it sits in alpha, a pale midrib and veins, lit from
// either side and glowing when the sun is behind it
float4 leaf_ps(WoodOut i, bool front : SV_IsFrontFace) : SV_Target0
{
    float3 n = normalize(i.normal) * (front ? 1.0 : -1.0);
    float2 uv = i.uv;
    float rib = 1.0 - smoothstep(0.0, 0.08, abs(uv.x));
    float vein = 1.0 - smoothstep(0.0, 0.12, abs(frac((uv.y - abs(uv.x) * 0.5) * 6.0) - 0.5));
    float spot = smoothstep(0.75, 0.9, wood_noise(float3(uv * 7.0, i.color.a * 40.0)));
    float3 c = i.color.rgb * (0.9 + 0.25 * rib + 0.08 * vein) * (1.0 - spot * 0.4) * (front ? 1.0 : 0.85);
    return park_lit(i, n, c, 0.5, 0.0, lerp(0.35, 1.0, i.color.a), 0.65);
}

// A card of leaves in a crown, uv across it shifted by whole steps so each card has its own: a few
// leaves scattered over it, each turned its own way and a little lighter or darker, the card cut
// away round them. Its normal faces out of the clump, so the crown shades as one, and its alpha
// says how far out of the clump it sits.
float4 foliage_ps(WoodOut i) : SV_Target0
{
    float2 base = frac(i.uv);
    if (length(base - 0.5) > 0.5) discard;
    float2 q = i.uv * 4.0;
    float2 cell = floor(q - 0.5);
    float best = 1.0e9;
    float pick = 0.0;
    float along = 0.0;
    for (int y = 0; y <= 1; y++)
    {
        for (int x = 0; x <= 1; x++)
        {
            float2 c = cell + float2(x, y);
            float2 o = c + 0.5 + (float2(wood_hash(float3(c, 2.0)), wood_hash(float3(c, 3.0))) - 0.5) * 0.9;
            float a = wood_hash(float3(c, 4.0)) * 6.2832;
            float2 d = q - o;
            d = float2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a));
            float leaf = length(d * float2(1.7, 1.0)) - 0.5 * (0.75 + 0.25 * wood_hash(float3(c, 5.0)));
            if (leaf < best)
            {
                best = leaf;
                pick = wood_hash(float3(c, 6.0));
                along = d.x;
            }
        }
    }
    if (best > 0.0) discard;
    float3 n = normalize(i.normal);
    float3 c = i.color.rgb * lerp(0.75, 1.2, pick) * (1.0 + 0.15 * (1.0 - smoothstep(0.0, 0.05, abs(along))));
    return park_lit_matte(i, n, c, lerp(0.3, 1.0, i.color.a), 0.6);
}

// A fallen leaf lying on the lawn or the table, a card whose uv shift picks its shape, a maple's
// five pointed lobes or an oak's rounded ones, curled a little, with a pale midrib, dry and matt
float4 fallen_ps(WoodOut i, bool front : SV_IsFrontFace) : SV_Target0
{
    float2 p = frac(i.uv) * 2.0 - 1.0;
    float seed = floor(i.uv.x);
    float r = length(p);
    float a = atan2(p.x, -p.y);
    bool maple = frac(seed * 0.37) > 0.5;
    float rim = maple ? 0.42 + 0.52 * pow(abs(cos(a * 2.5)), 3.0) : 0.5 + 0.14 * abs(cos(a * 3.5)) - 0.18 * p.y;
    rim *= 1.0 - 0.25 * smoothstep(0.6, 1.0, abs(p.x));
    if (r > rim) discard;
    float rib = (1.0 - smoothstep(0.0, 0.05, abs(p.x))) * step(p.y, 0.6);
    float3 n = normalize(normalize(i.normal) * (front ? 1.0 : -1.0) + float3(p.x, 0.0, p.y) * 0.25);
    float3 c = i.color.rgb * (0.85 + 0.25 * wood_noise(float3(p * 6.0, seed))) * (1.0 + 0.2 * rib);
    return park_lit(i, n, c, 0.75, 0.0, 1.0, 0.3);
}

// Three hashes from 0 to 1 for lattice cell p, apart enough to place a pore by
float3 concrete_hash(float3 p)
{
    p = frac(p * float3(0.1031, 0.103, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return frac((p.xxy + p.yxx) * p.zyx);
}

// The pore or sand grain of the lattice cell holding q, kept inside its cell so one look finds
// it, its radius from size x to y in cells, mostly small, some drawn out, its rim torn by wobble
// up to size z less one. Returns how far out from its middle q lies, 1 at its rim, a pick from 0
// to 1 for whether the cell holds a pore, a grain or neither, and the grain's shade.
float3 concrete_pore(float3 q, float wobble, float3 size)
{
    float3 cell = floor(q);
    float3 h = concrete_hash(cell);
    float3 k = concrete_hash(cell + 41.0);
    float r = lerp(size.x, size.y, k.x * k.x);
    float3 mid = size.z * r + (1.0 - 2.0 * size.z * r) * h;
    float3 v = (frac(q) - mid) * lerp(1.0, 2.0, h.zxy);
    return float3(lerp(length(v), abs(v.x) + abs(v.y) + abs(v.z), 0.5) / r + wobble, k.z, frac(k.y * 5.3 + h.x));
}

// Weathered cement, pale warm grey: gritty fine relief of raised sand grains, light and dark,
// that catches the low sun over a gentle lumpiness, pores pitting it, chalky pale clouds and
// darker warm stains, and grime from the ground up where rain splashes it. Four noises, and pore
// and sand lattices that cost only hashes, turned askew so no face lies along their grids. Whatever would
// be finer than a pixel fades flat. Values: the cement's grey, and in w the ground's height in
// metres.
float4 concrete_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.local / PARK_METRE;
    float3 a = mul(p, float3x3(0.0, 0.8, 0.6, -0.8, 0.36, -0.48, -0.6, -0.48, 0.64));
    float px = length(fwidth(p));
    float blot = wood_noise(a * 2.5);
    float cloud = wood_noise(a * 11.0 + 5.0);
    float lump = (wood_noise(a * 80.0 + 2.0) - 0.5) * saturate(2.0 - px * 400.0);
    float crumb = (wood_noise(a * 380.0) - 0.5) * saturate(2.0 - px * 1900.0);
    float3 c = room_linear(material[0].rgb) * (0.82 + 0.32 * blot);
    c *= lerp(float3(0.92, 0.88, 0.82), float3(1.0, 1.0, 1.0), smoothstep(0.15, 0.45, blot));
    c *= 1.0 + 0.16 * smoothstep(0.5, 0.8, cloud) + 0.18 * lump + 0.16 * crumb;
    float3 pore = concrete_pore(a * 260.0, crumb * 0.5, float3(0.12, 0.38, 1.3));
    float3 sand = concrete_pore(a * 520.0 + 0.5, crumb * 0.25, float3(0.3, 0.44, 1.13));
    float edge = max(px * 1300.0, 0.05);
    float show = saturate(2.0 - px * 1300.0);
    float hole = pore.y < 0.35 ? saturate((1.0 - pore.x) / edge) * show : 0.0;
    float grain = pore.y > 0.45 ? saturate((0.8 - pore.x) / edge) * show : 0.0;
    float grit = sand.y < 0.75 ? saturate((1.0 - sand.x) / max(px * 1500.0, 0.05)) * saturate(2.0 - px * 2600.0) * (1.0 - hole) : 0.0;
    c *= (1.0 - 0.55 * hole) * (1.0 + grain * (pore.z - 0.5) * 0.7) * (1.0 + grit * (sand.z - 0.5) * 0.5);
    float up = p.y - material[0].w + 0.08 * (blot - 0.5);
    c *= lerp(float3(1.0, 1.0, 1.0), float3(0.6, 0.62, 0.5), 1.0 - smoothstep(0.0, 0.22, up));
    float high = lump * 0.0006 + crumb * 0.0004 + grain * saturate(1.0 - pore.x * pore.x) * 0.0004 + grit * saturate(1.0 - sand.x * sand.x) * 0.0003 - hole * 0.0008;
    float3 n = wood_bump(n0, i.world, high * PARK_METRE);
    return park_lit(i, n, c, 0.92, 0.0, 1.0 - 0.6 * hole, 0.0);
}

// Painted cast iron, worn to the metal at the edges here and there. Values: the paint.
float4 iron_ps(WoodOut i) : SV_Target0
{
    float3 n0 = normalize(i.normal);
    float3 p = i.world / PARK_METRE;
    float chip = smoothstep(0.78, 0.86, wood_noise(p * 90.0));
    float3 c = lerp(room_linear(material[0].rgb), float3(0.25, 0.24, 0.23), chip);
    return park_lit(i, n0, c, lerp(0.45, 0.6, chip), chip * 0.6, 1.0, 0.0);
}

// Far woods round the park, a band of trees whose crowns break against the sky, their trunks and
// shadows showing low, hazed blue with the distance. uv goes round the band in x and down it in y.
float4 woods_ps(WoodOut i, bool front : SV_IsFrontFace) : SV_Target0
{
    float3 lp = i.local;
    float u = i.uv.x;
    float high = 1.0 - i.uv.y;
    float seed = material[0].y + i.color.a * 7.0;
    float x = u * 150.0;
    float crowns = 0.0;
    float which = 0.0;
    for (int k = -1; k <= 1; k++)
    {
        float t = floor(x) + k;
        float top = 0.45 + 0.3 * wood_hash(float3(t, seed, 1.0));
        float wide = 0.7 + 0.6 * wood_hash(float3(t, seed, 2.0));
        float d = (x - t - 0.5) / wide;
        float crown = top + 0.22 * sqrt(saturate(1.0 - d * d)) - 0.3 * saturate(abs(d) - 1.0);
        if (crown > crowns)
        {
            crowns = crown;
            which = wood_hash(float3(t, seed, 3.0));
        }
    }
    crowns += 0.03 * wood_noise(float3(u * 900.0, high * 40.0, seed));
    if (high > crowns) discard;
    float mix_ = wood_fbm(float3(u * 35.0, high * 4.0, seed));
    float3 tone = lerp(float3(0.14, 0.2, 0.07), float3(0.36, 0.3, 0.11), smoothstep(0.35, 0.65, mix_));
    tone = lerp(tone, float3(0.4, 0.2, 0.08), smoothstep(0.62, 0.75, wood_fbm(float3(u * 22.0, high * 3.0, seed + 5.0))) * 0.6);
    float leaves = wood_fbm(float3(u * 500.0, high * 60.0, seed));
    float3 c = tone * (0.55 + 0.7 * leaves);
    float trunks = smoothstep(0.6, 0.7, wood_noise(float3(u * 900.0, 0.0, seed))) * (1.0 - smoothstep(0.15, 0.35, high));
    c = lerp(c, float3(0.06, 0.05, 0.04), trunks);
    c = room_linear(c) * lerp(0.55, 1.0, smoothstep(crowns - 0.3, crowns, high));
    float3 n = normalize(float3(-lp.x, 0.0, -lp.z));
    return park_lit(i, n, c, 0.95, 0.0, 0.8, 0.3);
}

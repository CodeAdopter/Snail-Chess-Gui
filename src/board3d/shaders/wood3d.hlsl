// Wood for the 3D board and its pieces, under a lacquer, lit by the sun with a soft shadow, the sky
// and ground, and a soft room round the board that the lacquer mirrors. Grain is worked out in the
// wood's own space, rings round a log's axis swayed by noise, thin dark late wood, fine fibres and
// pores along the grain and a soft figure, so it never swims as a piece moves. The grain's late
// wood and pores sit a hair lower than the rest, so the grain catches the light.

#include "C:/Snail/Snail Engine/engine/shaders/three.hlsli"
#include "C:/Snail/Snail Engine/engine/shaders/three_standard.hlsli"
#include "lamps3d.hlsli"

// Three's pixel input, plus the point in the mesh's own space and where the mesh stands, which
// picks the part of the log a piece is cut from.
struct WoodOut
{
    float4 position : SV_Position;
    float3 world : TEXCOORD0;
    float3 normal : TEXCOORD1;
    float4 color : TEXCOORD2;
    float2 uv : TEXCOORD3;
    float depth : TEXCOORD4;
    float4 shadow0 : TEXCOORD5;
    float4 shadow1 : TEXCOORD6;
    float4 shadow2 : TEXCOORD7;
    float3 local : TEXCOORD8;
    float3 seed : TEXCOORD9;
    float flip : TEXCOORD10;
};

// A further image of the material's, after the shadow maps: the pieces mirrored under a polished
// board, or what lies behind glass.
Texture2D<float4> extra_texture : register(t4, space2);
SamplerState extra_sampler : register(s4, space2);

// What the field knows of the board beyond its values, read by the boards and the pieces: x how
// many feet there are, y the square whose king is in check, below 0 for none, z how many pieces
// effects show on and w the burning clock in seconds, then where each piece stands, its x and z,
// how high it is held and how wide its foot is, then each square's stain, an sRGB colour and how
// strongly it shows, the squares counted from a1 along the ranks. Then for each piece effects show
// on its origin and moss, how charred it is, its glint, how far it has burnt away and how high
// it burns, and its fire's colour, then the last move's dust (x, z, seconds, strength), its trail
// from x, z to x, z with its seconds, how far its piece has come, strength and length, and the
// burn where it took (x, z, seconds, strength).
cbuffer WoodField : register(b2, space3)
{
    float4 field_counts;
    float4 field_feet[33];
    float4 field_stains[64];
    float4 field_spots[33];
    float4 field_wear[33];
    float4 field_hues[33];
    float4 field_moves[4];
};

// Light the effects give off at the pixel, added past its lighting
static float3 fx_glow = float3(0.0, 0.0, 0.0);

WoodOut wood_vs(ThreeIn i)
{
    ThreeOut t = three_vs(i);
    WoodOut o;
    o.position = t.position;
    o.world = t.world;
    o.normal = t.normal;
    o.color = t.color;
    o.uv = t.uv;
    o.depth = t.depth;
    o.shadow0 = t.shadow0;
    o.shadow1 = t.shadow1;
    o.shadow2 = t.shadow2;
    o.local = i.position;
    o.seed = i.model3.xyz;
    // a piece drawn upside down under the board, as a polished board mirrors it, is lit where it
    // really stands, seen from the eye mirrored under the board
    o.flip = i.model1.y < 0.0 ? 1.0 : 0.0;
    if (o.flip > 0.5)
    {
        o.world.y = -o.world.y;
        o.normal.y = -o.normal.y;
    }
    return o;
}

float wood_hash(float3 p)
{
    p = frac(p * 0.3183099 + 0.1);
    p *= 17.0;
    return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float wood_noise(float3 x)
{
    float3 i = floor(x);
    float3 f = frac(x);
    f = f * f * (3.0 - 2.0 * f);
    float a = lerp(lerp(wood_hash(i), wood_hash(i + float3(1, 0, 0)), f.x), lerp(wood_hash(i + float3(0, 1, 0)), wood_hash(i + float3(1, 1, 0)), f.x), f.y);
    float b = lerp(lerp(wood_hash(i + float3(0, 0, 1)), wood_hash(i + float3(1, 0, 1)), f.x), lerp(wood_hash(i + float3(0, 1, 1)), wood_hash(i + float3(1, 1, 1)), f.x), f.y);
    return lerp(a, b, f.z);
}

float wood_fbm(float3 p)
{
    float s = 0.0;
    float a = 0.5;
    for (int k = 0; k < 4; k++)
    {
        s += a * wood_noise(p);
        p = p * 2.03 + 1.7;
        a *= 0.5;
    }
    return s;
}

// Wood as the grain leaves it, its colour, how far its surface sits below the rest in parts of the
// lacquer's bump, and how much rougher it is there.
struct Wood
{
    float3 color;
    float low;
    float rough;
};

// Wood at q with the log's axis along x, rings so many to a square, the early wood as given and
// the late wood darker and browner by strength, with pores as short dark dashes along the grain.
// Whatever would be finer than a pixel fades to its average, so the grain never shimmers.
Wood wood_at(float3 q, float3 early, float rings, float strength)
{
    float sway = wood_fbm(float3(q.x * 0.35, q.y * 1.8, q.z * 1.8)) - 0.5;
    float wobble = wood_noise(float3(q.x * 2.3, q.y * 11.0, q.z * 11.0)) - 0.5;
    float r = (length(q.yz) + sway * 0.09 + wobble * 0.01) * rings;
    float ring = frac(r);
    float blur = saturate(fwidth(r) * 2.5 - 0.4);
    float late = smoothstep(0.48, 0.8, ring) * (1.0 - smoothstep(0.88, 1.0, ring));
    late = lerp(late, 0.3, blur);
    float fine = saturate(1.0 - length(fwidth(q.yz)) * 50.0);
    float fibre = (wood_noise(float3(q.x * 5.0, q.y * 70.0, q.z * 70.0)) - 0.5) * fine;
    float3 pq = float3(q.x * 7.0, q.y * 55.0, q.z * 55.0);
    float tiny = saturate(1.5 - length(fwidth(pq.yz)) * 1.2);
    float pore = smoothstep(0.7, 0.86, wood_noise(pq)) * tiny * (0.4 + 0.6 * late);
    float figure = wood_fbm(float3(q.x * 1.3, q.y * 9.0, q.z * 9.0));
    float3 c = lerp(early, early * float3(0.68, 0.6, 0.54), late * strength);
    c *= 1.0 + strength * (0.24 * (figure - 0.5) + 0.15 * fibre);
    c *= 1.0 - 0.45 * pore * strength;
    Wood w;
    w.color = c;
    w.low = late * 0.6 * (1.0 - blur) + pore * 0.6 + fibre * 0.25;
    w.rough = late * 0.08 + pore * 0.25;
    return w;
}

// Normal n bent so a surface raised by high world lengths at point p catches the light, from how
// high changes across the pixel.
float3 wood_bump(float3 n, float3 p, float high)
{
    float3 dpx = ddx(p);
    float3 dpy = ddy(p);
    float3 r1 = cross(dpy, n);
    float3 r2 = cross(n, dpx);
    float det = dot(dpx, r1);
    if (abs(det) < 1e-12) return n;
    float3 grad = sign(det) * (ddx(high) * r1 + ddy(high) * r2);
    return normalize(abs(det) * n - grad);
}

// The sun's shadow at the pixel, sixteen reads on a spiral each blended between texels, so its
// edge goes soft over several texels. While glass pieces stand and no lamps are lit, their own
// map lets half the sun through.
float wood_shadow(WoodOut i)
{
    if (lights.sun_through.x > 0.5) return sun_shadow(i.shadow0, i.shadow1, i.shadow2);
    float lit = lamp_shadow(0, i.shadow0);
    if (lamp_count() == 0 && lights.shadow[1].x > 0.5) lit *= lerp(0.5, 1.0, lamp_shadow(1, i.shadow1));
    return lit;
}

// Karis' fit of how much of the room a rough surface mirrors at a slant, as a scale and bias on its
// colour at a head on look.
float2 wood_env_brdf(float rough, float nv)
{
    float4 r = rough * float4(-1.0, -0.0275, -0.572, 0.022) + float4(1.0, 0.0425, 1.04, -0.04);
    float a = min(r.x * r.x, exp2(-9.28 * nv)) * r.x + r.y;
    return float2(-1.04, 1.04) * a + r.zw;
}

// The room the lamps light, seen the way r points, as blurred as rough: a dim warm surround,
// darker below, and a soft glow toward each lamp as bright as it shines on the board, weighed by
// the lamp room's strength.
float3 wood_lamp_room(float3 r, float rough)
{
    float3 c = lerp(float3(0.02, 0.016, 0.012), float3(0.06, 0.05, 0.04), smoothstep(-0.4, 0.5, r.y)) * lights.lamp_room.y;
    float sharp = lerp(90.0, 2.0, rough);
    for (int k = 0; k < lamp_count(); k++)
    {
        float3 way = normalize(lights.lamps[k].xyz);
        c += lamp_glow(k, float3(0.0, 0.0, 0.0)) * pow(saturate(dot(r, way)), sharp) * (sharp + 1.0) * lights.lamp_room.z;
    }
    return c;
}

// The room the board stands in, seen the way r points, as blurred as rough: a dim warm wall all
// round, a broad soft panel overhead, a tall strip beside the eye on the sun's side and a low warm
// glow behind the board, which rims the pieces against the squares.
float3 wood_room(float3 r, float rough)
{
    if (lamp_count() > 0) return wood_lamp_room(r, rough);
    if (lights.sun_through.y > 0.0) return sky_room(r, rough);
    float3 eye = normalize(float3(lights.eye.x, 0.0, lights.eye.z) + float3(0.0001, 0.0, 0.0));
    float3 side = normalize(float3(three_sun_way().x, 0.0, three_sun_way().z));
    float soft = 0.08 + rough * 0.5;
    float3 c = lerp(float3(0.05, 0.04, 0.035), float3(0.22, 0.2, 0.18), smoothstep(-0.3, 0.6, r.y));
    c += float3(0.9, 0.86, 0.8) * smoothstep(0.82 - soft, 0.92, r.y);
    float h = length(r.xz) + 0.0001;
    float strip = smoothstep(0.75 - soft, 0.95, dot(r.xz / h, side.xz)) * smoothstep(-0.1 - soft, 0.15, r.y) * (1.0 - smoothstep(0.55, 0.75 + soft, r.y));
    c += float3(0.75, 0.7, 0.62) * strip;
    float back = smoothstep(0.55 - soft, 0.95, dot(r.xz / h, -eye.xz)) * smoothstep(-0.2 - soft, 0.1, r.y) * (1.0 - smoothstep(0.35, 0.6 + soft, r.y));
    c += float3(0.6, 0.45, 0.3) * back;
    return c;
}

// A lacquered surface of colour c facing n, the wood beneath of roughness rough and the lacquer of
// weight coat and roughness gloss, its open light shaded by ao and its sun by sun_shade beyond the
// shadow map, lit by the sun and the lamps and fogged. Its alpha is how far ahead of the eye it
// is, which the lens of a room reads to blur what is out of focus.
float4 wood_lit_seen(WoodOut i, float3 n, float3 c, float rough, float coat, float gloss, float ao, float sun_shade, float4 seen)
{
    float3 eye = three_eye();
    if (i.flip > 0.5) eye.y = -eye.y;
    float3 v = normalize(eye - i.world);
    float3 l = three_sun_way();
    float nv = saturate(dot(n, v));
    float nl = saturate(dot(n, l));
    float3 sun = lights.sun_color.rgb * wood_shadow(i) * sun_shade;
    float3 rl = reflect(-v, n);
    float3 lit = sun * nl * c;
    lit += three_hemisphere(n) * THREE_RECIPROCAL_PI * c * ao;
    float2 ab = wood_env_brdf(rough, nv);
    lit += sun * nl * THREE_PI * three_specular_ggx(l, v, n, float3(0.04, 0.04, 0.04), rough) * (1.0 - coat * 0.7);
    lit += wood_room(rl, rough) * (0.04 * ab.x + ab.y) * ao * (1.0 - coat * 0.7);
    float3 top = sun * nl * THREE_PI * three_specular_ggx(l, v, n, float3(0.04, 0.04, 0.04), gloss);
    for (int k = 0; k < lamp_count(); k++)
    {
        float3 lk;
        float3 e = lamp_light(k, i.world, i.shadow0, i.shadow1, i.shadow2, lk) * saturate(dot(n, lk));
        lit += e * c + e * THREE_PI * three_specular_ggx(lk, v, n, float3(0.04, 0.04, 0.04), rough) * (1.0 - coat * 0.7);
        top += e * THREE_PI * three_specular_ggx(lk, v, n, float3(0.04, 0.04, 0.04), gloss);
    }
    float fc = 0.04 + 0.96 * pow(1.0 - nv, 5.0);
    lit *= 1.0 - coat * fc;
    float2 cb = wood_env_brdf(gloss, nv);
    top += (wood_room(rl, gloss) * (1.0 - seen.a) + seen.rgb) * (0.04 * cb.x + cb.y) * lerp(1.0, ao, 0.6);
    lit += top * coat;
    lit += fx_glow;
    // a mirrored piece's alpha is its cover, which the board it is mirrored in reads
    return float4(three_fog_at(lit, i.depth, i.world), i.flip > 0.5 ? 1.0 : i.depth);
}

float4 wood_lit(WoodOut i, float3 n, float3 c, float rough, float coat, float gloss, float ao, float sun_shade)
{
    return wood_lit_seen(i, n, c, rough, coat, gloss, ao, sun_shade, float4(0.0, 0.0, 0.0, 0.0));
}

// What a polished board mirrors at the pixel, the pieces drawn upside down beneath it into the
// extra image at the scene's size, lit linear with their cover in alpha, read a little aside as
// the surface tilts and blurred over more of the image the rougher it is.
float4 wood_mirror(WoodOut i, float3 n, float rough)
{
    float2 size;
    extra_texture.GetDimensions(size.x, size.y);
    float2 uv = i.position.xy / size + float2(n.x, -n.z) * 0.015;
    float2 spread = rough * 0.012 * float2(size.y / size.x, 1.0);
    float4 sum = extra_texture.SampleLevel(extra_sampler, uv, 0.0) * 0.28;
    for (int k = 0; k < 6; k++)
    {
        float a = k * 1.0472 + 0.3;
        sum += extra_texture.SampleLevel(extra_sampler, uv + float2(cos(a), sin(a)) * spread, 0.0) * 0.12;
    }
    return sum;
}

// What the effects lay on the board at the pixel over its colour c: moss spreading round the foot
// of a mossy piece, soot and the light of the fire round one that burns, dust thrown in a ring from
// where the last move landed, a streak of light along its way, and the burn where it took. The
// fire's light and the streak's glow go into fx_glow, past the lighting.
void field_effects(WoodOut i, inout float3 c)
{
    float2 at = i.world.xz;
    float t = field_counts.w;
    for (int k = 0; k < (int)field_counts.z; k++)
    {
        float4 spot = field_spots[k];
        float4 wear = field_wear[k];
        float r = length(at - spot.xz);
        if (spot.w > 0.0 && r < 0.6)
        {
            float nz = wood_fbm(float3(at * 9.0, 1.7)) - 0.5;
            float reach = 0.24 + spot.w * 0.14;
            float cover = smoothstep(reach, reach - 0.08, r + nz * 0.14) * smoothstep(0.1, 0.4, spot.w);
            float tuft = wood_noise(float3(at * 70.0, 4.3));
            float3 green = lerp(three_srgb_to_linear(float3(0.07, 0.12, 0.03)), three_srgb_to_linear(float3(0.24, 0.32, 0.08)), tuft);
            c = lerp(c, green, cover * (0.75 + 0.25 * tuft));
        }
        if (wear.w > 0.0)
        {
            float flicker = 0.8 + 0.2 * sin(t * 9.0 + k * 1.7) * sin(t * 5.3 + k);
            float scorch = smoothstep(0.5, 0.16, r + (wood_fbm(float3(at * 7.0, 2.3)) - 0.5) * 0.15) * wear.w;
            c *= 1.0 - scorch * 0.55;
            fx_glow += field_hues[k].rgb * wear.w * flicker * exp(-r * r * 3.5) * 0.55;
        }
    }
    float4 dust = field_moves[0];
    if (dust.w > 0.0 && dust.z >= 0.0)
    {
        float life = saturate(dust.z / 0.8);
        float ease = 1.0 - pow(1.0 - life, 3.0);
        float r = length(at - dust.xy);
        float ring_at = 0.32 + ease * 0.9;
        float ring = exp(-pow((r - ring_at + (wood_fbm(float3(at * 6.0, t)) - 0.5) * 0.1) / (0.04 + 0.12 * ease), 2.0)) * pow(1.0 - life, 1.5);
        c = lerp(c, three_srgb_to_linear(float3(0.8, 0.74, 0.64)), ring * 0.4 * dust.w);
    }
    float4 from_to = field_moves[1];
    float4 trail = field_moves[2];
    if (trail.z > 0.0 && trail.x >= 0.0)
    {
        float2 a = from_to.xy;
        float2 ab = from_to.zw - a;
        float span = max(length(ab), 0.001);
        float2 way = ab / span;
        float along = dot(at - a, way) / span;
        float across = abs(dot(at - a, float2(-way.y, way.x)));
        float behind = trail.y - along;
        float life = saturate(trail.x / max(trail.w, 0.01));
        float tail = saturate(1.0 - behind * (0.6 + life * 2.4));
        float shown = smoothstep(-0.02, 0.01, behind) * smoothstep(-0.12, 0.0, along);
        float w = 0.2 * (0.25 + 0.75 * tail);
        float glow = exp(-pow(across / (w * 0.3), 2.0)) + exp(-pow(across / w, 2.0)) * 0.4;
        fx_glow += lerp(float3(1.0, 0.6, 0.25), float3(1.0, 0.9, 0.7), saturate(glow - 0.4)) * glow * shown * tail * pow(1.0 - life, 1.4) * trail.z * 0.9;
    }
    float4 burn = field_moves[3];
    if (burn.w > 0.0 && burn.z >= 0.0)
    {
        float r = length(at - burn.xy);
        float grown = saturate(burn.z / 0.35);
        float scorch = smoothstep(0.38, 0.12, r + (wood_fbm(float3(at * 8.0, 5.1)) - 0.5) * 0.18) * grown * burn.w;
        c *= 1.0 - scorch * 0.5;
        float embers = pow(saturate(wood_noise(float3(at * 40.0, t * 2.0))), 6.0) * scorch * saturate(1.0 - burn.z / 1.2);
        fx_glow += float3(1.0, 0.35, 0.05) * embers * 3.0;
    }
}

// The squares' stains, the check's glow under its king and the shade round each piece's foot laid
// over c, the colour of the square at cell, f across it, edge from its nearest side, whose own
// colour is base. Gives the shade the feet cast.
float field_marks(WoodOut i, float2 cell, float2 f, float edge, float3 base, inout float3 c)
{
    // an edge pixel a hair past the field reads its nearest square, never past the stains
    int square = clamp((int)(7.0 - cell.y), 0, 7) * 8 + clamp((int)cell.x, 0, 7);
    float4 stain = field_stains[square];
    if (stain.a > 0.0)
    {
        float wash = stain.a * (0.75 + 0.25 * (1.0 - smoothstep(0.0, 0.16, edge)));
        c = lerp(c, three_srgb_to_linear(stain.rgb) * (0.6 + 0.6 * dot(c, float3(0.3, 0.55, 0.15)) / max(dot(base, float3(0.3, 0.55, 0.15)), 0.001)), wash);
    }
    if ((int)field_counts.y == square)
    {
        float glow = 1.0 - smoothstep(0.3, 0.68, length(f - 0.5));
        c = lerp(c, float3(0.75, 0.06, 0.03), glow * 0.85);
    }
    float ao = 1.0;
    for (int k = 0; k < (int)field_counts.x; k++)
    {
        float4 foot = field_feet[k];
        float d = max(length(i.world.xz - foot.xy) - foot.w * 0.7, 0.0) / (foot.w * 0.9);
        ao *= 1.0 - 0.6 * exp(-d * d) / (1.0 + foot.z * 8.0);
    }
    field_effects(i, c);
    return ao;
}

// Burl's figure where it is asked for, q moved so the grain swirls round small knots, and how much
// of a knot's dark eye shows there. Strong it is burl walnut's tangle, weak bird's eye maple's
// scattered dimples in straight grain.
float3 wood_burl(float3 q, float amount, out float eye)
{
    eye = 0.0;
    if (amount <= 0.0) return q;
    float3 w = float3(wood_fbm(q * 2.7), wood_fbm(q * 2.7 + 7.3), wood_fbm(q * 2.7 + 13.7)) - 0.5;
    q += w * amount * 1.4;
    float3 e = q * 9.0 / max(amount, 0.35);
    float n = wood_noise(e) * 0.7 + wood_noise(e * 2.3 + 4.1) * 0.3;
    float fine = saturate(1.6 - length(fwidth(e)) * 1.2);
    eye = smoothstep(0.66, 0.8, n) * fine;
    q.yz += eye * 0.05;
    return q;
}

// The playing field, uv across it from 0 to 1 with a8 at its far left, maple and walnut squares,
// each cut from its own part of the log with its grain along the files, the walnut cut on a slight
// slant through the rings so they show as arches and the maple curled, a fine dark joint between
// them, the shade round each piece's foot and the squares' stains. Values: the light wood, the dark
// wood and the frame's wood as rgb, their w the lacquer's weight, its roughness and how deep the
// grain sits, then x roughness, y rings to a square, z how strongly the grain shows and w how much
// burl figure there is.
float4 board_ps(WoodOut i) : SV_Target0
{
    float2 at = i.uv * 8.0;
    float2 cell = min(floor(at), 7.0);
    float2 f = at - cell;
    float rank = 7.0 - cell.y;
    bool dark = fmod(cell.x + rank, 2.0) < 0.5;
    float seed = wood_hash(float3(cell, 3.0));
    float across = wood_hash(float3(cell, 9.0)) - 0.5;
    float3 early = three_srgb_to_linear(dark ? material[1].rgb : material[0].rgb);
    early *= 0.95 + 0.1 * wood_hash(float3(cell, 5.0));
    float tilt = dark ? 0.06 + 0.12 * wood_hash(float3(cell, 7.0)) : 0.0;
    float3 q = float3(f.x + seed * 23.0, 0.35 + seed * 1.3 + (f.x - 0.5) * tilt, f.y - 0.5 + across * 2.0);
    float eye;
    q = wood_burl(q, material[3].w * (dark ? 1.0 : 0.25), eye);
    Wood w = wood_at(q, early, material[3].y * (dark ? 1.0 : 1.4), material[3].z * (dark ? 1.0 : 0.55));
    float3 c = w.color * (1.0 - eye * (dark ? 0.55 : 0.3));
    float3 v = normalize(three_eye() - i.world);
    float curl = sin(q.x * 44.0 + wood_fbm(q * float3(2.0, 6.0, 6.0)) * 9.0);
    float shimmer = saturate(1.0 - fwidth(q.x * 44.0) * 0.5);
    if (!dark) c *= 1.0 + 0.07 * curl * v.x * shimmer;
    float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
    float joint = smoothstep(0.0, fwidth(at.x) + 0.004, edge);
    c *= lerp(0.5, 1.0, joint);
    float ao = field_marks(i, cell, f, edge, early, c);
    float3 n = wood_bump(normalize(i.normal), i.world, -w.low * material[2].w * joint);
    return wood_lit(i, n, c, material[3].x + w.rough, material[0].w, material[1].w, ao, lerp(0.75, 1.0, ao));
}

// The coordinates on the frame's top, the files along the near and far sides and the ranks down
// the left and right, each a raised maple letter turned upright for the eye. A letter's cell is
// this many squares across, its middle this far out from the field.
static const float CoordCell = 0.34;
static const float CoordOut = 0.31;

// How far point p on the frame's top lies outside the nearest letter, in squares, below 0 inside
// it, and a little past the letter's reach where there is none, the atlas read at mip lod.
float coord_distance(float2 p, float2 up, float2 right, float lod)
{
    float2 centre;
    float glyph;
    if (abs(p.x) < 4.0 && abs(p.y) > 4.0)
    {
        float file = clamp(floor(p.x + 4.0), 0.0, 7.0);
        centre = float2(file - 3.5, sign(p.y) * (4.0 + CoordOut));
        glyph = file;
    }
    else if (abs(p.y) < 4.0 && abs(p.x) > 4.0)
    {
        float rank = clamp(floor(4.0 - p.y), 0.0, 7.0);
        centre = float2(sign(p.x) * (4.0 + CoordOut), 3.5 - rank);
        glyph = 8.0 + rank;
    }
    else return 0.05;
    float2 d = p - centre;
    float2 uv = float2(dot(d, right), dot(d, up)) / CoordCell + 0.5;
    if (any(uv < 0.0) || any(uv > 1.0)) return 0.05;
    float col = fmod(glyph, 4.0);
    float row = floor(glyph / 4.0);
    float s = material_texture.SampleLevel(material_sampler, float2(col + uv.x, row + 1.0 - uv.y) * 0.25, lod).r;
    return (0.5 - s) * 2.0 * (10.0 / 96.0) * CoordCell - 0.0015;
}

// A frame's wood, uv along each side and out from the field, its grain along the side, a thin
// maple stringing inlaid in its top a little out from the field, and the coordinates, raised from
// its top and turned upright for the eye, or printed flat in the light wood's colour, each side's
// turned to read from that side. Values as the field's.
float4 frame_lit(WoodOut i, bool printed)
{
    float3 n = normalize(i.normal);
    float3 early = three_srgb_to_linear(material[2].rgb);
    float3 q = float3(i.uv.x, i.world.y + 0.9, i.uv.y - 0.3);
    float eye;
    q = wood_burl(q, material[3].w, eye);
    Wood w = wood_at(q, early, material[3].y * 0.8, material[3].z);
    float3 c = w.color * (1.0 - eye * 0.55);
    float top = step(0.9, n.y);
    float aa = fwidth(i.uv.y) + 0.002;
    float inlay = (smoothstep(0.07 - aa, 0.07, i.uv.y) - smoothstep(0.09, 0.09 + aa, i.uv.y)) * top;
    Wood maple = wood_at(float3(i.uv.x * 3.0, 0.6, i.uv.y * 2.0), three_srgb_to_linear(material[0].rgb) * 1.05, material[3].y * 1.4, material[3].z * 0.5);
    c = lerp(c, maple.color, inlay);
    float2 p = i.world.xz;
    float2 seat = lights.eye.xz;
    float2 up = abs(seat.y) >= abs(seat.x) ? float2(0.0, -sign(seat.y)) : float2(-sign(seat.x), 0.0);
    if (printed) up = abs(p.y) > 4.0 && abs(p.x) < 4.0 ? float2(0.0, -sign(p.y)) : float2(-sign(p.x), 0.0);
    float2 right = float2(-up.y, up.x);
    float lod = max(log2(sqrt(length(ddx(p)) * length(ddy(p))) * 96.0 / CoordCell), 0.0);
    float d = coord_distance(p, up, right, lod);
    float aw = fwidth(d) + 0.0008;
    float inside = smoothstep(aw, -aw, d) * top;
    if (printed)
    {
        c = lerp(c, maple.color * 1.15, inside);
        n = wood_bump(n, i.world, -w.low * material[2].w * (1.0 - inlay) * (1.0 - inside));
        return wood_lit(i, n, c, material[3].x + w.rough + inside * 0.15, material[0].w, material[1].w, 1.0, 1.0);
    }
    float bevel = max(0.012, aw * 1.5);
    float sun_shade = 1.0;
    if (top > 0.5 && d < 0.04)
    {
        float h = 0.0035;
        float dx = coord_distance(p + right * h, up, right, lod) - coord_distance(p - right * h, up, right, lod);
        float dy = coord_distance(p + up * h, up, right, lod) - coord_distance(p - up * h, up, right, lod);
        float2 grad = (right * dx + up * dy) / (2.0 * h);
        float slope = 0.009 / bevel * (1.0 - smoothstep(0.0, bevel * 0.5, abs(d + bevel * 0.5)));
        n = normalize(float3(0.0, 1.0, 0.0) + float3(grad.x, 0.0, grad.y) * slope);
        float2 sun = normalize(three_sun_way().xz + 0.0001);
        float cast = smoothstep(0.004, -0.004, coord_distance(p + sun * 0.016, up, right, lod));
        sun_shade = 1.0 - 0.65 * cast * (1.0 - inside);
        c *= 1.0 - 0.3 * smoothstep(0.014, 0.0, d) * (1.0 - inside);
    }
    c = lerp(c, maple.color * 0.95, inside);
    float low = w.low * material[2].w * (1.0 - inlay) * (1.0 - inside);
    n = wood_bump(n, i.world, -low);
    return wood_lit(i, n, c, material[3].x + w.rough, material[0].w, material[1].w, 1.0, sun_shade);
}

float4 frame_ps(WoodOut i) : SV_Target0
{
    return frame_lit(i, false);
}

float4 print_frame_ps(WoodOut i) : SV_Target0
{
    return frame_lit(i, true);
}


#include "piecefx3d.hlsli"

// Wood turned on a lathe at q, the log's axis along x, going from early wood to late wood across
// each ring, rings so many to a square and of uneven width, the late wood ending sharply where
// the next year starts. How open the grain is runs from close grained boxwood at 0, faint and
// even, to rosewood at 1, wide dark late wood, each year's wood a shade apart, dark streaks along
// the grain and pores as thin dashes along it, one to a cell of a lattice in some of the cells.
// Strength scales all of that. Silky fibres show up close where side tells the surface runs along
// the grain, as on end grain they would be finer than the eye sees. Whatever would be finer than
// a pixel fades to its average, so the grain never shimmers. A lacquer fills the grain, so nothing
// sits lower: a bump read from the grain broke the gloss into specks up close.
Wood turned_wood(float3 q, float3 early, float3 late, float rings, float open, float strength, float side)
{
    float sway = wood_fbm(float3(q.x * 0.35, q.y * 1.8, q.z * 1.8)) - 0.5;
    float wobble = wood_noise(float3(q.x * 2.3, q.y * 11.0, q.z * 11.0)) - 0.5;
    float rr = (length(q.yz) + sway * 0.09 + wobble * 0.01) * rings;
    float r = rr + wood_noise(float3(rr * 0.3, 3.1, 7.7)) * 1.5;
    float ring = frac(r);
    float fw = fwidth(r);
    float blur = saturate(fw * 2.5 - 0.4);
    float band = smoothstep(lerp(0.6, 0.45, open), 0.9, ring) * (1.0 - smoothstep(1.0 - max(fw * 1.5, 0.03), 1.0, ring));
    band = lerp(band, lerp(0.15, 0.3, open), blur);
    float3 c = lerp(early, late, band);
    float tone = lerp(0.08, 0.5, open) * strength * (1.0 - blur);
    c *= 1.0 + (wood_hash(float3(floor(r), 5.3, 1.9)) - 0.5) * tone * float3(1.1, 0.9, 0.8);
    c *= 1.0 - lerp(0.06, 0.3, open) * strength * smoothstep(0.55, 0.75, wood_fbm(float3(q.x * 0.6, q.y * 16.0, q.z * 16.0)));
    float3 fq = float3(q.x * 3.0, q.y * 150.0, q.z * 150.0);
    float across = length(fwidth(fq.yz));
    float fibre = (wood_noise(fq) - 0.5) * saturate(1.6 - across) + (wood_noise(fq * 0.4 + 3.1) - 0.5) * saturate(1.6 - across * 0.4);
    c *= 1.0 + 0.12 * fibre * side;
    float3 pc = q * float3(8.0, 60.0, 60.0);
    float3 cell = floor(pc);
    float3 f = frac(pc);
    float h = wood_hash(cell + 0.17);
    float2 at = 0.3 + 0.4 * float2(wood_hash(cell.zxy + 3.7), wood_hash(cell.yzx + 9.1));
    float width = 0.1 + 0.08 * h;
    float d = length(float2(length(f.yz - at), max(abs(f.x - 0.5) - 0.2 - 0.2 * h, 0.0) * 7.5));
    float aa = max(length(fwidth(pc.yz)), 1e-4);
    float dash = lerp(width * 1.2, 1.0 - smoothstep(width - aa, width + aa, d), saturate(width / aa - 0.3)) * step(h, 0.5 * open);
    c *= 1.0 - 0.6 * strength * dash;
    Wood w;
    w.color = c;
    w.low = 0.0;
    w.rough = band * 0.08 + dash * 0.2;
    return w;
}

// A piece, turned from a billet whose log ran up it, the log's axis off to one side so the rings
// show as gently curving bands, each piece cut from its own part of the log. Light pieces are
// boxwood, the tint their early wood, close grained with faint golden rings. Dark ones are
// rosewood, their early wood a redder, lighter tint and their late wood a deep warm brown, rings of
// uneven shades, dark streaks and open pores. The tint's alpha picks the part of the log, so a
// piece keeps its grain as it moves. Its foot is shaded where it meets the board. Values: x
// roughness, y rings to a square and z how strongly the grain shows, then the lacquer's weight and
// roughness on light wood and on dark.
float4 piece_ps(WoodOut i) : SV_Target0
{
    PieceFx fx = piece_fx(i);
    float seed = wood_hash(float3(i.color.a * 97.0, 0.37, 1.3));
    float3 p = i.local;
    float3 q = float3(p.y + seed * 19.0, p.x - 0.45 - seed * 0.5, p.z + 0.25 - seed * 0.5);
    float light = smoothstep(0.05, 0.3, dot(i.color.rgb, float3(0.3, 0.55, 0.15)));
    float3 tint = i.color.rgb;
    float strength = material[0].z;
    float3 early = tint * lerp(float3(1.45, 1.3, 1.15), float3(1.0, 1.0, 1.0), light);
    float3 late = lerp(early, tint * lerp(float3(0.58, 0.47, 0.42), float3(0.8, 0.7, 0.56), light), saturate(strength));
    float side = 1.0 - smoothstep(0.5, 0.9, abs(normalize(i.normal).y));
    Wood w = turned_wood(q, early, late, material[0].y, 1.0 - light, strength, side);
    float coat = lerp(material[1].z, material[1].x, light);
    float gloss = lerp(material[1].w, material[1].y, light);
    float lift = max(i.world.y - p.y, 0.0);
    float ao = 1.0 - 0.45 * exp(-p.y / 0.05) / (1.0 + lift * 8.0);
    return piece_fx_over(i, fx, wood_lit(i, normalize(i.normal), w.color, material[0].x + w.rough, coat, gloss, ao, 1.0));
}

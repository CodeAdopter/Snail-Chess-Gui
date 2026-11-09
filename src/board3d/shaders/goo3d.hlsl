// Goo pieces for the 3D board: each piece a jelly of slime, lime for white and violet for black,
// what lies behind it seen bent and clouded through its body as glass shows it, with bubbles
// hanging inside and a wet gloss over it. It wobbles as it stands and goo creeps down its sides in
// runs that swell into a bead at their front. The board scene leans and squashes a piece through
// its matrix, a shear of how far its top goes for each unit of height and its scale, so its shadow
// leans with it, and the vertex shader turns the lean into a bend growing with height, the foot
// held where it stands. The puddle under a piece and the strand hanging from one carried are drawn
// with it through goo_drop_vs. Values as glass reads them: white's slime as sRGB and how rough,
// black's the same, then the board's squares.

#include "glass3d.hlsl"

// The field again as the vertex shader reads it, the same bytes at b2 space1, for its clock past the
// rest: x the seconds the goo has run
cbuffer GooField : register(b2, space1)
{
    float4 goo_counts;
    float4 goo_feet[33];
    float4 goo_stains[64];
    float4 goo_spots[33];
    float4 goo_wear[33];
    float4 goo_hues[33];
    float4 goo_moves[4];
    float4 goo_clock;
};

// The height whose bend matches the shear the matrix carries, so the shadow's lean meets the top
static const float GooBend = 0.9;

// How much goo stays on a surface facing n: all of it on the sides and the tops, little under an
// overhang, from which it drips away
float goo_holds(float3 n)
{
    return smoothstep(-0.6, 0.0, n.y);
}

// Goo creeping down a piece at p in its own space at t seconds, as how far it stands off the
// surface: five runs round the piece, each starting somewhere up its side and creeping down at a
// pace of its own, a bead swelling at its front and its trail thinning behind, until it passes the
// foot and a new one starts.
float goo_runs(float3 p, float t, float seed)
{
    float r = max(length(p.xz), 0.04);
    float ang = atan2(p.z, p.x);
    float h = 0.0;
    [unroll] for (int k = 0; k < 5; k++)
    {
        float a = wood_hash(float3(seed * 13.0, (float)k, 2.1));
        float b = wood_hash(float3((float)k, seed * 7.0, 4.3));
        float c = wood_hash(float3((float)k, seed * 3.0, 8.9));
        float heading = ((float)k + 0.25 + 0.5 * a) * 1.2566371;
        float phase = frac(t / (9.0 + 6.0 * b) + a);
        float top = 0.3 + 1.1 * c;
        float front = top * (1.0 - phase) - 0.04;
        float da = ang - heading;
        da -= 6.2831853 * round(da / 6.2831853);
        float across = da * r;
        float behind = (p.y - front) / max(top - front, 0.02);
        float width = lerp(0.03, 0.014, saturate(behind));
        float trail = (1.0 - smoothstep(0.0, width, abs(across))) * step(0.0, behind) * smoothstep(top, top - 0.05, p.y) * (1.0 - 0.5 * saturate(behind)) * 0.006;
        float2 bead_at = float2(across, (p.y - front) * 1.3);
        float bead = saturate(1.0 - dot(bead_at, bead_at) / 0.0016);
        h = max(h, max(trail, bead * bead * 0.012) * smoothstep(0.0, 0.08, phase));
    }
    return h;
}

// A goo piece's corners: wobbling, the runs standing off its sides, and bent by the lean its matrix
// carries. Its pixels get the clock in uv's x and 1 in its y, which asks for the runs.
WoodOut goo_vs(ThreeIn i)
{
    float t = goo_clock.x;
    float2 shear = float2(i.model1.x, i.model1.z);
    i.model1.x = 0.0;
    i.model1.z = 0.0;
    float3 p = i.position;
    float3 n = normalize(i.normal);
    float stir = wood_noise(p * 6.0 + float3(t * 0.7, -t * 0.5, i.tint.a * 13.0)) - 0.5;
    // the runs mostly in the light, as a small lift folds the tight rings of a foot into each other
    float lift = goo_runs(p, t, i.tint.a) * goo_holds(n) * 0.35;
    i.position = p + n * (stir * (0.006 + length(shear) * 0.05) + lift);
    WoodOut o = wood_vs(i);
    o.local = p;
    o.uv = float2(t, 1.0);
    float rise = p.y / GooBend;
    float3 bend = float3(shear.x, 0.0, shear.y) * p.y * rise;
    float3 drawn = o.world;
    if (o.flip > 0.5) drawn.y = -drawn.y;
    drawn += bend;
    o.world += bend;
    // the bend's slope tilts the surface: its normal loses what the bend gains along it
    float3 bn = o.normal;
    bn.y -= 2.0 * rise * dot(shear, bn.xz);
    o.normal = normalize(bn);
    o.position = mul(frame.view_projection, float4(drawn, 1.0));
    o.depth = dot(drawn - frame.eye.xyz, frame.ahead.xyz);
    o.shadow0 = three_shadow_coord(0, o.world, o.normal);
    o.shadow1 = three_shadow_coord(1, o.world, o.normal);
    o.shadow2 = three_shadow_coord(2, o.world, o.normal);
    return o;
}

// A puddle or a hanging strand of goo, as drawn, with the clock in uv's x and no runs
WoodOut goo_drop_vs(ThreeIn i)
{
    WoodOut o = wood_vs(i);
    o.uv = float2(goo_clock.x, 0.0);
    return o;
}

float4 goo_piece_ps(WoodOut i) : SV_Target0
{
    PieceFx fx = piece_fx(i);
    bool white = piece_white(i);
    float4 kind = white ? material[0] : material[1];
    float3 tint = three_srgb_to_linear(kind.rgb);
    float rough = kind.w;
    float t = i.uv.x;
    float seed = i.color.a;
    float3 n0 = normalize(i.normal);
    float runs = i.uv.y > 0.5 ? goo_runs(i.local, t, seed) * goo_holds(n0) : 0.0;
    float3 n = wood_bump(n0, i.world, runs * 1.2);
    float3 v = normalize(piece_eye(i) - i.world);
    float nv = saturate(dot(n, v));
    float3 l = three_sun_way();
    float nl = dot(n, l);
    // the way in bent as through water, out through a column round the piece's axis as glass works
    // it, darkened by the slime's colour along the way and clouded
    float3 tr = refract(-v, n, 1.0 / 1.35);
    float2 off = i.world.xz - i.seed.xz;
    float a = dot(tr.xz, tr.xz);
    float through = a > 0.00001 ? max(-2.0 * dot(off, tr.xz) / a, 0.0) : 0.3;
    through = clamp(through, 0.03, 0.8);
    float3 far = i.world + tr * (through + 0.5);
    if (i.flip > 0.5) far.y = -far.y;
    float3 behind = glass_behind(glass_screen(far), 0.3);
    float3 seen = behind * exp(-(1.0 - tint) * through * 4.0) * lerp(float3(1.0, 1.0, 1.0), tint, 0.5);
    // light soaked into the jelly and scattered back out, round the side and through thin rims
    float3 sun = lights.sun_color.rgb * wood_shadow(i);
    float3 sky = three_hemisphere(n) * THREE_RECIPROCAL_PI;
    float wrap = saturate((nl + 0.6) / 1.6);
    float thin = pow(1.0 - nv, 2.0);
    float3 glow = tint * (sky + sun * (wrap * 0.6 + 0.12) + sun * pow(saturate(dot(-v, l)), 4.0) * (0.25 + thin));
    float3 q = i.local - v * 0.05;
    float cloud = wood_fbm(q * 7.0 + float3(0.0, t * 0.04, seed * 5.0));
    float3 body = lerp(seen, glow, 0.2 + 0.25 * cloud) * piece_foot(i);
    body += tint * thin * sky * 0.6;
    // the runs are thicker, wetter goo
    body = lerp(body, glow * 1.3, saturate(runs / 0.012) * 0.5);
    // bubbles hanging a little way inside
    float3 bq = (i.local - v * 0.035) * 7.0 + float3(0.0, t * 0.02, 0.0);
    float3 cell = floor(bq);
    float3 jitter = float3(wood_hash(cell + 1.3), wood_hash(cell + 2.7), wood_hash(cell + 5.1)) - 0.5;
    float3 bf = frac(bq) - 0.5 - jitter * 0.5;
    float size = wood_hash(cell + seed * 3.0) > 0.84 ? 0.08 + 0.07 * wood_hash(cell + 9.1) : 0.0;
    float bd = length(bf);
    float aa = fwidth(bd) + 0.004;
    float bubble = size > 0.0 ? 1.0 - smoothstep(size - aa, size + aa, bd) : 0.0;
    float catch_light = size > 0.0 ? 1.0 - smoothstep(0.0, size * 0.4, length(bf - float3(-0.3, 0.35, 0.0) * size)) : 0.0;
    body = lerp(body, body * 1.1 + glow * 0.2, bubble * 0.6) + catch_light * bubble * 0.5 * (sun + sky);
    float fresnel = 0.03 + 0.97 * pow(1.0 - nv, 5.0);
    float3 r = reflect(-v, n);
    float2 ab = wood_env_brdf(rough, nv);
    float3 mirrored = piece_seen(i.world, i.seed.xz, r, rough) * (0.03 * ab.x + ab.y);
    float3 spec = sun * saturate(nl) * THREE_PI * three_specular_ggx(l, v, n, float3(0.03, 0.03, 0.03), rough);
    float3 c = body * (1.0 - fresnel) + mirrored + spec;
    // mirrored in a polished board nothing lies behind, so only what the goo gives back shows
    if (i.flip > 0.5) return piece_fx_over(i, fx, float4(mirrored + spec + glow * 0.5, saturate(fresnel + 0.55)));
    return piece_fx_over(i, fx, piece_out(i, c, 1.0));
}

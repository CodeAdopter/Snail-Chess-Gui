// Above the clouds: the board floats high over a sea of clouds, seen from straight above, the sun
// in the top left. Three layers of cumulus lie at depths of their own, drifting with the wind, the
// nearer ones faster, so the sea of them has depth as it moves. Each cloud's tops are lit on the
// sun's side and fall into blue shade on the other, the lower layers hazed toward the sky's blue
// and shaded by those above, and through the gaps the sea lies far below. The board's shadow falls
// on each layer further from it the deeper the layer lies and softer, and now and then a high wisp
// drifts over the board itself.

#include "backdrop.hlsli"

static const float2 ToSun = float2(-0.6, -0.8);
static const float2 Drift = float2(0.92, 0.38);

float cloud_density(float2 p, float cover, float t)
{
    float2 w = float2(bd_fbm(p * 0.6 + t * 0.012, 3), bd_fbm(p * 0.6 + 4.1 - t * 0.01, 3));
    float n = bd_fbm(p + w * 0.9, 5);
    return smoothstep(cover, cover + 0.22, n);
}

// One layer at p: its density in w, its colour in rgb, lit from the sun's side and shaded by the
// layer above through above.
float4 cloud_layer(float2 u, float scale, float speed, float cover, float seed, float t, float haze)
{
    float2 p = (u - Drift * t * speed) * scale + seed;
    float d = cloud_density(p, cover, t);
    float2 toward = normalize(ToSun) * 0.16;
    float lit = saturate(0.5 + (d - cloud_density(p + toward, cover, t)) * 2.6);
    float3 sunlit = float3(1.0, 0.97, 0.9);
    float3 shade = float3(0.5, 0.58, 0.74);
    float3 c = lerp(shade, sunlit, lit) * (0.8 + 0.25 * d);
    // thin edges let the light through and the sky's blue in
    c = lerp(c, float3(0.78, 0.86, 0.97), (1.0 - d) * 0.35);
    c = lerp(c, float3(0.55, 0.7, 0.9), haze);
    return float4(c, d);
}

float wisps(float2 u, float t)
{
    float2 p = (u - Drift * t * 0.05) * float2(0.9, 2.2);
    p = bd_turn(p, 0.35);
    float n = bd_fbm(p * float2(1.0, 0.35) + bd_fbm(p * 2.0, 3) * 0.6, 5);
    return smoothstep(0.66, 0.82, n);
}

float4 clouds(UiPixel q)
{
    Stage s = stage_of(q);
    float2 u = s.u;
    float t = s.t;
    float2 away = -normalize(ToSun);
    if (s.front)
    {
        float w = wisps(u, t);
        float3 c = lerp(float3(0.92, 0.95, 1.0), float3(1.0, 0.98, 0.94), saturate(-u.y * 0.5 + 0.5));
        return bd_over(q, c, w * 0.32);
    }
    // the board hides what lies under it
    if (bd_board(u, 0.0) < -0.03)
        return bd_out(q, float3(0.0, 0.0, 0.0));
    // the sea far below, its coasts blurred by the depth of air between
    float land = smoothstep(0.52, 0.6, bd_fbm((u - Drift * t * 0.004) * 0.35 + 21.0, 4));
    float3 c = lerp(float3(0.06, 0.24, 0.44), float3(0.25, 0.36, 0.28), land);
    c = lerp(c, float3(0.42, 0.58, 0.8), 0.35);
    c *= 1.0 - 0.25 * bd_shadow(u, away * 1.4, 0.5);
    float4 low = cloud_layer(u, 1.9, 0.012, 0.47, 3.0, t, 0.3);
    float4 mid = cloud_layer(u, 3.0, 0.022, 0.53, 11.0, t, 0.1);
    float4 high = cloud_layer(u, 4.6, 0.036, 0.62, 27.0, t, 0.0);
    // what lies above shades what lies below, a little away from the sun
    float mid_over_low = cloud_density((u - away * 0.1 - Drift * t * 0.022) * 3.0 + 11.0, 0.53, t);
    low.rgb *= 1.0 - 0.35 * mid_over_low;
    low.rgb *= 1.0 - 0.32 * bd_shadow(u, away * 0.62, 0.11);
    c = lerp(c, low.rgb, low.w * 0.95);
    mid.rgb *= 1.0 - 0.28 * smoothstep(0.2, 0.8, high.w);
    mid.rgb *= 1.0 - 0.38 * bd_shadow(u, away * 0.38, 0.07);
    c = lerp(c, mid.rgb, mid.w);
    high.rgb *= 1.0 - 0.42 * bd_shadow(u, away * 0.2, 0.04);
    c = lerp(c, high.rgb, high.w);
    float w = wisps(u, t);
    c = lerp(c, float3(0.95, 0.97, 1.0), w * 0.45);
    // the sun's warmth toward its side
    c *= lerp(float3(1.05, 1.0, 0.93), float3(0.93, 0.97, 1.05), saturate(dot(u, away) * 0.2 + 0.5));
    return bd_out(q, c);
}

UI_MATERIAL(clouds)

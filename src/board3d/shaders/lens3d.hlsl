// A camera's lens over the 3D board's scenes, one pass on the half float scene whose alpha is how
// far ahead of the eye each pixel is. Everything from the board's near edge to its far edge stays
// sharp. What lies beyond spreads into a disc as a wide aperture spreads it, gathered from at most
// forty taps on a spiral turned a little every pixel, however large the picture, never letting
// what is behind bleed over what is nearer and sharp. A second pass smooths the blur, darkens the
// corners and lays a fine grain over all.

#include "C:/Snail/Snail Engine/engine/shaders/post.hlsl"

// Lens: x and y the nearest and farthest depths kept sharp, z how many pixels across the blur of
// the far distance is, w the most blur in pixels. Look: x the time, y 1 while the surroundings are
// drawn aside, which leaves the corners and the grain to the sharp pass, z the vignette, w the
// grain. Surroundings blurred aside already come back at the far end of what is kept sharp.
cbuffer LensUniforms : register(b1, space3)
{
    float4 lens;
    float4 look;
};

float lens_blur(float depth)
{
    float far = depth > lens.y ? 1.0 - lens.y / depth : 0.0;
    float near = depth < lens.x ? min(lens.x / max(depth, 0.001) - 1.0, 1.0) : 0.0;
    return min((far + near) * lens.z, lens.w);
}

// Interleaved gradient noise, a different turn for every pixel that a blur hides
float lens_noise(float2 p)
{
    return frac(52.9829189 * frac(dot(p, float2(0.06711056, 0.00583715))));
}

float4 lens_ps(FullscreenOut i) : SV_Target0
{
    float2 size;
    scene.GetDimensions(size.x, size.y);
    float2 px = 1.0 / size;
    float4 centre = scene.SampleLevel(scene_sampler, i.uv, 0.0);
    float depth = centre.a;
    float own = lens_blur(depth);
    float3 c = centre.rgb;
    if (own > 0.75)
    {
        int taps = (int)clamp(own * own * 0.35, 8.0, 40.0);
        float spin = lens_noise(i.position.xy) * 6.2832;
        float3 sum = min(c, 6.0);
        float weight = 1.0;
        for (int k = 0; k < taps; k++)
        {
            float r = sqrt((k + 0.5) / taps) * own;
            float a = k * 2.39996 + spin;
            float4 s = scene.SampleLevel(scene_sampler, i.uv + float2(cos(a), sin(a)) * px * r, 0.0);
            float blur = lens_blur(s.a);
            if (s.a > depth) blur = min(blur, own * 2.0);
            float w = smoothstep(r - 1.0, r + 1.0, blur);
            sum += min(s.rgb, 6.0) * w;
            weight += w;
        }
        c = sum / weight;
    }
    return float4(c, centre.a);
}

// The lens's second pass, which smooths what the first blurred with eight taps a fraction of its
// blur across among pixels as blurred, so a few taps that caught a bright flame never show as
// dots, then darkens the corners and lays the grain
float4 lens_smooth_ps(FullscreenOut i) : SV_Target0
{
    float2 size;
    scene.GetDimensions(size.x, size.y);
    float2 px = 1.0 / size;
    float4 centre = scene.SampleLevel(scene_sampler, i.uv, 0.0);
    float own = lens_blur(centre.a);
    float3 c = centre.rgb;
    if (own > 1.5)
    {
        float reach = min(own * 0.4, 8.0);
        float3 sum = c;
        float weight = 1.0;
        for (int k = 0; k < 8; k++)
        {
            float a = k * 0.7854 + 0.39;
            float4 s = scene.SampleLevel(scene_sampler, i.uv + float2(cos(a), sin(a)) * px * reach, 0.0);
            float w = smoothstep(own * 0.3, own * 0.6, lens_blur(s.a));
            sum += s.rgb * w;
            weight += w;
        }
        c = sum / weight;
    }
    if (look.y < 0.5)
    {
        float2 d = i.uv - 0.5;
        c *= 1.0 - look.z * dot(d, d) * 2.0;
        c *= 1.0 + (lens_noise(i.position.xy + frac(look.x) * 917.0) - 0.5) * look.w;
    }
    return float4(c, centre.a);
}

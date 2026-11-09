// What the board and backdrop materials share: colours packed as 0xRRGGBB in a float, which holds
// any 24 bit number exactly, a hash of a cell, and a pixel's place in a box in its own pixels.
#ifndef LOOKS_HLSLI
#define LOOKS_HLSLI

#include "C:/Snail/Snail Engine/engine/shaders/ui_material.hlsli"

float3 looks_rgb(float packed)
{
    uint c = (uint)(packed + 0.5);
    return float3((c >> 16) & 255u, (c >> 8) & 255u, c & 255u) / 255.0;
}

float looks_hash(float2 p)
{
    p = frac(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return frac(p.x * p.y);
}

// The pixel's place in its box, in the box's own pixels from its top left corner.
float2 looks_at(UiPixel q)
{
    return (q.p - q.s.rect.xy) / max(q.px, 1e-4);
}

// The box's size in its own pixels.
float2 looks_size(UiPixel q)
{
    return q.s.rect.zw / max(q.px, 1e-4);
}

// How far round a box's edge from its top left, clockwise, the edge nearest p lies.
float looks_around(float2 p, float4 rect)
{
    float2 o = p - rect.xy;
    float2 c = o - rect.zw * 0.5;
    float2 out_by = abs(c) - rect.zw * 0.5;
    float x = clamp(o.x, 0.0, rect.z);
    float y = clamp(o.y, 0.0, rect.w);
    if (out_by.y > out_by.x)
        return c.y < 0.0 ? x : 2.0 * rect.z + rect.w - x;
    return c.x > 0.0 ? rect.z + y : 2.0 * (rect.z + rect.w) - y;
}

// The point u round a box's edge from its top left, clockwise, as looks_around measures it.
float2 looks_on_edge(float u, float4 rect)
{
    float w = rect.z;
    float h = rect.w;
    u = u - 2.0 * (w + h) * floor(u / (2.0 * (w + h)));
    if (u < w)
        return rect.xy + float2(u, 0.0);
    if (u < w + h)
        return rect.xy + float2(w, u - w);
    if (u < 2.0 * w + h)
        return rect.xy + float2(2.0 * w + h - u, h);
    return rect.xy + float2(0.0, 2.0 * (w + h) - u);
}

// A colour drawn opaque over the box, its edge softened as the box's is.
float4 looks_out(UiPixel q, float3 c)
{
    float k = ui_cover(q.d, q.px);
    return float4(saturate(c) * k, k);
}

#endif

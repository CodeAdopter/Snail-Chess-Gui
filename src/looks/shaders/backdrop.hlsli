// What every backdrop shares. A backdrop is drawn about the board, in halves of the board from its
// middle, so the board spans -1 to 1 both ways with y down, and what lies round it keeps its size
// against the board's on any window. The same material draws twice: behind the board over the
// whole room, and in front over the board's own square for what reaches over its edge.
// Values: seconds, which wrap each hour, the board's middle from the box's top left corner, and
// half the board's size plus 8192 times the code, the variant plus 16 when drawn in front.
#ifndef BACKDROP_HLSLI
#define BACKDROP_HLSLI

#include "looks.hlsli"

struct Stage
{
    float2 u;
    float px;
    float t;
    float variant;
    bool front;
    float2 lo;
    float2 hi;
};

Stage stage_of(UiPixel q)
{
    Stage s;
    float code = floor(q.values.w / 8192.0);
    float half_size = max(q.values.w - code * 8192.0, 1.0);
    float2 centre = q.s.rect.xy + q.values.yz;
    s.u = (q.p - centre) / half_size;
    s.px = q.px / half_size;
    s.t = q.values.x;
    s.front = code >= 15.5;
    s.variant = s.front ? code - 16.0 : code;
    s.lo = (q.s.rect.xy - centre) / half_size;
    s.hi = (q.s.rect.xy + q.s.rect.zw - centre) / half_size;
    return s;
}

uint bd_pcg(uint v)
{
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

// A hash of a cell from 0 to 1, exact for any whole cell however far out.
float bd_hash(float2 cell)
{
    int2 i = (int2)floor(cell);
    return (float)bd_pcg((uint)i.x * 1597334677u ^ bd_pcg((uint)i.y + 0x9E3779B9u)) / 4294967295.0;
}

float2 bd_hash2(float2 cell)
{
    int2 i = (int2)floor(cell);
    uint a = bd_pcg((uint)i.x * 1597334677u ^ bd_pcg((uint)i.y + 0x9E3779B9u));
    uint b = bd_pcg(a);
    return float2(a, b) / 4294967295.0;
}

float bd_noise(float2 p)
{
    float2 i = floor(p);
    float2 f = p - i;
    float2 w = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = bd_hash(i);
    float b = bd_hash(i + float2(1.0, 0.0));
    float c = bd_hash(i + float2(0.0, 1.0));
    float d = bd_hash(i + float2(1.0, 1.0));
    return lerp(lerp(a, b, w.x), lerp(c, d, w.x), w.y);
}

// Octaves of noise, each turned from the last so no grid shows, from 0 to 1.
float bd_fbm(float2 p, int octaves)
{
    float v = 0.0;
    float a = 0.5;
    float total = 0.0;
    for (int i = 0; i < octaves; i++)
    {
        v += a * bd_noise(p);
        total += a;
        p = float2(1.6 * p.x - 1.2 * p.y, 1.2 * p.x + 1.6 * p.y) + 11.7;
        a *= 0.5;
    }
    return v / total;
}

float2 bd_turn(float2 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// How far outside the board a point is, its corners rounded by r.
float bd_board(float2 u, float r)
{
    float2 d = abs(u) - (1.0 - r);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// The error function near enough, kept off tanh's far ends, which overflow on some GPUs.
float2 bd_erf(float2 x)
{
    return tanh(clamp(1.2025 * x, -9.0, 9.0));
}

// The share of light the board takes from a point under it, the board moved by off and its edge
// blurred over blur, as a box under a gaussian blur.
float bd_shadow(float2 u, float2 off, float blur)
{
    float2 p = u - off;
    float2 a = 0.5 * (bd_erf((1.0 - p) / blur) + bd_erf((1.0 + p) / blur));
    return saturate(a.x * a.y);
}

// Distance to a segment from a to b, and how far along it the nearest point lies.
float2 bd_segment(float2 p, float2 a, float2 b)
{
    float2 ab = b - a;
    float h = saturate(dot(p - a, ab) / max(dot(ab, ab), 1e-8));
    return float2(length(p - a - ab * h), h);
}

// The colour drawn behind, opaque over the box, or in front, laid over the board at its alpha.
float4 bd_out(UiPixel q, float3 c)
{
    return looks_out(q, c);
}

float4 bd_over(UiPixel q, float3 c, float a)
{
    float k = ui_cover(q.d, q.px);
    return float4(saturate(c) * a * k, a * k);
}

float3 bd_aces(float3 x)
{
    return saturate((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14));
}

#endif

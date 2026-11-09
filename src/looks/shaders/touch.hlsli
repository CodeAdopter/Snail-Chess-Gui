// What the detailed themes' materials read of the person, from the values each is given: the
// seconds since the last press, or far below zero to hold still, then the pointer in the window's
// pixels, and for a panel the press point packed as x * 4096 + y in steps of 2 pixels. Both points
// are brought into the shape's own place through the pixel being shaded, which holds however its
// group is scaled or scrolled. t is the UI clock, held at 0 when still.
#ifndef TOUCH_HLSLI
#define TOUCH_HLSLI

#include "looks.hlsli"

struct Touch
{
    float t;
    float2 pointer;
    float age;
    float2 press;
};

Touch touch_of(UiPixel q)
{
    Touch g;
    bool still = q.values.x < -1.0e8;
    g.t = still ? 0.0 : lights.clock.x;
    g.age = still ? 100.0 : q.values.x;
    g.pointer = still ? float2(-1.0e6, -1.0e6) : q.p + (q.values.yz - q.pixel) * q.px;
    float column = floor(q.values.w / 4096.0);
    g.press = q.p + (float2(column, q.values.w - column * 4096.0) * 2.0 - q.pixel) * q.px;
    return g;
}

// How far into the page laid back over the sheet a point lies, below zero past its edge. The page's
// round corner tells which side the sheet is on, so the page is taken as running on past the
// window on its other side and below, or on both sides when it has no round corner, as under a bar
// alone.
float page_depth(float2 p, UiShape s)
{
    float4 r = s.rect;
    r.w += 1000.0;
    if (s.radii.y >= s.radii.x)
    {
        r.x -= 1000.0;
        r.z += 1000.0;
    }
    if (s.radii.x >= s.radii.y)
        r.z += 1000.0;
    float2 half = r.zw * 0.5;
    return -ui_round_box(p - r.xy - half, half, s.radii);
}

#endif

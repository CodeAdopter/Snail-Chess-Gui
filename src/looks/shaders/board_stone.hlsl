// Stone: each square a polished tile cut from a slab of its own. Style 1 is marble, white Carrara
// in the light tiles with grey veins and grey Bardiglio in the dark with pale ones, the veins crisp
// threads in a soft haze over a cloudy ground, a finer web among them. 2 is lapis lazuli, deep blue
// mottled paler and darker, with grey calcite clouds, fine white veins and rare specks of gold
// pyrite, against white marble. 3 is onyx, black with faint smoky flows and now and then a fine
// pale vein, against cream onyx laid down in broad soft bands of honey and paler cream. A thin
// grout parts the tiles, their edges eased, and the polish holds a reflected window, each tile
// catching it at its own slight tilt, crisper on lapis and onyx and showing most on dark stones. Detail finer than a pixel fades to its average, so small boards stay calm.
// Values: the light stone and the dark stone as 0xRRGGBB, the style, unused.

#include "backdrop.hlsli"

// Lines where noise crosses its middle, 1 on them, as veins run.
float ridge(float2 p, int octaves)
{
    return 1.0 - abs(2.0 * bd_fbm(p, octaves) - 1.0);
}

float3 marble(float2 p, float3 base, bool light, float fine, float3 dark_vein, float3 pale_vein, float strength)
{
    // veins flow mostly one way through a slab, folded as the stone was
    float2 flow = float2(p.x * 0.5 + p.y * 0.3, p.y * 0.9 - p.x * 0.25);
    float2 w = flow + float2(bd_fbm(p * 0.8, 4), bd_fbm(p * 0.8 + 5.2, 4)) * 1.3;
    float v = ridge(w * 0.75, 4);
    float vein = pow(v, lerp(7.0, 16.0, fine));
    float haze = pow(v, 2.5);
    float web = pow(ridge(w * 2.1 + 3.1, 3), lerp(9.0, 22.0, fine));
    float cloud = bd_fbm(p * 2.0 + 9.0, 4);
    float3 c = base * (0.94 + 0.1 * cloud);
    float3 vc = light ? dark_vein : pale_vein;
    // veins come and go across a slab
    float run = smoothstep(0.3, 0.62, bd_fbm(p * 0.4 + 13.0, 3));
    c = lerp(c, vc, saturate(haze * 0.22 + vein * 0.6 + web * 0.3 * run) * strength * lerp(0.5, 1.0, run));
    return c;
}

float3 lapis(float2 p, float3 base, float fine)
{
    // patches of deeper and paler blue, grainy within
    float patch = bd_fbm(p * 1.5, 5);
    float grain = bd_fbm(p * 11.0 + 3.0, 3);
    float3 deep = base * float3(0.45, 0.5, 0.72);
    float3 bright = base * float3(1.25, 1.3, 1.22) + float3(0.0, 0.02, 0.06);
    float3 c = lerp(deep, bright, smoothstep(0.28, 0.78, patch));
    c *= 0.88 + 0.24 * lerp(0.5, grain, fine);
    // calcite in pale grey clouds and a few fine veins
    float2 w = p + float2(bd_fbm(p * 0.9 + 7.0, 4), bd_fbm(p * 0.9 + 2.0, 4)) * 1.2;
    float vein = pow(ridge(w * 0.8, 4), lerp(30.0, 80.0, fine)) * smoothstep(0.55, 0.78, bd_fbm(p * 0.5 + 21.0, 3));
    float cloud = smoothstep(0.62, 0.9, bd_fbm(p * 1.3 + 40.0, 4));
    c = lerp(c, float3(0.62, 0.68, 0.78), cloud * 0.35);
    c = lerp(c, float3(0.86, 0.88, 0.9), vein * 0.75);
    // pyrite in rare specks of gold
    float2 gp = p * 7.0;
    float2 gc = floor(gp);
    float2 at = 0.25 + 0.5 * bd_hash2(gc + 17.0);
    float d = length((gp - gc - at) * float2(1.0, 1.6));
    float speck = step(0.95, bd_hash(gc + 5.0)) * smoothstep(0.13, 0.05, d);
    c = lerp(c, float3(0.86, 0.7, 0.36), speck * fine * 0.85);
    return c;
}

float3 black_onyx(float2 p, float3 base, float fine)
{
    // flows folded through the stone, faint smoke in the black
    float2 w = p + float2(bd_fbm(p * 0.7 + 3.0, 4), bd_fbm(p * 0.7 + 8.0, 4)) * 1.6;
    float flow = bd_fbm(w * 1.1, 5);
    float layers = 0.5 + 0.5 * sin((w.y * 1.4 + flow * 4.0) * 3.14159);
    float3 c = base * (0.55 + 0.95 * smoothstep(0.3, 0.75, flow) + 0.2 * layers);
    // now and then a fine pale vein
    float vein = pow(ridge(w * 0.6 + 11.0, 3), lerp(30.0, 80.0, fine)) * smoothstep(0.62, 0.8, bd_fbm(p * 0.45 + 29.0, 3));
    return lerp(c, float3(0.7, 0.69, 0.68), vein * 0.7);
}

float3 cream_onyx(float2 p, float3 base, float fine)
{
    // layers laid down in broad soft bands, bent as the stone settled, some honey, some paler
    float2 w = p + float2(bd_fbm(p * 0.5 + 5.0, 4), bd_fbm(p * 0.5 + 1.0, 4)) * 0.8;
    float t = w.y * 1.7 + bd_fbm(w * 1.2, 3) * 1.1;
    float b = frac(t);
    float id = floor(t);
    float width = lerp(0.2, 0.55, bd_hash(float2(id, 3.0)));
    float band = smoothstep(0.0, 0.22, b) * (1.0 - smoothstep(width, width + 0.3, b));
    float kind = bd_hash(float2(id, 9.0));
    float3 c = base * (0.97 + 0.05 * bd_fbm(p * 2.5, 3));
    float3 tint = kind > 0.5 ? base * float3(0.95, 0.86, 0.7) : min(base * 1.05 + 0.02, 1.0);
    c = lerp(c, tint, band * 0.6);
    // a faint line where one layer meets the next
    return c * (1.0 - 0.035 * exp(-pow(b / 0.02, 2.0)) * fine);
}

float4 stone(UiPixel q)
{
    float2 uv = q.uv * 8.0;
    float2 cell = floor(uv);
    float2 f = uv - cell;
    bool light = fmod(cell.x + cell.y, 2.0) < 0.5;
    float3 base = looks_rgb(light ? q.values.x : q.values.y);
    float style = q.values.z;
    float2 h = bd_hash2(cell + float2(19.0 * style, 3.0));
    float2 p = f * 1.1 + h * 41.0;
    float sq_px = looks_size(q).x / 8.0;
    float fine = saturate((sq_px - 18.0) / 40.0);
    float3 c;
    if (style < 1.5)
        c = marble(p, base, light, fine, base * float3(0.6, 0.62, 0.66), min(base * 1.35 + 0.1, 0.92), 1.0);
    else if (style < 2.5)
    {
        if (light)
            c = marble(p * 0.8, base, true, fine, base * float3(0.78, 0.8, 0.82), base, 0.55);
        else
            c = lapis(p, base, fine);
    }
    else
    {
        if (light)
            c = cream_onyx(p, base, fine);
        else
            c = black_onyx(p * 1.1, base, fine);
    }
    // grout and eased edges, lit from the top left
    float2 e = float2(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * sq_px;
    float3 grout = light ? base * 0.7 : base * 0.6 + 0.08;
    c = lerp(grout, c, smoothstep(0.0, 1.1, min(e.x, e.y)));
    float lit = saturate(1.0 - f.y * sq_px / 2.0) + saturate(1.0 - f.x * sq_px / 2.0);
    float shade = saturate(1.0 - (1.0 - f.y) * sq_px / 2.0) + saturate(1.0 - (1.0 - f.x) * sq_px / 2.0);
    c *= 1.0 + 0.07 * saturate(lit) - 0.08 * saturate(shade);
    // the polish: a room's soft light falling off from the top left, and a window of two panes
    // reflected over the top right, each tile tilted a hair so the window breaks at the grout
    float2 r = q.uv + (h - 0.5) * 0.012;
    float2 pane = abs(float2(r.x - 0.72 + r.y * 0.12, r.y - 0.2) / float2(0.17, 0.3));
    float soft = style < 1.5 ? 0.82 : 0.93;
    float glass = (1.0 - smoothstep(soft, 1.0, max(pane.x, pane.y))) * smoothstep(0.03, 0.06, abs(r.x - 0.72 + r.y * 0.12));
    float sheen = exp(-pow((r.x * 0.8 + r.y * 0.6 - 0.42) / 0.2, 2.0));
    c *= 1.03 - 0.08 * length(q.uv - float2(0.3, 0.25));
    c += sheen * 0.035 + glass * (style < 1.5 ? 0.07 : 0.1);
    return looks_out(q, c);
}

UI_MATERIAL(stone)

// The surroundings of a scene round the 3D board, drawn small and blurred aside, laid behind its
// sharp middle: a quad over the whole view at the far plane, tested against what is drawn but
// writing no depth, so it shows only where nothing else stands. Its alpha is the far end of what
// the lens keeps sharp, given in the material's first value, so the lens leaves it as it is, and a
// pixel on a piece's edge, where several samples are averaged, stays sharp too.

#include "C:/Snail/Snail Engine/engine/shaders/three.hlsli"

struct BackdropOut
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
};

BackdropOut backdrop_vs(ThreeIn i)
{
    BackdropOut o;
    o.position = float4(i.position.x, i.position.y, 0.000001, 1.0);
    o.uv = float2(i.position.x * 0.5 + 0.5, 0.5 - i.position.y * 0.5);
    return o;
}

float4 backdrop_ps(BackdropOut i) : SV_Target0
{
    float4 c = material_texture.SampleLevel(material_sampler, i.uv, 0.0);
    return float4(c.rgb, material[0].x);
}

// What the sharp pass draws, drawn with the surroundings only to cast its shadows over them
float4 unseen_ps(ThreeOut i) : SV_Target0
{
    discard;
    return float4(0.0, 0.0, 0.0, 0.0);
}

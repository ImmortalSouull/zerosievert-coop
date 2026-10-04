// ZERO Sievert co-op: replacement pixel shader for the game's shd_tree (D3D11), compiled by tools/make_shaders.py.
// Same logic as the original (opaque cutout + occlusion fade with a 4x4 Bayer stipple), but the stipple is
// anchored to WORLD coordinates instead of screen pixels: with a camera moving by fractions of a pixel (and
// even more so with the high refresh rate interpolation) a screen-anchored pattern crawls over the tree,
// which looks like flicker. The constant buffer, resources and signatures match the original exactly.

Texture2D texture__gm_BaseTexture : register(t0);
SamplerState sampler__gm_BaseTexture : register(s0);

float  _alpha_cutoff        : register(c0);
float  _fade_radius         : register(c1);
float  _gm_AlphaRefValue    : register(c2);
bool   _gm_AlphaTestEnabled : register(c3);
float4 _gm_FogColour        : register(c4);
bool   _gm_PS_FogEnabled    : register(c5);
float  _occ_count           : register(c6);
float2 _occluders[8]        : register(c7);

struct PS_IN
{
    float2 tex   : TEXCOORD0;
    float2 world : TEXCOORD1;
    float4 unused2 : TEXCOORD2;
    float4 pos   : SV_Position;
};

struct PS_OUT
{
    float4 c0 : SV_Target0;
    float4 c1 : SV_Target1;
    float4 c2 : SV_Target2;
    float4 c3 : SV_Target3;
};

float bayer2(float2 v) { return 2.0 * v.x + 3.0 * v.y - 4.0 * v.x * v.y; }
float bayer4x4(float2 p)
{
    float2 t = floor(fmod(p, 4.0));
    return (4.0 * bayer2(fmod(t, 2.0)) + bayer2(floor(t / 2.0))) / 16.0;
}

PS_OUT main(PS_IN i)
{
    float4 col = texture__gm_BaseTexture.Sample(sampler__gm_BaseTexture, i.tex);
    if (col.a < _alpha_cutoff) discard;
    float f = 0.0;
    [loop] for (int k = 0; k < 8; k++)
    {
        if ((float)k >= _occ_count) break;
        float d = distance(i.world, _occluders[k]);
        f = max(f, (1.0 - smoothstep(_fade_radius * 0.35, _fade_radius, d)) * 0.6);
    }
    // half-world-pixel cells, positive coordinates for fmod
    float2 cell = floor(i.world * 2.0 + 65536.0);
    if (f > 0.0 && bayer4x4(cell) < f) discard;
    PS_OUT o;
    o.c0 = col; o.c1 = col; o.c2 = col; o.c3 = col;
    return o;
}

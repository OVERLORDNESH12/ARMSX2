// BASED ON OVERLORD NESH BITWISE MATH FOR AetherSx2 1.6-4890.

cbuffer cb : register(b0) {
    uint4 const0;
    uint4 const1;
    int2 srcOffset;
};

Texture2D InputTexture : register(t0);
RWTexture2D<float4> OutputTexture : register(u0);

#define A_GPU 1
#define A_HLSL 1
#include "ffx_a.h"

// Pure bitwise math alternative for HLSL. Eliminates array cache lookups completely!
float getDitherValue(int x, int y)
{
    // Replicates the exact 8x8 Bayer pattern values using single-cycle ALU operations
    int idx = ((x ^ y) & 1) << 5 | (y & 1) << 4 | (((x >> 1) ^ (y >> 1)) & 1) << 3 | 
              ((y >> 1) & 1) << 2 | (((x >> 2) ^ (y >> 2)) & 1) << 1 | ((y >> 2) & 1);
    return float(idx);
}

AF3 CasLoad(ASU2 p)
{
    // Compute pixel coordinates locally within the caller frame scope
    int3 pos = int3(srcOffset, 0) + int3(p, 0);
    
    // Sample texture unit maps cleanly into the HLSL registers
    AF3 rgbColor = InputTexture.Load(pos).rgb;
    
    // Apply your custom dark screen profile blend calculation
    rgbColor *= 0.97f;
    
    // Isolate bounds mask checking dynamically to avoid global register pollution
    int x = pos.x & 7;
    int y = pos.y & 7;
    float noise = (getDitherValue(x, y) / 64.0f - 0.5f) * (1.0f / 128.0f);
    
    // Clamp limits explicitly before feeding variables to the CAS routine
    rgbColor.r = clamp(rgbColor.r + noise, 0.0f, 1.0f);
    rgbColor.g = clamp(rgbColor.g + noise, 0.0f, 1.0f);
    rgbColor.b = clamp(rgbColor.b + noise, 0.0f, 1.0f);
    
    return rgbColor;
}

// Stripped down completely to maximize compiler optimization linear passes
void CasInput(inout AF1 r, inout AF1 g, inout AF1 b) {}

#include "ffx_cas.h"

[numthreads(64, 1, 1)]
void main(uint3 LocalThreadId : SV_GroupThreadID, uint3 WorkGroupId : SV_GroupID)
{
    // Remap thread arrays for local layout swizzle patterns
    AU2 gxy = ARmp8x8(LocalThreadId.x) + AU2(WorkGroupId.x << 4u, WorkGroupId.y << 4u);

    #if CAS_SHARPEN_ONLY
    const bool sharpenOnly = true;
    #else
    const bool sharpenOnly = false;
    #endif

    AF3 c;

    CasFilter(c.r, c.g, c.b, gxy, const0, const1, sharpenOnly);
    OutputTexture[ASU2(gxy)] = float4(c, 1.0f);
    gxy.x += 8u;

    CasFilter(c.r, c.g, c.b, gxy, const0, const1, sharpenOnly);
    OutputTexture[ASU2(gxy)] = float4(c, 1.0f);
    gxy.y += 8u;
    
    CasFilter(c.r, c.g, c.b, gxy, const0, const1, sharpenOnly);
    OutputTexture[ASU2(gxy)] = float4(c, 1.0f);
    gxy.x -= 8u;

    CasFilter(c.r, c.g, c.b, gxy, const0, const1, sharpenOnly);
    OutputTexture[ASU2(gxy)] = float4(c, 1.0f);
}

// BASED ON OVERLORD NESH BITWISE MATH FOR ARMSX2.

layout(push_constant) uniform const_buffer {
    uvec4 const0;
    uvec4 const1;
    ivec2 srcOffset;
};

layout(set=0, binding=0) uniform texture2D imgSrc;
layout(set=0, binding=1, rgba8) uniform writeonly image2D imgDst;
layout(constant_id=0) const int sharpenOnly = 0;

#define A_GPU 1
#define A_GLSL 1
#include "ffx_a.h"

float getDitherValue(int x, int y)
{
    int idx = ((x ^ y) & 1) << 5 | (y & 1) << 4 | (((x >> 1) ^ (y >> 1)) & 1) << 3 | 
              ((y >> 1) & 1) << 2 | (((x >> 2) ^ (y >> 2)) & 1) << 1 | ((y >> 2) & 1);
    return float(idx);
}

AF3 CasLoad(ASU2 p)
{
    ivec2 currentPos = srcOffset + ivec2(p);
    AF3 rgbColor = texelFetch(imgSrc, currentPos, 0).rgb;
    
    // 3% darker screen profile (0.97f = 97% brightness)
    rgbColor *= 0.80f;
    
    int x = currentPos.x & 7;
    int y = currentPos.y & 7;
    float noise = (getDitherValue(x, y) / 64.0f - 0.5f) * (1.0f / 128.0f);
    
    return clamp(rgbColor + noise, 0.0f, 1.0f);
}

void CasInput(inout AF1 r, inout AF1 g, inout AF1 b) {}

#include "ffx_cas.h"

layout(local_size_x=64) in;
void main()
{
    AU2 gxy = ARmp8x8(gl_LocalInvocationID.x) + AU2(gl_WorkGroupID.x << 4u, gl_WorkGroupID.y << 4u);
    const bool mode = bool(sharpenOnly);

    AF4 c1 = vec4(0.0f, 0.0f, 0.0f, 1.0f);
    CasFilter(c1.r, c1.g, c1.b, gxy, const0, const1, mode);
    imageStore(imgDst, ASU2(gxy), c1);

    gxy.x += 8u;
    AF4 c2 = vec4(0.0f, 0.0f, 0.0f, 1.0f);
    CasFilter(c2.r, c2.g, c2.b, gxy, const0, const1, mode);
    imageStore(imgDst, ASU2(gxy), c2);

    gxy.y += 8u;
    AF4 c3 = vec4(0.0f, 0.0f, 0.0f, 1.0f);
    CasFilter(c3.r, c3.g, c3.b, gxy, const0, const1, mode);
    imageStore(imgDst, ASU2(gxy), c3);

    gxy.x -= 8u;
    AF4 c4 = vec4(0.0f, 0.0f, 0.0f, 1.0f);
    CasFilter(c4.r, c4.g, c4.b, gxy, const0, const1, mode);
    imageStore(imgDst, ASU2(gxy), c4);
}

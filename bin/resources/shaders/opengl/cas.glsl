// BASED ON OVERLORD NESH BITWISE MATH FOR AetherSx2 1.6-4890.

uniform uvec4 const0;
uniform uvec4 const1;
uniform ivec2 srcOffset;

// Sampler binding defaults to 0 if not explicitly set; texture unit 0 is used in code.
uniform sampler2D imgSrc;
layout(binding=0, rgba8) uniform writeonly image2D imgDst;

#define A_GPU 1
#define A_GLSL 1

#include "ffx_a.h"

// Pure bitwise math alternative. Completely eliminates array allocations!
float getDitherValue(int x, int y)
{
    // Replicates the exact 8x8 Bayer pattern values down to the precise decimal
    int idx = ((x ^ y) & 1) << 5 | (y & 1) << 4 | (((x >> 1) ^ (y >> 1)) & 1) << 3 | 
              ((y >> 1) & 1) << 2 | (((x >> 2) ^ (y >> 2)) & 1) << 1 | ((y >> 2) & 1);
    return float(idx);
}
AF3 CasLoad(ASU2 p)
{
	// Compute pixel coordinates locally inside the caller frame scope
	ivec2 currentPos = srcOffset + ivec2(p);
	
	// Sample texture unit maps cleanly into the pipeline registers
	AF3 rgbColor = texelFetch(imgSrc, currentPos, 0).rgb;
	
	// Apply your custom dark screen profile blend calculation
	rgbColor *= 0.97f;
	
	// Isolate bounds mask checking dynamically to avoid global register pollution
	int x = currentPos.x & 7;
	int y = currentPos.y & 7;
	float noise = (getDitherValue(x, y) / 64.0f - 0.5f) * (1.0f / 128.0f);
	
	// Clamp limits explicitly before feeding variables to the CAS routine
	rgbColor.r = clamp(rgbColor.r + noise, 0.0f, 1.0f);
	rgbColor.g = clamp(rgbColor.g + noise, 0.0f, 1.0f);
	rgbColor.b = clamp(rgbColor.b + noise, 0.0f, 1.0f);
	
	return rgbColor;
}

void CasInput(inout AF1 r, inout AF1 g, inout AF1 b) {}

#include "ffx_cas.h"

layout(local_size_x=64) in;
void main()
{
	// Remap thread arrays for local PlayStation-like hw layout swizzle patterns
	AU2 gxy = ARmp8x8(gl_LocalInvocationID.x) + AU2(gl_WorkGroupID.x << 4u, gl_WorkGroupID.y << 4u);

	// Enforce alpha channel to 1.0f to stabilize fast-path swapchains on ANGLE backends
	AF4 c = vec4(0.0f, 0.0f, 0.0f, 1.0f);
	
	CasFilter(c.r, c.g, c.b, gxy, const0, const1, CAS_SHARPEN_ONLY);
	imageStore(imgDst, ASU2(gxy), c);
	gxy.x += 8u;
	
	CasFilter(c.r, c.g, c.b, gxy, const0, const1, CAS_SHARPEN_ONLY);
	imageStore(imgDst, ASU2(gxy), c);
	gxy.y += 8u;

	CasFilter(c.r, c.g, c.b, gxy, const0, const1, CAS_SHARPEN_ONLY);
	imageStore(imgDst, ASU2(gxy), c);
	gxy.x -= 8u;

	CasFilter(c.r, c.g, c.b, gxy, const0, const1, CAS_SHARPEN_ONLY);
	imageStore(imgDst, ASU2(gxy), c);
}

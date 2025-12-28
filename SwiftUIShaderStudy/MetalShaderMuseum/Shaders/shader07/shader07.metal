#include <metal_stdlib>
#include "../../../MetalCommon/ShaderCommonUniform.h"
#include "../../../MetalCommon/shadersample_internal.h"

using namespace metal;

// MARK: - Ray Marching Constants
constant int MAX_STEPS = 100;
constant float MAX_DIST = 100.0;
constant float SURF_DIST = 0.001;

struct Shader07Parameters {
    float radius;
    float grooveWidth;
    float patternScale;
    float bumpHeight;
};

// MARK: - SDF Functions

// Smooth Minimum (Polynomial)
static float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

static float sdSphere(float3 p, float s) {
    return length(p) - s;
}

static float getDist(float3 p, float time, float radius, float grooveWidth, float patternScale, float bumpHeight) {
    // Central sphere (fixed size 0.3 as requested)
    float d1 = sdSphere(p, 0.3);
    
    // Moving sphere (size 0.1)
    // Move in a Lissajous-like curve or just complex orbit passing through zero
    float t = time;
    float3 pos2 = float3(sin(t * 1.5), sin(t * 1.2) * cos(t * 0.8), cos(t * 0.5));
    // Scale movement to keep it somewhat near center but passing through
    pos2 *= 0.6; 
    
    float d2 = sdSphere(p - pos2, 0.1);
    
    // Smooth blending
    // k controls the smoothness of the blend.
    float k = 0.2;
    
    return smin(d1, d2, k);
}

static float rayMarch(float3 ro, float3 rd, float time, float radius, float grooveWidth, float patternScale, float bumpHeight) {
    float dO = 0.0;
    for (int i = 0; i < MAX_STEPS; ++i) {
        float3 p = ro + rd * dO;
        float dS = getDist(p, time, radius, grooveWidth, patternScale, bumpHeight);
        dO += dS;
        if (dO > MAX_DIST || abs(dS) < SURF_DIST) break;
    }
    return dO;
}

static float3 getNormal(float3 p, float time, float radius, float grooveWidth, float patternScale, float bumpHeight) {
    float d = getDist(p, time, radius, grooveWidth, patternScale, bumpHeight);
    float2 e = float2(0.001, 0.0);
    float3 n = d - float3(
        getDist(p - e.xyy, time, radius, grooveWidth, patternScale, bumpHeight),
        getDist(p - e.yxy, time, radius, grooveWidth, patternScale, bumpHeight),
        getDist(p - e.yyx, time, radius, grooveWidth, patternScale, bumpHeight)
    );
    return normalize(n);
}

static float3 getLight(float3 p, float3 rd, float time, float radius, float grooveWidth, float patternScale, float bumpHeight) {
    float3 lightPos = float3(2.0, 5.0, 3.0);
    float3 l = normalize(lightPos - p);
    float3 n = getNormal(p, time, radius, grooveWidth, patternScale, bumpHeight);
    
    float dif = clamp(dot(n, l), 0.0, 1.0);
    float3 halfVec = normalize(l - rd);
    float spec = pow(clamp(dot(n, halfVec), 0.0, 1.0), 32.0);
    
    float3 surfaceColor = float3(0.2, 0.6, 1.0); // Blueish
    float3 amb = float3(0.5, 0.6, 0.7) * 0.2;
    float3 col = surfaceColor * (amb + dif) + spec * 0.5;
    return col;
}

// MARK: - Main Fragment Shader

fragment float4 shader07Fragment(VertexOut data [[stage_in]],
                                 constant ShaderCommonUniform *uniform [[buffer(0)]],
                                 constant Shader07Parameters *params [[buffer(1)]]) {
    float2 uv = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);
    uv.y = -uv.y;
    
    float zoom = clamp(uniform->scale, 0.1, 10.0);
    float2 rot = uniform->drag / min(data.vsize.x, data.vsize.y) * 5.0;
    
    float3 ro = float3(0.0, 0.0, -3.0 / zoom);
    
    // Camera rotation
    float cy = cos(-rot.x);
    float sy = sin(-rot.x);
    ro.xz = float2(ro.x * cy - ro.z * sy, ro.x * sy + ro.z * cy);
    
    float cx = cos(-rot.y);
    float sx = sin(-rot.y);
    ro.yz = float2(ro.y * cx - ro.z * sx, ro.y * sx + ro.z * cx);
    
    float3 rd = normalize(float3(uv.x, uv.y, 1.0));
    
    // Rotate rd same as ro
    rd.xz = float2(rd.x * cy - rd.z * sy, rd.x * sy + rd.z * cy);
    rd.yz = float2(rd.y * cx - rd.z * sx, rd.y * sx + rd.z * cx);
    
    
    float radius = params ? params->radius : 0.8;
    float grooveWidth = params ? params->grooveWidth : 0.8; // Threshold for smoothstep
    float patternScale = params ? params->patternScale : 5.0;
    float bumpHeight = params ? params->bumpHeight : 0.05;
    
    float d = rayMarch(ro, rd, uniform->time, radius, grooveWidth, patternScale, bumpHeight);
    
    float3 col = float3(0.0);
    
    if (d < MAX_DIST) {
        float3 p = ro + rd * d;
        col = getLight(p, rd, uniform->time, radius, grooveWidth, patternScale, bumpHeight);
    }
    
    col = pow(col, float3(0.4545)); // Gamma correction
    return float4(col, 1.0);
}

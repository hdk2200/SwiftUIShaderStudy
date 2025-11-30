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

static float sdSphere(float3 p, float s) {
    return length(p) - s;
}

static float geometricPattern(float3 p, float scale, float width) {
    // Create a grid-like pattern on the sphere
    // Use sine waves to create a lattice
    float3 q = p * scale;
    
    // Pattern 1: Cubic lattice
    // float val = max(abs(sin(q.x)), max(abs(sin(q.y)), abs(sin(q.z))));
    
    // Pattern 2: Smoother grid
    float val = sin(q.x) * sin(q.y) * sin(q.z);
    
    // Map to 0-1 range roughly
    val = val * 0.5 + 0.5;
    
    // Create grooves: when val is close to specific values (e.g. 0.5)
    // Let's try to make "grooves" where the sine waves intersect or peak
    
    // Simple approach:
    // abs(sin(x)) creates peaks.
    // max(abs(sin(x)), abs(sin(y))...) creates a grid structure.
    
    float3 s = abs(sin(q));
    float grid = max(s.x, max(s.y, s.z));
    
    // Invert so that high values are "surface" and low values are "grooves"
    // or vice versa.
    // Let's say we want grooves.
    // If we subtract this pattern from the sphere radius, we get cuts.
    
    // Let's use a smoothstep to define the groove width
    // width 0.0 -> 1.0
    // We want a value that is 1.0 (no cut) most places, and 0.0 (deep cut) in grooves.
    
    float groove = smoothstep(width, width + 0.1, grid);
    
    return groove;
}

static float getDist(float3 p, float time, float radius, float grooveWidth, float patternScale, float bumpHeight) {
    float dSphere = sdSphere(p, radius);
    
    // Rotate pattern over time
    float t = time * 0.2;
    float c = cos(t);
    float s = sin(t);
    float3 q = p;
    q.xz = float2(q.x * c - q.z * s, q.x * s + q.z * c);
    
    float pattern = geometricPattern(q, patternScale, grooveWidth);
    
    // Apply displacement
    // We want the pattern to carve INTO the sphere or stick OUT.
    // Let's make it stick out or carve in based on bumpHeight.
    // If bumpHeight is positive, it sticks out.
    
    // pattern is 0..1.
    // 1.0 = full height, 0.0 = base level.
    
    float displacement = pattern * bumpHeight;
    
    // We subtract displacement from distance to add material
    // d = sphere - displacement
    
    return dSphere - displacement;
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
    
    // Color
    // Make grooves darker or different color?
    // We can re-calculate the pattern value to decide color.
    
    // Re-calc pattern for coloring
    float t = time * 0.2;
    float c = cos(t);
    float s = sin(t);
    float3 q = p;
    q.xz = float2(q.x * c - q.z * s, q.x * s + q.z * c);
    float pattern = geometricPattern(q, patternScale, grooveWidth);
    
    float3 surfaceColor = float3(0.8, 0.3, 0.2); // Reddish
    float3 grooveColor = float3(0.1, 0.1, 0.1);  // Dark
    
    float3 col = mix(grooveColor, surfaceColor, pattern);
    
    float3 amb = float3(0.1);
    
    return col * (amb + dif) + spec * 0.5;
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

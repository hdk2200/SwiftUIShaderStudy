#include <metal_stdlib>
#include "../../../MetalCommon/ShaderCommonUniform.h"
#include "../../../MetalCommon/shadersample_internal.h"

using namespace metal;

// Ray Marching Constants
constant int MAX_STEPS = 100;
constant float MAX_DIST = 100.0;
constant float SURF_DIST = 0.001;

// Helper Functions
static float mod(float x, float y) {
    return x - y * floor(x / y);
}

static float3 palette(float t) {
    float3 a = float3(0.5, 0.5, 0.5);
    float3 b = float3(0.5, 0.5, 0.5);
    float3 c = float3(1.0, 1.0, 1.0);
    float3 d = float3(0.263, 0.416, 0.557);
    return a + b * cos(6.28318 * (c * t + d));
}

static float3 rotate(float3 p, float3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return p * c + cross(axis, p) * s + axis * dot(axis, p) * oc;
}

// SDF Functions
static float sdSphere(float3 p, float s) {
    return length(p) - s;
}

static float sdBox(float3 p, float3 b) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

static float sdOctahedron(float3 p, float s) {
    p = abs(p);
    return (p.x + p.y + p.z - s) * 0.57735027;
}

static float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Scene Description
static float getDist(float3 p, float time) {
    // Domain Repetition
    float3 q = p;
    q.z += time * 0.5; // Move forward
    q.xy = fract(q.xy) - 0.5; // Repetition in XY
    q.z = mod(q.z, 2.0) - 1.0; // Repetition in Z
    
    // Rotate objects
    q = rotate(q, float3(1, 1, 0), time * 0.5);
    
    float sphere = sdSphere(q, 0.2);
    float box = sdBox(q, float3(0.15));
    float octa = sdOctahedron(q, 0.25);
    
    // Morphing between shapes
    float d = mix(box, sphere, sin(time) * 0.5 + 0.5);
    d = smin(d, octa, 0.1);
    
    return d * 0.7; // Correction for distortion
}

// Ray Marching Loop
static float rayMarch(float3 ro, float3 rd, float time) {
    float dO = 0.0;
    
    for(int i = 0; i < MAX_STEPS; i++) {
        float3 p = ro + rd * dO;
        float dS = getDist(p, time);
        dO += dS;
        if(dO > MAX_DIST || abs(dS) < SURF_DIST) break;
    }
    
    return dO;
}

// Normal Calculation
static float3 getNormal(float3 p, float time) {
    float d = getDist(p, time);
    float2 e = float2(0.001, 0);
    
    float3 n = d - float3(
        getDist(p - e.xyy, time),
        getDist(p - e.yxy, time),
        getDist(p - e.yyx, time)
    );
    
    return normalize(n);
}

// Lighting
static float3 getLight(float3 p, float3 rd, float time) {
    float3 lightPos = float3(2, 4, -3);
    // lightPos.xz += float2(sin(time), cos(time)) * 2.0;
    
    float3 l = normalize(lightPos - p);
    float3 n = getNormal(p, time);
    
    // Diffuse
    float dif = clamp(dot(n, l), 0.0, 1.0);
    
    // Specular
    float3 r = reflect(-l, n);
    float spec = pow(clamp(dot(r, -rd), 0.0, 1.0), 32.0);
    
    // Shadow
    float d = rayMarch(p + n * SURF_DIST * 2.0, l, time);
    if(d < length(lightPos - p)) dif *= 0.1;
    
    // Color based on position and normal
    float3 col = palette(length(p) * 0.1 + time * 0.2 + p.z * 0.1);
    
    // Combine lighting
    float3 amb = float3(0.1);
    col = col * (dif + amb) + float3(spec);
    
    return col;
}

fragment float4 shader04Fragment(VertexOut data [[stage_in]], constant ShaderCommonUniform *uniform [[buffer(0)]]) {
    float2 uv = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);
    
    // Interaction Parameters
    float zoom = clamp(uniform->scale, 0.1, 5.0);
    float2 rot = uniform->drag / min(data.vsize.x, data.vsize.y) * 5.0; // Sensitivity
    float roll = uniform->rotation;
    
    // Camera Setup
    float3 ro = float3(0, 0, -3.0 / zoom); // Zoom affects distance
    
    // Rotate camera based on drag
    ro = rotate(ro, float3(1, 0, 0), -rot.y);
    ro = rotate(ro, float3(0, 1, 0), -rot.x);
    
    float3 rd = normalize(float3(uv.x, uv.y, 1.5));
    
    // Apply camera rotation to ray direction
    rd = rotate(rd, float3(0, 0, 1), -roll); // Roll
    rd = rotate(rd, float3(1, 0, 0), -rot.y);
    rd = rotate(rd, float3(0, 1, 0), -rot.x);
    
    float d = rayMarch(ro, rd, uniform->time);
    
    float3 col = float3(0.0);
    
    if(d < MAX_DIST) {
        float3 p = ro + rd * d;
        col = getLight(p, rd, uniform->time);
        
        // Fog
        col = mix(col, float3(0.05, 0.05, 0.1), 1.0 - exp(-0.08 * d));
    } else {
        // Background
        col = float3(0.05, 0.05, 0.1);
    }

    // Gamma correction
    col = pow(col, float3(0.4545));

    return float4(col, 1.0);
}

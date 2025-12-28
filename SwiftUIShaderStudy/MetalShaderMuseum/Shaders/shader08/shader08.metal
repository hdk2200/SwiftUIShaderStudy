#include <metal_stdlib>
#include "../../../MetalCommon/ShaderCommonUniform.h"
#include "../../../MetalCommon/shadersample_internal.h"

using namespace metal;

struct Shader08Parameters {
    float blendStrength;
    int maxSteps;
    float hitThreshold;
    float maxDist;
    int blendMode; // 0: smax, 1: sub, 2: xor
    float timeScale;
};

// MARK: - SDF Boolean Operations

// Smooth Intersection (smax)
static float opSmoothIntersection(float d1, float d2, float k) {
    float h = clamp(0.5 - 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) + k * h * (1.0 - h);
}

// Smooth Subtraction
static float opSmoothSubtraction(float d1, float d2, float k) {
    float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0);
    return mix(d2, -d1, h) + k * h * (1.0 - h);
}

// Smooth XOR (Exclusive OR)
static float opSmoothXor(float d1, float d2, float k) {
    float h_union = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    float s_union = mix(d2, d1, h_union) - k * h_union * (1.0 - h_union);
    
    float h_inter = clamp(0.5 - 0.5 * (d2 - d1) / k, 0.0, 1.0);
    float s_inter = mix(d2, d1, h_inter) + k * h_inter * (1.0 - h_inter);
    
    // Smooth Subtraction: Union - Intersection
    float h_sub = clamp(0.5 - 0.5 * (s_union + s_inter) / k, 0.0, 1.0);
    return mix(s_union, -s_inter, h_sub) + k * h_sub * (1.0 - h_sub);
}


// MARK: - Scene Helpers

static float sdSphere(float3 p, float s) {
    return length(p) - s;
}

static float sdBox(float3 p, float3 b) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

static float3 rotate(float3 p, float3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    return p * c + cross(axis, p) * s + axis * dot(axis, p) * oc;
}

// Scene Description
// Changed 'constant Shader08Parameters &params' to value 'Shader08Parameters params'
// to allow passing both constant buffer values and thread-local copies.
static float getDist(float3 p, float time, Shader08Parameters params) {
    
    // Object A: Central Box
    float3 pBox = p;
    pBox = rotate(pBox, float3(1, 1, 0), time * 0.5);
    float dBox = sdBox(pBox, float3(0.5));
    
    // Object B: Orbiting Sphere
    float3 pSphere = p;
    float orbitR = 0.8;
    float3 spherePos = float3(cos(time) * orbitR, sin(time) * orbitR * 0.5, sin(time) * orbitR);
    float dSphere = sdSphere(pSphere - spherePos, 0.6);
    
    // Apply selected blend
    float d = dBox;
    if (params.blendMode == 0) {
        d = opSmoothIntersection(dBox, dSphere, params.blendStrength);
    } else if (params.blendMode == 1) {
        d = opSmoothSubtraction(dSphere, dBox, params.blendStrength);
    } else {
        d = opSmoothXor(dBox, dSphere, params.blendStrength);
    }
    
    return d;
}

static float3 getNormal(float3 p, float time, Shader08Parameters params) {
    float2 e = float2(0.001, 0.0);
    float d = getDist(p, time, params);
    float3 n = d - float3(
        getDist(p - e.xyy, time, params),
        getDist(p - e.yxy, time, params),
        getDist(p - e.yyx, time, params)
    );
    return normalize(n);
}

static float3 getLight(float3 p, float3 rd, float time, Shader08Parameters params) {
    float3 lightPos = float3(2.0, 4.0, 3.0);
    float3 l = normalize(lightPos - p);
    float3 n = getNormal(p, time, params);

    float dif = clamp(dot(n, l), 0.0, 1.0);
    float3 halfVec = normalize(l - rd);
    float spec = pow(clamp(dot(n, halfVec), 0.0, 1.0), 32.0);
    
    float3 col = 0.5 + 0.5 * n;
    col = mix(float3(0.1, 0.2, 0.3), float3(0.8, 0.7, 0.6), dif);
    col += float3(spec) * 0.5;

    return col;
}


// MARK: - Fragment Shader

fragment float4 shader08Fragment(VertexOut data [[stage_in]],
                                 constant ShaderCommonUniform *uniform [[buffer(0)]],
                                 constant Shader08Parameters *params [[buffer(1)]]) {
    Shader08Parameters p;
    if (params) {
        p = *params;
    } else {
        p.blendStrength = 0.1;
        p.maxSteps = 64;
        p.hitThreshold = 0.001;
        p.maxDist = 48.0;
        p.blendMode = 0;
        p.timeScale = 1.0;
    }
    
    float2 uv = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);
    uv.y = -uv.y;

    float dragScale = 5.0 / min(data.vsize.x, data.vsize.y);
    float2 pan = uniform->drag * dragScale; 
    
    float zoom = clamp(uniform->scale, 0.1, 10.0);
    
    // Camera Setup
    float3 ro = float3(0.0, 0.0, 3.0);
    ro.z /= zoom;
    ro.x -= pan.x;
    ro.y += pan.y;
    
    float3 rd = normalize(float3(uv, -1.5));
    float angle = uniform->rotation;
    rd = rotate(rd, float3(0,0,1), angle);
    
    // Ray Marching
    float dO = 0.0;
    float3 col = float3(0.05, 0.05, 0.08); // Background
    
    int steps = p.maxSteps;
    float maxD = p.maxDist;
    float thres = p.hitThreshold;
    
    bool hit = false;
    for (int i = 0; i < 200; ++i) {
        if (i >= steps) break;
        float3 pPos = ro + rd * dO;
        float dS = getDist(pPos, uniform->time * p.timeScale, p);
        if (abs(dS) < thres) {
            hit = true;
            break;
        }
        dO += dS;
        if (dO > maxD) break;
    }
    
    if (hit) {
        float3 pPos = ro + rd * dO;
        col = getLight(pPos, rd, uniform->time * p.timeScale, p);
    }
    
    col = pow(col, float3(0.4545));
    return float4(col, 1.0);
}

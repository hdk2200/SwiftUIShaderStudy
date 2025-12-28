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
    float baseAlpha;
};

// Smooth Union (smin)
static float opSmoothUnion(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

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

// Morph
static float opMorph(float d1, float d2, float t) {
    return mix(d1, d2, t);
}

// Stepped Union
static float opSteppedUnion(float d1, float d2, float k, float n) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    h = floor(h * n) / n;
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

// Chamfer Union
static float opChamferUnion(float d1, float d2, float r) {
    return min(min(d1, d2), (d1 + d2 - r) * 0.7071067);
}

// Groove Union
static float opGrooveUnion(float d1, float d2, float ra, float rb) {
    float d = min(d1, d2);
    return max(d, ra - abs(d1 - d2 - rb));
}


// MARK: - Scene Constants
constant float3 kBoxSize = float3(0.5);
constant float3 kBoxRotateAxis = float3(0.5, 0.3, 0.1);
constant float  kBoxRotateSpeed = 0.5;

constant float  kSphereRadius = 0.7;
constant float3 kSphereOffset = float3(0.0, 0.3, 0.2); // Shift path from center
constant float3 kSphereOscFreq = float3(0.6, 0.5, 0.3);
constant float3 kSphereOscAmp = float3(1.5, 0.4, 0.2);

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
static float getDist(float3 p, float time, Shader08Parameters params) {
    
    // Object A: Central Box
    float3 pBox = p;
    pBox = rotate(pBox, kBoxRotateAxis, time * kBoxRotateSpeed);
    float dBox = sdBox(pBox, kBoxSize);
    
    // Object B: Oscillating Sphere (Passes through and returns)
    float3 pSphere = p;
    float3 spherePos = kSphereOffset + float3(
        sin(time * kSphereOscFreq.x) * kSphereOscAmp.x,
        sin(time * kSphereOscFreq.y) * kSphereOscAmp.y,
        cos(time * kSphereOscFreq.z) * kSphereOscAmp.z
    );
    float dSphere = sdSphere(pSphere - spherePos, kSphereRadius);
    
    // Apply selected blend
    float d = dBox;
    if (params.blendMode == 0) {
        d = opSmoothUnion(dBox, dSphere, params.blendStrength);
    } else if (params.blendMode == 1) {
        d = opSmoothIntersection(dBox, dSphere, params.blendStrength);
    } else if (params.blendMode == 2) {
        d = opSmoothSubtraction(dSphere, dBox, params.blendStrength);
    } else if (params.blendMode == 3) {
        d = opMorph(dBox, dSphere, params.blendStrength);
    } else if (params.blendMode == 4) {
        d = opSteppedUnion(dBox, dSphere, params.blendStrength, 8.0);
    } else if (params.blendMode == 5) {
        d = opChamferUnion(dBox, dSphere, params.blendStrength);
    } else {
        d = opGrooveUnion(dBox, dSphere, params.blendStrength * 0.3, params.blendStrength * 0.1);
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

static float getGhostDist(float3 p, float time, Shader08Parameters params) {
    // Object A: Central Box
    float3 pBox = p;
    pBox = rotate(pBox, kBoxRotateAxis, time * kBoxRotateSpeed);
    float dBox = sdBox(pBox, kBoxSize);
    
    // Object B: Oscillating Sphere
    float3 pSphere = p;
    float3 spherePos = kSphereOffset + float3(
        sin(time * kSphereOscFreq.x) * kSphereOscAmp.x,
        sin(time * kSphereOscFreq.y) * kSphereOscAmp.y,
        cos(time * kSphereOscFreq.z) * kSphereOscAmp.z
    );
    float dSphere = sdSphere(pSphere - spherePos, kSphereRadius);
    
    return min(dBox, dSphere);
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
        p.timeScale = 0.8;
        p.baseAlpha = 0.2;
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
    rd = rotate(rd, float3(1,0,1), angle);
    
    // Ray Marching (Main Blended Shapes)
    float dO = 0.0;
    float3 bgCol = float3(0.05, 0.05, 0.08); // Background
    float3 col = bgCol;
    
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
    } else if (p.baseAlpha > 0.0) {
        // Ray Marching for Ghost Shapes
        float dO_g = 0.0;
        bool ghost_hit = false;
        for (int i = 0; i < 200; ++i) {
            if (i >= steps) break;
            float3 pPos = ro + rd * dO_g;
            float dS_g = getGhostDist(pPos, uniform->time * p.timeScale, p);
            if (abs(dS_g) < thres) {
                ghost_hit = true;
                break;
            }
            dO_g += dS_g;
            if (dO_g > maxD) break;
        }
        
        if (ghost_hit) {
            float3 pPos = ro + rd * dO_g;
            float3 ghostCol = getLight(pPos, rd, uniform->time * p.timeScale, p);
            col = mix(bgCol, ghostCol, p.baseAlpha);
        }
    }
    
    col = pow(col, float3(0.4545));
    return float4(col, 1.0);
}

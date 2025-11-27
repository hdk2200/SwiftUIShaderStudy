#include <metal_stdlib>
#include "../../../MetalCommon/ShaderCommonUniform.h"
#include "../../../MetalCommon/shadersample_internal.h"

using namespace metal;

// MARK: - Ray Marching Constants
constant int MAX_STEPS = 80;
constant float MAX_DIST = 80.0;
constant float SURF_DIST = 0.001;

// MARK: - Helpers
static float3 rotate(float3 p, float3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    return p * c + cross(axis, p) * s + axis * dot(axis, p) * oc;
}

static float2 rotate2D(float2 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

static float sdPlaneZ(float3 p, float h) {
    return p.z - h;
}

static float sdSphere(float3 p, float s) {
    return length(p) - s;
}

static float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// MARK: - Scene Functions
static float getRepeatedSpheres(float3 p, float time) {
    float2 cellSize = float2(0.35, 0.35);
    float2 baseCell = floor(p.xy / cellSize);
    float minDist = 1000.0;

    for (int xi = -1; xi <= 1; ++xi) {
        for (int yi = -1; yi <= 1; ++yi) {
            float2 cellId = baseCell + float2(xi, yi);
            float2 cellCenter = (cellId + 0.5) * cellSize;
            float2 offset = p.xy - cellCenter;

            float rotation = dot(cellId, float2(0.37, 0.61));
            float2 orbitOffset = rotate2D(float2(0.08, 0.0), rotation);
            float2 local = offset - orbitOffset;

            float oscillation = sin(time * 1.3 + rotation * 2.3);
            float sphereCenterZ = oscillation * 0.15;
            float3 sample = float3(local, p.z - sphereCenterZ);

            float dist = sdSphere(sample, 0.05);
            minDist = min(minDist, dist);
        }
    }

    return minDist;
}

static float getDist(float3 p, float time) {
    float planeDist = sdPlaneZ(p, 0.0);
    float spheres = getRepeatedSpheres(p, time);
    return smin(planeDist, spheres, 0.03);
}

static float rayMarch(float3 ro, float3 rd, float time) {
    float dO = 0.0;
    for (int i = 0; i < MAX_STEPS; ++i) {
        float3 p = ro + rd * dO;
        float dS = getDist(p, time);
        dO += dS;
        if (dO > MAX_DIST || abs(dS) < SURF_DIST) break;
    }
    return dO;
}

static float3 getNormal(float3 p, float time) {
    float d = getDist(p, time);
    float2 e = float2(0.001, 0.0);
    float3 n = d - float3(
        getDist(p - e.xyy, time),
        getDist(p - e.yxy, time),
        getDist(p - e.yyx, time)
    );
    return normalize(n);
}

static float3 getLight(float3 p, float3 rd, float time) {
    float3 lightPos = float3(-1.2, 1.8, 1.6);
    float3 l = normalize(lightPos - p);
    float3 n = getNormal(p, time);

    float dif = clamp(dot(n, l), 0.0, 1.0);
    float3 halfVec = normalize(l - rd);
    float spec = pow(clamp(dot(n, halfVec), 0.0, 1.0), 32.0);

    float sphereField = getRepeatedSpheres(p, time);
    float sphereMask = 1.0 - smoothstep(-0.01, 0.05, sphereField);

    float3 planeColor = float3(0.35, 0.36, 0.38);
    float3 sphereColor = float3(0.82, 0.86, 0.92);
    float3 baseCol = mix(planeColor, sphereColor, sphereMask);

    float3 amb = float3(0.12, 0.13, 0.15);
    return baseCol * (amb + dif) + float3(spec);
}

fragment float4 shader06Fragment(VertexOut data [[stage_in]],
                                 constant ShaderCommonUniform *uniform [[buffer(0)]]) {
    float2 uv = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);
    uv.y = -uv.y;

    float zoom = clamp(uniform->scale, 0.1, 5.0);
    float2 rot = uniform->drag / min(data.vsize.x, data.vsize.y) * 5.0;
    float roll = uniform->rotation;

    float3 ro = float3(0.0, 0.25, 2.2 / zoom);
    ro = rotate(ro, float3(1, 0, 0), -rot.y);
    ro = rotate(ro, float3(0, 1, 0), -rot.x);

    float3 rd = normalize(float3(uv.x, uv.y, -1.4));
    rd = rotate(rd, float3(0, 0, 1), -roll);
    rd = rotate(rd, float3(1, 0, 0), -rot.y);
    rd = rotate(rd, float3(0, 1, 0), -rot.x);

    float dist = rayMarch(ro, rd, uniform->time);
    float3 col = float3(0.18, 0.19, 0.22);

    if (dist < MAX_DIST) {
        float3 p = ro + rd * dist;
        col = getLight(p, rd, uniform->time);
        col = mix(col, float3(0.1, 0.11, 0.13), 1.0 - exp(-0.04 * dist));
    }

    col = pow(col, float3(0.4545));
    return float4(col, 1.0);
}

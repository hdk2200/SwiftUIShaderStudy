#include <metal_stdlib>
#include "../../../MetalCommon/ShaderCommonUniform.h"
#include "../../../MetalCommon/shadersample_internal.h"

using namespace metal;

// MARK: - Ray Marching Constants
constant int MAX_STEPS = 64;
constant float MAX_DIST = 48.0;
constant float SURF_DIST = 0.001;

struct Shader06Parameters {
    float sminBlend;
    float cellSize;
    float sphereAmplitude;
    float oscillationSpeed;
    float sphereRadius;
};

// MARK: - Helpers
static float3 rotate(float3 p, float3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    return p * c + cross(axis, p) * s + axis * dot(axis, p) * oc;
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

static float sampleSphereCell(float3 p,
                              float2 offset,
                              float2 cellId,
                              float time,
                              float amplitude,
                              float speed,
                              float radius) {
    float rotation = dot(cellId, float2(0.37, 0.61));
    float s = sin(rotation);
    float c = cos(rotation);
    float orbitRadius = 0.08;
    float2 orbitOffset = float2(c, s) * orbitRadius;

    float2 local = offset - orbitOffset;
    float freq = max(speed, 0.05);
    float normalized = fract(time * freq + rotation * 0.31);
    normalized = min(normalized + 0.001, 1.0);
    float sphereCenterZ = mix(-amplitude, amplitude, normalized);
    float3 sample = float3(local, p.z - sphereCenterZ);

    float clampedRadius = clamp(radius, 0.02, 0.15);
    return sdSphere(sample, clampedRadius);
}

// MARK: - Scene Functions
static float getRepeatedSpheres(float3 p, float time, float cellSize, float amplitude, float speed, float radius) {
    float spacing = clamp(cellSize, 0.15, 0.8);
    float2 cell = float2(spacing, spacing);
    float2 gridCoord = (p.xy + cell * 0.5) / cell;
    float2 baseId = floor(gridCoord);
    float2 local = (fract(gridCoord) - 0.5) * cell;
    float minDist = 1000.0;

    float2 axisSign = float2(local.x >= 0.0 ? 1.0 : -1.0,
                             local.y >= 0.0 ? 1.0 : -1.0);
    float2 shiftX = float2(axisSign.x, 0.0) * cell;
    float2 shiftY = float2(0.0, axisSign.y) * cell;

    minDist = min(minDist, sampleSphereCell(p, local, baseId, time, amplitude, speed, radius));
    minDist = min(minDist, sampleSphereCell(p, local - shiftX, baseId + float2(axisSign.x, 0.0), time, amplitude, speed, radius));
    minDist = min(minDist, sampleSphereCell(p, local - shiftY, baseId + float2(0.0, axisSign.y), time, amplitude, speed, radius));
    minDist = min(minDist, sampleSphereCell(p, local - shiftX - shiftY, baseId + axisSign, time, amplitude, speed, radius));

    return minDist;
}

static float getDist(float3 p, float time, float blend, float cellSize, float amplitude, float speed, float radius) {
    float planeDist = sdPlaneZ(p, 0.0);
    float spheres = getRepeatedSpheres(p, time, cellSize, amplitude, speed, radius);
    return smin(planeDist, spheres, blend);
}

static float rayMarch(float3 ro, float3 rd, float time, float blend, float cellSize, float amplitude, float speed, float radius) {
    float dO = 0.0;
    for (int i = 0; i < MAX_STEPS; ++i) {
        float3 p = ro + rd * dO;
        float dS = getDist(p, time, blend, cellSize, amplitude, speed, radius);
        dO += dS;
        if (dO > MAX_DIST || abs(dS) < SURF_DIST) break;
    }
    return dO;
}

static float3 getNormal(float3 p, float time, float blend, float cellSize, float amplitude, float speed, float radius) {
    float d = getDist(p, time, blend, cellSize, amplitude, speed, radius);
    float2 e = float2(0.001, 0.0);
    float3 n = d - float3(
        getDist(p - e.xyy, time, blend, cellSize, amplitude, speed, radius),
        getDist(p - e.yxy, time, blend, cellSize, amplitude, speed, radius),
        getDist(p - e.yyx, time, blend, cellSize, amplitude, speed, radius)
    );
    return normalize(n);
}

static float3 getLight(float3 p, float3 rd, float time, float blend, float cellSize, float amplitude, float speed, float radius) {
    float3 lightPos = float3(-1.2, 1.8, 1.6);
    float3 l = normalize(lightPos - p);
    float3 n = getNormal(p, time, blend, cellSize, amplitude, speed, radius);

    float dif = clamp(dot(n, l), 0.0, 1.0);
    float3 halfVec = normalize(l - rd);
    float spec = pow(clamp(dot(n, halfVec), 0.0, 1.0), 32.0);

    float sphereField = getRepeatedSpheres(p, time, cellSize, amplitude, speed, radius);
    float sphereMask = 1.0 - smoothstep(-0.01, 0.05, sphereField);

    float3 planeColor = float3(0.35, 0.36, 0.38);
    float3 sphereColor = float3(0.82, 0.86, 0.92);
    float3 baseCol = mix(planeColor, sphereColor, sphereMask);

    float3 amb = float3(0.12, 0.13, 0.15);
    return baseCol * (amb + dif) + float3(spec);
}

fragment float4 shader06Fragment(VertexOut data [[stage_in]],
                                 constant ShaderCommonUniform *uniform [[buffer(0)]],
                                 constant Shader06Parameters *params [[buffer(1)]]) {
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

    float blend = params ? params->sminBlend : 0.03;
    float cellSize = params ? params->cellSize : 0.35;
    float amplitude = params ? params->sphereAmplitude : 0.15;
    float speed = params ? params->oscillationSpeed : 1.3;
    float radius = params ? params->sphereRadius : 0.05;
    float dist = rayMarch(ro, rd, uniform->time, blend, cellSize, amplitude, speed, radius);
    float3 col = float3(0.18, 0.19, 0.22);

    if (dist < MAX_DIST) {
        float3 p = ro + rd * dist;
        col = getLight(p, rd, uniform->time, blend, cellSize, amplitude, speed, radius);
        col = mix(col, float3(0.1, 0.11, 0.13), 1.0 - exp(-0.04 * dist));
    }

    col = pow(col, float3(0.4545));
    return float4(col, 1.0);
}

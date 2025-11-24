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

static float sdPlane(float3 p, float h) {
    return p.y - h;
}

static float sdSphere(float3 p, float s) {
    return length(p) - s;
}

static float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

static float3 palette(float t) {
    float3 a = float3(0.5, 0.5, 0.5);
    float3 b = float3(0.5, 0.5, 0.5);
    float3 c = float3(1.0, 1.0, 1.0);
    float3 d = float3(0.263, 0.416, 0.557);
    return a + b * cos(6.28318 * (c * t + d));
}

// MARK: - Scene Functions
static float getSmallSphereField(float3 p, float time) {
    constexpr uint SMALL_SPHERE_COUNT = 48;
    float objectsDist = 1000.0;
    float spacing = 0.35;
    float baseRadius = 0.08;
    float timeOffset = time * 0.35;

    for (uint i = 0; i < SMALL_SPHERE_COUNT; ++i) {
        float fi = float(i);
        float ring = floor(fi / 12.0);
        float angle = (fi * 0.5) + timeOffset * (0.6 + 0.1 * ring);
        float radius = (ring + 1.0) * spacing;

        float wobble = sin(fi * 0.73 + time * 1.2) * 0.12;
        float height = -0.5 + ring * 0.08 + wobble;

        float3 center = float3(cos(angle) * radius, height, sin(angle) * radius);
        float size = baseRadius * (1.0 + 0.3 * sin(fi + time * 2.0));

        float dist = sdSphere(p - center, size);
        objectsDist = smin(objectsDist, dist, 0.25);
    }
    return objectsDist;
}

static float getDist(float3 p, float time) {
    float planeDist = sdPlane(p, -1.0);
    float spheres = getSmallSphereField(p, time);
    return smin(spheres, planeDist, 0.4);
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
    float3 lightPos = float3(2.0, 4.0, -3.0);
    float3 l = normalize(lightPos - p);
    float3 n = getNormal(p, time);

    float dif = clamp(dot(n, l), 0.0, 1.0);
    float3 r = reflect(-l, n);
    float spec = pow(clamp(dot(r, -rd), 0.0, 1.0), 24.0);

    float3 objectColor = palette(length(p) * 0.4 + time * 0.1);
    float3 planeColor = float3(0.2, 0.2, 0.25);

    float mixFactor = smoothstep(-0.1, 0.1, sdPlane(p, -1.0));
    float3 col = mix(objectColor, planeColor, mixFactor);

    float3 amb = float3(0.08);
    col = col * (dif + amb) + float3(spec);
    return col;
}

fragment float4 shader06Fragment(VertexOut data [[stage_in]],
                                 constant ShaderCommonUniform *uniform [[buffer(0)]]) {
    float2 uv = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);
    uv.y = -uv.y;

    float zoom = clamp(uniform->scale, 0.1, 5.0);
    float2 rot = uniform->drag / min(data.vsize.x, data.vsize.y) * 5.0;
    float roll = uniform->rotation;

    float3 ro = float3(0.0, 1.5, -4.0 / zoom);
    ro = rotate(ro, float3(1, 0, 0), -rot.y);
    ro = rotate(ro, float3(0, 1, 0), -rot.x);

    float3 rd = normalize(float3(uv.x, uv.y - 0.3, 1.5));
    rd = rotate(rd, float3(0, 0, 1), -roll);
    rd = rotate(rd, float3(1, 0, 0), -rot.y);
    rd = rotate(rd, float3(0, 1, 0), -rot.x);

    float dist = rayMarch(ro, rd, uniform->time);
    float3 col = float3(0.04, 0.05, 0.08);

    if (dist < MAX_DIST) {
        float3 p = ro + rd * dist;
        col = getLight(p, rd, uniform->time);
        col = mix(col, float3(0.03, 0.04, 0.08), 1.0 - exp(-0.04 * dist));
    }

    col = pow(col, float3(0.4545));
    return float4(col, 1.0);
}

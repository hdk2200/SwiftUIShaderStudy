#include <metal_stdlib>
using namespace metal;

#include "../../../MetalCommon/ShaderCommonUniform.h"
#include "../../../MetalCommon/shadersample_internal.h"
#include "../../../MetalCommon/SDFPrimitives.metal"

#ifndef M_PI
  #define M_PI 3.14159265359
#endif

inline float hash11(float n) {
  return fract(sin(n) * 43758.5453123);
}

inline float2 hash21(float2 p) {
  return fract(sin(float2(dot(p, float2(12.9898, 78.233)), dot(p, float2(39.3468, 11.135)))) *
               float2(43758.5453, 24634.6345));
}

inline float sdEquilateralTriangle(float2 p, float size) {
  const float k = 1.73205080757;  // sqrt(3)
  float invSize = 1.0 / max(size, 1e-4);
  p *= invSize;
  p.x = fabs(p.x) - 1.0;
  p.y = p.y + 1.0 / k;
  if (p.x + k * p.y > 0.0) {
    p = float2(p.x - k * p.y, -k * p.x - p.y) * 0.5;
  }
  p.x -= clamp(p.x, -2.0, 0.0);
  float dist = -length(p) * sign(p.y);
  return dist * size;
}

inline float2 rotate2(float2 p, float angle) {
  float s = sin(angle);
  float c = cos(angle);
  return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

inline float sdRing(float2 p, float radius, float thickness) {
  return fabs(length(p) - radius) - thickness;
}

inline float sdCapsule(float2 p, float2 a, float2 b, float r) {
  float2 pa = p - a;
  float2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h) - r;
}

static inline void accumulateShape(thread bool &hasShape, thread float &acc, float dist, float smooth) {
  acc = hasShape ? smin(acc, dist, smooth) : dist;
  hasShape = true;
}

fragment float4 fragment_primitives_smin(
  VertexOut data [[stage_in]],
  float2 uv [[point_coord]],
  constant ShaderCommonUniform *uniform [[buffer(0)]])
{
  float screenWH = min(data.vsize.x, data.vsize.y);
  float2 posShifted = data.position.xy - uniform->drag;
  float2 pos = (posShifted * 2.0 - data.vsize) / screenWH;
  float tm = uniform->time;
  float baseScale = clamp(uniform->scale, 0.001, 2.0);
  float centerScale = baseScale + 0.8;
  float seedOffset = float(uniform->seed) * 0.0013;
  float2 seedVec = float2(seedOffset, seedOffset * 1.37);

  float smooth = 0.2 * baseScale;
  float d = 1e5;
  bool hasShape = false;

  // ----- Circles -----
  const int maxCircles = 100;
  int circleCount = 5;  // adjust to add/remove circles easily
  circleCount = clamp(circleCount, 0, maxCircles);
  for (int i = 0; i < circleCount; ++i) {
    float fi = float(i);
    float seed = fi * 13.37 + seedOffset;
    float angle = hash11(seed) * M_PI * 2.0 + tm * 0.15;
    float radiusNoise = hash11(seed + 1.0);
    float2 radial = float2(cos(angle), sin(angle));
    float2 jitter = hash21(float2(seed, seed + 7.0) + seedVec) * 0.5 - 0.1;
    float2 drift = radial * (0.35 + 0.35 * sin(tm * 0.35 + fi)) + jitter;
    float2 circleCenter = drift * centerScale;
    float circleRadius = (0.15 + 0.1 * radiusNoise + 0.03 * sin(tm * 0.9 + fi)) * baseScale;
    float dist = circle(pos - circleCenter, circleRadius);
    accumulateShape(hasShape, d, dist, smooth);
  }

  // ----- Rectangles -----
  const int maxRects = 100;
  int rectCount = 0;
  rectCount = clamp(rectCount, 0, maxRects);
  for (int i = 0; i < rectCount; ++i) {
    float fi = float(i);
    float2 randOffset = hash21(float2(fi * 1.7, fi * 2.9) + seedVec) * 2.0 - 1.0;
    float2 rectCenter = randOffset * float2(1.0, 0.9);
    rectCenter += 0.25 * float2(sin(tm * 0.8 + fi), cos(tm * 0.9 + fi));
    rectCenter *= centerScale;
    float2 rectSize = float2(0.28 - 0.04 * hash11(fi + seedOffset), 0.18 + 0.04 * hash11(fi + 10.0 + seedOffset)) * baseScale;
    float angle = 0.5 * (hash11(fi + 5.0 + seedOffset) - 0.5) + 0.3 * sin(tm * 0.4 + fi);
    float2 rectPos = rotate2(pos - rectCenter, angle);
    float dist = box(rectPos, rectSize);
    accumulateShape(hasShape, d, dist, smooth);
  }

  // ----- Triangles -----
  const int maxTriangles = 100;
  int triangleCount = 0;
  triangleCount = clamp(triangleCount, 0, maxTriangles);
  for (int i = 0; i < triangleCount; ++i) {
    float fi = float(i);
    float2 hashVec = hash21(float2(fi * 3.1, fi * 6.7) + seedVec);
    float2 triCenter = hashVec * float2(1.6, 1.2) - float2(0.8, 0.6);
    triCenter += 0.35 * float2(sin(tm * 0.3 + fi), cos(tm * 0.2 + fi * 1.2));
    triCenter *= centerScale;
    float triAngle = (hash11(fi + 20.0 + seedOffset) - 0.5) * M_PI + 0.5 * sin(tm * 0.5 + fi);
    float2 triPos = rotate2(pos - triCenter, triAngle);
    float dist = sdEquilateralTriangle(triPos, (0.45 + 0.08 * fi) * baseScale);
    accumulateShape(hasShape, d, dist, smooth);
  }

  // ----- Rings -----
  const int maxRings = 100;
  int ringCount = 5;
  ringCount = clamp(ringCount, 0, maxRings);
  for (int i = 0; i < ringCount; ++i) {
    float fi = float(i);
    float2 center = hash21(float2(fi * 0.7, fi * 3.17) + seedVec) * 1.8 - 0.2;
    center += 0.2 * float2(cos(tm * 0.7 + fi), sin(tm * 0.6 + fi));
    center *= centerScale;
    float radius = (0.25 + 0.15 * hash11(fi + 40.0 + seedOffset) + 0.9 * sin(tm * 0.1 + fi)) * baseScale;
    float thickness = (0.02 + 0.02 * hash11(fi + 50.0 + seedOffset) + 0.01 * cos(tm * 0.9 + fi)) * baseScale;
    float dist = sdRing(pos - center, radius, thickness);
    accumulateShape(hasShape, d, dist, smooth);
  }

  // ----- Capsules / segments -----
  const int maxCapsules = 100;
  int capsuleCount = 0;
  capsuleCount = clamp(capsuleCount, 0, maxCapsules);
  for (int i = 0; i < capsuleCount; ++i) {
    float fi = float(i);
    float2 seeds = float2(fi * 5.3, fi * 2.1) + seedVec;
    float2 randA = hash21(seeds) * 1.6 - 0.8;
    float2 randB = hash21(seeds + float2(10.0, 10.0)) * 1.6 - 0.8;
    float2 baseA = randA * 1.1;
    float2 baseB = randB * 1.1;
    float jitter = 0.2 * sin(tm * (0.4 + 0.1 * fi) + fi * 1.3);
    float2 offset = rotate2(float2(jitter, 0.0), tm * 0.2 + fi);
    float2 a = (baseA + offset) * centerScale;
    float2 b = (baseB + offset) * centerScale;
    float radius = (0.03 + 0.02 * hash11(fi + 60.0 + seedOffset)) * baseScale;
    float dist = sdCapsule(pos, a, b, radius);
    accumulateShape(hasShape, d, dist, smooth);
  }

  float edge = 0.007;
  float mask = smoothstep(0.0, edge, -d);
  float inner = smoothstep(-smooth, smooth, -d);

  // Background gradient with subtle animation
  float3 bg =
    float3(0.06, 0.08, 0.11) +
    0.05 * float3(
      sin(tm * 0.2 + pos.x * 2.3),
      sin(tm * 0.17 + pos.y * 1.8 + 1.4),
      cos(tm * 0.15 + (pos.x + pos.y) * 1.1)
    );

  // Palette inspired by fragment_circle_smin
  float hue = length(pos * float2(0.8, 1.2));
  float3 wave = 0.5 + 0.5 * float3(
    sin(tm + hue * 3.0),
    sin(tm * 1.23 + pos.y * 2.7),
    cos(tm * 0.77 + (pos.x + pos.y) * 1.6)
  );

  float core = clamp((-d) / max(0.2, 0.45 * baseScale), 0.0, 1.0);
  float3 coreColor = mix(float3(0.7, 0.6, 0.9), float3(0.9, 0.95, 0.7), core);
  float3 fillColor = mix(wave, coreColor, core);

  float rim = smoothstep(0.0, edge * 4.0, abs(d));
  float3 rimColor = float3(1.0, 0.92, 0.85) * pow(1.0 - rim, 2.5) * 0.8;

  float glow = exp(-abs(d) * 15.0) * 0.15;
  float3 glowColor = float3(0.9, 0.5, 0.85) * glow;

  float3 finalColor = mix(bg, fillColor, mask);
  finalColor += rimColor * mask;
  finalColor += glowColor * mask;
  finalColor = clamp(finalColor, 0.0, 1.0);

  return float4(finalColor, 1.0);
}

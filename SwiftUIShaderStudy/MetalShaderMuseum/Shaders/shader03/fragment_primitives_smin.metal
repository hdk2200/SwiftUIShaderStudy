#include <metal_stdlib>
using namespace metal;

#include "../../../MetalCommon/ShaderCommonUniform.h"
#include "../../../MetalCommon/shadersample_internal.h"
#include "../../../MetalCommon/SDFPrimitives.metal"

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

fragment float4 fragment_primitives_smin(
  VertexOut data [[stage_in]],
  float2 uv [[point_coord]],
  constant ShaderCommonUniform *uniform [[buffer(0)]])
{
  float screenWH = min(data.vsize.x, data.vsize.y);
  float2 pos = (data.position.xy * 2.0 - data.vsize) / screenWH;
  float tm = uniform->time;

  // Circle that gently drifts around the left side
  float2 circleCenter = float2(-0.45 + 0.15 * sin(tm * 0.6), 0.2 + 0.05 * cos(tm * 0.4));
  float circleRadius = 0.28;
  float dCircle = circle(pos - circleCenter, circleRadius);

  // Rectangle on the right, lightly waving up/down
  float2 rectCenter = float2(0.45, 0.05 + 0.1 * sin(tm * 0.7));
  float2 rectSize = float2(0.30, 0.20);
  float angle = 0.1 * sin(tm * 0.9);
  float2 rectPos = rotate2(pos - rectCenter, angle);
  float dRect = box(rectPos, rectSize);

  // Triangle near the bottom, slow rotation
  float2 triCenter = float2(0.0, -0.45);
  float triAngle = -0.15 + 0.25 * sin(tm * 0.5);
  float2 triPos = rotate2(pos - triCenter, triAngle);
  float dTri = sdEquilateralTriangle(triPos, 0.55);

  float smooth = 0.18;
  float d = smin(dCircle, dRect, smooth);
  d = smin(d, dTri, smooth);

  float edge = 0.007;
  float mask = smoothstep(0.0, edge, -d);
  float inner = smoothstep(-smooth, smooth, -d);

  // Simple grayscale palette with subtle lighting
  float background = 0.08 + 0.05 * pos.y;
  float highlight = 0.7 + 0.1 * inner - 0.1 * d;
  float rim = smoothstep(0.0, edge * 4.0, abs(d));
  float finalLuma = mix(background, clamp(highlight, 0.0, 1.0), mask) + (1.0 - rim) * 0.05 * mask;
  finalLuma = clamp(finalLuma, 0.0, 1.0);

  return float4(finalLuma, finalLuma, finalLuma, 1.0);
}

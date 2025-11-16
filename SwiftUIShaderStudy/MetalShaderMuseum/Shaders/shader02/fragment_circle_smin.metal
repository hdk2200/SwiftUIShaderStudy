#include <metal_stdlib>
using namespace metal;

#include "../../../MetalCommon/ShaderCommonUniform.h"
#include "../../../MetalCommon/shadersample_internal.h"
#include "../../../MetalCommon/SDFPrimitives.metal"

#define M_PI 3.14159265359

fragment float4 fragment_circle_smin(VertexOut data [[stage_in]],
                            float2 uv [[point_coord]],
                            constant ShaderCommonUniform *uniform [[buffer(0)]])
{
  // Normalize screen coordinates (-1..1)
  float screenWH = min(data.vsize.x, data.vsize.y);
  float2 pos = (data.position.xy * 2.0 - data.vsize) / screenWH;
  float tm = uniform->time;
  float2 tapPix = float2(uniform->userpt.x, uniform->userpt.y);
  float2 tap = (tapPix * 2.0 - data.vsize) / screenWH;
//  float2 tap = float2(0.25,-1.5);

if (length(pos - tap) < 0.01) {
    return float4(1.0, 0.0, 0.0, 1.0);
}

  // Circle parameters
  float baseScale = clamp(uniform->scale, 0.001, 2.0);
  float r = 0.28 * baseScale; // radius now grows with pinch scale
  float k = 0.18 + 0.06 * sin(tm * 0.9); // smoothing for smin

  // Number of circles (change this to adjust how many circles are used)
  const int circleCount = 50; // fixed for now; changeable in code
  const int MAX_CIRCLES = 100;
  int count = clamp(circleCount, 1, MAX_CIRCLES);

  // Accumulate signed distance for multiple animated circles using smin
  // We generalize the previous c0..c3 pattern into a parametric sequence
  float d = 1e9; // large initial distance
  for (int i = 0; i < count; ++i) {
      float fi = float(i);
      // Pseudo-random spread over a disk with gentle time drift
      // Hash helpers
      auto hash11 = [&](float n) -> float {
          return fract(sin(n) * 43758.5453123);
      };
      auto hash21 = [&](float2 p) -> float {
          return fract(sin(dot(p, float2(12.9898,78.233))) * 43758.5453);
      };

      float radiusMax = 0.85; // how far from center circles can spread (normalized)
      float angle = 2.0 * M_PI * hash11(fi * 13.37);
      float rr = sqrt(hash11(fi * 97.13)); // sqrt for uniform-in-disk distribution

      // Add a slow drift so points move smoothly over time
      float drift = 0.25 * sin(tm * 0.15 + fi * 0.7);
      float2 base = float2(cos(angle), sin(angle));
      float2 jitter = float2(
          cos(2.0 * angle + drift) * 0.1,
          sin(1.5 * angle - drift) * 0.1
      );

      float2 ci = (base * rr + jitter) * radiusMax;

      // Slightly vary radius for variety (first one like original, others similar)
      float ri = r * mix(0.75, 1.0, (i % 3 == 0) ? 1.0 : 0.85);
      float di = length(pos - ci) - ri;
      d = (i == 0) ? di : smin(d, di, k);
  }

  // Soft edge mask
  float edge = 0.008; // controls antialias width
  float mask = 1.0 - smoothstep(0.0, edge, d);

  // Tap-driven ripple (distance from tap controls wave phase)
  float dist = length(pos - tap);
  float rippleWave = sin(dist * 1.0 - tm * 1.0);
  float ripple = smoothstep(0.0, 1.0, rippleWave * 0.5 + 0.5);
  float rippleFalloff = exp(-dist * 1.5); // fade wave as it spreads outward
  float rippleMask = ripple * rippleFalloff; // affect entire scene, not just edges

  // Color inside vs outside
  float3 bg = float3(0.06, 0.07, 0.10);
  float3 inColor = 0.5 + 0.5 * float3(
      sin(tm + pos.x * 3.2),
      sin(tm * 1.31 + pos.y * 2.4),
      cos(tm * 0.73 + (pos.x + pos.y) * 1.2)
  );

  // Add a subtle rim lighting based on gradient of distance
  float rim = smoothstep(0.0, edge * 3.0, abs(d));
  float3 rimColor = float3(1.0, 0.95, 0.9) * (1.0 - rim) * 0.25;

  float3 rippleColor = float3(0.9, 0.6, 1.0) * rippleMask;

  float3 finalColor = mix(bg, inColor, mask) + rimColor * mask + rippleColor;

  return float4(finalColor, 1.0);
}


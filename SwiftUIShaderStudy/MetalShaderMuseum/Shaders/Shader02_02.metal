#include <metal_stdlib>
using namespace metal;

#include "../../MetalCommon/ShaderCommonUniform.h"
#include "../../MetalCommon/shadersample_internal.h"
#include "../../MetalCommon/SDFPrimitives.metal"

#define M_PI 3.14159265359

fragment float4 shader02_02(VertexOut data [[stage_in]],
                            float2 uv [[point_coord]],
                            constant ShaderCommonUniform *uniform [[buffer(0)]])
{
  // Normalize screen coordinates (-1..1)
  float screenWH = min(data.vsize.x, data.vsize.y);
  float2 pos = (data.position.xy * 2.0 - data.vsize) / screenWH;
  float tm = uniform->time;
//  float2 tapf2 = float2(uniform->userpt.x, uniform->userpt.y);
//  float2 tap = (tapf2 * 2.0 - data.vsize) / screenWH;
//  pos += tap;

  // Circle parameters
  float baseScale = max(0.2, uniform->scale);
  float r = 0.28 / baseScale; // radius scales with uniform->scale
  float k = 0.18 + 0.06 * sin(tm * 0.9); // smoothing for smin

  // Define animated circle centers in normalized space
  float2 c0 = float2(0.35 * sin(tm * 0.8),  0.35 * cos(tm * 0.6));
  float2 c1 = float2(0.35 * sin(tm * 0.8 + 2.094), 0.35 * cos(tm * 0.6 + 1.618));
  float2 c2 = float2(0.35 * sin(tm * 0.8 + 4.188), 0.35 * cos(tm * 0.6 + 3.236));
  float2 c3 = float2(0.15 * cos(tm * 1.7), 0.15 * sin(tm * 1.3));

  // Signed distance to circles (distance - radius)
  float d0 = length(pos - c0) - r;
  float d1 = length(pos - c1) - r;
  float d2 = length(pos - c2) - r;
  float d3 = length(pos - c3) - (r * 0.75);

  // Smooth union via smin
  float d = smin(d0, d1, k);
  d = smin(d, d2, k);
  d = smin(d, d3, k);

  // Soft edge mask
  float edge = 0.008; // controls antialias width
  float mask = 1.0 - smoothstep(0.0, edge, d);

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

  float3 finalColor = mix(bg, inColor, mask) + rimColor * mask;

  return float4(finalColor, 1.0);
}

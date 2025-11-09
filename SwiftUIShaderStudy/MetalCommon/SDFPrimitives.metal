//
//  SDFPrimitives.metal
//  Shared signed distance helpers for basic shapes.
//

#include <metal_stdlib>
using namespace metal;

inline float circle(float2 p, float r) {
  return length(p) - r;
}

inline float box(float2 p, float2 b) {
  float2 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

inline float cross(float2 p, float w) {
  return min(abs(p.x), abs(p.y)) - w;
}

//
//  SDFPrimitives.metal
//  Shared signed distance helpers for basic shapes.
//

#include <metal_stdlib>
using namespace metal;


static inline float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}
static inline half sminhalf(half a, half b, half k) {
  half h = clamp(0.5H + 0.5H * (b - a) / k, 0.0H, 1.0H);
  return mix(b, a, h) - k * h * (1.0H - h);
}


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

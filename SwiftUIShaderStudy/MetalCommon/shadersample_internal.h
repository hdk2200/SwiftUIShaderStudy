//
// Copyright (c) 2024, - All rights reserved. 
// 
//

#ifndef shadersample_internal_h
#define shadersample_internal_h

#include <metal_stdlib>



/* types */
typedef struct VertexOut
{
  float4 position [[position]];
  float time [[flat]];
  vector_float2 vsize [[flat]];
  float aspect [[flat]];
  uint  seed [[flat]];
  float3 userpt [[flat]];
} VertexOut;

/* function prototype */

uint xorshift32(thread uint* state);
float randXORShift(thread uint* state);
float smin(float a, float b, float k);


//template <typename T> T smin(T a, T b, T k);


/* macro */
#define linearstep(edge0, edge1, x) min(max(((x) - (edge0)) / ((edge1) - (edge0)), 0.0), 1.0)


#endif /* shadersample_internal_h */

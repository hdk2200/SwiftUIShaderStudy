

#ifndef SHADERCOMMON_H
#define SHADERCOMMON_H

#include <simd/simd.h>

typedef struct ShaderCommonUniform {
  uint32_t seed;
  float time;
  vector_float2 vsize;
  float aspect;
  vector_float2 tsize;  // TextureSize
  vector_float3 userpt; // pointed by user 

} ShaderCommonUniform;


#endif /* SHADERCOMMON_H */
 

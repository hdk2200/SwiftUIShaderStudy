

#ifndef SHADERCOMMON_H
#define SHADERCOMMON_H

#include <simd/simd.h>

typedef struct ShaderCommonUniform {
  uint32_t seed;
  float time;
  vector_float2 vsize;
  float aspect;
  vector_float2 tsize;   // TextureSize
  vector_float3 userpt;  // pointed by user
  vector_float2 drag;    // ドラッグ位置（0..vsize）
  vector_float2 delta;   // 前フレームからの移動量
  float  scale;           // ピンチスケール
  float  rotation;       // 回転（ラジアン）



} ShaderCommonUniform;


#endif /* SHADERCOMMON_H */
 

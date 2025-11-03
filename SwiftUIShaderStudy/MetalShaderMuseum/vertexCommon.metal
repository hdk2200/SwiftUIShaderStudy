#include <metal_stdlib>

#include "../MetalCommon/shaderSample.h"
#include "../MetalCommon/shadersample_internal.h"
using namespace metal;



vertex VertexOut
vertexCommon(unsigned int vertexId [[vertex_id]],
                   const device float4 *vertexs [[buffer(0)]],
                   constant ShaderCommonUniform *uniform [[buffer(1)]])
{
  VertexOut out;
  float4 point = vertexs[vertexId];
  out.position = point;
  //  if( uniform->aspect < 1){ // portrait
  //    out.position = float4( point.x, point.y * uniform->aspect, point.z, point.w) ;
  //  }
  //  else{ // landscape
  //    out.position = float4( point.x * uniform->aspect, point.y , point.z, point.w) ;
  //  }

  out.seed = uniform->seed;
  out.time = uniform->time;
  out.vsize = uniform->vsize;
  out.aspect = uniform->aspect;
  out.userpt = uniform->userpt;
  return out;
}

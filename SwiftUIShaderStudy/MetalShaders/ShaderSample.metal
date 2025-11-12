//

#include <metal_stdlib>

#include "../MetalCommon/ShaderCommonUniform.h"
#include "../MetalCommon/shadersample_internal.h"
#include "../MetalCommon/SDFPrimitives.metal"
using namespace metal;


//
//uint xorshift32(thread uint* state) {
//    *state ^= (*state << 13);
//    *state ^= (*state >> 17);
//    *state ^= (*state << 5);
//    return *state;
//}
//
//float randXORShift(thread uint* state) {
//    return float(xorshift32(state)) / 4294967295.0;
//}

//template <typename T>
//T smin(T a, T b, T k)
//{
//  T h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
//  return mix(b, a, h) - k * h * (1.0 - h);
//}



vertex VertexOut
shaderSampleVertex(unsigned int vertexId [[vertex_id]],
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

fragment float4 shaderSampleFragment_sample(VertexOut data [[stage_in]],
                                            float2 uv [[point_coord]],
                                            unsigned int sampleId [[sample_id]])
{
  float shorterSide = min(data.vsize.x, data.vsize.y);

  //  float2 c = float2((data.vsize.x - wh) / (data.vsize.x * 1.0),
  //                    (data.vsize.y - wh) / (data.vsize.y * 1.0));
  //  float2 pos = data.position.xy / data.vsize * 2.0 - 1.0 ;
  //    float2 pos = data.position.xy / data.vsize ;
  //  float2 pos = data.position.xy;
  // 画面中央を原点(0､0)として、幅・高さ短い方が-1.0～1.0の範囲になるように正規化する
  // (長い軸は1を超える )

  float2 pos = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);

  float lineWidth = 1.0 / shorterSide * 2;
  if (-lineWidth < pos.y && pos.y < lineWidth)
  {
    return float4(1, 0, 0, 1);
  }

  if (-lineWidth < pos.x && pos.x < lineWidth)
  {
    return float4(0, 1, 0, 1);
  }
  //    else{
  //
  //    }
  //  }
  //  else{
  //    if (-lineWidth <  pos.x && pos.x  < lineWidth ){
  //      return float4(0,1,1,1);
  //    }
  //    else{
  //      return float4(0,0,1,1);
  //    }
  //  }

  //  return float4(1.0 * pos.x * (0.5 + 0.5 * sin(data.time)) , 1.0 * pos.x ,1.0 * pos.x, 1.0);

  //  return float4(0, 0.1 , 0, 1);
  // 2D円形のSDFを計算する
  float2 center = float2(0.0, 0.0);  // 円の中心座標
                                     //  float2 center = data.vsize.xy / 2.0;
                                     //  float radius = 50.0; // 円の半径
  float radius = 0.5;
  //  float sdf = length(fragCoord - center) - radius; // SDFの計算
  float sdf = length(pos - center) - radius;  // SDFの計算

  if (sdf < 0.0)
  {
    //    return float4(1,1,1,1);
  }
  else
  {
    //    return float4(0,0,0,1);
  }

  // 時間に基づいて色を変化させる
  float l = 0.5 + 0.5 * sin(data.time);
//  float r = 0.5 + 0.5 * sin(data.time);
//  float g = 0.5 + 0.5 * cos(data.time + 0.1);
//  float b = 0.5 + 0.5 * cos(data.time);

  // SDFに基づいて色をブレンドする
  //  float alpha = clamp(0.5 - sdf * 0.5, 0.0, 1.0);
//  float alpha = step(0, sdf);
  //  float la = smoothstep(0,0.1,abs(sdf)) * l;
  float la = linearstep(0, 0.1, abs(sdf)) * l;

  return float4(float3(la), 1.0);
  //  return float4(float3(l * alpha),1.0);
  //  return float4(r * alpha, g * alpha, b * alpha, 1.0);
  //  return float4(1,1,1,1);

  //
  //  // 色と透明度を返す
  //  if(sdf > 0){
  //    return float4(r, 0, 0, alpha);
  //  }
  //  else if(sdf > 0.0001){
  //    return float4(0, g, 0, alpha);
  //  }
  //  else if(sdf > 1.0){
  //    return float4(0, 0,b, alpha);
  //  }
  //
  //  else{
  ////    discard_fragment();
  //    return float4(0, 1, 0, alpha);
  //  }
}


// 水滴のような表現
fragment float4 shaderSampleFragment_2(VertexOut data [[stage_in]],
                                       float2 uv [[point_coord]],
                                       unsigned int sampleId [[sample_id]])
{
  // 画面中央を原点(0､0)として、幅・高さ短い方が-1.0～1.0の範囲になるように正規化する
  // (長い軸は1を超える )
  float shorterSide = min(data.vsize.x, data.vsize.y);
  float ymax = data.vsize.y / shorterSide;

  float4 color = float4(0, 0, 0, 1);
  float2 pos = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);

  float lineWidth = 1.0 / shorterSide * 2;
  if (-lineWidth < pos.y && pos.y < lineWidth)
  {
    color += float4(float3(0.9), 1);
  }

  if (-lineWidth < pos.x && pos.x < lineWidth)
  {
    color += float4(float3(0.9), 1);
  }

  float minSDF = 100.0;
  float sumSDF = 0.0;
//  float maxSDF = 0.0;
  float sminSDF = 100.0;

  float radius = 0.35;

  for (int i = 0; i < 10; i++)
  {
    float2 center = float2(0.0,
                           ymax - radius - abs(sin(data.time / 2)) * (i) * 1.0);
    radius = clamp(0.35 - 0.05 * i, 0.05, 0.5);

    float sdf = length(pos - center) - radius;
    float sdfc = length(pos - center);
    minSDF = min(minSDF, sdf);
    sminSDF = smin(sminSDF, sdf, 0.2F);

    //    if (sdf>0.0){
    sumSDF += abs(sdfc);
    //    }

    if (-lineWidth <= sdf && sdf <= lineWidth)
    {
      //      color += float4(float3(0.5),1);
    }
    //
    if (sdf < 0.0)
    {
      //      color += float4(float3(0.6),1);
//      float3 c = clamp(float3((1.0 - (-sdf / radius))), 0.5, 0.8);

      //        color += float4(c,1);
      //      color += float4(0.9);
      //      color += float4(1.0);
    }
    //    else{
    //      float ratio = (1.0 - (sdf - radius)) * 0.3;
    //      color += float4(float3(ratio),1);
    //    }
  }

//  float3 cmin = smoothstep(0.1, 1.0, 1.0 - minSDF);
  //  color += float4(cmin,1);

  if (-lineWidth <= minSDF && minSDF <= lineWidth)
  {
    //    color += float4(1,0,0,1);
  }
//  float3 c = clamp(float3((1.0 - (minSDF))), 0.1, 1.0);
  //    color += float4(c,1);

  if (-lineWidth * 8 <= sminSDF && sminSDF <= lineWidth * 8)
  {
    color += float4(0, 0, 1, 1);
  }
  if (sminSDF <= 0)
  {
    color += float4(0, 0, 0.9, 1);
  }

  if (-lineWidth <= sumSDF && sumSDF <= lineWidth)
  {
    color += float4(1, 0, 0, 1);
  }
  //  float3 csum = clamp(float3(( 1.0 - (sumSDF))),0.1,1.0);
  ////  color += float4(csum,1);

  float3 csum = smoothstep(0.0, 1.0, sumSDF / 100);
  color += float4(csum, 1);

  return clamp(color, 0.0, 1.0);
}


fragment float4 shaderSampleFragment(VertexOut data [[stage_in]],
                                       float2 uv [[point_coord]],
                                       unsigned int sampleId [[sample_id]])
{
  // 画面中央を原点(0､0)として、幅・高さ短い方が-1.0～1.0の範囲になるように正規化する
  // (長い軸は1を超える )
  float shorterSide = min(data.vsize.x, data.vsize.y);
//  float ymax = data.vsize.y / shorterSide;
  float count = 3;

  float4 color = float4(0, 0, 0, 1);
  float2 pos = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);

  float lineWidth = 1.0 / shorterSide * 2;
  if (-lineWidth < pos.y && pos.y < lineWidth)
  {
    color += float4(float3(0.9), 1);
  }

  if (-lineWidth < pos.x && pos.x < lineWidth)
  {
    color += float4(float3(0.9), 1);
  }

  float minSDF = 100.0;
  float sumSDF = 0.0;
  float maxSDF = 0.0;
  float sminSDF = 200.0;

  float rcount = 5;
  float posR = 0.1;

  float radius = 0.05;

//  thread uint32_t state =  data.seed;
//  thread uint32_t state2 =  data.time;
  
  
  for(int j=0;j<rcount;j++){
    
//    posR = smoothstep(0.0,0.5,(j) / rcount);
//    posR = clamp( j * 0.5 + 0.1, 0.0, 1.5);
    posR = mix(0.2, 0.9, float(j) / rcount);

    
    posR = posR  * abs(cos(data.time)) * (j %2)
    + posR * abs(sin(data.time)) * (j % 2 + 1);
//    radius = smoothstep(0.0,0.3,j / rcount);
    radius = 0.1 * j + 0.05;
    
    
    for (int i = 0; i < count; i++)
    {
      // count分のradianをつくる
      float rad = i * 3.14159265359 * 2 / count + data.time * (j % 2 == 0 ? 1.0 : -1.0 ) ;
      // 0.5の半径の円周上の点を求める
      float2 center = float2(cos(rad) * posR,
                             sin(rad) * posR);
      
      //    float2 center = float2(0.0,
      //                           ymax - radius - abs(sin(data.time / 2)) * (i) * 1.0);
      //    float2 center = float2(xorshift32(&state) * 2 - 1.0,
      //                           xorshift32(&state) * 2 - 1.0 + sin(data.time));
      //    float2 center = float2(randXORShift(&state) * 2 - 1.0,
      //                           randXORShift(&state) * 2 - 1.0 );
      
      
      
      
//      radius = 0.1;
      
      //    float sdf = length( pos - float2(0.1 * data.time  * i *  sin(data.time),
      //                                     0.1 * i)) - 0.02 + sin(data.time) * 0.01;
      float sdf = length(pos - center) - radius;
      float sdfc = length(pos - center);
      minSDF = min(minSDF, sdf);
      maxSDF = max(maxSDF, sdf);
      sminSDF = smin(sminSDF, sdf,  0.3);
      
      
      
      //    if (sdf>0.0){
      sumSDF += abs(sdfc);
      //    }
      
      //    if (-lineWidth <= sdf && sdf <= lineWidth){
      //            color += float4(float3(0.5),1);
      //    }
      //
      if (sdf < 0.0)
      {
        
//        float3 c = clamp(float3((1.0 - (-sdf / radius))), 0.5, 0.8);
        
      }
      
    }
  }
//  float3 cmin = smoothstep(0.1, 1.0, 1.0 - minSDF);
  //  color += float4(cmin,1);

  if (-lineWidth <= minSDF && minSDF <= lineWidth)
  {
    //    color += float4(1,0,0,1);
  }
//  float3 c = clamp(float3((1.0 - (minSDF))), 0.1, 1.0);
  //    color += float4(c,1);

  if (-lineWidth * 8 <= sminSDF && sminSDF <= lineWidth * 8)
  {
//    color += float4(0, 0, 1, 1);
  }
  if (sminSDF <= 0)
  {
//    color += float4(0, 0, 0.9, 1);
//    color += float4(float3(clamp(1.0 - sin(sminSDF/1.0),0.0,0.9)), 1);
    color += float4(clamp(1.0 - abs(sminSDF * sin(data.time)) ,0.0,1.0),
                    clamp(1.0 - abs(sminSDF * sin(data.time)) ,0.0,1.0),
                    clamp(1.0 - abs(sminSDF * sin(data.time)) ,0.0,1.0),
                    1);
//    color += float4(clamp(1.0 - abs(sminSDF * sin(data.time)) ,0.0,1.0),

//    color += float4(float3( abs(sin(sminSDF * 100.0 * sin(data.time))) ), 1);
//    color += float4(float3( abs(sin(sminSDF * 100.0 )) ), 1);

  }
  else{
//    color += float4(float3(clamp(1.0 - sin(sminSDF),0.0,0.9)), 1);
//    color += float4(float3( abs(sin(sminSDF * 60.0 * sin(data.time))) >0.5 ? 0.0:1.0), 1);
    color += float4(float3( abs(sin(sminSDF * 60.0)) ), 1);
  }

//  if (-lineWidth <= sumSDF && sumSDF <= lineWidth)
//  {
//    color += float4(1, 0, 0, 1);d
//  }
  //  float3 csum = clamp(float3(( 1.0 - (sumSDF))),0.1,1.0);
  ////  color += float4(csum,1);

//  float3 csum = smoothstep(0.0, 1.0, sumSDF / 100);
//  color += float4(csum, 1);

  return clamp(color, 0.0, 1.0);
}


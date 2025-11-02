//
// Copyright (c) 2025,  All rights reserved. 
// 
//
#include <metal_stdlib>
using namespace metal;

#include "../MetalCommon/shaderSample.h"
#include "../MetalCommon/shadersample_internal.h"

#define M_PI 3.14159265359

fragment float4 shader02_01(VertexOut data [[stage_in]],
                                           float2 uv [[point_coord]],
                                           constant ShaderCommonUniform *uniform [[buffer(0)]])
{
  // -1.0 ~ 1.0 に正規化されたスクリーン座標を計算
  float2 pos = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);


  // 上位から渡された時間
  float tm = uniform->time;


  // スクリーン上のZ位置（基本的に0）
  float zPos = 0.0;

  // カメラの初期位置（Z方向に奥に配置）
  float3 cameraPos = float3(0, (sin(tm) + 1.0) * 1.0, 5.0);

  // レイの方向ベクトルを正規化して生成
  float3 ray = normalize(float3(pos, zPos) - cameraPos);

  // 光の方向ベクトル（Z方向から）
//  float3 lightDir = normalize(float3( sin(tm),  sin(tm), 1.0));
  float3 lightDir = normalize(float3( sin(tm), 0.0 ,  1.0 ));
//  float3 lightDir =  normalize(float3( 1.0, 1.0 ,1.0 ));
//  float3 cameraPos = float3(0.0, 1.5, 5.0);        // 少し上から
//  float3 ray = normalize(float3(pos, 0.0) - cameraPos);
//  float3 lightDir = normalize(float3(0.5, 0.5, 1.0));   斜めから光

  // レイの進行距離初期化
  float depth = 0.05;

  // ベースカラーと初期カラー設定
  float3 baseColor = float3(0.8, 0.8, 0.9);
  float3 color = float3(0.8 * sin(tm) , 0.8 * sin(tm), 0.9 * sin(tm * 0.1)  );


  return float4(color, 1.0);
}

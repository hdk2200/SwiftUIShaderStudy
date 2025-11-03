//
// Copyright (c) 2025,  All rights reserved. 
// 
//
#include <metal_stdlib>
using namespace metal;

#include "../../MetalCommon/shaderSample.h"
#include "../../MetalCommon/shadersample_internal.h"

#define M_PI 3.14159265359
//
//fragment float4 shader02_01(VertexOut data [[stage_in]],
//                                           float2 uv [[point_coord]],
//                                           constant ShaderCommonUniform *uniform [[buffer(0)]])
//{
//  // -1.0 ~ 1.0 に正規化されたスクリーン座標を計算
//  float2 pos = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);
//
//
//  // 上位から渡された時間
//  float tm = uniform->time;
//
//
//  // スクリーン上のZ位置（基本的に0）
//  float zPos = 0.0;
//
//
//
////  float xy = fract(pos[0] * pos[1] );
////  float x = fract(pos[0] * 100) ;
////  float y = fract(pos[1] * 100);
////  float x = fmod(pos[0] * 10000,32) ;
////  float y = fmod(pos[1] * 10000,32) ;
//  float2 xy2 = pos / 0.01;
//
//  float xMod = fmod( pos.x, 3.0);
//  float yMod = fmod( pos.y , 3.0);
//
//
//  //  float k = sin(xMod  yMod);  // ベースカラーと初期カラー設定
//  float3 baseColor = float3(0.8, 0.8, 0.9);
//  float tm1 = sin(tm);
//  float r = sin(tm ) * xy2[0] ;
//  float g = cos(tm ) * xy2[1] ;
//  float b = cos(tm) ;
//  float3 color = float3(r,g,b);
//
////  return float4(baseColor, 1.0);
//  return float4(color, 1.0);
//}
//
////
//// Copyright (c) 2025, All rights reserved.
////
////
//#include <metal_stdlib>
//using namespace metal;
//
//#include "../MetalCommon/shaderSample.h"
//#include "../MetalCommon/shadersample_internal.h"
//
//#define M_PI 3.14159265359
//
//// ヘルパー関数: 距離計算で円を描く
//float circle(float2 p, float r) {
//    return length(p) - r;
//}
//
//// ヘルパー関数: ボックスを描く
//float box(float2 p, float2 b) {
//    float2 d = abs(p) - b;
//    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
//}

//// ヘルパー関数: 距離計算で円を描く
//float circle(float2 p, float r) {
//return length(p) - r;
//}
//// ヘルパー関数: ボックスを描く
//float box(float2 p, float2 b) {
//float2 d = abs(p) - b;
//return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
//}
//fragment float4 shader02_01_old(VertexOut data [[stage_in]],
//                            float2 uv [[point_coord]],
//                            constant ShaderCommonUniform *uniform [[buffer(0)]])
//{
//    // -1.0 ~ 1.0 に正規化されたスクリーン座標を計算
//    float2 pos = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);
//
//    // 上位から渡された時間
//    float tm = uniform->time;
//
//    // スクリーン上のZ位置（基本的に0）
//    float zPos = 0.0;
//
//    // メッシュ化: グリッドサイズを設定（時間で変動させる）
//    float gridSize = 0.2 + 0.1 * sin(tm * 2.0); // 時間でグリッドサイズをアニメーション
//    float2 gridPos = fract(pos / gridSize); // 各セル内の相対位置 (0.0 ~ 1.0)
//    float2 cellCenter = float2(0.5, 0.5); // セルの中心
//
//    // 各セルで幾何学的な表現: 時間によって形状を変える
//    float shape;
//    float tmMod = fmod(tm, 3.0); // 3秒周期で形状を切り替え
//    if (tmMod < 1.0) {
//        // 円
//        shape = circle(gridPos - cellCenter, 0.3 + 0.1 * sin(tm));
//    } else if (tmMod < 2.0) {
//        // 四角
//        shape = box(gridPos - cellCenter, float2(0.3, 0.3) * (0.8 + 0.2 * cos(tm)));
//    } else {
//        // 十字（ラインの組み合わせ）
//        float lineWidth = 0.1 + 0.05 * sin(tm);
//        shape = min(abs(gridPos.x - 0.5), abs(gridPos.y - 0.5)) - lineWidth / 2.0;
//    }
//
//    // 形状に基づいて色を決定
//    float3 color;
//    if (shape < 0.0) {
//        // 形状内: 時間で色を変える
//        color = float3(0.5 + 0.5 * sin(tm + pos.x), 0.5 + 0.5 * cos(tm + pos.y), 0.5 + 0.5 * sin(tm * 1.5));
//    } else {
//        // 形状外: 背景色
//        color = float3(0.1, 0.1, 0.2);
//    }
//
//    // グリッドラインを追加で描画（オプション）
//    float gridLine = smoothstep(0.01, 0.0, min(fract(pos.x / gridSize), fract(pos.y / gridSize)));
//    color = mix(color, float3(1.0, 1.0, 1.0), gridLine * 0.5);
//
//    return float4(color, 1.0);
//}

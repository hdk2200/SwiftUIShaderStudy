//
// Copyright (c) 2025, All rights reserved.
// 
//
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
  // 正規化スクリーン座標 (-1 ~ 1)
  float screenWH = min(data.vsize.x, data.vsize.y);
  float2 pos = (data.position.xy * 2.0 - data.vsize) / screenWH;
  float tm = uniform->time;
  float2 tapf2 = float2(uniform->userpt.x,uniform->userpt.y);
  float2 tap = ( tapf2 * 2.0 - data.vsize) / screenWH;
    pos += tap;
//  pos = pos * sin(tm) ;
    // === 1. グリッドサイズを滑らかにアニメーション ===
    float baseGrid = 1.0 * uniform->scale;
    float gridPulse = 0.01 * sin(tm * 1.8);           // ゆっくり脈動
    float gridSize = baseGrid + gridPulse;

    // グリッドの「位相」を時間でずらして流れるように
    float2 gridOffset = float2(sin(tm * 0.7), cos(tm * 0.5)) * 0.3;
    float2 gridPos = fract((pos + gridOffset) / gridSize);
    float2 cellCenter = float2(0.5, 0.5);

    // === 2. 形状を滑らかにブレンド（3種類を時間で補間）===
    float cycle = 1.0; // 1サイクル秒数
    float t = fract(tm / cycle); // 0~1 の正規化時間

  // 各形状のSDF
  float shapeCircle = circle(gridPos - cellCenter, 0.3 + 0.18 * sin(tm * 2.0));
  float shapeBox    = box(gridPos - cellCenter, float2(0.25 + 0.2 * cos(tm), 0.35));
  float shapeCross  = cross(gridPos - cellCenter, 0.08 + 0.05 * sin(tm * 3.0));

    // 3つのフェーズに分けて滑らかにブレンド
    float shape;
    if (t < 0.33) {
        // 円 → ボックス
        float localT = smoothstep(0.0, 0.33, t);
        shape = mix(shapeCircle, shapeBox, localT);
    } else if (t < 0.66) {
        // ボックス → 十字
        float localT = smoothstep(0.33, 0.66, t);
        shape = mix(shapeBox, shapeCross, localT);
    } else {
        // 十字 → 円
        float localT = smoothstep(0.66, 1.0, t);
        shape = mix(shapeCross, shapeCircle, localT);
    }

    // === 3. 色も滑らかに変化 ===
    float3 colorIn  = 0.5 + 0.5 * float3(
        sin(tm + pos.x * 3.0),
        sin(tm * 1.3 + pos.y * 2.0),
        cos(tm * 0)
    );

    float3 colorOut = float3(0.08, 0.1, 0.18); // 背景
    float3 finalColor = mix(colorOut, colorIn, step(shape, 0.0));

    // === 4. グリッド線を滑らかに（オプション）===
    float2 gridLine = abs(fract((pos + gridOffset) / gridSize) - 0.5);
    float lineMask = 1.0 - smoothstep(0.0, 0.03, min(gridLine.x, gridLine.y));
    finalColor = mix(finalColor, float3(1.0, 1.0, 1.0), lineMask * 0.25);

    // === 5. 全体に微かな波紋エフェクト（滑らかさを増す）===
    float ripple = sin(length(pos) * 8.0 - tm * 4.0) * 0.02;
    finalColor += ripple * (step(shape, 0.0) ? 1.0 : 0.3);

    return float4(finalColor, 1.0);
}

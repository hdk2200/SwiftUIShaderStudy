//
// Copyright (c) 2024, - All rights reserved.
//
//

#include <metal_stdlib>
using namespace metal;

#include "../MetalCommon/ShaderCommonUniform.h"
#include "../MetalCommon/shadersample_internal.h"
#include "../MetalCommon/SDFPrimitives.metal"
#define M_PI 3.14159265359
// -----------------------------------------------------

template <typename Tx, typename Ty>
// オブジェクトを繰り返す際に利用するmod関数
// MSLのfmodはglslのmodと差があるため作成する。
inline Tx mod(Tx x, Ty y)
{
  return x - y * floor(x / y);
}

// XYZ軸の合成回転行列を生成する
float3x3 rotationXYZ(float angleX, float angleY, float angleZ)
{
  float cx = cos(angleX);
  float sx = sin(angleX);
  float cy = cos(angleY);
  float sy = sin(angleY);
  float cz = cos(angleZ);
  float sz = sin(angleZ);

  float3x3 rotX = float3x3(
    float3(1, 0, 0),
    float3(0, cx, -sx),
    float3(0, sx, cx)
  );

  float3x3 rotY = float3x3(
    float3(cy, 0, sy),
    float3(0, 1, 0),
    float3(-sy, 0, cy)
  );

  float3x3 rotZ = float3x3(
    float3(cz, -sz, 0),
    float3(sz, cz, 0),
    float3(0, 0, 1)
  );

  // 合成回転: X → Y → Z の順に適用
  return rotZ * rotY * rotX;
}

// objectを繰り返す。長さmの範囲で繰り返し、m/2を移動する
/// オブジェクトの位置を `m` 間隔で繰り返す。`mod(p, m) - m / 2.0` により中心を原点に揃える。
template <typename Tx ,typename T>
inline Tx trans(Tx p, T m)
{
return mod(p, m) - m / 2.0;
//  return mod(p, m) ;
}

//
/// 繰り返し配置された球オブジェクトとの距離を計算する。
float sphareDistanceTrans(float3 p, float3 center, float radius, float m)
{
  return length(trans(p - center, m)) - radius;
}
/// 単一の球オブジェクトとの距離を計算する（繰り返しなし）。
float sphareDistance(float3 p, float3 center, float radius, float m)
{
  return length(p - center) - radius;
}

//float sdBox(float3 p, float3 b)
//{
//  //  float3 q = abs(p) - b;
//  //  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
//  float3 q = abs(p);
//  return length(max(q - b, 0.0));
//}

/// ボックスのSDF。中心を原点とし、サイズ `b` のボックスとの距離を返す。
float sdBox(float3 p, float3 b)
{
  //  float3 q = abs(p) - b;
  //  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
  float3 q = abs(p);
  return length(max(q - b, 0.0));
}


/// `p` 位置にあるオブジェクト（繰り返しボックス）の距離を返す。
float distance(float3 p)
{
  return sdBox(trans(p - float3(0), 1), float3(0.1, 0.1, 0.1));
}

// 法線を求める。
//■ 法線（Normal）とは？
//  •  表面に垂直なベクトル
//  •  光の反射や陰影計算（ライティング）に必須
//  •  法線を使って、光の当たり方や色を決めることができる
//
// 仕組み（数値微分による勾配の近似）
//  sphareDistance(p + Δx) - sphareDistance(p - Δx)
//  のように、左右で少しずつ距離を測り、その差分で勾配を求める手法です。
//  各軸に対して：
//  •  X方向の変化（近傍との差）で x成分
//  •  Y方向の変化で y成分
//  •  Z方向の変化で z成分
//
// 最後にそれらを組み合わせて正規化（normalize）すると、表面に垂直な単位ベクトル＝法線になります。
//
//■ 処理の流れ（まとめ）
//  •  d = 0.001：小さなオフセット
//  •  各軸方向で「距離関数の差分」を取る → 勾配ベクトル
//  •  normalize で長さを1にして、向きだけのベクトルにする → 法線完成
float3 sphareNormal(float3 p, float3 center, float radius, float m)
{
  float d = 0.001;

  return normalize(float3(
      sphareDistance(p + float3(d, 0.0, 0.0), center, radius, m) - sphareDistance(p + float3(-d, 0.0, 0.0), center, radius, m),
      sphareDistance(p + float3(0.0, d, 0.0), center, radius, m) - sphareDistance(p + float3(0.0, -d, 0.0), center, radius, m),
      sphareDistance(p + float3(0.0, 0.0, d), center, radius, m) - sphareDistance(p + float3(0.0, 0.0, -d), center, radius, m)));
}

// 法線を求める。
/// ボックス形状の法線をSDFの勾配を利用して求める。
float3 sdBoxNormal(float3 p)
{
  float d = 0.001;

  return normalize(float3(
      distance(p + float3(d, 0.0, 0.0)) - distance(p + float3(-d, 0.0, 0.0)),
      distance(p + float3(0.0, d, 0.0)) - distance(p + float3(0.0, -d, 0.0)),
      distance(p + float3(0.0, 0.0, d)) - distance(p + float3(0.0, 0.0, -d))));
}

// =============================
// RayMarchingの基本的な例
// -----------------------------
// - 単純なボックスオブジェクトにレイを飛ばし、衝突判定とシェーディングを行う
// - カメラ位置は固定（例: cameraPos = float3(0, 0, 20)）、ライト方向も固定
//
// ▼ RayMarching 概要
// RayMarchingは、カメラ（目）→投影面 → 対象物 の構造で、
// カメラから投影面上の各ピクセル方向へレイを飛ばし、
// オブジェクトとの距離情報をもとに色を算出する。
// フラグメントシェーダーは、投影面の各ピクセルについて実行され、
// 「カメラ → ピクセル位置」方向のレイを進めて対象物との衝突を調べ、
// 衝突した場合にライティングやシェーディングによって色を決定する。
//
// ▼ イメージ構図
// [対象物]                ← ワールド空間に配置されたオブジェクト（距離関数）
//    ▲
//    │
//    │
// [投影面（スクリーン）]    ← ピクセルごとにレイを飛ばす仮想平面（z = 0 付近）
//    ▲
//    │ 各ピクセルの位置（pos）をもとに
//    │ 「カメラ → ピクセル」の方向ベクトル（ray）を算出
//    │
// [カメラの位置]           ← cameraPos（例: z = +20.0）
//
// ▼ 補足
// - 時間によって繰り返し配置間隔 m が変化する：
//     float m = clamp(10.0 * cos(uniform->time), 0.5, 10.0);
// - 各ステップで距離 dist をもとにレイを進め、
//   衝突したら法線を求めてライティング
// - dot(normal, lightDir) により影・明るさを計算
// - palette(...) 関数を使えば色表現のバリエーションも可能
//
// 距離導出関数＝物体の配置になる。
//
// =============================
fragment float4 shaderSampleRayMarching01(VertexOut data [[stage_in]],
                                           float2 uv [[point_coord]],
                                           constant ShaderCommonUniform *uniform [[buffer(0)]])
{
  // 球の半径（ここでは固定値で使用）
  float radius = 0.3;

  // 球の中心位置（未使用だが残っている）
  float3 spharePos = float3(0.0);

  // -1.0 ~ 1.0 に正規化されたスクリーン座標を計算
  float2 pos = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);

  // カメラの初期位置（Z方向に奥に配置）
  float3 cameraPos = float3(0.0, .0, 20.0);

  // スクリーン上のZ位置（基本的に0）
  float zPos = 0.0;

  // レイの方向ベクトルを正規化して生成
  float3 ray = normalize(float3(pos, zPos) - cameraPos);

  // 光の方向ベクトル（Z方向から）
  float3 lightDir = normalize(float3(0.0, 0.0, 1.0));

  // レイの進行距離初期化
  float depth = 0.05;

  // ベースカラーと初期カラー設定
  float3 baseColor = float3(0.8, 0.8, 0.9);
  float3 color = float3(0.0);

  // 時間に応じて繰り返し配置の間隔を変化させる（最低0.5、最大10.0）
  float m = clamp(10.0 * cos(uniform->time), 0.5, 10.0);

  // 最大ステップ数でループ（Ray Marching）
  for (int i = 0; i < 128; i++) {
    // 現在のレイの位置を計算
    float3 rayPos = cameraPos + ray * depth;

    // その位置とオブジェクト（繰り返しボックス）との距離を取得
    float dist = distance(rayPos);

    // しきい値以下なら衝突とみなす
    if (dist < 0.001) {
      // 衝突面の法線を取得
      float3 normal = sdBoxNormal(cameraPos);

      // 法線と光の方向の内積からディフューズライティングを計算
      float differ = dot(normal, lightDir);

      // カラーを光とベースカラーで調整
      color = clamp(float3(differ) * baseColor, 0.01, 1.0);
      break;
    }

    // 衝突しなければ、レイをさらに進める
    cameraPos += ray * dist;
  }

  // フラグメントカラーとして返す（アルファは1.0）
  return float4(color, 1.0);
}
//-------------------------------------------------

// 回転行列を生成する関数
float3x3 rotationMatrix(float angle)
{
  float cosA = cos(angle);
  float sinA = sin(angle);

  return float3x3(float3(cosA, -sinA, 0),
                  float3(sinA, cosA, 0),
                  float3(0, 0, 1));
}

float3 rotationXZ(float3 p, float angle)
{
  float cosA = cos(angle);
  float sinA = sin(angle);
  return p * float3x3(float3(cosA, 0, -sinA),
                      float3(0, 1, 0),
                      float3(sinA, 0, cosA));
}

template <typename Tx,typename T>
inline T sdSphere(Tx p, T s)
{
  return length(p) - s;
}

template <typename T>
inline T sdRoundBox(vec<T,3> p, vec<T,3> b, float r)
{
  vec<T,3> q = abs(p) - b + r;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), T(0.0)) - r;

}
//
//inline float sdRoundBox(float3 p, float3 b, float r)
//{
//  float3 q = abs(p) - b + r;
//  return length(max(q, 0.0F)) + min(max(q.x, max(q.y, q.z)), 0.0F) - r;
//}
//
//inline half sdRoundBox(half3 p, half3 b, half r)
//{
//  half3 q = abs(p) - b + r;
//  return length(max(q, 0.0H)) + min(max(q.x, max(q.y, q.z)), 0.0H) - r;
//}


//float3 palette(float t, float3 offset, float3 amplitude, float3 frequency, float3 phase)
//{
//  return offset + amplitude * cos(6.28318530718 * (t * frequency + phase));
//}
template <typename Tx>
Tx palette(float t, Tx offset, Tx amplitude, Tx frequency, Tx phase)
{
  return offset + amplitude * cos(6.28318530718H * (t * frequency + phase));
}


template <typename T>
T map_template(vec<T,3> p, constant ShaderCommonUniform *uniform)
{
  T sphareRadius = 0.1;
  vec<T,3> p2 = p - vec<T,3>(0.0,
                         uniform->time,
                         0.0);
  T sphare = sdSphere(trans(p2, 2.0), sphareRadius);
  T sphareOrigin = sdSphere(p, 0.01);
  T boxSize = 0.18;
  vec<T,3> bpt2 = p - vec<T,3>(0.0, 0.0, 0.0);
  T rbox = sdRoundBox(trans(bpt2, 2.0),
                      vec<T,3>(boxSize, boxSize, boxSize), 0.01);

  return smin(min(sphare, sphareOrigin), rbox, 0.3);
}

//***********************************
// MAP
//  ground と球体
inline float mapWorld_sphare_ground(float3 p, float tm)
{
  half sphareRadius = 0.3h;
  float3 p2 = p - float3(0.0,
                         -tm,
                         0.0);
  float sphare = sdSphere(trans(p2,  3.0), sphareRadius);
//  float sphare = sdSphere(p2, sphareRadius);
  float sphareOrigin = sdSphere(p, 0.01);
//  float boxSize = 0.18;
//  float3 bpt2 = p - float3(0.0, 0.0, 0.0);
//  float rbox = sdRoundBox(trans(bpt2, 2.0),
//                          float3(boxSize, boxSize, boxSize), 0.01);
//  float rbox = sdBox(trans(bpt2, 2.0),
//                          float3(boxSize, boxSize, boxSize));
//  float rbox = sdBox(bpt2,
//                          float3(boxSize, boxSize, boxSize));
//  return smin(min(sphare, sphareOrigin), rbox, 0.3);

  float ground =  2.0 - p.y ;
//  float ground2 =  -1.75 - p.y ;
//  float gmin = min(ground,ground2);
//  float ground2 = p.y + 6;

//  return smin(min(sphare, sphareOrigin), ground, 0.5);
//  return smin(sphare, ground, 0.3);
  return smin(sphare, ground, 0.4);

}

//  ground と球体
inline float mapWorld(float3 p, float tm){
  float sphareRadius = 0.2;
  float3 p2 = p - float3(0.0,
                         tm,
                         0.0);
  float sphare = sdSphere(trans(p2, 3.0), sphareRadius);
  float sphareOrigin = sdSphere(p, 0.01);
  float boxSize = 0.18;
  float3 bpt2 = p - float3(0.0, 0.0, 0.0);
  float rbox = sdRoundBox(trans(bpt2, 3.0),
                          float3(boxSize, boxSize, boxSize), 0.01);

  return smin(min(sphare, sphareOrigin), rbox, 0.3);
}


float map(float3 p, constant ShaderCommonUniform *uniform)
{
  float sphareRadius = 0.1;
  float3 p2 = p - float3(0.0,
                         uniform->time,
                         0.0);
  float sphare = sdSphere(trans(p2, 2.0), sphareRadius);
  float sphareOrigin = sdSphere(p, 0.01);
  float boxSize = 0.18;
  float3 bpt2 = p - float3(0.0, 0.0, 0.0);
  float rbox = sdRoundBox(trans(bpt2, 2.0),
                          float3(boxSize, boxSize, boxSize), 0.01);

  return smin(min(sphare, sphareOrigin), rbox, 0.3);
}

half map(half3 p, constant ShaderCommonUniform *uniform)
{
  half sphareRadius = 0.1;
  half3 p2 = p - half3(0.0,
                         uniform->time,
                         0.0);
  half sphare = sdSphere(trans(p2, 2.0), sphareRadius);
  half sphareOrigin = sdSphere(p, 0.01);
  half boxSize = 0.18;
  half3 bpt2 = p - half3(0.0, 0.0, 0.0);
  half rbox = sdRoundBox(trans(bpt2, 2.0),
                         half3(boxSize, boxSize, boxSize), 0.01);

  return sminhalf(min(sphare, sphareOrigin), rbox, 0.3);
}


float map3(float3 p, constant ShaderCommonUniform *uniform)
{
  //  float3 q = trans(p , 3);
  //  float3 q = p;
  float sphareRadius = 0.10;

  //  float3 spahrePt = p - float3(1 *( sin(uniform->time) - cos(uniform->time)) - 0.5,
  //                               1 *( cos(uniform->time) + sin(uniform->time)) - 0.5,
  //                               0.0);

  //  float sphare = sdSphere( trans(spahrePt ,2),    sphareRadius);
  //  float3 p2 = p - float3(0.0,sin(uniform->time ),0.0);
  float3 p2 = p - float3(0.0,
                         sin(uniform->time) * 1.1,
                         0.0);
  float sphare = sdSphere(trans(p2, 2), sphareRadius);

  //  float sphare = sdSphere( trans(p - float3(0.0,sin(uniform->time ),0.0),
  //                                 sin(uniform->time) * 10 ),
  //
  //                          sphareRadius);
  //  float sphare = sdSphere(float3(q), sphareRadius);
  float sphareOrigin = sdSphere(p, 0.01);
  //  return sphare;

  //  float3 boxPt = p - float3( .9 *( sin(uniform->time) - cos(uniform->time)),
  //                               0.9 *( cos(uniform->time) + sin(uniform->time)),
  //                              3 * sin(uniform->time));
  //  float3 boxPt = p - float3( 0.2,0.3,-0.1);
  //  float3 boxPt = spahrePt - cos(uniform->time * 0.1) * 1;
  //  float3 boxPt = p - float3(  1.0 * sin(uniform->time) ,
  //                            1.0 *  cos(uniform->time / 2) ,
  //                              0.0);
  float boxSize = 0.2;
  //  float box = sdBox(trans(p  ,10)  ,float3(boxSize));
  //  float rbox = sdRoundBox(trans(p,3) ,float3(boxSize),0.05);
  //
  float3 bpt2 = p - float3(0.0, 0.0, 0.0);
  float rbox = sdRoundBox(trans(bpt2, 2),
                          float3(boxSize), 0.01);

  return smin(min(sphare, sphareOrigin), rbox, 0.5);

  //  return smin(sphare,smin(min(rbox,box),sphareOrigin,1.0),1);
}
//
// float map2(float3 p,constant ShaderCommonUniform *uniform ){
////  return length(p - float3(sin(uniform->time) - cos(uniform->time),
////                           cos(uniform->time) + sin(uniform->time),
////                           smoothstep(0.0,1.0,trunc(uniform->time))  - 3.0));
////  float sphare = length(p - float3(0.0,0.0,0.0)) - 0.3;
////  float sphare = length(p - float3(0.0,0.0,0.0)) - 0.3;
//  float3 q = trans(p, 2);
//  float3 sphareCenter = float3(-0.5,-0.8,2.0);
////  float3 sphareCenter = float3( sin(uniform->time) * 5.0,
////                               sin(uniform->time * 2 ) * 2.0 + 1.0,
////                               0.0);
//
//  float sphareRadius = 0.2;
////  float sphare = sdSphere(p - sphareCenter, sphareRadius);
//  float sphare = sdSphere(trans(p  , 3) - sin(uniform->time) * 2, sphareRadius);
//  return sphare;
//  float box = sdBox(p,float3(0.4,0.3,0.1)) - 0.1;
////  float ground = abs(1.0 * p.y * sin(uniform->time))  ;
////  return box;
//
//  float ground =  (-p.y + 5.8 );
////  return ground;
//  return smin(ground,min(sphare,box),2.0);
////  return min(ground,box);
////  return smin(sphare,box ,+1.0);
////  return smin(smin(sphare,box ,+5.0),ground,+5.0);
//
////  return sphare;
//}

/**
 * RayMarchingのサンプル
 * フラグメントシェーダーで処理する各ピクセル（uv)からレイを照射し、
 * オブジェクトとの衝突を判定する。
 *
 * この例では、球と箱のオブジェクトを作成する。
 *
 */
fragment float4 shaderSampleRayMarching02(VertexOut data [[stage_in]],
                                           float2 uv [[point_coord]],
                                           constant ShaderCommonUniform *uniform [[buffer(0)]])
{
  // -1.0 ~ 1.0に 正規化された座標
  float2 pos = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);
  float tm = uniform->time;

  //  float3 lightDir = normalize(float3(sin(uniform->time),-0.5,-0.5));
  //  float3 cameraPos = float3( -1.0 ,
  //                             2.0  ,
  //                            -3.0   ); // カメラの位置
  //  float3 cameraPos = float3( 3.0 * (sin(uniform->time) - cos(uniform->time) ),
  //                             3.0  * (cos(uniform->time)  + sin(uniform->time)),
  //                            -2.0   ); // カメラの位置
  //  float3 cameraPos = float3( 0.0,
  //                             0.5 ,
  //                            -3.0   ); // カメラの位置

  //    float3 cameraPos = float3(1.0 * (sin(uniform->time) - cos(uniform->time) ) + 1.0,
  //                              5.0 * (sin(uniform->time) - cos(uniform->time) ) + 1.0,
  //                               10.0  * (cos(uniform->time * 0.5)  + sin(uniform->time * 0.5))  + -5.0     ); // カメラの位置
  //  float3 cameraPos = float3(sin(uniform->time * 0.5) ,
  //                            3.0 * (sin(uniform->time) - cos(uniform->time) ) ,
  //                            3.0 * (sin(uniform->time) + cos(uniform->time))  ); // カメラの位置
  //  float3 cameraPos = float3(0.0, 0.0 , -3.0); // カメラの位置
  // カメラの位置を算出する（UIのタッチポイントからずらす。）
  float3 cameraPos = float3(-1.0 * uniform->userpt.x,
                            uniform->userpt.y,
                            uniform->userpt.z);

  if (uniform->time > 20.0) {  // 20秒以降は時間で移動させる

    // ｘ軸方向に移動
    cameraPos = float3(cameraPos.x + sin(tm - 20.0) * 0.9,
                       cameraPos.y,
                       cameraPos.z
                       //                     cameraPos.z+ sin(tm)
    );
    if (tm > 30.0) {  // 30秒以降はz方向も同時移動させる

      cameraPos = float3(cameraPos.x,
                         cameraPos.y,
                         cameraPos.z + sin(tm / 2.0) * 0.3
                         //                     cameraPos.z+ sin(tm)
      );
    }
  }

  //  光の方向を決める。（cameraの方向）
  float3 lightDir = normalize(float3(cameraPos));
  //  float3 lightDir = normalize(float3(-cameraPos));
  //  float3 lightDir = normalize(float3(uniform->point.x,-2.0,-2.0));
  //
  //  float3 cameraPos = float3(0.0, -0.0,-3.0); // カメラの位置
  //  float3 ray = normalize(float3(pos,1.0));   // レイの方向
  //  float3 ray = normalize(float3(pos,1.0));   // レイの方向
  //  float3 ray = normalize(float3(pos,1.0 ) - cameraPos);   // レイの方向

  // レイの方向（単位ベクトル）
  // この方向にレイを伸ばし、オブジェクトに衝突するまでずらす。
  // 中心からカメラ方向に向かうベクトルを、fragmentの座標だけずらして正規化する。
  //  float3 ray = normalize(float3(0.0) - cameraPos + float3(pos, 0.0));  // レイの方向
  float3 ray = normalize(float3(float3(0.0) - cameraPos) + float3(pos, 0.0));  // レイの方向
  // 視野角90度 画面サイズ1.0としてｚ位置を計算する
  //  ray =  normalize(float3(pos, - 1.0 / tan(3.14159265359 / 4)));
  //  float3 ray = normalize( float3(pos   , 1.0));  // レイの方向

  float3 color = float3(0.0);  // 最終の色

  float traveledDistance = 0.0;  // RaymarhchingでレイをTotal distance travelled

  float dist = 0.0;  // レイの先端（衝突点）とオブジェクトの距離

  float3 normal = float3(0.0);  // 衝突点の法線ベクトル

  // レイマーチング
  // ・ループ中はレイ先端からオブジェクトとの距離をもとめ、レイを進める。
  // ・レイ先端とオブジェクトの距離が小さい場合、表面に到達したと判断する。
  //   その場合、法線を求め、ループ終了。
  // ・レイ先端が遠くに到達した場合、オブジェクトが無かったと判断し、ループ終了。
  for (int i = 0; i < 48; i++) {
    // レイの先端位置を算出する
    float3 rayPos = cameraPos + ray * traveledDistance;
    // オブジェクトとの距離を求める
    dist = mapWorld(rayPos, tm);

    // レイを伸ばした距離を加算する
    traveledDistance += dist;
    //    color = float3( traveledDistance * 0.1);
    //    color = float3( i / 64.0);

    if (traveledDistance > 20.0) {
      // 距離が遠すぎる場合は終了
      break;
    }
    if (dist < .001) {
      // 距離が小さいので衝突と判断。
      // 正規化した法線（normal）を求める。（ｘ、ｙ、ｚ位置を少しずらした点とオブジェクトとの距離から求める）
      // shading - How to compute normal of surface from implicit equation for ray-marching? - Computer Graphics Stack Exchange
      // https://computergraphics.stackexchange.com/questions/8093/how-to-compute-normal-of-surface-from-implicit-equation-for-ray-marching

      //      Finite difference - Wikipedia
      //    https://en.wikipedia.org/wiki/Finite_difference#Relation_with_derivatives
      float epsilon = 0.001;  // arbitrary — should be smaller than any surface detail in your distance function, but not so small as to get lost in float precision
      float xDistance = mapWorld(rayPos + float3(epsilon, 0, 0), tm);
      float yDistance = mapWorld(rayPos + float3(0, epsilon, 0), tm);
      float zDistance = mapWorld(rayPos + float3(0, 0, epsilon), tm);
      //      float xDistance2 = map(rayPos + float3(-epsilon, 0, 0),uniform);
      //      float yDistance2 = map(rayPos + float3(0, -epsilon, 0),uniform);
      //      float zDistance2 = map(rayPos + float3(0, 0, -epsilon),uniform);

      normal = normalize(float3(xDistance, yDistance, zDistance) - dist);
      //      normal = normalize(float3(xDistance-xDistance2, yDistance-yDistance2, zDistance-zDistance2)) ;

      break;
    }
  }

  //  float t = (sin(uniform->time * 0.1) + 1 ) /2;

  //  color = float3( traveledDistance * 0.1 * t );           // color based on distance
  //  float brightness = 1.0 - min(traveledDistance / 100.0, 1.0); // 距離に応じた明るさ
  //  float brightness = 1.0 / pow(traveledDistance,1.2);
  //  float brightness = -0.9 * smoothstep(0,1.0,traveledDistance / 5.0) + 1;

  //  color = float3(brightness);

  if (dist < .001) {
    // 衝突した場合は、色を設定する。
    float light = clamp(dot(lightDir, normal), 0.2, 1.0);
    float3 palcolor = palette(traveledDistance / 10,     // t
                              float3(0.0, 1.0, 1.0),     // offset
                              float3(0.0, 0.5, 0.8),     // amplitude
                              float3(0.0, 0.8, 0.0),     // frequency
                              float3(0.5, 0.20, 0.25));  // phase

    // color = float3(light * color);
    //    color = float3(clamp(smoothstep(1,0,(traveledDistance/10.0)) , 0.01,1.0)) * light * color ;
    // 近くのものが明るく、遠くのものが暗くなるようにする。
    color = float3(smoothstep(1, 0.001, (traveledDistance / 30.0)));
    if (tm > 3.0) {
      color *= light;  // 光を追加
    }

    if (tm > 6.0) {
      color *= palcolor;  // 色を追加
    }
  }
  else {
    // 遠い場合は背景色を黒にする。
    color = float3(0.0);
  }

  //  color = float3(abs(normal.x),abs(normal.y),abs(normal.z));

  //  color = float3( traveledDistance * 0.1 * t );           // color based on distance
  //  color = float3(clamp( 3.0 - traveledDistance,0.0,1.0));

  return float4(color, 1.0);  // フラグメントの色を返す
  //  return float4(ray.xy,-1.0 * ray.z,1.0);
}

// ===================================================================================
/**
  half version
*/

//
//half sdSphere(half3 p, float s)
//{
//  return length(p) - s;
//}
//
//float sdRoundBox(float3 p, float3 b, float r)
//{
//  float3 q = abs(p) - b + r;
//  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
//}
//
//float3 palette(float t, float3 offset, float3 amplitude, float3 frequency, float3 phase)
//{
//  return offset + amplitude * cos(6.28318530718 * (t * frequency + phase));
//}




fragment half4 shaderSampleRayMarching03(VertexOut data [[stage_in]],
                                          float2 uv [[point_coord]],
                                          constant ShaderCommonUniform *uniform [[buffer(0)]])
{
  half2 pos = half2((data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y));
  half3 cameraPos = half3(-1.0 * uniform->userpt.x,
                          uniform->userpt.y,
                          uniform->userpt.z);

  if (uniform->time > 20.0) {  // 20秒以降は時間で移動させる
    // ｘ軸方向に移動
    cameraPos = half3(cameraPos.x + sin(uniform->time - 20.0) * 0.9,
                      cameraPos.y,
                      cameraPos.z
                      //                     cameraPos.z+ sin(uniform->time)
    );
    if (uniform->time > 30.0) {  // 30秒以降はz方向も同時移動させる
      cameraPos = half3(cameraPos.x,
                        cameraPos.y,
                        cameraPos.z + sin(uniform->time - 30.0) * 1.0
                        //                     cameraPos.z+ sin(uniform->time)
      );
    }
  }

  //  光の方向を決める。（cameraの方向）
  half3 lightDir = normalize(half3(cameraPos));

  // レイの方向（単位ベクトル）
  // この方向にレイを伸ばし、オブジェクトに衝突するまでずらす。
  // 中心からカメラ方向に向かうベクトルを、fragmentの座標だけずらして正規化する。
  //  half3 ray = normalize(half3(0.0) - cameraPos + half3(pos, 0.0));  // レイの方向
  half3 ray = normalize(half3(half3(0.0) - cameraPos) + half3(pos, 0.0));  // レイの方向
  // 視野角90度 画面サイズ1.0としてｚ位置を計算する
  //  ray =  normalize(half3(pos, - 1.0 / tan(3.14159265359 / 4)));
  //  half3 ray = normalize( half3(pos   , 1.0));  // レイの方向

  half3 color = half3(0.0);  // 最終の色

  half traveledDistance = 0.0;  // RaymarhchingでレイをTotal distance travelled

  half dist = 0.0;  // レイの先端（衝突点）とオブジェクトの距離

  half3 normal = half3(0.0);  // 衝突点の法線ベクトル

  // レイマーチング
  // ・ループ中はレイ先端からオブジェクトとの距離をもとめ、レイを進める。
  // ・レイ先端とオブジェクトの距離が小さい場合、表面に到達したと判断する。
  //   その場合、法線を求め、ループ終了。
  // ・レイ先端が遠くに到達した場合、オブジェクトが無かったと判断し、ループ終了。
  for (int i = 0; i < 512; i++) {
    // レイの先端位置を算出する
    half3 rayPos = cameraPos + ray * traveledDistance;
    // オブジェクトとの距離を求める
    dist = map(rayPos, uniform);

    // レイを伸ばした距離を加算する
    traveledDistance += dist;
    //    color = half3( traveledDistance * 0.1);
    //    color = half3( i / 64.0);

    if (traveledDistance > 100.0) {
      // 距離が遠すぎる場合は終了
      break;
    }
    if (dist < .0001) {
      // 距離が小さいので衝突と判断。
      // 正規化した法線（normal）を求める。（ｘ、ｙ、ｚ位置を少しずらした点とオブジェクトとの距離から求める）
      // shading - How to compute normal of surface from implicit equation for ray-marching? - Computer Graphics Stack Exchange
      // https://computergraphics.stackexchange.com/questions/8093/how-to-compute-normal-of-surface-from-implicit-equation-for-ray-marching

      //      Finite difference - Wikipedia
      //    https://en.wikipedia.org/wiki/Finite_difference#Relation_with_derivatives
      half epsilon = 0.001;  // arbitrary — should be smaller than any surface detail in your distance function, but not so small as to get lost in half precision
      half xDistance = map(rayPos + half3(epsilon, 0, 0), uniform);
      half yDistance = map(rayPos + half3(0, epsilon, 0), uniform);
      half zDistance = map(rayPos + half3(0, 0, epsilon), uniform);
      normal = normalize(half3(xDistance, yDistance, zDistance) - dist);
      //      normal = normalize(half3(xDistance-xDistance2, yDistance-yDistance2, zDistance-zDistance2)) ;

      break;
    }
  }
  if (dist < .0001) {
    // 衝突した場合は、色を設定する。
    half light = clamp(dot(lightDir, normal), 0.2H, 1.0H);
    half3 palcolor = palette(traveledDistance / 10,    // t
                             half3(0.0, 1.0, 1.0),     // offset
                             half3(0.0, 0.5, 0.8),     // amplitude
                             half3(0.0, 0.8, 0.0),     // frequency
                             half3(0.5, 0.20, 0.25));  // phase

    // 近くのものが明るく、遠くのものが暗くなるようにする。
    color = half3(smoothstep(1, 0.001, (traveledDistance / 30.0)));
    if (uniform->time > 3.0) {
      color *= light;  // 光を追加
    }

    if (uniform->time > 6.0) {
      color *= palcolor;  // 色を追加
    }
  }
  else {
    // 遠い場合は背景色を黒にする。
    color = half3(0.0);
  }

  return half4(color, 1.0);  // フラグメントの色を返す
}

// ===================================================================================
// vertexからparamを取る。
fragment float4 shaderSampleRayMarching04(VertexOut data [[stage_in]],
                                           float2 uv [[point_coord]])

{
  // -1.0 ~ 1.0に 正規化された座標
  float2 pos = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);

  //  float3 lightDir = normalize(float3(sin(uniform->time),-0.5,-0.5));
  //  float3 cameraPos = float3( -1.0 ,
  //                             2.0  ,
  //                            -3.0   ); // カメラの位置
  //  float3 cameraPos = float3( 3.0 * (sin(uniform->time) - cos(uniform->time) ),
  //                             3.0  * (cos(uniform->time)  + sin(uniform->time)),
  //                            -2.0   ); // カメラの位置
  //  float3 cameraPos = float3( 0.0,
  //                             0.5 ,
  //                            -3.0   ); // カメラの位置

  //    float3 cameraPos = float3(1.0 * (sin(uniform->time) - cos(uniform->time) ) + 1.0,
  //                              5.0 * (sin(uniform->time) - cos(uniform->time) ) + 1.0,
  //                               10.0  * (cos(uniform->time * 0.5)  + sin(uniform->time * 0.5))  + -5.0     ); // カメラの位置
  //  float3 cameraPos = float3(sin(uniform->time * 0.5) ,
  //                            3.0 * (sin(uniform->time) - cos(uniform->time) ) ,
  //                            3.0 * (sin(uniform->time) + cos(uniform->time))  ); // カメラの位置
  //  float3 cameraPos = float3(0.0, 0.0 , -3.0); // カメラの位置
  // カメラの位置を算出する（UIのタッチポイントからずらす。）
  float3 cameraPos = float3(-1.0 * data.userpt.x,
                            data.userpt.y,
                            data.userpt.z);

  if (data.time > 20.0) {  // 20秒以降は時間で移動させる

    // ｘ軸方向に移動
    cameraPos = float3(cameraPos.x + sin(data.time - 20.0) * 0.9,
                       cameraPos.y,
                       cameraPos.z
                       //                     cameraPos.z+ sin(uniform->time)
    );
    if (data.time > 30.0) {  // 30秒以降はz方向も同時移動させる

      cameraPos = float3(cameraPos.x,
                         cameraPos.y,
                         cameraPos.z + sin(data.time - 30.0) * 1.0
                         //                     cameraPos.z+ sin(uniform->time)
      );
    }
  }

  //  光の方向を決める。（cameraの方向）
  float3 lightDir = normalize(float3(cameraPos));
  //  float3 lightDir = normalize(float3(-cameraPos));
  //  float3 lightDir = normalize(float3(uniform->point.x,-2.0,-2.0));
  //
  //  float3 cameraPos = float3(0.0, -0.0,-3.0); // カメラの位置
  //  float3 ray = normalize(float3(pos,1.0));   // レイの方向
  //  float3 ray = normalize(float3(pos,1.0));   // レイの方向
  //  float3 ray = normalize(float3(pos,1.0 ) - cameraPos);   // レイの方向

  // レイの方向（単位ベクトル）
  // この方向にレイを伸ばし、オブジェクトに衝突するまでずらす。
  // 中心からカメラ方向に向かうベクトルを、fragmentの座標だけずらして正規化する。
  //  float3 ray = normalize(float3(0.0) - cameraPos + float3(pos, 0.0));  // レイの方向
  float3 ray = normalize(float3(float3(0.0) - cameraPos) + float3(pos, 0.0));  // レイの方向
  // 視野角90度 画面サイズ1.0としてｚ位置を計算する
  //  ray =  normalize(float3(pos, - 1.0 / tan(3.14159265359 / 4)));
  //  float3 ray = normalize( float3(pos   , 1.0));  // レイの方向

  float3 color = float3(0.0);  // 最終の色

  float traveledDistance = 0.0;  // RaymarhchingでレイをTotal distance travelled

  float dist = 0.0;  // レイの先端（衝突点）とオブジェクトの距離

  float3 normal = float3(0.0);  // 衝突点の法線ベクトル

  // レイマーチング
  // ・ループ中はレイ先端からオブジェクトとの距離をもとめ、レイを進める。
  // ・レイ先端とオブジェクトの距離が小さい場合、表面に到達したと判断する。
  //   その場合、法線を求め、ループ終了。
  // ・レイ先端が遠くに到達した場合、オブジェクトが無かったと判断し、ループ終了。
  for (int i = 0; i < 64; i++) {
    // レイの先端位置を算出する
    float3 rayPos = cameraPos + ray * traveledDistance;
    // オブジェクトとの距離を求める
    dist = mapWorld(rayPos, data.time);

    // レイを伸ばした距離を加算する
    traveledDistance += dist;
    //    color = float3( traveledDistance * 0.1);
    //    color = float3( i / 64.0);

    if (traveledDistance > 100.0) {
      // 距離が遠すぎる場合は終了
      break;
    }
    if (dist < .001) {
      // 距離が小さいので衝突と判断。
      // 正規化した法線（normal）を求める。（ｘ、ｙ、ｚ位置を少しずらした点とオブジェクトとの距離から求める）
      // shading - How to compute normal of surface from implicit equation for ray-marching? - Computer Graphics Stack Exchange
      // https://computergraphics.stackexchange.com/questions/8093/how-to-compute-normal-of-surface-from-implicit-equation-for-ray-marching

      //      Finite difference - Wikipedia
      //    https://en.wikipedia.org/wiki/Finite_difference#Relation_with_derivatives
      float epsilon = 0.001;  // arbitrary — should be smaller than any surface detail in your distance function, but not so small as to get lost in float precision
      float xDistance = mapWorld(rayPos + float3(epsilon, 0, 0), data.time);
      float yDistance = mapWorld(rayPos + float3(0, epsilon, 0), data.time);
      float zDistance = mapWorld(rayPos + float3(0, 0, epsilon), data.time);
      //      float xDistance2 = map(rayPos + float3(-epsilon, 0, 0),uniform);
      //      float yDistance2 = map(rayPos + float3(0, -epsilon, 0),uniform);
      //      float zDistance2 = map(rayPos + float3(0, 0, -epsilon),uniform);

      normal = normalize(float3(xDistance, yDistance, zDistance) - dist);
      //      normal = normalize(float3(xDistance-xDistance2, yDistance-yDistance2, zDistance-zDistance2)) ;

      break;
    }
  }

  //  float t = (sin(uniform->time * 0.1) + 1 ) /2;

  //  color = float3( traveledDistance * 0.1 * t );           // color based on distance
  //  float brightness = 1.0 - min(traveledDistance / 100.0, 1.0); // 距離に応じた明るさ
  //  float brightness = 1.0 / pow(traveledDistance,1.2);
  //  float brightness = -0.9 * smoothstep(0,1.0,traveledDistance / 5.0) + 1;

  //  color = float3(brightness);

  if (dist < .001) {
    // 衝突した場合は、色を設定する。
    float light = clamp(dot(lightDir, normal), 0.2, 1.0);
    float3 palcolor = palette(traveledDistance / 10,     // t
                              float3(0.0, 1.0, 1.0),     // offset
                              float3(0.0, 0.5, 0.8),     // amplitude
                              float3(0.0, 0.8, 0.0),     // frequency
                              float3(0.5, 0.20, 0.25));  // phase

    // color = float3(light * color);
    //    color = float3(clamp(smoothstep(1,0,(traveledDistance/10.0)) , 0.01,1.0)) * light * color ;
    // 近くのものが明るく、遠くのものが暗くなるようにする。
    color = float3(smoothstep(1, 0.001, (traveledDistance / 30.0)));
    if (data.time > 3.0) {
      color *= light;  // 光を追加
    }

    if (data.time > 6.0) {
      color *= palcolor;  // 色を追加
    }
  }
  else {
    // 遠い場合は背景色を黒にする。
    color = float3(0.0);
  }

  //  color = float3(abs(normal.x),abs(normal.y),abs(normal.z));

  //  color = float3( traveledDistance * 0.1 * t );           // color based on distance
  //  color = float3(clamp( 3.0 - traveledDistance,0.0,1.0));

  return float4(color, 1.0);  // フラグメントの色を返す
  //  return float4(ray.xy,-1.0 * ray.z,1.0);
}


// 矩形波
float squareWave(float time, float period) {
    float halfPeriod = period / 2.0;
    float phase = mod(time, period);
    return phase < halfPeriod ? 1.0 : -1.0;
}

// ノコギリ派

float sawtoothWave(float time, float period) {
    float phase = mod(time, period);
    return (phase / period) * 2.0 - 1.0;
}

// 三角派
float tri(float time, float period) {
    float phase = mod(time, period);
    return abs(1.0 - (2.0 * phase / period)) * 2.0 - 1.0;
}

/**
 * RayMarchingのサンプル
 * フラグメントシェーダーで処理する各ピクセル（uv)からレイを照射し、
 * オブジェクトとの衝突を判定する。
 *
 * この例では、球と箱のオブジェクトを作成する。
 *
 */
fragment float4 shaderSampleRayMarching05(VertexOut data [[stage_in]],
                                           float2 uv [[point_coord]],
                                           constant ShaderCommonUniform *uniform [[buffer(0)]])
{
  // -1.0 ~ 1.0に 正規化された座標
  float2 pos = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);
  float tm = uniform->time;

  // カメラの位置を算出する（UIのタッチポイントからずらす。）
  float3 cameraPos = float3(-1.0 * uniform->userpt.x,
                            uniform->userpt.y,
                            uniform->userpt.z);
  // ｘ軸方向に移動

//  cameraPos = float3(cameraPos.x + sin(tm) * 0.5,
////                     cameraPos.y - tri(tm,10.0) * 3,
//                     cameraPos.y + tri(tm,20.0) * 0.3,
//                     cameraPos.z + tri(tm,10.0) * 0.3 );


  if (uniform->time > 20.0) {  // 20秒以降は時間で移動させる
//
//    // ｘ軸方向に移動
//    cameraPos = float3(cameraPos.x + triangleWave(tm,2.0) * 0.9,
//                       cameraPos.y,
//                       cameraPos.z
//                       //                     cameraPos.z+ sin(tm)
//    );
    if (tm > 30.0) {  // 30秒以降はz方向も同時移動させる

//      cameraPos = float3(cameraPos.x,
//                         cameraPos.y,
//                         cameraPos.z + sin(tm / 2.0) * 0.1
//                         //                     cameraPos.z+ sin(tm)
//      );
    }
  }

  //  光の方向を決める。（cameraの方向）
  float3 lightDir = normalize(float3(-cameraPos));
//  float3 lightDir = normalize(float3(0.5 ,-1, 3.0 ));
//  float3 lightDir = normalize(float3(0.5 ,-1, 3.0 ));

  //  float3 lightDir = normalize(float3(-cameraPos));
  //  float3 lightDir = normalize(float3(uniform->point.x,-2.0,-2.0));
  //
  //  float3 cameraPos = float3(0.0, -0.0,-3.0); // カメラの位置
  //  float3 ray = normalize(float3(pos,1.0));   // レイの方向
  //  float3 ray = normalize(float3(pos,1.0));   // レイの方向
  //  float3 ray = normalize(float3(pos,1.0 ) - cameraPos);   // レイの方向

  // レイの方向（単位ベクトル）
  // この方向にレイを伸ばし、オブジェクトに衝突するまでずらす。
  // 中心からカメラ方向に向かうベクトルを、fragmentの座標だけずらして正規化する。
  //  float3 ray = normalize(float3(0.0) - cameraPos + float3(pos, 0.0));  // レイの方向

  // カメラから中心へ向かうレイ
  //  float3 ray = normalize(float3(float3(0.0) - cameraPos) + float3(pos, 0.0));  // レイの方向

  float3 ray = normalize(float3(cameraPos) + float3(pos, 0.0));  // レイの方向

  // カメラ方向のレイ
//  float3 ray = normalize(float3(cameraPos) + float3(pos, 0.0));  // レイの方向

  //
//  float3 ray = normalize(float3(0.0,0.1,0.0) + float3(pos, 0.0));  // レイの方向

//  float3 ray = normalize(float3(sin(tm) * 3 * pos.x,sin(tm) * 3 * pos.y , 0));  // レイの方向

  // 視野角90度 画面サイズ1.0としてｚ位置を計算する
  //  ray =  normalize(float3(pos, - 1.0 / tan(3.14159265359 / 4)));
  //  float3 ray = normalize( float3(pos   , 1.0));  // レイの方向

  float3 color = float3(0.0);  // 最終の色

  float traveledDistance = 0.0;  // RaymarhchingでレイをTotal distance travelled

  float dist = 0.0;  // レイの先端（衝突点）とオブジェクトの距離

  float3 normal = float3(0.0);  // 衝突点の法線ベクトル

  // レイマーチング
  // ・ループ中はレイ先端からオブジェクトとの距離をもとめ、レイを進める。
  // ・レイ先端とオブジェクトの距離が小さい場合、表面に到達したと判断する。
  //   その場合、法線を求め、ループ終了。
  // ・レイ先端が遠くに到達した場合、オブジェクトが無かったと判断し、ループ終了。
  for (int i = 0; i < 64; i++) {
    // レイの先端位置を算出する
    float3 rayPos = cameraPos + ray * traveledDistance;
    // オブジェクトとの距離を求める
    dist = mapWorld(rayPos, tm);

    // レイを伸ばした距離を加算する
    traveledDistance += dist;
    //    color = float3( traveledDistance * 0.1);
    //    color = float3( i / 64.0);

    if (traveledDistance > 30.0) {
      // 距離が遠すぎる場合は終了
      break;
    }
    if (dist < .001) {
      // 距離が小さいので衝突と判断。
      // 正規化した法線（normal）を求める。（ｘ、ｙ、ｚ位置を少しずらした点とオブジェクトとの距離から求める）
      // shading - How to compute normal of surface from implicit equation for ray-marching? - Computer Graphics Stack Exchange
      // https://computergraphics.stackexchange.com/questions/8093/how-to-compute-normal-of-surface-from-implicit-equation-for-ray-marching

      //      Finite difference - Wikipedia
      //    https://en.wikipedia.org/wiki/Finite_difference#Relation_with_derivatives
      float epsilon = 0.001;  // arbitrary — should be smaller than any surface detail in your distance function, but not so small as to get lost in float precision
      float xDistance = mapWorld(rayPos + float3(epsilon, 0, 0), tm);
      float yDistance = mapWorld(rayPos + float3(0, epsilon, 0), tm);
      float zDistance = mapWorld(rayPos + float3(0, 0, epsilon), tm);
      //      float xDistance2 = map(rayPos + float3(-epsilon, 0, 0),uniform);
      //      float yDistance2 = map(rayPos + float3(0, -epsilon, 0),uniform);
      //      float zDistance2 = map(rayPos + float3(0, 0, -epsilon),uniform);

      normal = normalize(float3(xDistance, yDistance, zDistance) - dist);
      //      normal = normalize(float3(xDistance-xDistance2, yDistance-yDistance2, zDistance-zDistance2)) ;

      break;
    }
  }

  //  float t = (sin(uniform->time * 0.1) + 1 ) /2;

  //  color = float3( traveledDistance * 0.1 * t );           // color based on distance
  //  float brightness = 1.0 - min(traveledDistance / 100.0, 1.0); // 距離に応じた明るさ
  //  float brightness = 1.0 / pow(traveledDistance,1.2);
  //  float brightness = -0.9 * smoothstep(0,1.0,traveledDistance / 5.0) + 1;

  //  color = float3(brightness);

  if (dist < .001) {
    // 衝突した場合は、色を設定する。
    float light = clamp(dot(lightDir, normal), 0.2, 1.0);
    float3 palcolor = palette(traveledDistance / 10,     // t
                              float3(0.01, 0.7, 0.7),     // offset
                              float3(1.0, 1.0, 1.0),     // amplitude
                              float3(0.8, 0.3, 0.1),     // frequency
                              float3(0.0, 0.0, 0.0));  // phase

    // color = float3(light * color);
    //    color = float3(clamp(smoothstep(1,0,(traveledDistance/10.0)) , 0.01,1.0)) * light * color ;
    // 近くのものが明るく、遠くのものが暗くなるようにする。
    color = float3(smoothstep(1, 0.001, (traveledDistance / 30.0)));


    if ( tm < 2.0  ||  tm > 4.0) {
      color *= light;  // 光を追加
    }

    if ( tm < 2.0  ||  tm > 6.0) {
      color *= palcolor;  // 色を追加
    }
  }
  else {
    // 遠い場合は背景色を黒にする。
    color = float3(0.0);
  }

  //  color = float3(abs(normal.x),abs(normal.y),abs(normal.z));

  //  color = float3( traveledDistance * 0.1 * t );           // color based on distance
  //  color = float3(clamp( 3.0 - traveledDistance,0.0,1.0));

  return float4(color, 1.0);  // フラグメントの色を返す
  //  return float4(ray.xy,-1.0 * ray.z,1.0);
}



// ========================================================
// # RayMarching06
//

float3x3 rotationY(float angle) {
  float c = cos(angle);
  float s = sin(angle);
  return float3x3(
    float3(c, 0, -s),
    float3(0, 1,  0),
    float3(s, 0,  c)
  );
}


// 球体とBOXの合成
inline float distanceRayMarching06(float3 p, float tm)
{
  float sphareRadius = 0.1;
    float3 p2 = p - float3(sin(tm) * 1 , 0.0, 0.0);
    float sphare = sdSphere(p2, sphareRadius);

    float boxSize = 0.35;
    float3 bpt2 = p - float3(0.0);  // boxの原点基準に移動
    float3x3 rotZ = rotationMatrix(tm);       // Z軸
    float3x3 rotY = rotationY(tm * 0.5);      // Y軸も少し回す
    bpt2 = rotY * rotZ * bpt2;  // ← 合成回転を適用

    float rbox = sdRoundBox(bpt2, float3(boxSize), 0.01);

    return smin(sphare, rbox, 0.4);
}

float3 calcNormalRayMarching06(float3 p, float time)
{
  float eps = 0.001;
  float dx = distanceRayMarching06(p + float3(eps, 0, 0), time) - distanceRayMarching06(p - float3(eps, 0, 0), time);
  float dy = distanceRayMarching06(p + float3(0, eps, 0), time) - distanceRayMarching06(p - float3(0, eps, 0), time);
  float dz = distanceRayMarching06(p + float3(0, 0, eps), time) - distanceRayMarching06(p - float3(0, 0, eps), time);
  return normalize(float3(dx, dy, dz));
}


inline float fastLength(float3 v) {
  return rsqrt(dot(v, v)) * dot(v, v); // Newton-Raphson近似（または別方式）
}

inline float sdSphere_fast(float3 p, float r) {
  return fastLength(p) - r;
}
//float sminExp(float a, float b, float k) {
//  float res = exp(-k * a) + exp(-k * b);
//  return -log(res) / k;
//}
float sminPoly(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float distanceBlobbySpheres(float3 p, float t)
{
  float3 centerOffset = float3(0.0, 0.0, -3.0);
  float spiralRadius = 0.6;
  float heightSpeed = 0.5;
  float k = 0.5;
  float angle = t * 1.0;
  float3x3 rot = rotationXYZ(angle, angle, angle);

  float d = 10000.0;

  const int sphereCount = 7;

  for (int i = 0; i < sphereCount; i++) {
    float phase = t * heightSpeed + float(i);

    float3 offset = float3(
      spiralRadius * sin(float(i) * 2.0 * M_PI / sphereCount),
      sin(phase),
      spiralRadius * cos(float(i) * 2.0 * M_PI / sphereCount)
    );

    float3 center = centerOffset + rot * offset;

    float r = 0.2 + 0.1 * sin(phase);

    float dist = sdSphere_fast(p - center, r);
    d = smin(d, dist, k);
  }

  return d;
}

float3 calcNormalDistanceBlobbySpheres(float3 p, float time)
{
  float eps = 0.001;
  float dx = distanceBlobbySpheres(p + float3(eps, 0, 0), time) - distanceBlobbySpheres(p - float3(eps, 0, 0), time);
  float dy = distanceBlobbySpheres(p + float3(0, eps, 0), time) - distanceBlobbySpheres(p - float3(0, eps, 0), time);
  float dz = distanceBlobbySpheres(p + float3(0, 0, eps), time) - distanceBlobbySpheres(p - float3(0, 0, eps), time);
  return normalize(float3(dx, dy, dz));
}

template <typename DistanceFunc>
float3 calcNormal(float3 p, float time, DistanceFunc distFunc)
{
    float eps = 0.001;
    float dx = distFunc(p + float3(eps, 0, 0), time) - distFunc(p - float3(eps, 0, 0), time);
    float dy = distFunc(p + float3(0, eps, 0), time) - distFunc(p - float3(0, eps, 0), time);
    float dz = distFunc(p + float3(0, 0, eps), time) - distFunc(p - float3(0, 0, eps), time);
    return normalize(float3(dx, dy, dz));
}

fragment float4 shaderSampleRayMarching06(VertexOut data [[stage_in]],
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
  float3 color = float3(0.0);


  // 最大ステップ数でループ（Ray Marching）
  for (int i = 0; i < 32; i++) {
    // 現在のレイの位置を計算
    float3 rayPos = cameraPos + ray * depth;

    // その位置とオブジェクト（繰り返しボックス）との距離を取得
    float dist = distanceBlobbySpheres(rayPos,tm);

    // しきい値以下なら衝突とみなす
    if (dist < 0.003) {
      // 衝突面の法線を取得
//      float3 normal = calcNormal(rayPos,tm,distanceBlobbySpheres);

      float3 normal = calcNormalDistanceBlobbySpheres(rayPos,tm);
      // 法線と光の方向の内積からディフューズライティングを計算
      float differ = dot(normal, lightDir);

      // カラーを光とベースカラーで調整
      color = clamp(float3(differ) * baseColor, 0.1, 1.0);
      break;
    }

    // 衝突しなければ、レイをさらに進める
    cameraPos += ray * dist;
  }

  // フラグメントカラーとして返す（アルファは1.0）
  return float4(color, 1.0);
}

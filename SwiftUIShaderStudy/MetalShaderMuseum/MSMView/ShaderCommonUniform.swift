import simd

#if canImport(UIKit)
  import UIKit
#endif


public struct ShaderCommonUniform {
  public var seed: UInt32  // uint32_t
  public var time: Float  // float
  public var vsize: SIMD2<Float>  // vector_float2
  public var aspect: Float  // float
  public var tsize: SIMD2<Float>  // vector_float2 (Texture size)
  public var userpt: SIMD3<Float>  // vector_float3 (user pointer)
  
  // Gesture-driven values (参考: ShaderSample.swift の一般的な構成)
  public var drag: SIMD2<Float>  // ドラッグ位置（0..vsize）
  public var delta: SIMD2<Float>  // 前フレームからの移動量
  public var scale: Float  // ピンチスケール
  public var rotation: Float  // 回転（ラジアン）

  public init(
    seed: UInt32 = 0,
    time: Float = 0,
    vsize: SIMD2<Float> = .zero,
    aspect: Float = 1.0,
    tsize: SIMD2<Float> = .zero,
    userpt: SIMD3<Float> = .zero,
    drag: SIMD2<Float> = .zero,
    delta: SIMD2<Float> = .zero,
    scale: Float = 1.0,
    rotation: Float = 0.0
  ) {
    self.seed = seed
    self.time = time
    self.vsize = vsize
    self.aspect = aspect
    self.tsize = tsize
    self.userpt = userpt
    self.drag = drag
    self.delta = delta
    self.scale = scale
    self.rotation = rotation
  }
}

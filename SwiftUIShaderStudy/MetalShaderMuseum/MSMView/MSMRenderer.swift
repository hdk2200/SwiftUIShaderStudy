import Combine
import MetalKit
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

protocol MSMRendererDelegate: AnyObject {
  func renderer(_ renderer: MTKViewDelegate, didUpdateFPS fps: Double)
}

public final class MSMRenderer: NSObject, ObservableObject, MTKViewDelegate {

  // delegate
  weak var delegate: (any MSMRendererDelegate)?

  // MARK: - Metal resources
  public let device: MTLDevice
  private let commandQueue: MTLCommandQueue

  // MARK: - SwiftUI bindings
  @Published public var currentShader: MSMDrawable
  @Published public var frameCount: Int = 0
  @Published public var fps: Double = 0
  

  // MARK: - Vertex + Uniform
  private var triangleVertices: [SIMD4<Float>] = [
    SIMD4<Float>(-1, -1, 0, 1),
    SIMD4<Float>(1.0, -1.0, 0, 1),
    SIMD4<Float>(-1.0, 1.0, 0, 1),
    SIMD4<Float>(1.0, 1.0, 0, 1),
  ]

  private var viewportSize: CGSize = .zero
  private var startTime: CFTimeInterval = CACurrentMediaTime()
  private var seed: UInt32 = UInt32.random(in: 0...UInt32.max)
  private var tapPoint: CGPoint = .zero
  private var zPoint: Float = 0.0

  // MARK: - Gesture state
  private var dragPoint: CGPoint = .zero
  private var lastDragPoint: CGPoint = .zero
  private var pinchScale: CGFloat = 1.0
  private var rotationRadians: CGFloat = 0.0

  // For FPS 
  private var fpsStartTime: CFTimeInterval?
  private var fpsFrameCount: Int = 0

  public init(device: MTLDevice, shader: MSMDrawable) {
    self.device = device
    self.commandQueue = device.makeCommandQueue()!
    self.currentShader = shader

    // Gesture recognizers are attached later via attachGestures(to:) because MTKView is not provided here.
  }

  public func changeShader(to newShader: MSMDrawable) {
    self.currentShader = newShader
  }

  // MARK: - Gesture Recognizers (UIKit)
  #if canImport(UIKit)
    /// MTKView にジェスチャーをアタッチします
    /// - Important: SwiftUI で使用する場合、UIViewRepresentable の makeUIView などから呼び出してください。
    public func attachGestures(to view: MTKView) {
      view.isUserInteractionEnabled = true

      // Tap
      let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
      tap.delegate = self
      view.addGestureRecognizer(tap)

      // Pan (drag)
      let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
      pan.delegate = self
      pan.maximumNumberOfTouches = 2
      view.addGestureRecognizer(pan)

      // Pinch
      let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
      pinch.delegate = self
      view.addGestureRecognizer(pinch)

      // Rotation
      let rotation = UIRotationGestureRecognizer(
        target: self,
        action: #selector(handleRotation(_:))
      )
      rotation.delegate = self
      view.addGestureRecognizer(rotation)
    }

    // MARK: - Gesture handlers
    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
      guard let view = recognizer.view else { return }
      let p = recognizer.location(in: view)
      // Metal の座標系と一致させるためにそのままピクセル座標で保持
      updateTap(point: p, z: 0.0)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
      guard let view = recognizer.view else { return }
      let p = recognizer.location(in: view)
      updateDrag(point: p)
      if recognizer.state == .ended || recognizer.state == .cancelled {
        // ドラッグ終了時、前回位置をリセットして delta の暴れを抑える
        lastDragPoint = p
      }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
      updatePinch(scale: recognizer.scale)
      if recognizer.state == .ended || recognizer.state == .cancelled {
        // 継続的な累積を避けたい場合は 1.0 に戻す
        recognizer.scale = 1.0
      }
    }

    @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
      updateRotation(radians: recognizer.rotation)
      if recognizer.state == .ended || recognizer.state == .cancelled {
        recognizer.rotation = 0.0
      }
    }
  #endif


  public func updateTap(point: CGPoint, z: Float = 0.0) {
    tapPoint = point
    zPoint = z
  }

  // MARK: - Gesture updates (SwiftUI から反映)
  public func updateDrag(point: CGPoint) {
    lastDragPoint = dragPoint
    dragPoint = point
  }

  public func updatePinch(scale: CGFloat) {
    pinchScale = scale
  }

  public func updateRotation(radians: CGFloat) {
    rotationRadians = radians
  }

  // MARK: - MTKViewDelegate

  public func mtkView(_ mtkView: MTKView, drawableSizeWillChange size: CGSize) {
    viewportSize = size
  }

  public func draw(in mtkView: MTKView) {
    guard let drawable = mtkView.currentDrawable,
      let renderPassDescriptor = mtkView.currentRenderPassDescriptor
    else { return }

    // FPS進行
    frameCount += 1
    let elapsed = Float(CACurrentMediaTime() - startTime)

    // Uniform構築
    let vSize = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
    let tSize = SIMD2<Float>(0.0, 0.0)
    let pt = SIMD3<Float>(Float(tapPoint.x), Float(tapPoint.y), zPoint)

    // Gesture 値の計算
    let drag = SIMD2<Float>(Float(dragPoint.x), Float(dragPoint.y))
    let last = SIMD2<Float>(Float(lastDragPoint.x), Float(lastDragPoint.y))
    let delta = drag - last
    let scaleValue = Float(pinchScale)
    let rotationValue = Float(rotationRadians)

    var uniforms = ShaderCommonUniform(
      seed: seed,
      time: Float(Float(frameCount) / Float(mtkView.preferredFramesPerSecond)),
      vsize: vSize,
      aspect: Float(viewportSize.width / max(1, viewportSize.height)),
      tsize: tSize,
      userpt: pt,
      drag: drag,
      delta: delta,
      scale: scaleValue,
      rotation: rotationValue
    )

    // コマンドバッファ作成
    guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else { return }

    // ビューポート設定
    encoder.setViewport(
      MTLViewport(
        originX: 0,
        originY: 0,
        width: Double(viewportSize.width),
        height: Double(viewportSize.height),
        znear: 0.0,
        zfar: 1.0
      )
    )

    // currentShader に独自の設定をさせる
    currentShader.draw(commandEncoder: encoder)

    // 頂点情報とUniformを設定（全Shader共通）
    encoder.setVertexBytes(
      triangleVertices,
      length: MemoryLayout<SIMD4<Float>>.stride * triangleVertices.count,
      index: 0
    )
    encoder.setVertexBytes(&uniforms, length: MemoryLayout<ShaderCommonUniform>.stride, index: 1)
    encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ShaderCommonUniform>.stride, index: 0)

    // 描画コマンド
    encoder.drawPrimitives(
      type: .triangleStrip,
      vertexStart: 0,
      vertexCount: triangleVertices.count
    )

    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
    
    calculateFPS(in:mtkView)
  }
  
  private func calculateFPS(in mtkView: MTKView) {
    guard let startTime = fpsStartTime else {
      fpsStartTime = CACurrentMediaTime()
      return
    }

    fpsFrameCount += 1
    let endTime = CACurrentMediaTime()
    let elapsedTime = endTime - startTime

    if elapsedTime >= 1.0 {
      self.fps = Double(fpsFrameCount) / elapsedTime
      print("FPS: \(String(format: "%.2f", fps)) , frame= \(fpsFrameCount) , preffered=\(mtkView.preferredFramesPerSecond)  ")
//      delegate?.renderer(self, didUpdateFPS: fps)
      fpsStartTime = endTime
      fpsFrameCount = 0
//      self.frameCount = 0
    }
  }

}

#if canImport(UIKit)
  extension MSMRenderer: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      true
    }
  }
#endif

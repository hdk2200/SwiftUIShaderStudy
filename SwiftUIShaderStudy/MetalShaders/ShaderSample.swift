//
// Copyright (c) 2024, - All rights reserved.
//
//

import Foundation
import MetalKit

// Metalの空間（-1.0 - 1.0）でParticleを配置するバージョン

class ShaderSampleRenderer: NSObject {
  weak var delegate: (any MTKViewRendererDelegate)?
  private weak var mtkView: MTKView!
  private var tapPoint: CGPoint = CGPoint(x: 0.9, y: -0.1)
  private var zPoint: CGFloat = -2.0

  private var currentPipeline: MTLRenderPipelineState?
  private var pipelineStates: [ShaderType: MTLRenderPipelineState] = [:]

  private var commandQueue: MTLCommandQueue!

  private var viewportSize: CGSize = .zero
  private var computeSemaphore: DispatchSemaphore!

  private var fpsStartTime: CFTimeInterval?
  private var frameCount: Int = 0
  private var seed: UInt32 = .random(in: 0 ..< UINT32_MAX)

  private var textureLoader: MTKTextureLoader!
  private var texture: MTLTexture!

  var shaderType: ShaderType = .sdf1 {
    didSet {
      currentPipeline = pipelineStates[shaderType]
    }
  }

  //  GPUが現在のフレームを描画している間に、CPUが次のフレームの描画データを準備できるようにする
  //
//  let kMaxInflightBuffers: Int = 3
  var frameBoundarySemaphore: DispatchSemaphore!
//  var currentFrameIndex: Int = 0
//  var dynamicDataBuffers: [MTLBuffer] = []
//  var debugBuffer: MTLBuffer!
  var drawCount: Int = 0

  /// Background color of MTKView
  private var viewClearColor: MTLClearColor = .init(red: 0.0, green: 0.0, blue: 0.1, alpha: 0.0)

  // triangle ２つで全面とする
  var triangleVertices: [SIMD4<Float>] = [
    SIMD4<Float>(-1, -1, 0, 1),
    SIMD4<Float>(1.0, -1.0, 0, 1),
    SIMD4<Float>(-1.0, 1.0, 0, 1),
    SIMD4<Float>(1.0, 1.0, 0, 1),
  ]

  required init(metalKitView: MTKView) {
    super.init()

    if metalKitView.device == nil {
      fatalError("Device not created. Run on a physical device")
    }

    self.mtkView = metalKitView

    // Gesture recognizerの作成
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    tapGesture.numberOfTapsRequired = 2
    metalKitView.addGestureRecognizer(tapGesture)
    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    panGesture.minimumNumberOfTouches = 1
    panGesture.maximumNumberOfTouches = 2
    metalKitView.addGestureRecognizer(panGesture)

    let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
    metalKitView.addGestureRecognizer(pinchGesture)

    frameBoundarySemaphore = DispatchSemaphore(value: 1)

    guard let device = mtkView.device else {
      fatalError("Device not created. Run on a physical device")
    }

//    guard let library = device.makeDefaultLibrary() else {
//      fatalError("Failed to create library")
//    }

    textureLoader = MTKTextureLoader(device: device)
    texture = try! textureLoader.newTexture(name: "bird", scaleFactor: 1.0, bundle: nil, options: nil)

//    guard let vertexFunction = library.makeFunction(name: "shaderSampleFragment_sample") else {
//      fatalError("Failed to create vertex function")
//    }
//    guard let fragmentFunction = library.makeFunction(name: "shaderSampleFragment_2") else {
//      fatalError("Failed to create fragment function")
//    }
//    guard let fragmentFunction = library.makeFunction(name: "shaderSampleFragment") else {
//      fatalError("Failed to create fragment function")
//    }

//    guard let fragmentFunction2 = library.makeFunction(name: "shaderSampleFragment2") else {
//      fatalError("Failed to create fragment function")
//    }

    for type in ShaderType.allCases {
      var pipelineState: MTLRenderPipelineState
      switch type {
      case .sdf1:
        pipelineState = createRenderPipelineState(
          device: device,
          label: "shaderSampleFragment_1",
          vertexFunc: "shaderSampleVertex",
          fragmentFunc: "shaderSampleFragment",
          colorPixelFormat: mtkView.colorPixelFormat)
        
      case .sdf2:
        pipelineState = createRenderPipelineState(
          device: device,
          label: "shaderSampleFragment_2",
          vertexFunc: "shaderSampleVertex",
          fragmentFunc: "shaderSampleFragment_2",
          colorPixelFormat: mtkView.colorPixelFormat)
      case .sdf3:
        pipelineState = createRenderPipelineState(
          device: device,
          label: "shaderSampleFragment_3",
          vertexFunc: "shaderSampleVertex",
          fragmentFunc: "shaderSampleFragment_sample",
          colorPixelFormat: mtkView.colorPixelFormat)

      case .raymarching01:
        pipelineState = createRenderPipelineState(
          device: device,
          label: "shaderRaymarching01",
          vertexFunc: "shaderSampleVertex",
          fragmentFunc: "shaderSampleRayMarching01",
          colorPixelFormat: mtkView.colorPixelFormat)
      case .raymarching02:
        pipelineState = createRenderPipelineState(
          device: device,
          label: "shaderRaymarching02",
          vertexFunc: "shaderSampleVertex",
          fragmentFunc: "shaderSampleRayMarching02",
          colorPixelFormat: mtkView.colorPixelFormat)

      case .raymarching03:
        pipelineState = createRenderPipelineState(
          device: device,
          label: "shaderRaymarching03",
          vertexFunc: "shaderSampleVertex",
          fragmentFunc: "shaderSampleRayMarching03",
          colorPixelFormat: mtkView.colorPixelFormat)
      case .raymarching04:
        pipelineState = createRenderPipelineState(
          device: device,
          label: "shaderRaymarching04",
          vertexFunc: "shaderSampleVertex",
          fragmentFunc: "shaderSampleRayMarching04",
          colorPixelFormat: mtkView.colorPixelFormat)

      case .raymarching05:
        pipelineState = createRenderPipelineState(
          device: device,
          label: "shaderRaymarching05",
          vertexFunc: "shaderSampleVertex",
          fragmentFunc: "shaderSampleRayMarching05",
          colorPixelFormat: mtkView.colorPixelFormat)

      case .raymarching06:
        pipelineState = createRenderPipelineState(
          device: device,
          label: "shaderRaymarching06",
          vertexFunc: "shaderSampleVertex",
          fragmentFunc: "shaderSampleRayMarching06",
          colorPixelFormat: mtkView.colorPixelFormat)
      }
        pipelineStates[type] = pipelineState

    }


    

    guard let queue = device.makeCommandQueue() else {
      fatalError("Failed to create command queue")
    }

    self.commandQueue = queue
    print("ParticleRenderer init finish")
  }
}

func createRenderPipelineState(
  device: any MTLDevice,
  label: String,
  vertexFunc: String,
  fragmentFunc: String,
  colorPixelFormat: MTLPixelFormat = .bgra8Unorm) -> any MTLRenderPipelineState
{
  guard let library = device.makeDefaultLibrary() else {
    fatalError("Failed to create library")
  }

  guard let vertexFunction = library.makeFunction(name: vertexFunc) else {
    fatalError("Failed to create vertex function")
  }
  guard let fragmentFunction = library.makeFunction(name: fragmentFunc) else {
    fatalError("Failed to create fragment function")
  }

  let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
  pipelineStateDescriptor.label = label

  pipelineStateDescriptor.vertexFunction = vertexFunction

  pipelineStateDescriptor.fragmentFunction = fragmentFunction
//    pipelineStateDescriptor.fragmentFunction = fragmentFunction2

  pipelineStateDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat

  do {
    return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
  } catch {
    fatalError("Failed to create pipeline state \(error)")
  }
}

extension ShaderSampleRenderer {
  @objc func handleTap(_ gesture: UITapGestureRecognizer) {
    // ジェスチャーの位置を取得
    print("tap: \(tapPoint)")
    tapPoint = CGPoint(x: 0, y: 0)
    zPoint = -1.0
  }

  @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
    // ジェスチャーの位置を取得
//    let pt = gesture.location(in: mtkView)
    let trans = gesture.translation(in: mtkView)
    let w = min(viewportSize.width, viewportSize.height)
    let trans2 = CGPoint(x: trans.x / w, y: trans.y / w)
    if(gesture.numberOfTouches == 1){
      tapPoint = CGPoint(x: tapPoint.x + trans2.x, y: tapPoint.y + trans2.y)
    }
    else if(gesture.numberOfTouches == 2){
      zPoint -=  trans2.y
    }
    print("pan: \(gesture.numberOfTouches) \(String(format:"%0.2f",tapPoint.x)) \(String(format:"%0.2f",tapPoint.y)) z:\(String(format:"%0.2f",zPoint))  trans:\(String(format:"%0.2f",trans2.x)) \(String(format:"%0.2f",trans2.y))")
  }

  @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
    // ジェスチャーの位置を取得
    let scale = gesture.scale
    if scale > 0 {
//      zPoint = min(max(zPoint / scale, 0.001), 23.0) - 10.0
//      zPoint = min(max(zPoint / scale, 0.001), 23.0) - 10.0
//      zPoint = zPoint / scale
      if(scale > 1.0){
        zPoint = zPoint - scale * 0.05
      }
      else{
        zPoint = zPoint + scale * 0.05
      }
      zPoint = min(max(zPoint, -20.0), 20.0)
      
//      zPoint *= zPoint * scale
      
    }
    
    print("pinch: \(String(format:"%0.2f",tapPoint.x)) \(String(format:"%0.2f",tapPoint.y)) \(String(format:"%0.2f",zPoint)) \(String(format:"%0.2f",scale))")

//    print("pinch: \(tapPoint) \(zPoint) \(scale)")
  }
}

extension ShaderSampleRenderer: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    print("ParticleRenderer drawableSizeWillChange \(size)")
    viewportSize = size
  }

  private func calculateFPS() {
    guard let startTime = fpsStartTime else {
      fpsStartTime = CACurrentMediaTime()
      return
    }

    frameCount += 1
    let endTime = CACurrentMediaTime()
    let elapsedTime = endTime - startTime

    if elapsedTime >= 1.0 {
      let fps = Double(frameCount) / elapsedTime
      print("FPS: \(String(format: "%.2f", fps)) ")
      delegate?.renderer(self, didUpdateFPS: fps)
      self.fpsStartTime = endTime
      self.frameCount = 0
    }
  }

  func draw(in view: MTKView) {
    let currentDrawCount = self.drawCount
    self.drawCount += 1

    let vSize = vector_float2(Float(viewportSize.width),
                              Float(viewportSize.height))
    let tSize = vector_float2(0.0, 0.0)
  
    
    let pt = vector_float3(Float(tapPoint.x),Float(tapPoint.y),Float(zPoint))
    var uniform = ShaderCommonUniform(
      seed: seed,
      time: Float(Float(currentDrawCount) / Float(mtkView.preferredFramesPerSecond)),
      vsize: vSize,
      aspect: Float(viewportSize.width) / Float(viewportSize.height),
      tsize: tSize,
      userpt:  pt
    )

//    print("uniform[\(currentDrawCount)] \(uniform)")
//    print("ParticleRenderer draw[\(drawno)] \(viewportSize) currentFrameIndex=\(currentFrameIndex)")

    let _ = frameBoundarySemaphore.wait(timeout: DispatchTime.distantFuture)

//    let currentBuffer = dynamicDataBuffers[currentFrameIndex]
//    print("currentBuffer[0]=\(currentBuffer[0])")

    guard let renderCommandBuffer = commandQueue.makeCommandBuffer() else { return }
    renderCommandBuffer.label = "MyCommand"

    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = view.currentDrawable?.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].clearColor = viewClearColor
    renderPassDescriptor.colorAttachments[0].storeAction = .store

    // Create a render command encoder.
    guard let renderEncoder = renderCommandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
    renderEncoder.label = "MyRenderEncoder"

    // Set the region of the drawable to draw into.
    renderEncoder.setViewport(
      MTLViewport(originX: 0.0,
                  originY: 0.0,
                  width: Double(viewportSize.width),
                  height: Double(viewportSize.height),
                  znear: 0.0, zfar: 1.0))

    guard let currentPipeline = currentPipeline else {
      fatalError("currentPipeline is nil")
    }
    renderEncoder.setRenderPipelineState(currentPipeline)
    renderEncoder.setVertexBytes(triangleVertices,
                                 length: MemoryLayout<SIMD4<Float>>.stride * triangleVertices.count,
                                 index: 0)

    renderEncoder.setVertexBytes(&uniform, length: MemoryLayout<ShaderCommonUniform>.stride, index: 1)
    if( shaderType != .raymarching04){
      renderEncoder.setFragmentBytes(&uniform, length: MemoryLayout<ShaderCommonUniform>.stride, index: 0)
    }
    
    renderEncoder.drawPrimitives(type: .triangleStrip,
                                 vertexStart: 0,
                                 vertexCount: triangleVertices.count)

    renderEncoder.endEncoding()

    // Schedule a present once the framebuffer is complete using the current drawable.
    if let drawable = view.currentDrawable {
      renderCommandBuffer.present(drawable)
    }
    renderCommandBuffer.addCompletedHandler { _ in
      self.frameBoundarySemaphore.signal()
    }

    renderCommandBuffer.commit()

    calculateFPS()
  }
}

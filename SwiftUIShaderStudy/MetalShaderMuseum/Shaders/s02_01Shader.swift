import MetalKit
import simd
import SwiftUI

public struct S02_01Parameters {
  var lineWidth: Float

}
public final class S02_01Shader: MSMDrawable {
  public typealias Parameters = S02_01Parameters

  public let pipelineState: MTLRenderPipelineState
  private var shaderUniformBuffer: MTLBuffer?
  private var params = S02_01Parameters(lineWidth: 2.0)

  // triangle ２つで全面とする
  private var triangleVertices: [SIMD4<Float>] = [
    SIMD4<Float>(-1, -1, 0, 1),
    SIMD4<Float>(1.0, -1.0, 0, 1),
    SIMD4<Float>(-1.0, 1.0, 0, 1),
    SIMD4<Float>(1.0, 1.0, 0, 1),
  ]

  public init(device: MTLDevice, library: MTLLibrary) throws {
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "vertexCommon")
    descriptor.fragmentFunction = library.makeFunction(name: "shader02_01")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    shaderUniformBuffer = device.makeBuffer(
      length: MemoryLayout<S02_01Parameters>.stride,
      options: []
    )!
  }

  public func setParameters(_ parameters: S02_01Parameters) {
    self.params = parameters
    // 必要に応じて Metal バッファにコピー
    print("setParameters \(params)")
  }
  
//  func setShaderUniforms(_ uniforms: S02_01Parameters) {
//    shaderUniforms = uniforms
////    memcpy(shaderUniformBuffer.contents(), &uniforms, MemoryLayout<S02_01Parameters>.stride)
//  }

  public func draw(commandEncoder: MTLRenderCommandEncoder) {
    commandEncoder.setRenderPipelineState(pipelineState)
    commandEncoder.setFragmentBytes(&params, length: MemoryLayout<S02_01Parameters>.stride, index: 1)
  }
}

extension S02_01Shader: MSMConfigurableShader {
  public func settingsView() -> AnyView {
    AnyView(
      HStack {
        Text("Line Width \(String(format: "%.1f", params.lineWidth))")
          .foregroundStyle(.white)
        Slider(value: Binding<Double>(
          get: { Double(self.params.lineWidth) },
          set: { newValue in
            var p = self.params
            p.lineWidth = Float(newValue)
            self.setParameters(p)
          }
        ), in: 0.005...4.0)
      }
      .padding()
    )
  }
}

public final class S02_02Shader: MSMDrawable {
  public let pipelineState: MTLRenderPipelineState
  private var uniformBuffer: MTLBuffer
  var uniforms = ShaderCommonUniform(
    seed: 42,
    time: 0.0,
    vsize: SIMD2<Float>(800, 600),
    aspect: 800.0 / 600.0
  )

  private var _time: Float = 0.0

  // triangle ２つで全面とする
  private var triangleVertices: [SIMD4<Float>] = [
    SIMD4<Float>(-1, -1, 0, 1),
    SIMD4<Float>(1.0, -1.0, 0, 1),
    SIMD4<Float>(-1.0, 1.0, 0, 1),
    SIMD4<Float>(1.0, 1.0, 0, 1),
  ]

  public init(device: MTLDevice, library: MTLLibrary) throws {
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "vertexCommon")
    descriptor.fragmentFunction = library.makeFunction(name: "shader02_02")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    uniformBuffer = device.makeBuffer(
      length: MemoryLayout<ShaderCommonUniform>.stride,
      options: []
    )!
  }

  public func setParameters(_ parameters: Any) {
    guard let params = parameters as? ShaderCommonUniform else { return }
    uniforms = params
    memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<ShaderCommonUniform>.stride)
  }

  public func draw(commandEncoder: MTLRenderCommandEncoder) {
    //      uniforms.time = _time
    //      _time += 1.0
    //      setParameters(uniforms)
    //      print("time: \(_time)")

    commandEncoder.setRenderPipelineState(pipelineState)
    //        commandEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
    //      commandEncoder.setVertexBytes(uniformBuffer,
    //                                   length: MemoryLayout<SIMD4<Float>>.stride * triangleVertices.count,
    //                                   index: 0)


    // 頂点・描画処理をここに
  }
}

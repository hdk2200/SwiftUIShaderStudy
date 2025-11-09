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

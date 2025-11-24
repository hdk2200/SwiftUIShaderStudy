import MetalKit
import SwiftUI

public struct Shader06Parameters {
  // Future tweak hooks for shader06
}

public final class Shader06: MSMDrawable {
  public typealias Parameters = Shader06Parameters

  public let pipelineState: MTLRenderPipelineState
  private var params = Shader06Parameters()

  public init(device: MTLDevice, library: MTLLibrary) throws {
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "vertex_pathtrough")
    descriptor.fragmentFunction = library.makeFunction(name: "shader06Fragment")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
  }

  public func setParameters(_ parameters: Parameters) {
    self.params = parameters
  }

  public func draw(commandEncoder: MTLRenderCommandEncoder) {
    commandEncoder.setRenderPipelineState(pipelineState)
    // commandEncoder.setFragmentBytes(&params, length: MemoryLayout<Parameters>.stride, index: 1)
  }
}

extension Shader06: MSMConfigurableShader {
  public func settingsView() -> AnyView {
    AnyView(
      Text("Shader06 Settings")
        .foregroundStyle(.white)
        .padding()
    )
  }
}

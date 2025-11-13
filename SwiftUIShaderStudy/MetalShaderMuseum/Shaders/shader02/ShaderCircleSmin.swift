import MetalKit
import simd
import SwiftUI

public final class ShaderCircleSmin: MSMDrawable {
  public let pipelineState: MTLRenderPipelineState
  private var uniformBuffer: MTLBuffer

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
    descriptor.fragmentFunction = library.makeFunction(name: "shader02_circle_smin")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    uniformBuffer = device.makeBuffer(
      length: MemoryLayout<ShaderCommonUniform>.stride,
      options: []
    )!
  }

  public func setParameters(_ parameters: Any) {
    guard let params = parameters as? ShaderCommonUniform else { return }
  }

  public func draw(commandEncoder: MTLRenderCommandEncoder) {
    commandEncoder.setRenderPipelineState(pipelineState)
  }
}

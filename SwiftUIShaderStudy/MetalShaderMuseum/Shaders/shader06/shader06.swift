import MetalKit
import SwiftUI

public struct Shader06Parameters {
  var sminBlend: Float = 0.03
  var cellSize: Float = 0.35
  var sphereAmplitude: Float = 0.15
  private var padding: Float = 0
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
    commandEncoder.setFragmentBytes(&params, length: MemoryLayout<Parameters>.stride, index: 1)
  }
}

extension Shader06: MSMConfigurableShader {
  public func settingsView() -> AnyView {
    AnyView(
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Blend Radius \(String(format: "%.3f", params.sminBlend))")
          Slider(value: Binding<Double>(
            get: { Double(self.params.sminBlend) },
            set: { newValue in
              var updated = self.params
              updated.sminBlend = Float(newValue)
              self.setParameters(updated)
            }
          ), in: 0.005...0.50)
        }
        .foregroundStyle(.white)

        VStack(alignment: .leading, spacing: 4) {
          Text("Cell Size \(String(format: "%.2f", params.cellSize))")
          Slider(value: Binding<Double>(
            get: { Double(self.params.cellSize) },
            set: { newValue in
              var updated = self.params
              updated.cellSize = Float(newValue)
              self.setParameters(updated)
            }
          ), in: 0.15...0.6)
        }
        .foregroundStyle(.white)

        VStack(alignment: .leading, spacing: 4) {
          Text("Z Amplitude \(String(format: "%.2f", params.sphereAmplitude))")
          Slider(value: Binding<Double>(
            get: { Double(self.params.sphereAmplitude) },
            set: { newValue in
              var updated = self.params
              updated.sphereAmplitude = Float(newValue)
              self.setParameters(updated)
            }
          ), in: 0.05...0.3)
        }
        .foregroundStyle(.white)
      }
      .padding()
    )
  }
}

import MetalKit
import SwiftUI

public struct Shader07Parameters {
  var radius: Float = 0.8
  var grooveWidth: Float = 0.8
  var patternScale: Float = 5.0
  var bumpHeight: Float = 0.05
}

public final class Shader07: MSMDrawable {
  public typealias Parameters = Shader07Parameters

  public let pipelineState: MTLRenderPipelineState
  private var params = Shader07Parameters()

  public init(device: MTLDevice, library: MTLLibrary) throws {
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "vertex_pathtrough")
    descriptor.fragmentFunction = library.makeFunction(name: "shader07Fragment")
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

extension Shader07: MSMConfigurableShader {
  public func settingsView() -> AnyView {
    AnyView(
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Radius \(String(format: "%.2f", params.radius))")
          Slider(value: Binding<Double>(
            get: { Double(self.params.radius) },
            set: { newValue in
              var updated = self.params
              updated.radius = Float(newValue)
              self.setParameters(updated)
            }
          ), in: 0.1...1.5)
        }
        .foregroundStyle(.primary)

        VStack(alignment: .leading, spacing: 4) {
          Text("Groove Width \(String(format: "%.2f", params.grooveWidth))")
          Slider(value: Binding<Double>(
            get: { Double(self.params.grooveWidth) },
            set: { newValue in
              var updated = self.params
              updated.grooveWidth = Float(newValue)
              self.setParameters(updated)
            }
          ), in: 0.0...1.0)
        }
        .foregroundStyle(.primary)

        VStack(alignment: .leading, spacing: 4) {
          Text("Pattern Scale \(String(format: "%.1f", params.patternScale))")
          Slider(value: Binding<Double>(
            get: { Double(self.params.patternScale) },
            set: { newValue in
              var updated = self.params
              updated.patternScale = Float(newValue)
              self.setParameters(updated)
            }
          ), in: 1.0...20.0)
        }
        .foregroundStyle(.primary)

        VStack(alignment: .leading, spacing: 4) {
          Text("Bump Height \(String(format: "%.3f", params.bumpHeight))")
          Slider(value: Binding<Double>(
            get: { Double(self.params.bumpHeight) },
            set: { newValue in
              var updated = self.params
              updated.bumpHeight = Float(newValue)
              self.setParameters(updated)
            }
          ), in: 0.0...0.2)
        }
        .foregroundStyle(.primary)
      }
      .padding()
    )
  }
}

extension Shader07 {
  public var preferredSettingsDetents: [PresentationDetent] {
    [.fraction(0.4), .large]
  }
}

import MetalKit
import SwiftUI

public struct Shader06Parameters {
  var sminBlend: Float = 0.03
  var cellSize: Float = 0.35
  var sphereAmplitude: Float = 10.0
  var oscillationSpeed: Float = 1.3
  var sphereRadius: Float = 0.05
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
          ), in: 0.005...1.00)
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
          ), in: 0.15...1.0)
        }
        .foregroundStyle(.white)

        VStack(alignment: .leading, spacing: 4) {
          Text("Z Range ±\(String(format: "%.1f", params.sphereAmplitude))")
          Slider(value: Binding<Double>(
            get: { Double(self.params.sphereAmplitude) },
            set: { newValue in
              var updated = self.params
              updated.sphereAmplitude = Float(newValue)
              self.setParameters(updated)
            }
          ), in: 1.0...15.0)
        }
        .foregroundStyle(.white)

        VStack(alignment: .leading, spacing: 4) {
          Text("Motion Speed \(String(format: "%.2f", params.oscillationSpeed))")
          Slider(value: Binding<Double>(
            get: { Double(self.params.oscillationSpeed) },
            set: { newValue in
              var updated = self.params
              updated.oscillationSpeed = Float(newValue)
              self.setParameters(updated)
            }
          ), in: 0.001...1.0)
        }
        .foregroundStyle(.white)

        VStack(alignment: .leading, spacing: 4) {
          Text("Sphere Radius \(String(format: "%.3f", params.sphereRadius))")
          Slider(value: Binding<Double>(
            get: { Double(self.params.sphereRadius) },
            set: { newValue in
              var updated = self.params
              updated.sphereRadius = Float(newValue)
              self.setParameters(updated)
            }
          ), in: 0.02...0.5)
        }
        .foregroundStyle(.white)
      }
      .padding()
    )
  }
}

extension Shader06 {
  public var preferredSettingsDetents: [PresentationDetent] {
    [.fraction(0.45), .fraction(0.65), .large]
  }
}

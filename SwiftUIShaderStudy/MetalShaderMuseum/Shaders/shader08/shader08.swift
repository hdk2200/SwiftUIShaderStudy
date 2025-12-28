import MetalKit
import SwiftUI
import Combine

public struct Shader08Parameters {
  var blendStrength: Float = 0.1
  var maxSteps: Int32 = 64
  var hitThreshold: Float = 0.001
  var maxDist: Float = 48.0
  var blendMode: Int32 = 0 // 0: smax, 1: sub, 2: xor
  var timeScale: Float = 0.8
  var baseAlpha: Float = 0.2
}

public final class Shader08: MSMDrawable, ObservableObject {
  public typealias Parameters = Shader08Parameters

  public let pipelineState: MTLRenderPipelineState
  @Published var params = Shader08Parameters()
  private let startDate = Date()

  public init(device: MTLDevice, library: MTLLibrary) throws {
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "vertex_pathtrough")
    descriptor.fragmentFunction = library.makeFunction(name: "shader08Fragment")
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

extension Shader08: MSMConfigurableShader {
  public func settingsView() -> AnyView {
    AnyView(Shader08SettingsView(shader: self))
  }
}

extension Shader08 {
  public var preferredSettingsDetents: [PresentationDetent] {
    [.fraction(0.55), .large]
  }
}

private struct Shader08SettingsView: View {
  @ObservedObject var shader: Shader08
  
  
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      // Blend Mode
      VStack(alignment: .leading, spacing: 8) {
        Text("Blend Mode")
          .foregroundStyle(.primary)
        
        Picker("Blend Mode", selection: Binding<Int>(
          get: { Int(shader.params.blendMode) },
          set: { val in
            shader.params.blendMode = Int32(val)
          }
        )) {
          Text("smax").tag(0)
          Text("Subtraction ").tag(1)
          Text("XOR ").tag(2)
        }
        .pickerStyle(.segmented)
      }
      // Base Alpha
      VStack(alignment: .leading, spacing: 4) {
        Text("Base Alpha (Ghost): \(String(format: "%.2f", shader.params.baseAlpha))")
        Slider(value: Binding<Double>(
          get: { Double(shader.params.baseAlpha) },
          set: { val in
            var p = shader.params
            p.baseAlpha = Float(val)
            shader.params = p
          }
        ), in: 0.0...1.0)
      }
      
      // Blend Strength
      VStack(alignment: .leading, spacing: 4) {
        Text("Blend Strength (k): \(String(format: "%.3f", shader.params.blendStrength))")
        Slider(value: Binding<Double>(
          get: { Double(shader.params.blendStrength) },
          set: { val in
            var p = shader.params
            p.blendStrength = Float(val)
            shader.params = p
          }
        ), in: 0.001...1.0)
      }
//      .foregroundStyle(.white)

      // Max Steps
      VStack(alignment: .leading, spacing: 4) {
        Text("Max Steps: \(shader.params.maxSteps)")
        Slider(value: Binding<Double>(
          get: { Double(shader.params.maxSteps) },
          set: { val in
            var p = shader.params
            p.maxSteps = Int32(val)
            shader.params = p
          }
        ), in: 10...200, step: 1)
      }
//      .foregroundStyle(.white)

      // Hit Threshold
      VStack(alignment: .leading, spacing: 4) {
        Text("Hit Threshold: \(String(format: "%.4f", shader.params.hitThreshold))")
        Slider(value: Binding<Double>(
          get: { Double(shader.params.hitThreshold) },
          set: { val in
            var p = shader.params
            p.hitThreshold = Float(val)
            shader.params = p
          }
        ), in: 0.0001...0.01)
      }
//      .foregroundStyle(.white)

      // Max Dist
      VStack(alignment: .leading, spacing: 4) {
        Text("Max Dist: \(String(format: "%.1f", shader.params.maxDist))")
        Slider(value: Binding<Double>(
          get: { Double(shader.params.maxDist) },
          set: { val in
            var p = shader.params
            p.maxDist = Float(val)
            shader.params = p
          }
        ), in: 10.0...100.0)
      }
//      .foregroundStyle(.primary)


      
      Spacer()
    }
    .padding()
  }
}

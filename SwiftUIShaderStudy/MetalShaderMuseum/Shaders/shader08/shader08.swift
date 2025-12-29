import MetalKit
import SwiftUI
import Combine

public struct Shader08Parameters {
  var blendStrength: Float = 0.1
  var maxSteps: Int32 = 64
  var hitThreshold: Float = 0.001
  var maxDist: Float = 48.0
  var blendMode: Int32 = 0 // 0: Union, 1: Intersection, 2: Subtraction, 3: Morph, 4: Steps, 5: Chamfer, 6: Grooves
  var timeScale: Float = 1.8
  var baseAlpha: Float = 0.2
  var boxSize: Float = 0.5
  var sphereRadius: Float = 0.6
  var cubeSpeed: Float = 0.3
  var sphereSpeed: Float = 0.2
  var sphereOffset: SIMD3<Float> = SIMD3<Float>(0.1, 0.3, 0.2)
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
  
  public func resetParameters() {
    self.params = Shader08Parameters()
    // Restore specific defaults that match our latest tuning if struct defaults differ
    self.params.timeScale = 1.8
    self.params.baseAlpha = 0.2
    self.params.boxSize = 0.5
    self.params.sphereRadius = 0.6
    self.params.cubeSpeed = 0.3
    self.params.sphereSpeed = 0.2
    self.params.sphereOffset = SIMD3<Float>(0.1, 0.3, 0.2)
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
          Text("Uni").tag(0)
          Text("Int").tag(1)
          Text("Sub").tag(2)
          Text("Mor").tag(3)
          Text("Stp").tag(4)
          Text("Chm").tag(5)
          Text("Grv").tag(6)
        }
        .pickerStyle(.segmented)
      }
      // Box Size
      VStack(alignment: .leading, spacing: 4) {
        Text("Box Size: \(String(format: "%.2f", shader.params.boxSize))")
        Slider(value: Binding<Double>(
          get: { Double(shader.params.boxSize) },
          set: { val in
            var p = shader.params
            p.boxSize = Float(val)
            shader.params = p
          }
        ), in: 0.1...1.5)
      }
      
      // Sphere Radius
      VStack(alignment: .leading, spacing: 4) {
        Text("Sphere Radius: \(String(format: "%.2f", shader.params.sphereRadius))")
        Slider(value: Binding<Double>(
          get: { Double(shader.params.sphereRadius) },
          set: { val in
            var p = shader.params
            p.sphereRadius = Float(val)
            shader.params = p
          }
        ), in: 0.1...1.5)
      }
      
      // Cube Speed
      VStack(alignment: .leading, spacing: 4) {
        Text("Cube Speed: \(String(format: "%.2f", shader.params.cubeSpeed))")
        Slider(value: Binding<Double>(
          get: { Double(shader.params.cubeSpeed) },
          set: { val in
            var p = shader.params
            p.cubeSpeed = Float(val)
            shader.params = p
          }
        ), in: 0.0...2.0)
      }

      // Sphere Speed
      VStack(alignment: .leading, spacing: 4) {
        Text("Sphere Speed: \(String(format: "%.2f", shader.params.sphereSpeed))")
        Slider(value: Binding<Double>(
          get: { Double(shader.params.sphereSpeed) },
          set: { val in
            var p = shader.params
            p.sphereSpeed = Float(val)
            shader.params = p
          }
        ), in: 0.0...2.0)
      }
      
      // Sphere Offset
      VStack(alignment: .leading, spacing: 4) {
        Text("Sphere Offset")
          .font(.caption)
          .foregroundStyle(.secondary)
        
        HStack {
          Text("X: \(String(format: "%.2f", shader.params.sphereOffset.x))")
          Slider(value: Binding<Double>(
            get: { Double(shader.params.sphereOffset.x) },
            set: { val in
              var p = shader.params
              p.sphereOffset.x = Float(val)
              shader.params = p
            }
          ), in: -2.0...2.0)
        }
        HStack {
          Text("Y: \(String(format: "%.2f", shader.params.sphereOffset.y))")
          Slider(value: Binding<Double>(
            get: { Double(shader.params.sphereOffset.y) },
            set: { val in
              var p = shader.params
              p.sphereOffset.y = Float(val)
              shader.params = p
            }
          ), in: -1.0...1.0)
        }
        HStack {
          Text("Z: \(String(format: "%.2f", shader.params.sphereOffset.z))")
          Slider(value: Binding<Double>(
            get: { Double(shader.params.sphereOffset.z) },
            set: { val in
              var p = shader.params
              p.sphereOffset.z = Float(val)
              shader.params = p
            }
          ), in: -1.0...1.0)
        }
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

      Button(action: {
        shader.resetParameters()
      }) {
        HStack {
          Image(systemName: "arrow.counterclockwise")
          Text("Reset Parameters")
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
      }
      .foregroundStyle(.primary)

      Spacer()
    }
    .padding()
  }
}

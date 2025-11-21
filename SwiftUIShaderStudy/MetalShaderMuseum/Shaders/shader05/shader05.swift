import MetalKit
import simd
import SwiftUI

public struct Shader05Parameters {
    // Add parameters here if needed
}

public final class Shader05: MSMDrawable {
    public typealias Parameters = Shader05Parameters

    public let pipelineState: MTLRenderPipelineState
    private var params = Shader05Parameters()

    public init(device: MTLDevice, library: MTLLibrary) throws {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertex_pathtrough")
        descriptor.fragmentFunction = library.makeFunction(name: "shader05Fragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    public func setParameters(_ parameters: Parameters) {
        self.params = parameters
    }

    public func draw(commandEncoder: MTLRenderCommandEncoder) {
        commandEncoder.setRenderPipelineState(pipelineState)
        // Set parameters if needed
        // commandEncoder.setFragmentBytes(&params, length: MemoryLayout<Parameters>.stride, index: 1)
    }
}

extension Shader05: MSMConfigurableShader {
    public func settingsView() -> AnyView {
        AnyView(
            Text("Shader05 Settings")
                .foregroundStyle(.white)
                .padding()
        )
    }
}

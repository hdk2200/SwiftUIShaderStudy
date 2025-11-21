import MetalKit
import simd
import SwiftUI

public struct Shader04Parameters {
    // Add parameters here if needed
}

public final class Shader04: MSMDrawable {
    public typealias Parameters = Shader04Parameters

    public let pipelineState: MTLRenderPipelineState
    private var params = Shader04Parameters()

    public init(device: MTLDevice, library: MTLLibrary) throws {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertex_pathtrough")
        descriptor.fragmentFunction = library.makeFunction(name: "shader04Fragment")
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

extension Shader04: MSMConfigurableShader {
    public func settingsView() -> AnyView {
        AnyView(
            Text("No settings available")
                .foregroundStyle(.white)
                .padding()
        )
    }
}

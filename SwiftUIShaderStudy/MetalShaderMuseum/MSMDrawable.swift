import MetalKit

public protocol MSMDrawable {
    var pipelineState: MTLRenderPipelineState { get }
    func draw(commandEncoder: MTLRenderCommandEncoder)
    func setParameters(_ parameters: Any)
}

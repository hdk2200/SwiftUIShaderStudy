import SwiftUI
import MetalKit

public protocol MSMDrawable {
  associatedtype Parameters
  var pipelineState: MTLRenderPipelineState { get }
  func draw(commandEncoder: MTLRenderCommandEncoder)
  func setParameters(_ parameters: Parameters)
}

public protocol MSMConfigurableShader {
  func settingsView() -> AnyView
}

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
  var preferredSettingsDetents: [PresentationDetent] { get }
}

public extension MSMConfigurableShader {
  var preferredSettingsDetents: [PresentationDetent] {
    [.fraction(0.35), .fraction(0.55)]
  }
}

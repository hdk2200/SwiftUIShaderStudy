import SwiftUI
import MetalKit

public struct MSMView: UIViewRepresentable {
    let renderer: MSMRenderer

    public init(renderer: MSMRenderer) {
        self.renderer = renderer
    }

    public func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = renderer.device
        view.delegate = renderer
        return view
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {}
}


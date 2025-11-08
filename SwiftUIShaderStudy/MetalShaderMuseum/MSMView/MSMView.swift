import SwiftUI
import MetalKit

// UIViewRepresentable は SwiftUI の View 構造の一部であり、SwiftUI から UIKit の UIView を統合するための 構造体（値型） 。
// Coordinator は クラス（参照型） であり、SwiftUI によって ビューのライフサイクル中は同じインスタンスとして保持される。
// Coordinator は SwiftUI と UIKit の橋渡し役として、データバインディングやデリゲートイベントのやり取りをする。
//
public struct MSMView: UIViewRepresentable {
    let renderer: MSMRenderer

    public init(renderer: MSMRenderer) {
        self.renderer = renderer
    }

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = renderer.device
        mtkView.delegate = renderer
        renderer.attachGestures(to: mtkView)
        return mtkView
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {}
}


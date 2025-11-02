//
// Copyright (c) 2024, - All rights reserved.
//
//

import Foundation

import MetalKit
import SwiftUI

enum ShaderType: CaseIterable {
  case sdf1
  case sdf2
  case sdf3
  case raymarching01
  case raymarching02
  case raymarching03
  case raymarching04
  case raymarching05
  case raymarching06

  var name: String {
    switch self {
    case .sdf1: return "SDF1"
    case .sdf2: return "SDF2"
    case .sdf3: return "SDF3"
    case .raymarching01: return "Raymarching01"
    case .raymarching02: return "Raymarching02"
    case .raymarching03: return "Raymarching03(half)"
    case .raymarching04: return "Raymarching04(reduce arg)"
    case .raymarching05: return "Raymarching05"
    case .raymarching06: return "Raymarching06"
    }
  }
}

struct MTKViewRepresentable: UIViewRepresentable {
  @Binding var fps: Double
//  @State renderer: ShaderSampleRenderer?
  var shaderType: ShaderType
  var preferredFPS: Int = 60

  func makeUIView(context: Context) -> MTKView {
    guard let device = MTLCreateSystemDefaultDevice() else {
      fatalError("Metal is not supported on this device")
    }

    let mtkView = MTKView(frame: .zero, device: device)
    mtkView.enableSetNeedsDisplay = false
    mtkView.clearColor = MTLClearColorMake(0.0, 0.0, 1.0, 1.0)
    mtkView.isPaused = false

    let renderer = ShaderSampleRenderer(metalKitView: mtkView)
    renderer.delegate = context.coordinator // fpsをrendererから受け取る
    context.coordinator.renderer = renderer
    mtkView.delegate = renderer
    return mtkView
  }

  func updateUIView(_ mtkView: MTKView, context: Context) {
//    print("MetalView(Representable) updateUIView")

    mtkView.preferredFramesPerSecond = preferredFPS
    context.coordinator.renderer?.shaderType = shaderType
  }

  func makeCoordinator() -> Coordinator {
    return Coordinator(self)
  }

  class Coordinator: NSObject, MTKViewRendererDelegate {
    let parent: MTKViewRepresentable
    var renderer: ShaderSampleRenderer?

    init(_ parent: MTKViewRepresentable) {
      self.parent = parent
    }

    func renderer(_ renderer: MTKViewDelegate, didUpdateFPS fps: Double) {
      parent.fps = fps
    }
  }
}

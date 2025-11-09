//
// Copyright (c) 2025, ___ORGANIZATIONNAME___ All rights reserved.
//
//

import SwiftUI

struct MetalSharderMuseum: View {
  @StateObject private var renderer = try! MSMRenderer(
    device: MTLCreateSystemDefaultDevice()!,
    shader: S02_01Shader(
      device: MTLCreateSystemDefaultDevice()!,
      library: MTLCreateSystemDefaultDevice()!.makeDefaultLibrary()!
    )
  )

  @State private var showSettings = false
  @State private var lineWidth: Float = 1.0
  
  var body: some View {
    ZStack {
      MSMView(renderer: renderer)
        .edgesIgnoringSafeArea(.all)

      //        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)

      FloatingSettingsButton(isPresented: $showSettings) {
        MetalSharderMuseumSetting(
          showSettings: $showSettings,
          renderer: renderer
        )
        .presentationDetents([.fraction(0.3)])
      }

//      let frameCount = renderer.frameCount
      VStack {
        Spacer()
//        VStack {
//          // MTKView 表示（省略）
//
//          if let configurable = renderer.currentShader as? MSMConfigurableShader {
//            configurable.settingsView()
//          }
//        }

        HStack {
          Button("Shader A") {
            do {
              guard let defaultLibrary = renderer.device.makeDefaultLibrary() else {
                print("Failed to create default Metal library")
                return
              }
              let shader = try S02_01Shader(
                device: renderer.device,
                library: defaultLibrary
              )
              renderer.changeShader(to: shader)
            } catch {
              print("Failed to switch to S02_01Shader: \(error)")
            }
          }

          Button("Shader B") {
            do {
              guard let defaultLibrary = renderer.device.makeDefaultLibrary() else {
                print("Failed to create default Metal library")
                return
              }
              let shader = try S02_02Shader(
                device: renderer.device,
                library: defaultLibrary
              )
              renderer.changeShader(to: shader)
            } catch {
              print("Failed to switch to S02_02Shader: \(error)")
            }
          }
        }
        let fpsstr = String(format: "%.1f", renderer.fps)
        Text("fps: \(fpsstr)")
          .foregroundStyle(Color.white)
      }
    }
    .onAppear {
      print("MetalSharderMuseum onAppear")
    }
  }
}

#Preview {
  MetalSharderMuseum()
}


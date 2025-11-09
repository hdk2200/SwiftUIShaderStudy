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
          showSettings: $showSettings
        )
        .presentationDetents([.fraction(0.3)])
      }

//      let frameCount = renderer.frameCount
      VStack {
        Spacer()
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
        Text("frame count: \(fpsstr)")
          .foregroundStyle(Color.white)
      }
      VStack {
        // MTKView 表示（省略）

        if renderer.currentShader is S02_01Shader{
        
          HStack {
            Text("Line Width \(String(format: "%.1f", lineWidth))")
              .foregroundStyle(Color.white)
            Slider(value: Binding(
              get: { Double(lineWidth)},
              set: { newValue in
               
                guard let shader = renderer.currentShader as? S02_01Shader else { return }
                lineWidth = Float(newValue)
                shader.setParameters(S02_01Parameters(lineWidth: lineWidth))
              }
            ), in: 0.01...2.0)
          }
          .padding()
        }
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


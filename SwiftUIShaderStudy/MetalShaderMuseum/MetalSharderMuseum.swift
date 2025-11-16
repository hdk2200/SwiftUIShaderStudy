//
// Copyright (c) 2025, ___ORGANIZATIONNAME___ All rights reserved.
//
//

import SwiftUI

struct MetalSharderMuseum: View {
  @StateObject private var renderer = try! MSMRenderer(
    device: MTLCreateSystemDefaultDevice()!,
    shader: ShaderPrimitivesSmin(
      device: MTLCreateSystemDefaultDevice()!,
      library: MTLCreateSystemDefaultDevice()!.makeDefaultLibrary()!
    )
  )

  @State private var showSettings = false
  @State private var lineWidth: Float = 1.0
  @State private var showShaderPicker = false
  @State private var shaderPickerError: String?

  private let shaderOptions = ShaderOption.available
  
  var body: some View {
    ZStack {
      MSMView(renderer: renderer)
        .edgesIgnoringSafeArea(.all)

      // Shader selection + settings buttons
      VStack {
        Spacer()
        HStack {
          Spacer()
          VStack(spacing: 16) {
            Button(action: { showShaderPicker = true }) {
              FloatingShaderButtonLabel()
            }
            .sheet(isPresented: $showShaderPicker) {
              ShaderPickerSheet(
                options: shaderOptions,
                selectedOptionID: activeShaderID,
                onSelect: { option in selectShader(option) }
              )
            }

            FloatingSettingsButton(isPresented: $showSettings) {
              MetalSharderMuseumSetting(
                showSettings: $showSettings,
                renderer: renderer
              )
              .presentationDetents([.fraction(0.3)])
            }
          }
          .padding(.trailing, 32)
          .padding(.bottom, 32)
        }
      }

      //      let frameCount = renderer.frameCount
      VStack {
        Spacer()
        let fpsstr = String(format: "%.1f", renderer.fps)
        Text("fps: \(fpsstr)")
          .foregroundStyle(Color.white)
          .padding(.bottom, 24)
      }
    }
    .alert(
      "Shader Error",
      isPresented: Binding(
        get: { shaderPickerError != nil },
        set: { if !$0 { shaderPickerError = nil } }
      )
    ) {
      Button("OK", role: .cancel) {
        shaderPickerError = nil
      }
    } message: {
      Text(shaderPickerError ?? "")
    }
    .onAppear {
      print("MetalSharderMuseum onAppear")
    }
  }

  private var activeShaderID: String? {
    shaderOptions.first(where: { $0.matches(renderer.currentShader) })?.id
  }

  private func selectShader(_ option: ShaderOption) {
    do {
      let shader = try option.builder(renderer.device)
      renderer.changeShader(to: shader)
      showShaderPicker = false
    } catch {
      print("Failed to change shader: \(error)")
      shaderPickerError = error.localizedDescription
    }
  }
}

#Preview {
  MetalSharderMuseum()
}

private enum ShaderSelectionError: LocalizedError {
  case missingDefaultLibrary

  var errorDescription: String? {
    switch self {
    case .missingDefaultLibrary:
      return "Failed to load the default Metal library."
    }
  }
}

private struct ShaderOption: Identifiable {
  let id: String
  let title: String
  let builder: (MTLDevice) throws -> MSMDrawable
  let matches: (MSMDrawable) -> Bool

  static let available: [ShaderOption] = [
    ShaderOption(
      id: "ShaderBasicFigure",
      title: "Basic figures",
      builder: { device in
        guard let library = device.makeDefaultLibrary() else {
          throw ShaderSelectionError.missingDefaultLibrary
        }
        return try ShaderBasicFigure(device: device, library: library)
      },
      matches: { $0 is ShaderBasicFigure }
    ),
    ShaderOption(
      id: "ShaderCircleSmin",
      title: "Circles smin",
      builder: { device in
        guard let library = device.makeDefaultLibrary() else {
          throw ShaderSelectionError.missingDefaultLibrary
        }
        return try ShaderCircleSmin(device: device, library: library)
      },
      matches: { $0 is ShaderCircleSmin }
    ),
    ShaderOption(
      id: "ShaderPrimitivesSmin",
      title: "Primitives smin",
      builder: { device in
        guard let library = device.makeDefaultLibrary() else {
          throw ShaderSelectionError.missingDefaultLibrary
        }
        return try ShaderPrimitivesSmin(device: device, library: library)
      },
      matches: { $0 is ShaderPrimitivesSmin }
    ),
  ]
}

private struct ShaderPickerSheet: View {
  let options: [ShaderOption]
  let selectedOptionID: String?
  let onSelect: (ShaderOption) -> Void

  private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Select Shader")
        .font(.headline)
        .padding(.horizontal, 4)

      ScrollView {
        LazyVGrid(columns: columns, spacing: 16) {
          ForEach(options) { option in
            let isSelected = option.id == selectedOptionID
            Button(action: { onSelect(option) }) {
              VStack {
                Text(option.title)
                  .font(.title3)
                  .fontWeight(.semibold)
                  .frame(maxWidth: .infinity, alignment: .center)
                  .padding(.bottom, 4)
                if isSelected {
                  Text("Selected")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.8))
                }
              }
              .foregroundColor(.white)
              .padding()
              .frame(maxWidth: .infinity, minHeight: 90)
              .background(
                RoundedRectangle(cornerRadius: 14)
                  .fill(isSelected ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.15))
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.top, 8)
      }
    }
    .padding()
    .presentationDetents([.medium, .large])
  }
}

private struct FloatingShaderButtonLabel: View {
  var body: some View {
    ZStack {
      Circle()
        .fill(Color.accentColor.opacity(0.85))
        .frame(width: 60, height: 60)
      Image(systemName: "sparkles")
        .font(.system(size: 26, weight: .semibold))
        .foregroundColor(.white)
    }
  }
}

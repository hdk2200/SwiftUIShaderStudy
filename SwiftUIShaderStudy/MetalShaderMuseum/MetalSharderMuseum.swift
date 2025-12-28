//
// Copyright (c) 2025, ___ORGANIZATIONNAME___ All rights reserved.
//
//

import SwiftUI

struct MetalSharderMuseum: View {
  @StateObject private var renderer = try! MSMRenderer(
    device: MTLCreateSystemDefaultDevice()!,
    shader: Shader08(
      device: MTLCreateSystemDefaultDevice()!,
      library: MTLCreateSystemDefaultDevice()!.makeDefaultLibrary()!
    )
  )

  private enum BottomViewState {
    case none
    case settings
    case shaderPicker
  }

  @State private var bottomViewState: BottomViewState = .none
  @State private var lineWidth: Float = 1.0
  @State private var shaderPickerError: String?

  private let shaderOptions = ShaderOption.available

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        ZStack {
          MSMView(renderer: renderer)
            .edgesIgnoringSafeArea(.all)

          // Shader selection + settings buttons
          VStack {
            Spacer()
            HStack {
              Spacer()
              VStack(spacing: 16) {
                Button(action: {
                  withAnimation(.spring()) {
                    bottomViewState = (bottomViewState == .shaderPicker) ? .none : .shaderPicker
                  }
                }) {
                  FloatingShaderButtonLabel()
                }

                FloatingSettingsButton(isPresented: Binding(
                  get: { bottomViewState == .settings },
                  set: { val in
                    withAnimation(.spring()) {
                      bottomViewState = val ? .settings : .none
                    }
                  }
                )) {
                  EmptyView()
                }
              }
              .padding(.trailing, 16)
              .padding(.bottom, 16)
            }
          }

          VStack {
            Spacer()
            let fpsstr = String(format: "%.1f", renderer.fps)
            Text("fps: \(fpsstr)")
              .foregroundStyle(.secondary)
              .padding(.horizontal, 8)
              .background(.ultraThinMaterial)
              .cornerRadius(4)
              .padding(.bottom, 24)
          }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: bottomViewState != .none ? geometry.size.height * 0.5 : .infinity)

        if bottomViewState == .settings {
          MetalSharderMuseumSetting(
            showSettings: Binding(
              get: { bottomViewState == .settings },
              set: { val in bottomViewState = val ? .settings : .none }
            ),
            renderer: renderer
          )
          .frame(maxHeight: geometry.size.height * 0.5)
          .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if bottomViewState == .shaderPicker {
          ShaderPickerView(
            options: shaderOptions,
            selectedOptionID: activeShaderID,
            onSelect: { option in selectShader(option) },
            onClose: {
              withAnimation(.spring()) {
                bottomViewState = .none
              }
            }
          )
          .frame(maxHeight: geometry.size.height * 0.5)
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
    }
    .animation(.spring(), value: bottomViewState)

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

  private var currentSettingsDetents: Set<PresentationDetent> {
    if let configurable = renderer.currentShader as? MSMConfigurableShader {
      let detents = configurable.preferredSettingsDetents
      let normalized = detents.isEmpty ? [.fraction(0.35)] : detents
      return Set(normalized)
    }
    return [.fraction(0.35), .fraction(0.6)]
  }

  private func selectShader(_ option: ShaderOption) {
    do {
      let shader = try option.builder(renderer.device)
      renderer.changeShader(to: shader)
      withAnimation(.spring()) {
        bottomViewState = .none
      }
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
    ShaderOption(
      id: "Shader04",
      title: "Shader04 (RayMarching)",
      builder: { device in
        guard let library = device.makeDefaultLibrary() else {
          throw ShaderSelectionError.missingDefaultLibrary
        }
        return try Shader04(device: device, library: library)
      },
      matches: { $0 is Shader04 }
    ),
    ShaderOption(
      id: "Shader05",
      title: "Shader05 (RayMarching Smin)",
      builder: { device in
        guard let library = device.makeDefaultLibrary() else {
          throw ShaderSelectionError.missingDefaultLibrary
        }
        return try Shader05(device: device, library: library)
      },
      matches: { $0 is Shader05 }
    ),
    ShaderOption(
      id: "Shader06",
      title: "Shader06 (RayMarching Smin)",
      builder: { device in
        guard let library = device.makeDefaultLibrary() else {
          throw ShaderSelectionError.missingDefaultLibrary
        }
        return try Shader06(device: device, library: library)
      },
      matches: { $0 is Shader06 }
    ),
    ShaderOption(
      id: "Shader07",
      title: "Shader07 (Geometric Sphere)",
      builder: { device in
        guard let library = device.makeDefaultLibrary() else {
          throw ShaderSelectionError.missingDefaultLibrary
        }
        return try Shader07(device: device, library: library)
      },
      matches: { $0 is Shader07 }
    ),
    ShaderOption(
      id: "Shader08",
      title: "Shader08 (Boolean Blends)",
      builder: { device in
        guard let library = device.makeDefaultLibrary() else {
          throw ShaderSelectionError.missingDefaultLibrary
        }
        return try Shader08(device: device, library: library)
      },
      matches: { $0 is Shader08 }
    ),
  ]
}

private struct ShaderPickerView: View {
  let options: [ShaderOption]
  let selectedOptionID: String?
  let onSelect: (ShaderOption) -> Void
  let onClose: () -> Void

  private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Select Shader")
          .font(.headline)
        Spacer()
        Button(action: onClose) {
          Image(systemName: "xmark.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .font(.title2)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(.thinMaterial)

      ScrollView {
        LazyVGrid(columns: columns, spacing: 12) {
          ForEach(options) { option in
            Button(action: {
              withAnimation(.spring()) {
                onSelect(option)
              }
            }) {
              VStack(spacing: 4) {
                Text(option.title)
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .multilineTextAlignment(.center)
                  .fixedSize(horizontal: false, vertical: true)

                if option.id == (selectedOptionID ?? "") {
                  Text("Selected")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
              }
              .foregroundColor(.primary)
              .padding(.vertical, 12)
              .padding(.horizontal, 8)
              .frame(maxWidth: .infinity, minHeight: 60)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(option.id == (selectedOptionID ?? "") ? AnyShapeStyle(Color.accentColor.opacity(0.2)) : AnyShapeStyle(.ultraThinMaterial))
              )
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .strokeBorder(option.id == (selectedOptionID ?? "") ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(16)
      }
    }
    .background(.ultraThinMaterial)
    .ignoresSafeArea(edges: .bottom)
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
          .foregroundColor(.primary)
    }
  }
}

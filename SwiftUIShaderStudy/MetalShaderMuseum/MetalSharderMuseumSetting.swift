import SwiftUI

struct MetalSharderMuseumSetting: View {
  @Binding var showSettings: Bool
  @ObservedObject var renderer: MSMRenderer

  var body: some View {
    VStack(spacing: 0) {
      // Header with title and close button (optional but good for clarity)
      HStack {
        Text("Shader Settings")
          .font(.headline)
        Spacer()
        Button(action: {
          withAnimation(.spring()) {
            showSettings = false
          }
        }) {
          Image(systemName: "xmark.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .font(.title2)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 8)
      .background(.thinMaterial)

        VStack(spacing: 8) {
        VStack(spacing: 24) {
          if let configurable = renderer.currentShader as? MSMConfigurableShader {
            configurable.settingsView()
              .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            Text("No configurable settings for current shader")
              .foregroundStyle(.secondary)
              .padding()
          }

          Divider()

          Button(action: {
            renderer.resetInteraction()
          }) {
            HStack {
              Image(systemName: "arrow.counterclockwise")
              Text("Reset Interaction")
            }
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.15))
            .cornerRadius(12)
          }
          .padding(.horizontal)
          .padding(.bottom, 48)
        }
        .padding(.top)
      }
    }
    .background(.ultraThinMaterial)
//    .cornerRadius(20, corners: [.topLeft, .topRight])
    .ignoresSafeArea(edges: .bottom)
  }
}

extension View {
  func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
    clipShape(RoundedCorner(radius: radius, corners: corners))
  }
}

struct RoundedCorner: Shape {
  var radius: CGFloat = .infinity
  var corners: UIRectCorner = .allCorners

  func path(in rect: CGRect) -> Path {
    let path = UIBezierPath(
      roundedRect: rect,
      byRoundingCorners: corners,
      cornerRadii: CGSize(width: radius, height: radius)
    )
    return Path(path.cgPath)
  }
}
//      .border(Color.red, width: 1)
//
//    NavigationView {
//      Form {
//        Section(header: Text("Shader設定")) {
//
//        }
//
//        Section {
//          Button("Close") {
//            showSettings = false
//          }
//          .frame(maxWidth: .infinity)
//          .foregroundColor(.blue)
//        }
//      }
//      .navigationTitle("Shader settings")
//      .navigationBarTitleDisplayMode(.inline)
//    }
//  }
//}

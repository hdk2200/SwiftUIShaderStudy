import SwiftUI

struct MetalSharderMuseumSetting: View {
  @Binding var showSettings: Bool
  @ObservedObject var renderer: MSMRenderer

  var body: some View {
    VStack(spacing: 16) {
      HStack {
        Spacer()
        Button(action: { showSettings = false }) {
          Image(systemName: "xmark.circle")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
            .foregroundColor(.white)
        }
      }
      .padding(.top, 12)

      if let configurable = renderer.currentShader as? MSMConfigurableShader {
        ScrollView {
          configurable.settingsView()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      } else {
        Text("No configurable settings for current shader")
          .foregroundStyle(.secondary)
      }

      Button(action: {
        renderer.resetInteraction()
      }) {
        HStack {
          Image(systemName: "arrow.counterclockwise")
          Text("Reset Interaction")
        }
        .foregroundColor(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.8))
        .cornerRadius(10)
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 16)
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
}

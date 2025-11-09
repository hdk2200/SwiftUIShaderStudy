import SwiftUI

struct MetalSharderMuseumSetting: View {
  @Binding var showSettings: Bool
  @ObservedObject var renderer: MSMRenderer

  var body: some View {
    VStack(alignment: .center, spacing: 1) {
      Spacer().frame(height: 20)
      HStack {
        Spacer()
        
        Button(action: {
          showSettings = false
        }) {
          ZStack {
            //            Circle()
            //              .fill(Color.gray.opacity(0.7))
            //              .frame(width: 60, height: 60)
            Image(systemName: "xmark.circle")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width:24, height: 24) // Hamburgerアイコンのサイズを設定します
              .foregroundColor(.white) // Hamburgerアイコンの色を指定します
          }
        }.padding(.trailing, 16)
        
      }
      
      if let configurable = renderer.currentShader as? MSMConfigurableShader {
        configurable.settingsView()
      } else {
        Text("No configurable settings for current shader")
          .foregroundStyle(.secondary)
          .padding(.top, 8)
      }
    }
    Spacer()
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


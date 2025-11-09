import SwiftUI

struct MetalSharderMuseumSetting: View {
  @Binding var showSettings: Bool

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Shader設定")) {

        }

        Section {
          Button("閉じる") {
            showSettings = false
          }
          .frame(maxWidth: .infinity)
          .foregroundColor(.blue)
        }
      }
      .navigationTitle("設定")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

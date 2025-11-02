//

import SwiftUI

struct SettingsView: View {
  @Binding var showSettings: Bool
  @Binding var shaderType: ShaderType
  

  var body: some View {
    
    VStack(alignment: .center, spacing: 0) {
      Spacer()
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
//      .border(Color.red, width: 1)
      
      List {
        ForEach(ShaderType.allCases, id: \.self) { item in
          Button {
            self.shaderType = item
            showSettings = false
          } label: {
            Text(item.name)
          }
        }
      }
      .scrollContentBackground(.hidden)
//      .background(Color.gray.opacity(0.5))
//      .border(Color.red, width: 1)
    }.background(Color.gray.opacity(0.5))
  }
}


struct MetalShadersExample: View {
  @State var shaderType: ShaderType = .raymarching06
  @State private var showSettings = false
  @State private var fps: Double = 0.0

  var body: some View {
    ZStack {
      MTKViewRepresentable(fps: $fps,
                           shaderType: shaderType)
        .edgesIgnoringSafeArea(.all)

      VStack(alignment: .center, spacing: 0) {
        Spacer()
        HStack {
          Spacer()

          Button(action: {
            showSettings = true
          }) {
            ZStack {
              Circle()
                .fill(Color.gray.opacity(0.7))
                .frame(width: 60, height: 60)
              Image(systemName: "line.horizontal.3")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 10) // Hamburgerアイコンのサイズを設定します
                .foregroundColor(.white) // Hamburgerアイコンの色を指定します
            }
          }
//          .buttonStyle(.bordered)
//          .buttonBorderShape(.capsule)
          .sheet(isPresented: $showSettings) {
            SettingsView(showSettings: $showSettings,
                         shaderType: $shaderType)

              //            .presentationDetents([.medium, .large])
              .presentationDetents([.fraction(0.3)])
//              .presentationBackground(Color.clear)
          }
          .padding(.trailing, 32)
        }
      }
      VStack(alignment: .center, spacing: 0) {
        HStack {
          Spacer()
          HStack {
            
            Text("\(shaderType.name)")
              .padding(.horizontal, 8)
              .foregroundColor(.white)
            Text("FPS: \(String(format: "%.1f", fps))")
              .padding(.horizontal, 8)
              .frame(width:96)
              .foregroundColor(.white)
//            .border(Color.black, width: 1)
          }
          .background(.red.opacity(0.3))
          .padding(.horizontal, 32)
        }
        .frame(height: 32)
        Spacer()
      }
    }
  }
}

#Preview {
  MetalShadersExample()
}

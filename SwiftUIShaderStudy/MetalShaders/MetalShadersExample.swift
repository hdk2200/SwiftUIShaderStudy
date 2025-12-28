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
              .frame(width:24, height: 24)
              .foregroundColor(.primary)
          }
        }.padding(.trailing, 16)
        
      }
      
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
    }.background(.regularMaterial)
  }
}


struct MetalShadersExample: View {
  @State var shaderType: ShaderType = .shader02_01
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
                .fill(.thinMaterial)
                .frame(width: 60, height: 60)
              Image(systemName: "line.horizontal.3")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 10)
                .foregroundColor(.primary)
            }
          }
          .sheet(isPresented: $showSettings) {
            SettingsView(showSettings: $showSettings,
                         shaderType: $shaderType)

              .presentationDetents([.fraction(0.3)])
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
              .foregroundColor(.primary)
            Text("FPS: \(String(format: "%.1f", fps))")
              .padding(.horizontal, 8)
              .frame(width:96)
              .foregroundColor(.primary)
          }
          .background(.ultraThinMaterial)
          .cornerRadius(8)
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

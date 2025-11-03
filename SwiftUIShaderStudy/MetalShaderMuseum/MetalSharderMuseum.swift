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
  
    var body: some View {
      ZStack {
        MSMView(renderer: renderer)
          .edgesIgnoringSafeArea(.all)
        
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
      }
      .onAppear() {
        print("MetalSharderMuseum onAppear")
      }
    }
}

#Preview {
    MetalSharderMuseum()
}

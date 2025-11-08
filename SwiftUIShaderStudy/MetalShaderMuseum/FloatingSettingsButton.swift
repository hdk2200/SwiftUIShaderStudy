//
// Copyright (c) 2025,  All rights reserved. 
// 
//
import SwiftUI

struct FloatingSettingsButton<Content: View>: View {
    @Binding var isPresented: Bool
    var content: () -> Content
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { isPresented = true }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.7))
                            .frame(width: 60, height: 60)
                        Image(systemName: "line.horizontal.3")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 10)
                            .foregroundColor(.white)
                    }
                }
                .sheet(isPresented: $isPresented, content: content)
                .padding(.trailing, 32)
            }
        }
    }
}

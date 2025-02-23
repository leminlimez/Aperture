//
//  ContentView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI

struct ContentView: View {
    // Camera Variables
    @State private var capturedImage: UIImage? = nil
    @State private var showCamera: Bool = false
    
    var body: some View {
        VStack {
            Button(action: {
                showCamera.toggle()
            }) {
                Text("Test camera")
            }
        }
        .sheet(isPresented: $showCamera) {
            MainCameraView(image: $capturedImage)
        }
    }
}

#Preview {
    ContentView()
}

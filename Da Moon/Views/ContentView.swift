//
//  ContentView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    // Camera Variables
    @State private var capturedImage: UIImage? = nil
    @State private var chosenPhotoItem: PhotosPickerItem? = nil
    
    @State private var showCamera: Bool = false
    @State private var showPhotoLibrary: Bool = false
    
    var body: some View {
        VStack {
            Button(action: {
                showCamera.toggle()
            }) {
                Text("Test camera")
            }
            Button(action: {
                showPhotoLibrary.toggle()
            }) {
                Text("Test photo library")
            }
            if let img = capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 500)
            }
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $chosenPhotoItem)
        .onChange(of: chosenPhotoItem, initial: false) {
            if let chosenPhoto = chosenPhotoItem {
                Task {
                    guard let imageData = try await chosenPhoto.loadTransferable(type: Data.self) else { return }
                    guard let inputImage = UIImage(data: imageData) else { return }
                    capturedImage = inputImage
                }
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

//
//  ContentView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI
import PhotosUI
import NavigationTransitions

struct ContentView: View {
    // Camera Variables
    @State private var selectedImage: UIImage? = nil
    @State private var chosenPhotoItem: PhotosPickerItem? = nil
    
    @State private var showCamera: Bool = false
    @State private var showPhotoLibrary: Bool = false
    @State private var showEditorView: Bool = false
    
    var body: some View {
        NavigationStack {
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
            }
            .photosPicker(isPresented: $showPhotoLibrary, selection: $chosenPhotoItem)
            .onChange(of: chosenPhotoItem, initial: false) {
                if let chosenPhoto = chosenPhotoItem {
                    Task {
                        guard let imageData = try await chosenPhoto.loadTransferable(type: Data.self) else { return }
                        guard let inputImage = UIImage(data: imageData) else { return }
                        selectedImage = inputImage
                        chosenPhotoItem = nil
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                MainCameraView(image: $selectedImage)
            }
            .onChange(of: selectedImage, initial: false) {
                if selectedImage != nil {
                    showEditorView = true
                }
            }
            .navigationDestination(isPresented: $showEditorView) {
                EditorView(image: $selectedImage)
            }
        }
        .navigationTransition(.fade(.cross))
    }
}

#Preview {
    ContentView()
}

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
                Text("Da Moon")
                    .font(.system(size: 200)) // scale the text
                    .fontWeight(.black)
                    .minimumScaleFactor(0.01)
                    .scaledToFit()
                    .lineLimit(1)
                    .padding(.top, 25)
                    .padding(.horizontal, 35)
                Spacer()
                Button(action: {
                    showPhotoLibrary.toggle()
                }) {
                    Text("Choose from Photo Library")
                }
                .buttonStyle(.borderedProminent)
                .padding(5)
                Button(action: {
                    showCamera.toggle()
                }) {
                    Text("Take Photo")
                }
                .buttonStyle(.borderedProminent)
                .padding(5)
                Spacer()
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

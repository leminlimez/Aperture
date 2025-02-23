//
//  ContentView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI
import PhotosUI
import NavigationTransitions

let BUTTON_SIZE: CGFloat = 145.0

struct ContentView: View {
    // Camera Variables
    @State private var selectedImage: UIImage? = nil
    @State private var chosenPhotoItem: PhotosPickerItem? = nil
    
    // View Toggles
    @State private var showSettings: Bool = false
    @State private var showCamera: Bool = false
    @State private var showPhotoLibrary: Bool = false
    @State private var showEditorView: Bool = false
    
    @State private var orientation = UIDeviceOrientation.unknown
    private let isipad: Bool = UIDevice.current.userInterfaceIdiom == .pad
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Aperture")
                    .font(.custom("Courier-Bold", size: 85)) // scale the text
                    .fontWeight(.heavy)
                    .minimumScaleFactor(0.1)
                    .scaledToFit()
                    .lineLimit(1)
                    .padding(.top, 30)
                    .padding(.bottom, (isLandscape() && !isipad) ? 50 : 65)
                    .padding(.horizontal, 40)
                if isipad {
                    Spacer()
                }
                if isipad || isLandscape() {
                    HStack {
                        buttons
                    }
                } else {
                    buttons
                }
                if isipad {
                    Spacer()
                }
                Spacer()
                Text("Designed for Boilermake XII (2025)")
                    .font(.footnote)
            }
            .photosPicker(isPresented: $showPhotoLibrary, selection: $chosenPhotoItem, matching: .images)
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
            .sheet(isPresented: $showSettings) {
                SettingsView()
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
                if let selectedImage = selectedImage {
                    EditorView(image: selectedImage)
                }
            }
            .onRotate { newOrientation in
                orientation = newOrientation
            }
        }
        .navigationTransition(.fade(.cross))
    }
    
    var buttons: some View {
        return Group {
            MenuButton(icon: "photo", title: "Choose from\nPhoto Library", action: {
                showPhotoLibrary.toggle()
            })
            MenuButton(icon: "camera", title: "Capture Photo", action: {
                showCamera.toggle()
            })
            // Settings Button
            Button(action: {
                showSettings.toggle()
            }) {
                VStack {
                    if isipad || isLandscape() {
                        Image(systemName: "gear")
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 50)
                            .padding(5)
                    }
                    Text("Settings")
                }
                .frame(width: BUTTON_SIZE, height: (isipad || isLandscape()) ? BUTTON_SIZE : nil)
                .padding(10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.gray)
            .aspectRatio((isipad || isLandscape()) ? 1.0 : nil, contentMode: .fit)
            .shadow(color: .gray, radius: 13)
            .padding((isipad || isLandscape()) ? 10 : 20)
        }
    }
    
    struct MenuButton: View {
        var icon: String
        var title: String
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 50)
                        .padding(5)
                    Text(title)
                }
                .frame(width: BUTTON_SIZE, height: BUTTON_SIZE)
                .padding(10)
            }
            .buttonStyle(.borderedProminent)
            .aspectRatio(1.0, contentMode: .fit)
            .shadow(color: .blue, radius: 13)
            .padding(10)
        }
    }
    
    func isLandscape() -> Bool {
        return orientation == .landscapeLeft || orientation == .landscapeRight
    }
}

#Preview {
    ContentView()
}

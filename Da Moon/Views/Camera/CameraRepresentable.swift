//
//  CameraRepresentable.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

// adapted from https://stackoverflow.com/questions/58847638/swiftui-custom-camera-view

import SwiftUI
import AVFoundation

struct CustomCameraRepresentable: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    @Binding var didTapCapture: Bool
    
    func makeUIViewController(context: Context) -> CustomCameraController {
        let controller = CustomCameraController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ cameraViewController: CustomCameraController, context: Context) {
        // dismiss if there is an error
        if let error = cameraViewController.error {
            presentationMode.wrappedValue.dismiss()
            UIApplication.shared.alert(title: "Failed to open camera.", body: error.localizedDescription)
        }
        if self.didTapCapture {
            cameraViewController.didTapRecord()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, AVCapturePhotoCaptureDelegate {
        let parent: CustomCameraRepresentable
        
        init(_ parent: CustomCameraRepresentable) {
            self.parent = parent
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            
            parent.didTapCapture = false
            
            if let imageData = photo.fileDataRepresentation() {
                parent.image = UIImage(data: imageData)
            } else if let error = error {
                UIApplication.shared.alert(title: "Failed to save image.", body: error.localizedDescription)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

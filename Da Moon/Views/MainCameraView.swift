//
//  MainCameraView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI
import MijickCamera

struct MainCameraView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var image: UIImage?
    
    var body: some View {
        MCamera()
            .setCameraScreen {
                DefaultCameraScreen(cameraManager: $0, namespace: $1, closeMCameraAction: $2)
                    .cameraOutputSwitchAllowed(false)
            }
            .onImageCaptured { capturedImage, controller in
                image = capturedImage
                controller.closeMCamera()
                dismiss()
            }
            .setCloseMCameraAction {
                dismiss()
            }
            .setCameraOutputType(.photo)
            .setAudioAvailability(false)
            .setGridVisibility(false)
            .setGridVisibility(false)
            .setResolution(.iFrame960x540)
            .startSession()
    }
}

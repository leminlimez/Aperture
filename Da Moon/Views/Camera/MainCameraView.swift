//
//  MainCameraView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI

let CameraViewOffset: CGFloat = 200
let ShutterDuration: Double = 0.1

struct MainCameraView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var image: UIImage?
    
    @State var captured: Bool = false
    @State private var playShutter: Bool = false
    
    var body: some View {
        VStack {
            CustomCameraRepresentable(image: $image, didTapCapture: $captured)
                .frame(height: UIScreen.main.bounds.size.height - CameraViewOffset)
                .overlay( // Camera Shutter
                    Color.black
                        .opacity(playShutter ? 1 : 0)
                        .animation(.easeOut(duration: ShutterDuration))
                )
            
            ZStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .foregroundStyle(Color.white)
                            .font(.title3)
                    }
                    .padding(.leading, 25)
                    Spacer()
                }
                HStack {
                    Spacer()
                    CaptureButtonView(playShutter: $playShutter)
                        .onTapGesture {
                            withAnimation {
                                playShutter = true
                            }
                            captured = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + ShutterDuration) {
                                playShutter = false // switch animation off after delay
                            }
                        }
                        .scaleEffect(0.9)
                    Spacer()
                }
            }
            .frame(maxHeight: 100)
            .edgesIgnoringSafeArea(.bottom)
        }
        .background(Color.black)
    }
}

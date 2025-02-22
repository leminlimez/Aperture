//
//  EditorView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI
import CoreML

let BOTTOM_BAR_PADDING: CGFloat = 12

struct EditorView: View {
    @State var image: UIImage
    @State var subject: UIImage?
    
    @State private var playingGlossAnim: Bool = false
    @State private var animStartTime: Date? = nil
    
    var body: some View {
        ZStack {
            ZoomableView {
                Image(uiImage: image)
                    .resizable()
                    .opacity(subject == nil ? 1.0 : 0.2)
                    .transition(.opacity)
                    .animation(.easeOut, value: subject != nil)
                    .shine(playingGlossAnim)
                    .overlay(content: {
                        // MARK: Subject Only
                        if let subject = subject {
                            Image(uiImage: subject)
                                .resizable()
                                .transition(.opacity)
                        }
                    })
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
            }
            VStack {
                Spacer()
                // MARK: Bottom Bar
                HStack {
                    BottomButton(icon: "lasso", action: {
                        // TODO: Lasso Tool
                    })
                    BottomButton(icon: "rectangle.dashed", action: {
                        // TODO: Select bounding box tool
                    })
                    BottomButton(icon: "person.and.background.dotted", pressed: { return subject != nil}, action: {
                        // MARK: Select Subject
                        if !playingGlossAnim {
                            if subject != nil {
                                subject = nil
                                return
                            }
                            startGloss()
                            Task {
                                do {
                                    let foundSubject = try await maskSubject(from: image)
                                    if foundSubject == nil {
                                        throw MaskingError.noSubjects
                                    }
                                    finishGloss({
                                        subject = foundSubject
                                    })
                                } catch {
                                    UIApplication.shared.alert(title: "Failed to find subject", body: error.localizedDescription)
                                    playingGlossAnim = false
                                }
                            }
                        }
                    })
                    BottomButton(icon: "character.magnify", action: {
                        // TODO: Upscale Text
                    })
                }
                .frame(maxWidth: .infinity, maxHeight: 50)
                .padding(.bottom, 2)
                .padding(.top, 18)
                .background(.regularMaterial, ignoresSafeAreaEdges: .bottom)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: {
                        // MARK: Upscale Image
                        if !playingGlossAnim {
                            startGloss()
                            Task {
                                await finalizeAndUpscale()
                            }
                        }
                    }) {
                        Image(systemName: "photo.badge.checkmark")
                    }
                }
            }
        }
    }
    
    struct BottomButton: View {
        var icon: String
        var pressed: () -> Bool = { return false }
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Image(systemName: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .padding(8)
            .background {
                if pressed() {
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundStyle(.thinMaterial)
                } else {
                    Color.clear
                }
            }
            .padding(.horizontal, BOTTOM_BAR_PADDING)
        }
    }
    
    func startGloss() {
        playingGlossAnim = true
        animStartTime = Date()
    }
    
    func finishGloss(_ action: @escaping () -> Void) {
        if let animStartTime = animStartTime {
            let timeLeft = GLOSS_DURATION - Date().timeIntervalSince(animStartTime).truncatingRemainder(dividingBy: GLOSS_DURATION)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeLeft) {
                playingGlossAnim = false
                action()
            }
        } else {
            // No start date set, just end the animation
            playingGlossAnim = false
            action()
        }
    }
    
    func finalizeAndUpscale() async {
        print("Upscale button tapped.")
        
        
        // Check if the UIImage has a valid CGImage.
        if image.cgImage == nil {
            print("Warning: The input UIImage does not have a cgImage.")
        } else {
            print("cgImage is available. Image size: \(image.size)")
        }
        
        // Resize the image to 512x512 (logical size), forcing a scale of 1.0.
        guard let resizedImage = image.resized(to: CGSize(width: 512, height: 512)) else {
            print("Failed to resize input image to 512x512.")
            playingGlossAnim = false
            return
        }
        print("Resized image to 512x512.")
        
        // Convert the resized UIImage to a CVPixelBuffer.
        guard let pixelBuffer = resizedImage.toCVPixelBuffer() else {
            print("Failed to convert resized UIImage to CVPixelBuffer.")
            playingGlossAnim = false
            return
        }
        print("Successfully created CVPixelBuffer from the image. Pixel buffer size: \(CVPixelBufferGetWidth(pixelBuffer)) x \(CVPixelBufferGetHeight(pixelBuffer))")
        
        do {
            print("Initializing the model...")
            let model = try realesrgan512(configuration: MLModelConfiguration())
            print("Model initialized successfully. Running prediction...")
            
            let prediction = try model.prediction(input: pixelBuffer)
            print("Prediction complete.")
            
            // Convert the model's output CVPixelBuffer to a UIImage.
            if let upscaledImage = UIImage(pixelBuffer: prediction.activation_out) {
                print("Successfully converted prediction output to UIImage.")
                if let finalImage = upscaledImage.resized(to: image.size) {
                    print("Resized upscaled image to original size: \(image.size)")
                    finishGloss {
                        self.image = finalImage
                        print("Image updated with stretched upscaled version.")
                    }
                } else {
                    print("Failed to resize upscaled image to original size.")
                    playingGlossAnim = false
                }
            } else {
                print("Failed to convert prediction output to UIImage.")
                playingGlossAnim = false
            }

        } catch {
            print("Upscaling failed with error: \(error)")
            playingGlossAnim = false
        }
    }
}

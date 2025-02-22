//
//  EditorView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI
import CoreML
import UIKit

//let acceptedSquareSizes: [CGFloat] = [
//    256, 512, 768, 1024, 1280, 1536, 1792, 2048, 2304,
//    2560, 2816, 3072, 3328, 3584, 3840, 4096, 4352, 4608, 4864
//]
let BOTTOM_BAR_PADDING: CGFloat = 18

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
                        GeometryReader { geometry in
                            // MARK: Subject Only
                            if let subject = subject {
                                Image(uiImage: subject)
                                    .resizable()
                                    .frame(
                                        width: (subject.size.width / image.size.width) * geometry.size.width,
                                        height: (subject.size.height / image.size.height) * geometry.size.height
                                    )
                                    .position(x: geometry.frame(in: .local).midX, y: geometry.frame(in: .local).midY)
                                    .transition(.opacity)
                            }
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
                    Button(action: {
                        // TODO: Lasso Tool
                    }) {
                        Image(systemName: "lasso")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .padding(.horizontal, BOTTOM_BAR_PADDING)
                    Button(action: {
                        // TODO: Select bounding box tool
                    }) {
                        Image(systemName: "rectangle.dashed")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .padding(.horizontal, BOTTOM_BAR_PADDING)
                    Button(action: {
                        // MARK: Select Subject
                        if !playingGlossAnim {
                            startGloss()
                            Task {
                                subject = nil
                                let foundSubject = await getSubject(from: image)
                                if foundSubject == nil {
                                    UIApplication.shared.alert(title: "Failed to find subject", body: "No subject could be found in the image!")
                                    playingGlossAnim = false
                                } else {
                                    finishGloss({
                                        subject = foundSubject
                                    })
                                }
                            }
                        }
                    }) {
                        Image(systemName: "person.and.background.dotted")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .padding(.horizontal, BOTTOM_BAR_PADDING)
                    Button(action: {
                        // TODO: Upscale Text
                    }) {
                        Image(systemName: "character.magnify")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .padding(.horizontal, BOTTOM_BAR_PADDING)
                }
                .frame(maxWidth: .infinity, maxHeight: 40)
                .padding(.bottom, 10)
                .padding(.top, 20)
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
    
    
    /// Determines the smallest accepted square size larger than the image’s current maximum dimension.
//        func smallestAcceptedSquareSize(for imageSize: CGSize) -> CGSize {
//            let maxDimension = max(imageSize.width, imageSize.height)
//            if let target = acceptedSquareSizes.first(where: { $0 >= maxDimension }) {
//                return CGSize(width: target, height: target)
//            }
//            return CGSize(width: acceptedSquareSizes.last!, height: acceptedSquareSizes.last!)
//        }
    
    func mlMultiArrayToPixelBuffer(_ array: MLMultiArray) -> CVPixelBuffer? {
            guard array.shape.count == 3,
                  let height = array.shape[0] as? Int,
                  let width = array.shape[1] as? Int,
                  let channels = array.shape[2] as? Int, channels == 3 else {
                print("Expected MLMultiArray shape [H, W, 3].")
                return nil
            }
            
            var pixelBuffer: CVPixelBuffer?
            let attrs = [
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
            ] as CFDictionary
            
            guard CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                      kCVPixelFormatType_32BGRA, attrs, &pixelBuffer) == kCVReturnSuccess,
                  let pb = pixelBuffer else {
                print("Could not create CVPixelBuffer")
                return nil
            }
            
            CVPixelBufferLockBaseAddress(pb, [])
            guard let baseAddress = CVPixelBufferGetBaseAddress(pb) else {
                CVPixelBufferUnlockBaseAddress(pb, [])
                return nil
            }
            
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
            let dest = baseAddress.assumingMemoryBound(to: UInt8.self)
            let totalElements = width * height * channels
            let pointer = array.dataPointer.bindMemory(to: Float32.self, capacity: totalElements)
            
            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width * channels + x * channels
                    let r = UInt8(clamping: Int(pointer[index]))
                    let g = UInt8(clamping: Int(pointer[index + 1]))
                    let b = UInt8(clamping: Int(pointer[index + 2]))
                    let offset = y * bytesPerRow + x * 4
                    dest[offset + 0] = b      // Blue
                    dest[offset + 1] = g      // Green
                    dest[offset + 2] = r      // Red
                    dest[offset + 3] = 255    // Alpha
                }
            }
            CVPixelBufferUnlockBaseAddress(pb, [])
            return pb
        }
    
    func finalizeAndUpscale() async {
        print("Upscale button tapped.")
        
        
        // Check if the UIImage has a valid CGImage.
        if image.cgImage == nil {
            print("Warning: The input UIImage does not have a cgImage.")
        } else {
            print("cgImage is available. Image size: \(image.size)")
        }
                
        // Resize the image to 256x256 (logical size), forcing a scale of 1.0.
        guard let resizedImage = image.resized(to: CGSize(width: 256, height: 256)) else {
            print("Failed to resize input image to target size: 256x256.")
            playingGlossAnim = false
            return
        }
        print("Resized image to 256x256.")
        
        // Convert the resized UIImage to a CVPixelBuffer.
        guard let pixelBuffer = resizedImage.toCVPixelBuffer() else {
            print("Failed to convert resized UIImage to CVPixelBuffer.")
            playingGlossAnim = false
            return
        }
        print("Successfully created CVPixelBuffer from the image. Pixel buffer size: \(CVPixelBufferGetWidth(pixelBuffer)) x \(CVPixelBufferGetHeight(pixelBuffer))")
        
        do {
            // MARK: Stage 1 - NAFNet Prediction
            print("Initializing NAFNet model...")
            let config = MLModelConfiguration()
            config.computeUnits = .cpuOnly   // Required for FP32 inference.
            let nafnetModel = try nafnet_reds_64_fp8(configuration: config)
            print("NAFNet model initialized successfully. Running prediction...")
            
            let nafnetPrediction = try nafnetModel.prediction(image: pixelBuffer)
            print("NAFNet prediction complete.")
            
            // Convert NAFNet output (MLMultiArray) to UIImage.
            guard let nafnetPB = mlMultiArrayToPixelBuffer(nafnetPrediction.result),
                  let nafnetOutputImage = UIImage(pixelBuffer: nafnetPB) else {
                print("Failed to convert NAFNet prediction output to UIImage.")
                playingGlossAnim = false
                return
            }
            print("NAFNet output converted to UIImage.")
            
            let realsrganInputSize = CGSize(width: 512, height: 512)
            guard let realsrganInputImage = nafnetOutputImage.resized(to: realsrganInputSize) else {
                print("Failed to resize NAFNet output to 512x512 for RealESRGAN512.")
                playingGlossAnim = false
                return
            }
            print("Resized NAFNet output to 512x512 for RealESRGAN512.")
            
//             self.image = nafnetOutputImage.resized(to: image.size) ?? self.image
//             playingGlossAnim = false
//            return
            
            // MARK: Stage 2 - RealESRGAN512 Prediction
            // Convert the NAFNet output image to a CVPixelBuffer for RealESRGAN512 input.
            guard let realsrganInputBuffer = realsrganInputImage.toCVPixelBuffer() else {
                print("Failed to convert NAFNet output UIImage to CVPixelBuffer for RealESRGAN512.")
                playingGlossAnim = false
                return
            }
            print("Converted NAFNet output to CVPixelBuffer for RealESRGAN512 input.")
            
            print("Initializing RealESRGAN512 model...")
            let realsrganModel = try realesrgan512(configuration: config)
            print("RealESRGAN512 model initialized successfully. Running prediction...")
            
            let realsrganPrediction = try realsrganModel.prediction(input: realsrganInputBuffer)
            print("RealESRGAN512 prediction complete.")
            
            // Convert RealESRGAN512 output (MLMultiArray) to UIImage.
            if let finalUpscaledImage = UIImage(pixelBuffer: realsrganPrediction.activation_out) {
                print("Successfully converted RealESRGAN512 output to UIImage.")
                
                // Optionally, resize the final image back to your original image size.
                if let finalImage = finalUpscaledImage.resized(to: image.size) {
                    print("Resized final upscaled image to original size: \(image.size)")
                    finishGloss {
                        self.image = finalImage
                        print("Image updated with final upscaled version.")
                    }
                } else {
                    print("Failed to resize final upscaled image to original size.")
                    playingGlossAnim = false
                }
            } else {
                print("Failed to convert RealESRGAN512 prediction output to UIImage.")
                playingGlossAnim = false
            }
        } catch {
            print("Upscaling failed with error: \(error)")
            playingGlossAnim = false
        }
    }
}

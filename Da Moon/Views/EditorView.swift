//
//  EditorView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI
import CoreML

let BOTTOM_BAR_PADDING: CGFloat = 18

struct EditorView: View {
    @State var image: UIImage
    @State var subject: UIImage?
    
    @State var findingSubject: Bool = false
    
    var body: some View {
        ZStack {
            ZoomableView {
                Image(uiImage: image)
                    .resizable()
                    .opacity(subject == nil ? 1.0 : 0.2)
                    .shine(findingSubject)
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
                        if !findingSubject {
                            findingSubject = true
                            Task {
                                subject = nil
                                subject = await getSubject(from: image)
                                if subject == nil {
                                    UIApplication.shared.alert(title: "Failed to find subject", body: "No subject could be found in the image!")
                                }
                                findingSubject = false
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
                        // TODO: Finalize and Upscale button
                    }) {
                        Image(systemName: "photo.badge.checkmark")
                    }
                }
            }
        }
    }
    func finalizeAndUpscale() {
        print("Upscale button tapped.")
        
        guard let inputImage = image else {
            print("No image available.")
            return
        }
        
        // Check if the UIImage has a valid CGImage.
        if inputImage.cgImage == nil {
            print("Warning: The input UIImage does not have a cgImage.")
        } else {
            print("cgImage is available. Image size: \(inputImage.size)")
        }
        
        // Resize the image to 512x512 (logical size), forcing a scale of 1.0.
        guard let resizedImage = inputImage.resized(to: CGSize(width: 512, height: 512)) else {
            print("Failed to resize input image to 512x512.")
            return
        }
        print("Resized image to 512x512.")
        
        // Convert the resized UIImage to a CVPixelBuffer.
        guard let pixelBuffer = resizedImage.toCVPixelBuffer() else {
            print("Failed to convert resized UIImage to CVPixelBuffer.")
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
                DispatchQueue.main.async {
                    self.image = upscaledImage
                    print("Image updated with upscaled version.")
                }
            } else {
                print("Failed to convert prediction output to UIImage.")
            }
        } catch {
            print("Upscaling failed with error: \(error)")
        }
    }
}
extension UIImage {
    /// Resizes the image to the specified size with a forced scale of 1.0.
    func resized(to size: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // Force scale to 1.0 so the underlying pixels match the target size
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Converts UIImage to a CVPixelBuffer.
    func toCVPixelBuffer() -> CVPixelBuffer? {
        guard let cgImage = self.cgImage else {
            print("No CGImage available in UIImage")
            return nil
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                         kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        if status != kCVReturnSuccess {
            print("CVPixelBufferCreate failed with status: \(status)")
            return nil
        }
        guard let buffer = pixelBuffer else {
            print("CVPixelBuffer is nil")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        if let pixelData = CVPixelBufferGetBaseAddress(buffer) {
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            // Using CGImageAlphaInfo.noneSkipFirst for input conversion
            if let context = CGContext(data: pixelData,
                                       width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                       space: rgbColorSpace,
                                       bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            } else {
                print("Failed to create CGContext")
                CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
                return nil
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        return buffer
    }
    
    /// Initializes a UIImage from a CVPixelBuffer using updated bitmap info for proper color mapping.
    convenience init?(pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // Updated bitmap info: using byteOrder32Little and premultipliedFirst to correctly interpret BGRA
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        
        guard let context = CGContext(data: baseAddress,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo),
              let cgImage = context.makeImage() else {
            return nil
        }
        self.init(cgImage: cgImage)
    }
}

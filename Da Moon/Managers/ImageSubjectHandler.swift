//
//  ImageSubjectHandler.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import UIKit
import Vision
import VisionKit

@MainActor func getSubject(from image: UIImage) async -> UIImage? {
    let analyser = ImageAnalyzer()
    let interaction = ImageAnalysisInteraction()
    let configuration = ImageAnalyzer.Configuration([.text, .visualLookUp, .machineReadableCode])
    let analysis = try? await analyser.analyze(image, configuration: configuration)
    interaction.analysis = analysis
    return try? await interaction.image(for: interaction.subjects)
}

func maskSubject(from image: UIImage) async throws -> UIImage? {
    guard let cgImage = image.cgImage else { throw MaskingError.cgImage }
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage)
    try handler.perform([request])
    guard let result = request.results?.first else { throw MaskingError.noSubjects }
    let output = try result.generateMaskedImage(
      ofInstances: result.allInstances,
      from: handler,
      croppedToInstancesExtent: false)
    
    // convert the final image to a UIImage
    return UIImage(pixelBuffer: output, scale: image.scale, orientation: image.imageOrientation)
}

func finalizeAndUpscale(image: UIImage) async -> UIImage? {
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
        return nil
    }
    print("Resized image to 512x512.")
    
    // Convert the resized UIImage to a CVPixelBuffer.
    guard let pixelBuffer = resizedImage.toCVPixelBuffer() else {
        print("Failed to convert resized UIImage to CVPixelBuffer.")
        return nil
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
                return finalImage
            } else {
                print("Failed to resize upscaled image to original size.")
                return nil
            }
        } else {
            print("Failed to convert prediction output to UIImage.")
            return nil
        }

    } catch {
        print("Upscaling failed with error: \(error)")
        return nil
    }
}

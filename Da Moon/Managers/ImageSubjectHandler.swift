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
//
//func maskSubject(from image: UIImage) async throws -> UIImage? {
//    guard let cgImage = image.cgImage else { throw MaskingError.cgImage }
//    let request = VNGenerateForegroundInstanceMaskRequest()
//    let handler = VNImageRequestHandler(cgImage: cgImage)
//    try handler.perform([request])
//    guard let result = request.results?.first else { throw MaskingError.noSubjects }
//    let output = try result.generateMaskedImage(
//      ofInstances: result.allInstances,
//      from: handler,
//      croppedToInstancesExtent: true)
//    
//    // convert the final image to a UIImage
//    return UIImage(pixelBuffer: output, scale: image.scale, orientation: image.imageOrientation)
//}

func maskSubject(from image: UIImage) async throws -> UIImage? {
    // Ensure we have a valid CGImage.
    guard let cgImage = image.cgImage else { throw MaskingError.cgImage }
    
    // Create and perform the mask request.
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage)
    try handler.perform([request])
    
    // Get the result from the request.
    guard let result = request.results?.first as? VNForegroundInstanceMaskObservation else {
        throw MaskingError.noSubjects
    }
    
    // Get the indices of all detected instances.
    let instanceIndices = result.allInstances
    guard !instanceIndices.isEmpty else { throw MaskingError.noSubjects }
    
    // Iterate over the instance indices to select the one with the largest area.
    var primaryIndex: Int = instanceIndices.first!
    var maxArea: CGFloat = 0.0
    
    for index in instanceIndices {
        let box = result.boundingBox(for: index)
        let area = box.width * box.height
        if area > maxArea {
            primaryIndex = index
            maxArea = area
        }
    }
    
    // Create an IndexSet with only the primary instance.
    let primaryInstanceIndexSet = IndexSet(integer: primaryIndex)
    
    // Generate the masked image using only the primary instance and crop it.
    let output = try result.generateMaskedImage(
        ofInstances: primaryInstanceIndexSet,
        from: handler,
        croppedToInstancesExtent: true)
    
    // Convert the pixel buffer output to a UIImage.
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

func finalizeAndUpscaleServer(image: UIImage) async -> UIImage? {
    // Convert the image to a base64 string.
    guard let base64Image = image.jpegBase64() else {
        print("Failed to convert image to base64.")
        return nil
    }
    
    // Construct the JSON payload.
    let jsonPayload: [String: Any] = ["image": base64Image]
    
    guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonPayload) else {
        print("Failed to serialize JSON payload.")
        return nil
    }
    
    // Replace the string below with your actual server URL.
    guard let url = URL(string: "https://your.server.endpoint/api/upscale") else {
        print("Invalid URL.")
        return nil
    }
    
    // Create the POST request.
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData
    
    do {
        // Send the request and await the response.
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Optionally, check the response status code.
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            print("Server returned status code: \(httpResponse.statusCode)")
            return nil
        }
        
        // Parse the JSON response.
        if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let upscaledBase64 = jsonResponse["upscaledImage"] as? String,
           let upscaledImage = UIImage(base64: upscaledBase64) {
            return upscaledImage
        } else {
            print("Failed to parse JSON response or convert base64 to image.")
            return nil
        }
    } catch {
        print("Error during network request: \(error)")
        return nil
    }
}

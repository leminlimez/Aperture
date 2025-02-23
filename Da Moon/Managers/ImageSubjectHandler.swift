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

func createMultipartBody(with imageData: Data, boundary: String) -> Data {
    var body = Data()
    let lineBreak = "\r\n"
    // Append the image data as a form field, "file" is the field name
    body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\(lineBreak)".data(using: .utf8)!)
    body.append("Content-Type: image/jpeg\(lineBreak + lineBreak)".data(using: .utf8)!)
    body.append(imageData)
    body.append("\(lineBreak)".data(using: .utf8)!)
    body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
    return body
}


func finalizeAndUpscaleServer(image: UIImage) async -> UIImage? {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        print("Failed to convert image to JPEG data.")
        return nil
    }
    
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
    guard let url = URL(string: "https://4e52-128-211-155-43.ngrok-free.app/run_inference") else {
        print("Invalid URL.")
        return nil
    }
    
    guard let apiKey = ProcessInfo.processInfo.environment["API_SERVER_KEY"] else {
        print("API key not found in environment variables.")
        return nil
    }
    print(apiKey)
    
    // Create the POST request.
    var request = URLRequest(url: url)
    request.timeoutInterval = 20
    request.httpMethod = "POST"
    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    let body = createMultipartBody(with: imageData, boundary: boundary)
    request.httpBody = body
        
    print("Sending request with binary image data, size: \(body.count) bytes")
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            print("Server returned status code: \(httpResponse.statusCode)")
            if let errorMessage = String(data: data, encoding: .utf8) {
                print("Error message from server: \(errorMessage)")
            } else {
                print("No error message available.")
            }
            return nil
        }
        
        // Parse the JSON response.
        if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let upscaledBase64 = jsonResponse["deblurred_img"] as? String,
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

func combinedUpscale(image: UIImage) async -> UIImage? {
    let localOnly = UserDefaults.standard.bool(forKey: "useLocalOnly")
    
    // Try to get the upscaled image from the server.
    if !localOnly, let serverUpscaled = await finalizeAndUpscaleServer(image: image) {
        return serverUpscaled
    } else {
        if !localOnly {
            // Notify the user on the main thread.
            DispatchQueue.main.async {
                UIApplication.shared.alert(title: "Notice", body: "Server unreachable. Using local upscaling instead.")
            }
        }
        // Fall back to local upscaling.
        return await finalizeAndUpscale(image: image)
    }
}

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

@MainActor func maskSubject(from image: UIImage) async throws -> UIImage? {
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

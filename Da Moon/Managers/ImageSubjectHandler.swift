//
//  ImageSubjectHandler.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import UIKit
import VisionKit

@MainActor func getSubject(from image: UIImage) async -> UIImage? {
    let analyser = ImageAnalyzer()
    let interaction = ImageAnalysisInteraction()
    let configuration = ImageAnalyzer.Configuration([.text, .visualLookUp, .machineReadableCode])
    let analysis = try? await analyser.analyze(image, configuration: configuration)
    interaction.analysis = analysis
    return try? await interaction.image(for: interaction.subjects)
}

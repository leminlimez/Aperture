//
//  OCRViewModel.swift
//  Da Moon
//
//  Created by lemin on 2/22/25.
//

import SwiftUI
import Vision

@Observable
class OCR {
    /// The array of `RecognizedTextObservation` objects to hold the request's results.
    var observations = [RecognizedTextObservation]()
    var showObservations: Bool = false
    
    /// The Vision request.
    var request = RecognizeTextRequest()
    
    func performOCR(imageData: Data) async throws {
        /// Clear the `observations` array for photo recapture.
        observations.removeAll()
        
        /// Perform the request on the image data and return the results.
        let results = try await request.perform(on: imageData)
        
        /// Add each observation to the `observations` array.
        for observation in results {
            observations.append(observation)
        }
    }
}

//
//  MaskingError.swift
//  Da Moon
//
//  Created by lemin on 2/22/25.
//

import Foundation

enum MaskingError: LocalizedError {
    // Throw when cg image cannot be created
    case cgImage
    
    // Throw when image cannot be converted to data
    case noData
    
    // Throw when no subjects are found
    case noSubjects
    
    // Throw when no text is found
    case noText
    
    // Throw in all other cases
    case unexpected(code: Int)
    
    public var errorDescription: String? {
        switch self {
        case .cgImage:
            return "Failed to convert UIImage to CGImage."
        case .noData:
            return "Failed to convert UIImage to png data."
        case .noSubjects:
            return "No subjects were found in the photo."
        case .noText:
            return "No text was found in the image."
        case .unexpected(_):
            return "An unexpected error occurred."
        }
    }
}

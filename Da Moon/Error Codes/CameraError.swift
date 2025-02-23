//
//  CameraError.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import Foundation

enum CameraError: LocalizedError {
    // Throw when no cameras could be found
    case notFound
    
    // Throw in all other cases
    case unexpected(code: Int)
    
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "No cameras were found on the device."
        case .unexpected(_):
            return "An unexpected error occurred."
        }
    }
}

//
//  UIImage++.swift
//  Da Moon
//
//  Created by lemin on 2/22/25.
//

import SwiftUI

extension UIImage {
    // MARK: Resizing
    /// Resizes the image to the specified size with a forced scale of 1.0.
    func resized(to size: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // Force scale to 1.0 so the underlying pixels match the target size
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    // MARK: Cropping
    func cropImage(to rect: CGRect) -> UIImage? {
        guard let cg = cgImage else { return nil }
        guard let croppedCGImage = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: croppedCGImage, scale: scale, orientation: imageOrientation)
    }
    
    // MARK: CVPixelBuffer Operations
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
    
    func jpegBase64(compressionQuality: CGFloat = 1.0) -> String? {
        guard let jpegData = self.jpegData(compressionQuality: compressionQuality) else { return nil }
        return jpegData.base64EncodedString()
    }
        
    /// Initialize UIImage from a Base64 encoded string.
    convenience init?(base64: String) {
        guard let data = Data(base64Encoded: base64) else { return nil }
        self.init(data: data)
    }
    
    /// Initializes a UIImage from a CVPixelBuffer using updated bitmap info for proper color mapping.
    convenience init?(pixelBuffer: CVPixelBuffer, scale: CGFloat? = nil, orientation: UIImage.Orientation? = nil) {
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
        if let scale = scale, let orientation = orientation {
            self.init(cgImage: cgImage, scale: scale, orientation: orientation)
        } else {
            self.init(cgImage: cgImage)
        }
    }
}

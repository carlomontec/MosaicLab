import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public struct SourceImageCandidate: Sendable {
    public let identifier: String
    public let url: URL
    public let thumbnailPixels: Data // 16x16 RGBA (1024 bytes)
    public let edgeDescriptor: MosaicEdgeDescriptor
    public let meanR: Float
    public let meanG: Float
    public let meanB: Float
    
    public init(identifier: String, url: URL, thumbnailPixels: Data, edgeDescriptor: MosaicEdgeDescriptor? = nil) {
        self.identifier = identifier
        self.url = url
        self.thumbnailPixels = thumbnailPixels
        
        var sumR: Float = 0
        var sumG: Float = 0
        var sumB: Float = 0
        let count = 256
        
        thumbnailPixels.withUnsafeBytes { ptr in
            if let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                for i in 0..<count {
                    let off = i * 4
                    sumR += Float(base[off])
                    sumG += Float(base[off + 1])
                    sumB += Float(base[off + 2])
                }
            }
        }
        let invCount = 1.0 / Float(count)
        self.meanR = sumR * invCount
        self.meanG = sumG * invCount
        self.meanB = sumB * invCount
        
        if let ed = edgeDescriptor {
            self.edgeDescriptor = ed
        } else {
            self.edgeDescriptor = thumbnailPixels.withUnsafeBytes { ptr -> MosaicEdgeDescriptor in
                guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return MosaicEdgeDescriptor()
                }
                return MacOSaiXComputeEdgeDescriptor(base, 16, 16)
            }
        }
    }
}

public final class ImageLoader: @unchecked Sendable {
    private let supportedExtensions: Set<String> = [
        "heic", "heif", "hif", "avif", "jpg", "jpeg", "png", "tiff", "tif", "webp", "bmp", "gif"
    ]
    
    public init() {}
    
    /// Finds all image URLs in the given directory recursively.
    public func findImages(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        
        var urls: [URL] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                urls.append(fileURL)
            }
        }
        return urls
    }
    
    /// Loads a 16x16 RGBA thumbnail from an image URL (including HEIC) using ImageIO.
    public func loadThumbnail(from url: URL, targetSize: Int = 16) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else {
            return nil
        }
        
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: targetSize,
            kCGImageSourceCreateThumbnailWithTransform: true, // Auto-rotate for HEIC / EXIF orientation!
            kCGImageSourceShouldCacheImmediately: true
        ]
        
        guard let thumbImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return nil
        }
        
        return extractRGBABytes(from: thumbImage, width: targetSize, height: targetSize)
    }
    
    private func extractRGBABytes(from cgImage: CGImage, width: Int, height: Int) -> Data? {
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return Data(buffer)
    }
}

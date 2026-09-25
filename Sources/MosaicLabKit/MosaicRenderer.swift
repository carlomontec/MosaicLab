import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public final class MosaicRenderer {
    public init() {}
    
    public func render(
        tiles: [MosaicTile],
        mosaicSize: CGSize,
        outputWidth: Int,
        strokeWidth: Float = 0.0,
        strokeColor: String = "black",
        colorTransferStrength: Float = 0.0,
        isMonochrome: Bool = false,
        outputURL: URL
    ) throws {
        let scale = CGFloat(outputWidth) / mosaicSize.width
        let outputHeight = max(1, Int(mosaicSize.height * scale))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = outputWidth * 4
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw NSError(domain: "MosaicRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext"])
        }
        
        // High quality interpolation
        context.interpolationQuality = .high
        
        // Clear to transparent/black
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
        
        // Transform context from mosaic coordinate space to output pixel space, with (0,0) at top-left
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(outputHeight))
        context.scaleBy(x: scale, y: -scale)
        
        // Render each tile with bounded memory footprint
        for tile in tiles {
            autoreleasepool {
                context.saveGState()
                
                // Clip to tile's exact vector outline
                context.addPath(tile.geometry.outline)
                context.clip()
                
                if let imageURL = tile.bestImageURL {
                    let bounds = tile.geometry.bounds
                    let targetPixelDim = max(16, Int(max(bounds.width, bounds.height) * scale * 1.5))
                    
                    var img: CGImage? = nil
                    if imageURL.scheme == "applephotos" {
                        if let comps = URLComponents(url: imageURL, resolvingAgainstBaseURL: false),
                           let idItem = comps.queryItems?.first(where: { $0.name == "id" })?.value {
                            img = ApplePhotosSource.shared.cachedDisplayThumbnail(byIdentifier: idItem, maxPixelSize: targetPixelDim)
                        }
                    } else {
                        let opts: [CFString: Any] = [
                            kCGImageSourceShouldCache: false
                        ]
                        if let src = CGImageSourceCreateWithURL(imageURL as CFURL, opts as CFDictionary) {
                            let drawOpts: [CFString: Any] = [
                                kCGImageSourceCreateThumbnailFromImageAlways: true,
                                kCGImageSourceThumbnailMaxPixelSize: targetPixelDim,
                                kCGImageSourceCreateThumbnailWithTransform: true,
                                kCGImageSourceShouldCacheImmediately: true
                            ]
                            img = CGImageSourceCreateThumbnailAtIndex(src, 0, drawOpts as CFDictionary)
                        }
                    }
                    
                    if var cgImage = img {
                        if colorTransferStrength > 0.001 {
                            cgImage = ColorTransfer.applyColorTransfer(
                                to: cgImage,
                                targetStats: tile.targetColorStatistics,
                                strength: colorTransferStrength
                            )
                        }
                        
                        if isMonochrome {
                            cgImage = ColorTransfer.convertToMonochrome(cgImage)
                        }
                        
                        let imgW = CGFloat(cgImage.width)
                        let imgH = CGFloat(cgImage.height)
                        let fillScale = max(bounds.width / imgW, bounds.height / imgH)
                        let drawW = imgW * fillScale
                        let drawH = imgH * fillScale
                        let drawX = bounds.midX - drawW / 2.0
                        let drawY = bounds.midY - drawH / 2.0
                        
                        // Draw upright inside flipped context
                        context.saveGState()
                        context.translateBy(x: drawX, y: drawY + drawH)
                        context.scaleBy(x: 1.0, y: -1.0)
                        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: drawW, height: drawH))
                        context.restoreGState()
                    }
                } else {
                    // Fallback fill
                    context.setFillColor(CGColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0))
                    context.fill(tile.geometry.bounds)
                }
                
                context.restoreGState()
                
                // Optional outline stroke around tile borders
                if strokeWidth > 0.001 {
                    context.saveGState()
                    let isWhiteStroke = (strokeColor == "white")
                    let strokeCol = isWhiteStroke ?
                        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.6) :
                        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.35)
                    context.setStrokeColor(strokeCol)
                    context.setLineWidth(CGFloat(strokeWidth) / scale)
                    context.addPath(tile.geometry.outline)
                    context.strokePath()
                    context.restoreGState()
                }
            }
        }
        
        context.restoreGState()
        
        // Export to disk via CGImageDestination
        guard let finalCGImage = context.makeImage() else {
            throw NSError(domain: "MosaicRenderer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to generate final image from context"])
        }
        
        let ext = outputURL.pathExtension.lowercased()
        let uti: CFString
        switch ext {
        case "heic", "heif":
            uti = "public.heic" as CFString
        case "avif":
            uti = "public.avif" as CFString
        case "jpg", "jpeg":
            uti = UTType.jpeg.identifier as CFString
        default:
            uti = UTType.png.identifier as CFString
        }
        
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, uti, 1, nil) else {
            throw NSError(domain: "MosaicRenderer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination for \(ext.uppercased()) at \(outputURL.path)"])
        }
        
        let exportProperties: [CFString: Any]
        if ext == "png" {
            exportProperties = [:]
        } else {
            exportProperties = [
                kCGImageDestinationLossyCompressionQuality: 0.92
            ]
        }
        
        CGImageDestinationAddImage(destination, finalCGImage, exportProperties as CFDictionary)
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "MosaicRenderer", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to write image to \(outputURL.path)"])
        }
    }
    
    /// Quickly renders a preview mosaic into an in-memory CGImage (e.g. for QuickLook or UI previews).
    public func renderToImage(
        tiles: [MosaicTile],
        mosaicSize: CGSize,
        outputWidth: Int = 1280,
        strokeWidth: Float = 0.0,
        strokeColor: String = "black",
        colorTransferStrength: Float = 0.0,
        isMonochrome: Bool = false
    ) -> CGImage? {
        guard mosaicSize.width > 0, mosaicSize.height > 0 else { return nil }
        let scale = CGFloat(outputWidth) / mosaicSize.width
        let outputHeight = max(1, Int(mosaicSize.height * scale))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = outputWidth * 4
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        context.interpolationQuality = .high
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
        
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(outputHeight))
        context.scaleBy(x: scale, y: -scale)
        
        let transferStrength = colorTransferStrength
        let strokeW = CGFloat(strokeWidth)
        let strokeLineWidth = (scale > 0.0) ? strokeW / scale : strokeW
        
        for tile in tiles {
            context.saveGState()
            context.addPath(tile.geometry.outline)
            context.clip()
            
            if let imageURL = tile.bestImageURL {
                let bounds = tile.geometry.bounds
                let targetStats = (transferStrength > 0.001) ? tile.targetColorStatistics : nil
                if let cgImg = MosaicThumbnailCache.shared.thumbnail(
                    for: imageURL,
                    targetStats: targetStats,
                    colorTransferStrength: transferStrength,
                    isMonochrome: isMonochrome,
                    maxPixelSize: 128
                ) {
                    let imgW = CGFloat(cgImg.width)
                    let imgH = CGFloat(cgImg.height)
                    let fillScale = max(bounds.width / imgW, bounds.height / imgH)
                    let drawW = imgW * fillScale
                    let drawH = imgH * fillScale
                    let drawX = bounds.midX - drawW / 2.0
                    let drawY = bounds.midY - drawH / 2.0
                    
                    context.saveGState()
                    context.translateBy(x: drawX, y: drawY + drawH)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.draw(cgImg, in: CGRect(x: 0, y: 0, width: drawW, height: drawH))
                    context.restoreGState()
                }
            }
            context.restoreGState()
            
            if strokeW > 0.01 {
                context.saveGState()
                let strokeCol = (strokeColor == "white") ?
                    CGColor(red: 1, green: 1, blue: 1, alpha: 0.6) :
                    CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
                context.setStrokeColor(strokeCol)
                context.setLineWidth(strokeLineWidth)
                context.addPath(tile.geometry.outline)
                context.strokePath()
                context.restoreGState()
            }
        }
        
        context.restoreGState()
        return context.makeImage()
    }
}

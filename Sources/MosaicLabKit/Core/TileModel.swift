import Foundation
import CoreGraphics

public final class MosaicTile: @unchecked Sendable {
    public let geometry: MosaicTileGeometry
    public private(set) var targetPixels: Data?
    public private(set) var maskPixels: Data?
    public private(set) var edgeDescriptor: MosaicEdgeDescriptor
    
    public var bestScore: Float = 1.0
    public var bestImageIdentifier: String?
    public var bestImageURL: URL?
    
    public init(geometry: MosaicTileGeometry) {
        self.geometry = geometry
        self.bestScore = 1.0
        self.bestImageIdentifier = nil
        self.bestImageURL = nil
        self.edgeDescriptor = MosaicEdgeDescriptor()
    }
    
    public func extractTargetThumbnail(from targetImage: CGImage, mosaicSize: CGSize) {
        let size = 16
        let bytesPerRow = size * 4
        var buffer = [UInt8](repeating: 0, count: size * bytesPerRow)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(
            data: &buffer,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: rgbColorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return
        }
        
        context.interpolationQuality = .high
        
        let imgWidth = targetImage.width
        let imgHeight = targetImage.height
        guard imgWidth > 0 && imgHeight > 0 && mosaicSize.width > 0 && mosaicSize.height > 0 else {
            return
        }
        
        let bounds = geometry.bounds
        let scaleX = Double(imgWidth) / Double(mosaicSize.width)
        let scaleY = Double(imgHeight) / Double(mosaicSize.height)
        
        var rawX = Double(bounds.origin.x) * scaleX
        var rawY = Double(bounds.origin.y) * scaleY
        var rawW = Double(bounds.size.width) * scaleX
        var rawH = Double(bounds.size.height) * scaleY
        
        if rawX < 0.0 { rawW += rawX; rawX = 0.0 }
        if rawY < 0.0 { rawH += rawY; rawY = 0.0 }
        if rawX + rawW > Double(imgWidth) { rawW = Double(imgWidth) - rawX }
        if rawY + rawH > Double(imgHeight) { rawH = Double(imgHeight) - rawY }
        
        if rawW > 0.5 && rawH > 0.5 {
            var intX = Int(floor(rawX))
            var intY = Int(floor(rawY))
            var intW = Int(ceil(rawW))
            var intH = Int(ceil(rawH))
            
            if intX >= imgWidth { intX = imgWidth - 1 }
            if intY >= imgHeight { intY = imgHeight - 1 }
            if intX + intW > imgWidth { intW = imgWidth - intX }
            if intY + intH > imgHeight { intH = imgHeight - intY }
            
            if intW > 0 && intH > 0 {
                let cropRect = CGRect(x: intX, y: intY, width: intW, height: intH)
                if let subImage = targetImage.cropping(to: cropRect) {
                    context.draw(subImage, in: CGRect(x: 0, y: 0, width: size, height: size))
                } else {
                    context.draw(targetImage, in: CGRect(x: 0, y: 0, width: size, height: size))
                }
            } else {
                context.draw(targetImage, in: CGRect(x: 0, y: 0, width: size, height: size))
            }
        } else {
            context.draw(targetImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        
        self.targetPixels = Data(buffer)
        buffer.withUnsafeBufferPointer { ptr in
            if let baseAddress = ptr.baseAddress {
                self.edgeDescriptor = MacOSaiXComputeEdgeDescriptor(rgba: baseAddress, width: size, height: size)
            }
        }
    }
    
    public func rasterizeMask(resolution: Int32 = 16) {
        rasterizeMask(withResolution: resolution)
    }
    
    public func rasterizeMask(withResolution resolution: Int32 = 16) {
        let size = Int(resolution > 0 ? resolution : 16)
        let bytesPerRow = size
        var buffer = [UInt8](repeating: 0, count: size * bytesPerRow)
        
        let graySpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &buffer,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: graySpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return
        }
        
        context.setFillColor(gray: 0.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        
        context.setFillColor(gray: 1.0, alpha: 1.0)
        let bounds = geometry.bounds
        if bounds.size.width > 0.001 && bounds.size.height > 0.001 {
            context.scaleBy(x: CGFloat(size) / bounds.size.width, y: CGFloat(size) / bounds.size.height)
            context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
            context.addPath(geometry.outline)
            context.fillPath()
        }
        
        self.maskPixels = Data(buffer)
    }
}

public typealias Tile = MosaicTile

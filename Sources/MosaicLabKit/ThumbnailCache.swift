import Foundation
import CoreGraphics
import ImageIO

/// Thread-safe, memory-bounded cache for tile display thumbnails (256px max dimension for Retina sharpness).
/// Evicts automatically under memory pressure and bounds total RAM footprint.
public final class MosaicThumbnailCache: @unchecked Sendable {
    public static let shared = MosaicThumbnailCache()
    
    private let cache = NSCache<NSURL, CGImage>()
    private let transferredCache = NSCache<NSString, CGImage>()
    private let sourceStatsCache = NSCache<NSURL, ColorStatisticsBox>()
    
    public init() {
        cache.countLimit = 4000
        cache.totalCostLimit = 150 * 1024 * 1024 // 150 MB max RAM
        transferredCache.countLimit = 3000
        transferredCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB max RAM
        sourceStatsCache.countLimit = 4000
    }
    
    public func setThumbnail(_ image: CGImage, for url: URL) {
        let key = url as NSURL
        let cost = image.bytesPerRow * image.height
        cache.setObject(image, forKey: key, cost: cost)
    }
    
    public func thumbnail(for url: URL, maxPixelSize: Int = 256) -> CGImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        // Handle Apple Photos assets
        if url.scheme == "applephotos" {
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let idItem = comps.queryItems?.first(where: { $0.name == "id" })?.value {
                if let thumb = ApplePhotosSource.shared.cachedDisplayThumbnail(byIdentifier: idItem, maxPixelSize: maxPixelSize) {
                    let cost = thumb.bytesPerRow * thumb.height
                    cache.setObject(thumb, forKey: key, cost: cost)
                    return thumb
                }
            }
            return nil
        }
        
        if url.isFileURL {
            let opts: [CFString: Any] = [
                kCGImageSourceShouldCache: false
            ]
            guard let src = CGImageSourceCreateWithURL(url as CFURL, opts as CFDictionary) else {
                return nil
            }
            let thumbOpts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts as CFDictionary) else {
                return nil
            }
            let cost = thumb.bytesPerRow * thumb.height
            cache.setObject(thumb, forKey: key, cost: cost)
            return thumb
        }
        
        return nil
    }
    
    /// Retrieves a tile display thumbnail, optionally applying Reinhard perceptual color transfer.
    public func thumbnail(
        for url: URL,
        targetStats: ColorStatistics?,
        colorTransferStrength: Float,
        isMonochrome: Bool = false,
        maxPixelSize: Int = 256
    ) -> CGImage? {
        guard let base = thumbnail(for: url, maxPixelSize: maxPixelSize) else {
            return nil
        }
        
        if isMonochrome && (targetStats == nil || colorTransferStrength <= 0.001) {
            let key = "\(url.path)#mono" as NSString
            if let cached = transferredCache.object(forKey: key) {
                return cached
            }
            let mono = ColorTransfer.convertToMonochrome(base)
            let cost = mono.bytesPerRow * mono.height
            transferredCache.setObject(mono, forKey: key, cost: cost)
            return mono
        }
        
        guard let stats = targetStats, colorTransferStrength > 0.001 else {
            return isMonochrome ? ColorTransfer.convertToMonochrome(base) : base
        }
        
        // Quantize strength to 5% intervals to maximize cache hits while dragging the slider
        let quantizedPct = Int(round(colorTransferStrength * 20.0)) * 5
        let monoSuffix = isMonochrome ? "#mono" : ""
        let key = "\(url.path)#\(Int(stats.meanL * 1000))_\(Int(stats.meanA * 1000))_\(Int(stats.meanB * 1000))#\(quantizedPct)\(monoSuffix)" as NSString
        if let cached = transferredCache.object(forKey: key) {
            return cached
        }
        
        // Fetch or lazily compute and cache candidate's own source color statistics
        let urlKey = url as NSURL
        let srcStats: ColorStatistics
        if let cachedStats = sourceStatsCache.object(forKey: urlKey) {
            srcStats = cachedStats.value
        } else {
            srcStats = ColorTransfer.computeStatistics(from: base)
            sourceStatsCache.setObject(ColorStatisticsBox(srcStats), forKey: urlKey)
        }
        
        var effectiveStats = stats
        if isMonochrome {
            effectiveStats = ColorStatistics(meanL: stats.meanL, meanA: 0.0, meanB: 0.0, stdL: stats.stdL, stdA: 0.001, stdB: 0.001)
        }
        
        var transferred = ColorTransfer.applyColorTransfer(
            to: base,
            sourceStats: srcStats,
            targetStats: effectiveStats,
            strength: Float(quantizedPct) / 100.0
        )
        if isMonochrome {
            transferred = ColorTransfer.convertToMonochrome(transferred)
        }
        let cost = transferred.bytesPerRow * transferred.height
        transferredCache.setObject(transferred, forKey: key, cost: cost)
        return transferred
    }
    
    public func preheatThumbnail(for url: URL, maxPixelSize: Int = 256) {
        _ = thumbnail(for: url, maxPixelSize: maxPixelSize)
    }
    
    public func clear() {
        cache.removeAllObjects()
        transferredCache.removeAllObjects()
        sourceStatsCache.removeAllObjects()
    }
}

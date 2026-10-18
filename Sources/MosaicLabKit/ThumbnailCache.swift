import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

/// Thread-safe, memory-bounded, two-tier cache for tile display thumbnails (256px max dimension for Retina sharpness).
/// L1 RAM: Fast NSCache (evicts under memory pressure).
/// L2 Disk: Persistent JPEG storage in ~/Library/Caches/com.carlomontec.mosaiclab/thumbnails/ for instant restart redraws.
public final class MosaicThumbnailCache: @unchecked Sendable {
    public static let shared = MosaicThumbnailCache()
    
    private let cache = NSCache<NSString, CGImage>()
    private let transferredCache = NSCache<NSString, CGImage>()
    private let sourceStatsCache = NSCache<NSString, ColorStatisticsBox>()
    
    public let diskCacheURL: URL
    private let fileManager = FileManager.default
    
    public init() {
        cache.countLimit = 10000
        cache.totalCostLimit = 512 * 1024 * 1024 // 512 MB max RAM (safe for 16 GB M3)
        transferredCache.countLimit = 8000
        transferredCache.totalCostLimit = 256 * 1024 * 1024 // 256 MB max RAM
        sourceStatsCache.countLimit = 10000
        
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskCacheURL = caches.appendingPathComponent("com.carlomontec.mosaiclab/thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    private func cacheKey(for url: URL) -> NSString {
        if url.isFileURL {
            return url.standardizedFileURL.path as NSString
        }
        return url.absoluteString as NSString
    }
    
    private func diskKey(for url: URL, maxPixelSize: Int) -> String {
        let rawKey = "\(cacheKey(for: url))_\(maxPixelSize)"
        let digest = SHA256.hash(data: Data(rawKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func diskFileURL(for url: URL, maxPixelSize: Int) -> URL {
        return diskCacheURL.appendingPathComponent("\(diskKey(for: url, maxPixelSize: maxPixelSize)).jpg")
    }
    
    public func setThumbnail(_ image: CGImage, for url: URL) {
        let key = cacheKey(for: url)
        let cost = image.bytesPerRow * image.height
        cache.setObject(image, forKey: key, cost: cost)
    }
    
    public func thumbnail(for url: URL, maxPixelSize: Int = 256) -> CGImage? {
        let key = cacheKey(for: url)
        
        // 1. L1 RAM Cache (< 0.001 ms)
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        // 2. L2 Persistent Disk Cache (< 0.3 ms for 256px JPEG vs ~30ms cold RAW/HEIC decode)
        let diskFile = diskFileURL(for: url, maxPixelSize: maxPixelSize)
        if fileManager.fileExists(atPath: diskFile.path) {
            let diskOpts: [CFString: Any] = [
                kCGImageSourceShouldCacheImmediately: true
            ]
            if let src = CGImageSourceCreateWithURL(diskFile as CFURL, diskOpts as CFDictionary),
               let thumb = CGImageSourceCreateImageAtIndex(src, 0, diskOpts as CFDictionary) {
                let cost = thumb.bytesPerRow * thumb.height
                cache.setObject(thumb, forKey: key, cost: cost)
                return thumb
            }
        }
        
        // 3. Cold Decode from Source Image
        // Handle Apple Photos assets
        if url.scheme == "applephotos" {
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let idItem = comps.queryItems?.first(where: { $0.name == "id" })?.value {
                if let thumb = ApplePhotosSource.shared.cachedDisplayThumbnail(byIdentifier: idItem, maxPixelSize: maxPixelSize) {
                    let cost = thumb.bytesPerRow * thumb.height
                    cache.setObject(thumb, forKey: key, cost: cost)
                    
                    // Asynchronously persist to disk
                    let targetURL = diskFile
                    Task.detached(priority: .utility) {
                        self.saveJPEG(thumb, to: targetURL)
                    }
                    return thumb
                }
            }
            return nil
        }
        
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
        
        // Asynchronously persist 256px display thumbnail to disk
        let targetURL = diskFile
        Task.detached(priority: .utility) {
            self.saveJPEG(thumb, to: targetURL)
        }
        
        return thumb
    }
    
    private func saveJPEG(_ image: CGImage, to destinationURL: URL) {
        let tempURL = destinationURL.appendingPathExtension("tmp.\(UUID().uuidString)")
        guard let dest = CGImageDestinationCreateWithURL(tempURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.85
        ]
        CGImageDestinationAddImage(dest, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            try? fileManager.removeItem(at: tempURL)
            return
        }
        _ = try? fileManager.replaceItemAt(destinationURL, withItemAt: tempURL)
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
        
        let baseKey = cacheKey(for: url) as String
        if isMonochrome && (targetStats == nil || colorTransferStrength <= 0.001) {
            let key = "\(baseKey)#mono" as NSString
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
        let key = "\(baseKey)#\(Int(stats.meanL * 1000))_\(Int(stats.meanA * 1000))_\(Int(stats.meanB * 1000))#\(quantizedPct)\(monoSuffix)" as NSString
        if let cached = transferredCache.object(forKey: key) {
            return cached
        }
        
        // Fetch or lazily compute and cache candidate's own source color statistics
        let statsKey = baseKey as NSString
        let srcStats: ColorStatistics
        if let cachedStats = sourceStatsCache.object(forKey: statsKey) {
            srcStats = cachedStats.value
        } else {
            srcStats = ColorTransfer.computeStatistics(from: base)
            sourceStatsCache.setObject(ColorStatisticsBox(srcStats), forKey: statsKey)
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
    
    public func clearDisk() {
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    public var diskSizeBytes: Int64 {
        guard let enumerator = fileManager.enumerator(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let size = attrs.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}

import Foundation
import CoreGraphics

/// Central registry managing all local and remote image sources in MosaicLab.
public final class MosaicImageSourceRegistry: @unchecked Sendable {
    public static let shared = MosaicImageSourceRegistry()
    
    private var sources: [String: any MosaicImageSource] = [:]
    private let lock = NSLock()
    
    private init() {
        // Automatically register standard sources
        register(ApplePhotosSource.shared)
        register(WikimediaCommonsSource.shared)
        register(MetMuseumSource.shared)
        register(ArtInstituteChicagoSource.shared)
        register(BHLSource.shared)
        register(ParisMuseesSource.shared)
        register(SmithsonianSource.shared)
    }
    
    /// Register a new image source provider.
    public func register(_ source: any MosaicImageSource) {
        lock.lock()
        defer { lock.unlock() }
        sources[source.id] = source
    }
    
    /// Retrieve an image source by its unique provider identifier.
    public func source(forProviderID providerID: String) -> (any MosaicImageSource)? {
        lock.lock()
        defer { lock.unlock() }
        return sources[providerID]
    }
    
    /// Retrieve an image source capable of handling a given canonical URL.
    public func source(forURL url: URL) -> (any MosaicImageSource)? {
        lock.lock()
        defer { lock.unlock() }
        
        switch url.scheme {
        case "applephotos":
            return sources["apple-photos"]
        case "wikimedia":
            return sources["wikimedia-commons"]
        case "metmuseum":
            return sources["met-museum"]
        case "artic":
            return sources["artic"]
        case "bhl":
            return sources["bhl"]
        case "parismusees":
            return sources["paris-musees"]
        case "smithsonian":
            return sources["smithsonian"]
        case "file":
            return sources["local"]
        default:
            // Check if any source can match by host or prefix
            if let host = url.host {
                if host.contains("wikimedia.org") {
                    return sources["wikimedia-commons"]
                }
                if host.contains("metmuseum.org") {
                    return sources["met-museum"]
                }
                if host.contains("artic.edu") {
                    return sources["artic"]
                }
            }
            return nil
        }
    }
    
    /// Universal candidate thumbnail extraction (16x16 RGBA data) routing to the appropriate provider.
    public func loadCandidateThumbnail(for item: MosaicCandidateItem) async throws -> Data? {
        if let source = source(forProviderID: item.sourceProviderID) {
            return try await source.loadCandidateThumbnail(for: item)
        }
        if let url = item.originalURL, url.isFileURL {
            let loader = ImageLoader()
            return loader.loadThumbnail(from: url, targetSize: 16)
        }
        return nil
    }
    
    /// Universal display thumbnail resolution routing to the appropriate provider.
    public func loadDisplayThumbnail(for item: MosaicCandidateItem, maxPixelSize: Int = 140) async throws -> CGImage? {
        if let source = source(forProviderID: item.sourceProviderID) {
            return try await source.loadDisplayThumbnail(for: item, maxPixelSize: maxPixelSize)
        }
        return nil
    }
    
    /// Universal full-resolution image loading routing to the appropriate provider.
    public func loadFullResolutionImage(for item: MosaicCandidateItem) async throws -> CGImage? {
        if let source = source(forProviderID: item.sourceProviderID) {
            return try await source.loadFullResolutionImage(for: item)
        }
        return nil
    }
}

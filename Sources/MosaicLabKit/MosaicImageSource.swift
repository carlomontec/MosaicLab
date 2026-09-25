import Foundation
import CoreGraphics

/// Identifies an individual image candidate regardless of where it resides.
public struct MosaicCandidateItem: Identifiable, Hashable, Sendable {
    public let id: String                    // Local path, PHAsset identifier, or Google mediaItemId
    public let displayName: String
    public let sourceProviderID: String      // "local", "apple-photos", "google-photos", "onedrive"
    public let originalURL: URL?             // Optional local file URL if available
    
    public init(id: String, displayName: String, sourceProviderID: String, originalURL: URL? = nil) {
        self.id = id
        self.displayName = displayName
        self.sourceProviderID = sourceProviderID
        self.originalURL = originalURL
    }
    
    /// Generates a canonical URL representation for this candidate (e.g., file:// or applephotos://asset?id=...).
    public var canonicalURL: URL {
        if let originalURL = originalURL {
            return originalURL
        }
        if sourceProviderID == "apple-photos" {
            // Encode asset identifier safely into a custom URL
            let encodedID = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
            return URL(string: "applephotos://asset?id=\(encodedID)")!
        }
        return URL(string: "\(sourceProviderID)://item?id=\(id)")!
    }
}

/// Metadata describing a collection / album within a photo provider.
public struct MosaicAlbumItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let count: Int
    public let iconName: String
    
    public init(id: String, title: String, count: Int, iconName: String = "photo.stack") {
        self.id = id
        self.title = title
        self.count = count
        self.iconName = iconName
    }
}

/// Universal abstraction for local, native OS, and cloud photo sources.
public protocol MosaicImageSource: AnyObject, Sendable {
    var id: String { get }
    var displayName: String { get }
    var iconName: String { get }
    var isConfigured: Bool { get }
    
    /// Enumerate all candidate items in the source (or current album).
    func enumerateCandidates(progress: (@Sendable (Int, Int) -> Void)?) async throws -> [MosaicCandidateItem]
    
    /// Extract a 16x16 RGBA thumbnail Data buffer (1024 bytes) for fast candidate matching.
    func loadCandidateThumbnail(for item: MosaicCandidateItem) async throws -> Data?
    
    /// Load a display thumbnail (64-140px) for canvas rendering and tile inspection.
    func loadDisplayThumbnail(for item: MosaicCandidateItem, maxPixelSize: Int) async throws -> CGImage?
    
    /// Load or download full-resolution image when a photo wins a tile on the canvas or during export.
    func loadFullResolutionImage(for item: MosaicCandidateItem) async throws -> CGImage?
}

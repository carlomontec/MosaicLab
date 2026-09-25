import Foundation
import CoreGraphics
import ImageIO

public final class LocalFolderImageSource: MosaicImageSource, @unchecked Sendable {
    public let id: String = "local"
    public let displayName: String = "Local Folders"
    public let iconName: String = "folder"
    
    public var folders: [URL] = []
    private let loader = ImageLoader()
    
    public init(folders: [URL] = []) {
        self.folders = folders
    }
    
    public var isConfigured: Bool {
        return !folders.isEmpty
    }
    
    public func enumerateCandidates(progress: (@Sendable (Int, Int) -> Void)?) async throws -> [MosaicCandidateItem] {
        var items: [MosaicCandidateItem] = []
        var totalImagesFound = 0
        
        for folder in folders {
            let urls = loader.findImages(in: folder)
            for url in urls {
                let item = MosaicCandidateItem(
                    id: url.path,
                    displayName: url.lastPathComponent,
                    sourceProviderID: id,
                    originalURL: url
                )
                items.append(item)
                totalImagesFound += 1
                if totalImagesFound % 200 == 0 {
                    progress?(totalImagesFound, totalImagesFound)
                }
            }
        }
        progress?(totalImagesFound, totalImagesFound)
        return items
    }
    
    public func loadCandidateThumbnail(for item: MosaicCandidateItem) async throws -> Data? {
        guard let url = item.originalURL else { return nil }
        return loader.loadThumbnail(from: url, targetSize: 16)
    }
    
    public func loadDisplayThumbnail(for item: MosaicCandidateItem, maxPixelSize: Int = 140) async throws -> CGImage? {
        guard let url = item.originalURL else { return nil }
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
        return CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts as CFDictionary)
    }
    
    public func loadFullResolutionImage(for item: MosaicCandidateItem) async throws -> CGImage? {
        guard let url = item.originalURL else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, opts as CFDictionary) else {
            return nil
        }
        let loadOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: false,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateImageAtIndex(src, 0, loadOpts as CFDictionary)
    }
}

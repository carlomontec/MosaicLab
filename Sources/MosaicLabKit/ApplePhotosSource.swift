import Foundation
import CoreGraphics
import Photos
import AppKit

public final class ApplePhotosSource: MosaicImageSource, @unchecked Sendable {
    public static let shared = ApplePhotosSource()
    
    public let id: String = "apple-photos"
    public let displayName: String = "Apple Photos"
    public let iconName: String = "photo.stack"
    
    public var selectedAlbumID: String = "all"
    
    // In-memory cache for asset display thumbnails to avoid redundant PhotoKit fetches during canvas drawing
    private let displayThumbCache = NSCache<NSString, CGImage>()
    
    public init() {
        displayThumbCache.countLimit = 5000
        displayThumbCache.totalCostLimit = 150 * 1024 * 1024 // 150 MB
    }
    
    // MARK: - Authorization
    
    public static func authorizationStatus() -> PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    public static func requestAuthorization() async -> PHAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    public var isConfigured: Bool {
        let status = Self.authorizationStatus()
        return status == .authorized || status == .limited
    }
    
    // MARK: - Albums
    
    public func fetchAvailableAlbums() -> [MosaicAlbumItem] {
        guard isConfigured else { return [] }
        
        var albums: [MosaicAlbumItem] = []
        
        // 1. All Photos
        let allOptions = PHFetchOptions()
        allOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let allAssets = PHAsset.fetchAssets(with: allOptions)
        albums.append(MosaicAlbumItem(
            id: "all",
            title: "All Photos",
            count: allAssets.count,
            iconName: "photo.on.rectangle.angled"
        ))
        
        // 2. Favorites Smart Album
        let favCollections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .smartAlbumFavorites,
            options: nil
        )
        if let fav = favCollections.firstObject {
            let favAssets = PHAsset.fetchAssets(in: fav, options: allOptions)
            albums.append(MosaicAlbumItem(
                id: "favorites",
                title: fav.localizedTitle ?? "Favorites",
                count: favAssets.count,
                iconName: "heart.fill"
            ))
        }
        
        // 3. User Albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )
        userAlbums.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: allOptions)
            let title = collection.localizedTitle ?? "Album"
            albums.append(MosaicAlbumItem(
                id: collection.localIdentifier,
                title: title,
                count: assets.count,
                iconName: "folder"
            ))
        }
        
        return albums
    }
    
    // MARK: - Candidate Enumeration
    
    public func enumerateCandidates(progress: (@Sendable (Int, Int) -> Void)? = nil) async throws -> [MosaicCandidateItem] {
        guard isConfigured else { return [] }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult: PHFetchResult<PHAsset>
        if selectedAlbumID == "all" {
            fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        } else if selectedAlbumID == "favorites" {
            let favs = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumFavorites,
                options: nil
            )
            if let fav = favs.firstObject {
                fetchResult = PHAsset.fetchAssets(in: fav, options: fetchOptions)
            } else {
                fetchResult = PHAsset.fetchAssets(with: fetchOptions)
            }
        } else {
            let collections = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [selectedAlbumID],
                options: nil
            )
            if let coll = collections.firstObject {
                fetchResult = PHAsset.fetchAssets(in: coll, options: fetchOptions)
            } else {
                fetchResult = PHAsset.fetchAssets(with: fetchOptions)
            }
        }
        
        let total = fetchResult.count
        var items: [MosaicCandidateItem] = []
        items.reserveCapacity(total)
        
        for i in 0..<total {
            let asset = fetchResult.object(at: i)
            let item = MosaicCandidateItem(
                id: asset.localIdentifier,
                displayName: "Photo \(i + 1)",
                sourceProviderID: id,
                originalURL: nil
            )
            items.append(item)
            
            if (i + 1) % 500 == 0 || i == total - 1 {
                progress?(i + 1, total)
            }
        }
        
        return items
    }
    
    // MARK: - Fast 16x16 Candidate Thumbnail Loading
    
    public func loadCandidateThumbnail(for item: MosaicCandidateItem) async throws -> Data? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [item.id], options: nil)
        guard let asset = assets.firstObject else { return nil }
        
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false // ⚡️ Local thumbnail database only! Zero network traffic!
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 32, height: 32),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // If PhotoKit cancelled or failed, return nil
                guard let nsImage = image else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Convert NSImage to 16x16 RGBA Data
                guard let cgImg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let bytesPerRow = 16 * 4
                guard let ctx = CGContext(
                    data: nil,
                    width: 16,
                    height: 16,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                ) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                ctx.interpolationQuality = .low
                ctx.draw(cgImg, in: CGRect(x: 0, y: 0, width: 16, height: 16))
                
                if let raw = ctx.data {
                    let data = Data(bytes: raw, count: 16 * 16 * 4)
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Display Thumbnail Loading (64px - 140px)
    
    public func loadDisplayThumbnail(for item: MosaicCandidateItem, maxPixelSize: Int = 140) async throws -> CGImage? {
        return try await loadDisplayThumbnail(byIdentifier: item.id, maxPixelSize: maxPixelSize)
    }
    
    public func loadDisplayThumbnail(byIdentifier id: String, maxPixelSize: Int = 140) async throws -> CGImage? {
        let key = "\(id)_\(maxPixelSize)" as NSString
        if let cached = displayThumbCache.object(forKey: key) {
            return cached
        }
        
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject else { return nil }
        
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true // Allow low-res cloud download if local thumbnail missing
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            
            let targetSize = CGSize(width: maxPixelSize, height: maxPixelSize)
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, _ in
                guard let nsImg = image,
                      let cgImg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    continuation.resume(returning: nil)
                    return
                }
                let cost = cgImg.bytesPerRow * cgImg.height
                self?.displayThumbCache.setObject(cgImg, forKey: key, cost: cost)
                continuation.resume(returning: cgImg)
            }
        }
    }
    
    // Synchronous display thumbnail fetch (returns cached version or schedules request)
    public func cachedDisplayThumbnail(byIdentifier id: String, maxPixelSize: Int = 140) -> CGImage? {
        let key = "\(id)_\(maxPixelSize)" as NSString
        if let cached = displayThumbCache.object(forKey: key) {
            return cached
        }
        
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject else { return nil }
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        
        var result: CGImage? = nil
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: maxPixelSize, height: maxPixelSize),
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            guard let nsImg = image,
                  let cgImg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return
            }
            let cost = cgImg.bytesPerRow * cgImg.height
            self?.displayThumbCache.setObject(cgImg, forKey: key, cost: cost)
            result = cgImg
        }
        return result
    }
    
    // MARK: - Full Resolution Loading (Winning Tiles & High-Res Export)
    
    public func loadFullResolutionImage(for item: MosaicCandidateItem) async throws -> CGImage? {
        return try await loadFullResolutionImage(byIdentifier: item.id)
    }
    
    public func loadFullResolutionImage(byIdentifier id: String) async throws -> CGImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject else { return nil }
        
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true // Download full res from iCloud if needed
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, _ in
                guard let nsImg = image,
                      let cgImg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: cgImg)
            }
        }
    }
}

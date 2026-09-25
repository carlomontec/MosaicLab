import Foundation
import CoreGraphics
import ImageIO

public final class MosaicEngine: @unchecked Sendable {
    public let shapeType: MosaicShapeType
    public let tilesAcross: Int
    public let tilesDown: Int
    public let maxReuse: Int
    public let minDistance: Int
    public var metric: MosaicColorMetric
    
    public private(set) var tiles: [MosaicTile] = []
    public private(set) var mosaicSize: CGSize = .zero
    public private(set) var targetImage: CGImage?
    
    /// In-memory cache of tested source candidates (16x16 snippets + edge descriptors).
    /// Memory footprint is only ~1 KB per image (10 MB for 10,000 photos).
    /// Enables instantaneous (<10ms) single-tile recomputation.
    public private(set) var candidateStore: [String: SourceImageCandidate] = [:]
    private let candidateStoreLock = NSLock()
    
    public var isCancelled: Bool = false
    public var isPaused: Bool = false
    public var edgeWeight: Float = 0.0
    public var quadtreeMaxDepth: Int = 3
    public var quadtreeThreshold: Float = 0.15
    public var quadtreeBalanced: Bool = true
    public var quadtreeDetailAlpha: Float = 0.5
    public var quadtreeAlgorithm: MosaicQuadtreeAlgorithm = .juliaRange
    public var quadtreeMinTileDim: Float = 16.0
    
    /// Optional callback called on match updates (for live GUI rendering).
    public var onTileUpdated: ((_ tileIndex: Int) -> Void)?
    
    public init(
        shapeType: MosaicShapeType,
        tilesAcross: Int,
        tilesDown: Int,
        maxReuse: Int = 0,
        minDistance: Int = 0,
        metric: MosaicColorMetric = .riemersma,
        edgeWeight: Float = 0.0,
        quadtreeMaxDepth: Int = 3,
        quadtreeThreshold: Float = 0.15,
        quadtreeBalanced: Bool = true,
        quadtreeDetailAlpha: Float = 0.5,
        quadtreeAlgorithm: MosaicQuadtreeAlgorithm = .juliaRange,
        quadtreeMinTileDim: Float = 16.0
    ) {
        self.shapeType = shapeType
        self.tilesAcross = tilesAcross
        self.tilesDown = tilesDown
        self.maxReuse = maxReuse
        self.minDistance = minDistance
        self.metric = metric
        self.edgeWeight = edgeWeight
        self.quadtreeMaxDepth = quadtreeMaxDepth
        self.quadtreeThreshold = quadtreeThreshold
        self.quadtreeBalanced = quadtreeBalanced
        self.quadtreeDetailAlpha = quadtreeDetailAlpha
        self.quadtreeAlgorithm = quadtreeAlgorithm
        self.quadtreeMinTileDim = quadtreeMinTileDim
    }
    
    /// Loads the target image from a URL and prepares tile geometries, masks, and snippets.
    /// Downsamples images larger than maxDimension (default 2048) to avoid memory spikes and freezes.
    public func prepare(targetURL: URL, maxDimension: Int = 2048) throws {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(targetURL as CFURL, options as CFDictionary) else {
            throw NSError(domain: "MosaicEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open target image: \(targetURL.path)"])
        }
        
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let img = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            throw NSError(domain: "MosaicEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load target image: \(targetURL.path)"])
        }
        
        try prepare(with: img)
    }
    
    /// Normalizes any input CGImage (including 10-bit AVIF, HDR HEIC, IOSurface wrappers)
    /// into a standard 8-bit per channel sRGB in-memory raster CGImage.
    public static func normalizeToStandardSRGB(_ image: CGImage) -> CGImage {
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return image
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
    
    /// Prepares tile geometries, masks, and snippets using an in-memory CGImage.
    public func prepare(
        with image: CGImage,
        progressHandler: ((Double, String) -> Void)? = nil
    ) throws {
        let normalizedImage = Self.normalizeToStandardSRGB(image)
        self.targetImage = normalizedImage
        self.mosaicSize = CGSize(width: normalizedImage.width, height: normalizedImage.height)
        self.isCancelled = false
        self.isPaused = false
        
        progressHandler?(0.1, "Subdividing tile geometries...")
        
        // Generate tile shapes using battle-tested geometry formulas
        let geometries = MosaicShapes.generateShapes(
            for: shapeType,
            targetImage: normalizedImage,
            mosaicSize: mosaicSize,
            across: tilesAcross,
            down: tilesDown,
            maxDepth: quadtreeMaxDepth,
            detailThreshold: quadtreeThreshold,
            balanced: quadtreeBalanced,
            detailAlpha: quadtreeDetailAlpha,
            algorithm: quadtreeAlgorithm,
            minTileDim: quadtreeMinTileDim
        )
        
        progressHandler?(0.35, "Rasterizing masks and metrics for \(geometries.count) tiles in parallel...")
        
        // Build tile objects and extract thumbnails & masks concurrently across CPU cores
        let totalCount = geometries.count
        let mSize = self.mosaicSize
        let tileArray = geometries.map { MosaicTile(geometry: $0) }
        
        DispatchQueue.concurrentPerform(iterations: totalCount) { idx in
            let tile = tileArray[idx]
            tile.rasterizeMask(withResolution: 16)
            tile.extractTargetThumbnail(from: normalizedImage, mosaicSize: mSize)
        }
        
        self.tiles = tileArray
        progressHandler?(1.0, "Generated \(totalCount) tile shapes.")
    }
    
    /// Clears existing match results from all tiles without regenerating geometries.
    public func resetMatches() {
        for tile in tiles {
            tile.bestImageURL = nil
            tile.bestImageIdentifier = nil
            tile.bestScore = 1.0
        }
        candidateStoreLock.lock()
        candidateStore.removeAll()
        candidateStoreLock.unlock()
    }
    
    /// Processes an image candidate and tests it against all tiles. Returns true if any tile was updated.
    @discardableResult
    public func testCandidate(_ candidate: SourceImageCandidate) -> Bool {
        if isCancelled { return false }
        
        registerCandidate(candidate)
        
        let matcher = MosaicMatcher.shared()
        let candidatePixels = (candidate.thumbnailPixels as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        
        // 1. Calculate scores for all tiles
        var candidateScores: [(tileIndex: Int, score: Float)] = []
        candidateScores.reserveCapacity(tiles.count)
        
        for (idx, tile) in tiles.enumerated() {
            guard let targetData = tile.targetPixels, let maskData = tile.maskPixels else {
                continue
            }
            let targetBytes = (targetData as NSData).bytes.assumingMemoryBound(to: UInt8.self)
            let maskBytes = (maskData as NSData).bytes.assumingMemoryBound(to: UInt8.self)
            
            let score = matcher.compareTargetPixels(
                targetBytes,
                targetEdgeDesc: tile.edgeDescriptor,
                candidatePixels: candidatePixels,
                candidateEdgeDesc: candidate.edgeDescriptor,
                maskPixels: maskBytes,
                width: 16,
                height: 16,
                metric: metric,
                edgeWeight: edgeWeight
            )
            
            // Only consider if it beats the current best match
            if score < tile.bestScore {
                candidateScores.append((tileIndex: idx, score: score))
            }
        }
        
        if candidateScores.isEmpty {
            return false
        }
        
        // Sort candidate matches best first (lowest score = best)
        candidateScores.sort { $0.score < $1.score }
        
        var anyUpdated = false
        
        // 2. Assign to tiles respecting constraints
        for match in candidateScores {
            let tile = tiles[match.tileIndex]
            
            // Check reuse count
            if maxReuse > 0 {
                let currentUses = tiles.reduce(0) { count, t in
                    (t.bestImageIdentifier == candidate.identifier) ? count + 1 : count
                }
                if currentUses >= maxReuse {
                    break // Cannot reuse this image anymore
                }
            }
            
            // Check minimum distance constraint
            if minDistance > 0 {
                let gx = tile.geometry.gridX
                let gy = tile.geometry.gridY
                
                let tooClose = tiles.contains { otherTile in
                    guard otherTile.bestImageIdentifier == candidate.identifier else { return false }
                    let dx = otherTile.geometry.gridX - gx
                    let dy = otherTile.geometry.gridY - gy
                    let distSquared = dx * dx + dy * dy
                    return distSquared < (self.minDistance * self.minDistance)
                }
                
                if tooClose {
                    continue // Try next best tile
                }
            }
            
            // Update tile match
            tile.bestScore = match.score
            tile.bestImageIdentifier = candidate.identifier
            tile.bestImageURL = candidate.url
            anyUpdated = true
            
            onTileUpdated?(match.tileIndex)
        }
        
        return anyUpdated
    }
    
    public func registerCandidate(_ candidate: SourceImageCandidate) {
        candidateStoreLock.lock()
        defer { candidateStoreLock.unlock() }
        candidateStore[candidate.identifier] = candidate
    }
    
    private func getCachedCandidates() -> [SourceImageCandidate] {
        candidateStoreLock.lock()
        defer { candidateStoreLock.unlock() }
        return Array(candidateStore.values)
    }
    
    private func isCandidateCached(path: String) -> Bool {
        candidateStoreLock.lock()
        defer { candidateStoreLock.unlock() }
        return candidateStore[path] != nil
    }
    
    /// Finds the best alternative candidate photo for a specific tile, excluding currently assigned or rejected identifiers.
    /// Runs instantaneously (< 10 ms) over in-memory cached candidates.
    public func findSubstitute(
        for tile: MosaicTile,
        candidateURLs: [URL],
        excludedIdentifiers: Set<String>
    ) async -> (url: URL, score: Float)? {
        guard let targetData = tile.targetPixels, let maskData = tile.maskPixels else {
            return nil
        }
        let targetBytes = (targetData as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        let maskBytes = (maskData as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        let matcher = MosaicMatcher.shared()
        
        var bestScore: Float = Float.infinity
        var bestURL: URL? = nil
        var bestID: String? = nil
        
        func evaluateCandidate(cand: SourceImageCandidate) {
            let identifier = cand.identifier
            if excludedIdentifiers.contains(identifier) { return }
            
            // Check max reuse constraint against other tiles
            if self.maxReuse > 0 {
                let uses = self.tiles.reduce(0) { count, t in
                    (t !== tile && t.bestImageIdentifier == identifier) ? count + 1 : count
                }
                if uses >= self.maxReuse { return }
            }
            
            // Check min distance constraint against other tiles
            if self.minDistance > 0 {
                let gx = tile.geometry.gridX
                let gy = tile.geometry.gridY
                let tooClose = self.tiles.contains { otherTile in
                    guard otherTile !== tile, otherTile.bestImageIdentifier == identifier else { return false }
                    let dx = otherTile.geometry.gridX - gx
                    let dy = otherTile.geometry.gridY - gy
                    return (dx * dx + dy * dy) < (self.minDistance * self.minDistance)
                }
                if tooClose { return }
            }
            
            let candidatePixels = (cand.thumbnailPixels as NSData).bytes.assumingMemoryBound(to: UInt8.self)
            let score = matcher.compareTargetPixels(
                targetBytes,
                targetEdgeDesc: tile.edgeDescriptor,
                candidatePixels: candidatePixels,
                candidateEdgeDesc: cand.edgeDescriptor,
                maskPixels: maskBytes,
                width: 16,
                height: 16,
                metric: self.metric,
                edgeWeight: self.edgeWeight
            )
            
            if score < bestScore {
                bestScore = score
                bestURL = cand.url
                bestID = identifier
            }
        }
        
        // 1. FAST PATH: Evaluate all in-memory candidates immediately (< 5 ms)
        let inMemoryCandidates = getCachedCandidates()
        for cand in inMemoryCandidates {
            evaluateCandidate(cand: cand)
        }
        
        // 2. FALLBACK PATH: If candidateStore is empty or has missing URLs, load them
        if bestURL == nil && !candidateURLs.isEmpty {
            let missingURLs = candidateURLs.filter { !isCandidateCached(path: $0.path) }
            
            if !missingURLs.isEmpty {
                let loader = ImageLoader()
                let concurrency = max(16, ProcessInfo.processInfo.activeProcessorCount * 4)
                
                await withTaskGroup(of: SourceImageCandidate?.self) { group in
                    var submitted = 0
                    for url in missingURLs {
                        if submitted >= concurrency {
                            if let cand = await group.next() ?? nil {
                                self.registerCandidate(cand)
                                evaluateCandidate(cand: cand)
                            }
                        }
                        group.addTask {
                            guard let thumbData = loader.loadThumbnail(from: url, targetSize: 16) else { return nil }
                            return SourceImageCandidate(identifier: url.path, url: url, thumbnailPixels: thumbData)
                        }
                        submitted += 1
                    }
                    for await cand in group {
                        if let cand = cand {
                            self.registerCandidate(cand)
                            evaluateCandidate(cand: cand)
                        }
                    }
                }
            }
        }
        
        guard let winnerURL = bestURL, let winnerID = bestID else {
            return nil
        }
        
        tile.bestScore = bestScore
        tile.bestImageIdentifier = winnerID
        tile.bestImageURL = winnerURL
        MosaicThumbnailCache.shared.preheatThumbnail(for: winnerURL, maxPixelSize: 256)
        onTileUpdated?(tile.geometry.tileIndex)
        return (winnerURL, bestScore)
    }
    
    /// Manually assigns an arbitrary image URL to a specific tile, computing its match score.
    public func manuallyAssignImage(from url: URL, to tile: MosaicTile) -> Float? {
        guard let targetData = tile.targetPixels, let maskData = tile.maskPixels else {
            return nil
        }
        let loader = ImageLoader()
        guard let thumbData = loader.loadThumbnail(from: url, targetSize: 16) else {
            return nil
        }
        
        let identifier = url.path
        let cand = SourceImageCandidate(identifier: identifier, url: url, thumbnailPixels: thumbData)
        let candidatePixels = (cand.thumbnailPixels as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        let targetBytes = (targetData as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        let maskBytes = (maskData as NSData).bytes.assumingMemoryBound(to: UInt8.self)
        
        let matcher = MosaicMatcher.shared()
        let score = matcher.compareTargetPixels(
            targetBytes,
            targetEdgeDesc: tile.edgeDescriptor,
            candidatePixels: candidatePixels,
            candidateEdgeDesc: cand.edgeDescriptor,
            maskPixels: maskBytes,
            width: 16,
            height: 16,
            metric: self.metric,
            edgeWeight: self.edgeWeight
        )
        
        tile.bestScore = score
        tile.bestImageIdentifier = identifier
        tile.bestImageURL = url
        MosaicThumbnailCache.shared.preheatThumbnail(for: url, maxPixelSize: 256)
        onTileUpdated?(tile.geometry.tileIndex)
        return score
    }
}

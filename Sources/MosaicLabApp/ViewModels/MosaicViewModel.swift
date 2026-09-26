import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import CoreGraphics
import ImageIO
import Photos
import UserNotifications
import MosaicLabKit
import UniformTypeIdentifiers

public enum ImageSourceMode: String, CaseIterable, Identifiable {
    case localFolders = "Local Folders"
    case applePhotos = "Apple Photos"
    
    public var id: String { rawValue }
    public var iconName: String {
        switch self {
        case .localFolders: return "folder"
        case .applePhotos: return "photo.stack"
        }
    }
}

@MainActor
public final class MosaicViewModel: ObservableObject {
    // MARK: - Target Image State
    @Published public var targetImageURL: URL?
    @Published public var targetCGImage: CGImage?
    #if os(macOS)
    @Published public var targetNSImage: NSImage?
    #endif
    @Published public var targetResolutionText: String = "No image loaded"
    
    public var targetSwiftUIImage: Image? {
        guard let cg = targetCGImage else { return nil }
        #if os(macOS)
        return Image(nsImage: NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)))
        #else
        return Image(decorative: cg, scale: 1.0, orientation: .up)
        #endif
    }
    
    // Platform file picker presentation flags for iOS / iPadOS
    @Published public var isFolderPickerPresented: Bool = false
    @Published public var isTargetFileImporterPresented: Bool = false
    @Published public var isProjectImporterPresented: Bool = false
    
    // MARK: - Settings State
    @Published public var shapeType: MosaicShapeType = .rectangular {
        didSet {
            guard !isLoadingProject else { return }
            if shapeType != oldValue {
                if shapeType == .quadtree && tilesAcross > 20 {
                    tilesAcross = 12
                    if let img = targetCGImage {
                        tilesDown = max(2, Int(round(Double(tilesAcross) * Double(img.height) / Double(img.width))))
                    } else {
                        tilesDown = 8
                    }
                }
                prepareTiles()
            }
        }
    }
    @Published public var tilesAcross: Int = 30 {
        didSet {
            guard !isLoadingProject else { return }
            if tilesAcross != oldValue { prepareTiles() }
        }
    }
    @Published public var tilesDown: Int = 20 {
        didSet {
            guard !isLoadingProject else { return }
            if tilesDown != oldValue { prepareTiles() }
        }
    }
    @Published public var strokeWidth: Double = 0.5 {
        didSet { canvasVersion += 1 }
    }
    @Published public var strokeColor: String = "black" {
        didSet { canvasVersion += 1 }
    }
    @Published public var maxReuse: Int = 0
    @Published public var minDistance: Int = 2
    @Published public var colorMetric: MosaicColorMetric = .riemersma {
        didSet {
            engine?.metric = colorMetric
            canvasVersion += 1
        }
    }
    
    // Blend with Original (0.0 = 100% Mosaic, 1.0 = 100% Original Photo)
    @Published public var blendOpacity: Double = 0.0
    
    // Reinhard Perceptual Color Transfer (0.0 = untouched photos, 1.0 = full statistical color transfer)
    @Published public var colorTransferStrength: Double = 0.0
    @Published public var showingColorTransferInfo: Bool = false
    
    // Edge-Aware / Directional Matching (0.0 = color only, 1.0 = maximum edge orientation alignment)
    @Published public var edgeWeight: Double = 0.0 {
        didSet {
            engine?.edgeWeight = Float(edgeWeight)
        }
    }
    @Published public var showingEdgeMatchingInfo: Bool = false
    
    // Adaptive Multi-Resolution Quadtree Tiling
    @Published public var quadtreeMaxDepth: Int = 3 {
        didSet {
            guard !isLoadingProject else { return }
            if quadtreeMaxDepth != oldValue && shapeType == .quadtree { prepareTiles() }
        }
    }
    @Published public var quadtreeThreshold: Double = 0.08 {
        didSet {
            guard !isLoadingProject else { return }
            if quadtreeThreshold != oldValue && shapeType == .quadtree { prepareTiles() }
        }
    }
    @Published public var quadtreeBalanced: Bool = true {
        didSet {
            guard !isLoadingProject else { return }
            if quadtreeBalanced != oldValue && shapeType == .quadtree { prepareTiles() }
        }
    }
    @Published public var quadtreeDetailAlpha: Double = 0.5 {
        didSet {
            guard !isLoadingProject else { return }
            if quadtreeDetailAlpha != oldValue && shapeType == .quadtree { prepareTiles() }
        }
    }
    @Published public var quadtreeAlgorithm: String = "juliaRange" {
        didSet {
            guard !isLoadingProject else { return }
            if quadtreeAlgorithm != oldValue && shapeType == .quadtree { prepareTiles() }
        }
    }
    @Published public var quadtreeMinTileDim: Double = 16.0 {
        didSet {
            guard !isLoadingProject else { return }
            if quadtreeMinTileDim != oldValue && shapeType == .quadtree { prepareTiles() }
        }
    }
    @Published public var showingQuadtreeInfo: Bool = false
    @Published public var quadtreeSizeSummary: String = ""
    
    // MARK: - Image Sources State
    @Published public var useApplePhotos: Bool = false {
        didSet {
            if useApplePhotos != oldValue {
                if useApplePhotos && !isPhotosAuthorized {
                    requestPhotosAccess()
                } else {
                    if useApplePhotos && applePhotosCandidateItems.isEmpty {
                        loadApplePhotosCandidates()
                    } else {
                        recomputeCombinedCandidates()
                    }
                }
            }
        }
    }
    @Published public var useLocalFolders: Bool = true {
        didSet {
            if useLocalFolders != oldValue {
                recomputeCombinedCandidates()
            }
        }
    }
    
    @Published public var sourceFolders: [URL] = []
    @Published public var localCandidateItems: [MosaicCandidateItem] = []
    @Published public var applePhotosCandidateItems: [MosaicCandidateItem] = []
    @Published public var candidateItems: [MosaicCandidateItem] = []
    @Published public var foundImageURLs: [URL] = []
    @Published public var heicCount: Int = 0
    @Published public var formatBreakdownText: String = ""
    
    // Apple Photos State
    @Published public var photosAuthStatus: PHAuthorizationStatus = .notDetermined
    @Published public var availableAlbums: [MosaicAlbumItem] = []
    @Published public var selectedAlbumID: String = "all" {
        didSet {
            if selectedAlbumID != oldValue && useApplePhotos {
                loadApplePhotosCandidates()
            }
        }
    }
    @Published public var isLoadingPhotos: Bool = false
    
    // MARK: - Execution & Matching State
    @Published public var engine: MosaicEngine?
    @Published public var isRunning: Bool = false
    @Published public var isPaused: Bool = false
    @Published public var processedImagesCount: Int = 0
    @Published public var totalImagesCount: Int = 0
    @Published public var matchedTilesCount: Int = 0
    @Published public var totalTilesCount: Int = 0
    @Published public var averageScore: Float = 1.0
    @Published public var statusMessage: String = "Drag an image to begin"
    
    // Canvas Redraw Trigger
    @Published public var canvasVersion: Int = 0
    
    // Selected Tile for Inspection Popover
    @Published public var selectedTile: MosaicTile?
    @Published public var isFindingSubstitute: Bool = false
    private var tileExcludedIdentifiers: [Int: Set<String>] = [:]
    
    @Published public var isExportSheetPresented: Bool = false
    @Published public var isAboutPresented: Bool = false
    
    // Layout Change Warning & Confirmation
    @Published public var showingLayoutChangeWarning: Bool = false
    @Published public var pendingLayoutDescription: String = ""
    public var pendingLayoutAction: (() -> Void)?
    
    // Project Disk Safety
    @Published public var hasDiscardedMatchesFromSavedFile: Bool = false
    @Published public var showingOverwriteSavedWarning: Bool = false
    
    // Memory Estimation
    @Published public var estimatedRAMText: String = "0 MB"
    @Published public var isMemorySafe: Bool = true
    
    // Canvas interaction state
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var panOffset: CGSize = .zero
    @Published public var dragBaseOffset: CGSize = .zero
    
    // Drag & drop highlight state
    @Published public var isTargetDropTargeted: Bool = false
    @Published public var isSourcesDropTargeted: Bool = false
    @Published public var isCanvasDropTargeted: Bool = false
    
    // Export Sheet state
    @Published public var exportPreset: Int = 3000
    @Published public var exportCustomWidth: Int = 3000
    @Published public var exportIsCustom: Bool = false
    @Published public var exportFormat: String = "HEIC"
    @Published public var isExporting: Bool = false
    @Published public var exportErrorMessage: String?
    @Published public var isLoadingProject: Bool = false
    @Published public var loadingProjectName: String = ""
    @Published public var projectLoadingLogs: [String] = []
    @Published public var projectLoadingProgress: Double = 0.0
    
    private var matchingTask: Task<Void, Never>?
    private var tilePrepTask: Task<Void, Never>?
    private var sourcesScanTask: Task<Void, Never>?
    private let loader = ImageLoader()
    
    @MainActor
    public func appendLoadingLog(_ message: String, progress: Double? = nil) {
        projectLoadingLogs.append(message)
        if let progress = progress {
            projectLoadingProgress = progress
        }
        statusMessage = message
    }
    
    public init() {
        self.photosAuthStatus = ApplePhotosSource.authorizationStatus()
        if self.photosAuthStatus == .authorized || self.photosAuthStatus == .limited {
            self.availableAlbums = ApplePhotosSource.shared.fetchAvailableAlbums()
        }
    }
    
    public var canStart: Bool {
        return targetCGImage != nil && !foundImageURLs.isEmpty && !isRunning
    }
    
    public var hasCompletedTiles: Bool {
        return matchedTilesCount > 0
    }
    
    // MARK: - Target Image Handling
    public func setTargetImage(from url: URL) {
        guard !isExporting else { return }
        self.statusMessage = "Loading \(url.lastPathComponent)..."
        
        Task.detached(priority: .userInitiated) { [weak self] in
            let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
            guard let source = CGImageSourceCreateWithURL(url as CFURL, opts as CFDictionary) else {
                await MainActor.run { [weak self] in
                    self?.statusMessage = "Could not open image: \(url.lastPathComponent)"
                }
                return
            }
            
            // Fast metadata read without full pixel decoding
            var origW: Int = 0
            var origH: Int = 0
            if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                origW = (props[kCGImagePropertyPixelWidth] as? Int) ?? 0
                origH = (props[kCGImagePropertyPixelHeight] as? Int) ?? 0
            }
            
            // Downsample large images to max 2048 px to avoid memory spikes and freezes
            let maxDim: Int = 2048
            let thumbOpts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDim,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
            ]
            
            guard let rawCGImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts as CFDictionary) else {
                await MainActor.run { [weak self] in
                    self?.statusMessage = "Could not decode image: \(url.lastPathComponent)"
                }
                return
            }
            
            // Normalize image (including 10-bit AVIF, HDR HEIC, IOSurface) to standard 8-bit sRGB bitmap
            let cgImage = MosaicEngine.normalizeToStandardSRGB(rawCGImage)
            
            let loadedW = cgImage.width
            let loadedH = cgImage.height
            let resText: String
            if origW > maxDim || origH > maxDim {
                resText = "\(origW) × \(origH) px (optimized to \(loadedW) × \(loadedH))"
            } else {
                resText = "\(loadedW) × \(loadedH) px"
            }
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.targetImageURL = url
                self.targetCGImage = cgImage
                self.targetResolutionText = resText
                self.statusMessage = "Target image loaded (\(loadedW) × \(loadedH) px)."
                self.prepareTiles()
            }
        }
    }
    
    // MARK: - Tile Preparation
    public func prepareTiles() {
        guard !isExporting, !isLoadingProject, let cgImg = targetCGImage else { return }
        
        tilePrepTask?.cancel()
        self.tileExcludedIdentifiers.removeAll()
        
        let shape = self.shapeType
        let across = self.tilesAcross
        let down = self.tilesDown
        let reuse = self.maxReuse
        let minDist = self.minDistance
        let metric = self.colorMetric
        let edgeW = Float(self.edgeWeight)
        let qDepth = self.quadtreeMaxDepth
        let qThresh = Float(self.quadtreeThreshold)
        let qBalanced = self.quadtreeBalanced
        let qDetailAlpha = Float(self.quadtreeDetailAlpha)
        let qAlgo: MosaicQuadtreeAlgorithm = {
            switch self.quadtreeAlgorithm {
            case "colorRange": return .colorRange
            case "variance": return .variance
            case "wholeCanvas": return .wholeCanvas
            default: return .juliaRange
            }
        }()
        let qMinTileDim = Float(self.quadtreeMinTileDim)
        
        tilePrepTask = Task.detached(priority: .userInitiated) { [weak self, cgImg] in
            let newEngine = MosaicEngine(
                shapeType: shape,
                tilesAcross: across,
                tilesDown: down,
                maxReuse: reuse,
                minDistance: minDist,
                metric: metric,
                edgeWeight: edgeW,
                quadtreeMaxDepth: qDepth,
                quadtreeThreshold: qThresh,
                quadtreeBalanced: qBalanced,
                quadtreeDetailAlpha: qDetailAlpha,
                quadtreeAlgorithm: qAlgo,
                quadtreeMinTileDim: qMinTileDim
            )
            
            do {
                try newEngine.prepare(with: cgImg)
                if Task.isCancelled { return }
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.engine = newEngine
                    self.totalTilesCount = newEngine.tiles.count
                    self.matchedTilesCount = 0
                    self.processedImagesCount = 0
                    self.averageScore = 1.0
                    self.canvasVersion += 1
                    
                    if shape == .quadtree && !newEngine.tiles.isEmpty {
                        let minW = newEngine.tiles.map { $0.geometry.bounds.width }.min() ?? 0
                        let minH = newEngine.tiles.map { $0.geometry.bounds.height }.min() ?? 0
                        let maxW = newEngine.tiles.map { $0.geometry.bounds.width }.max() ?? 0
                        let maxH = newEngine.tiles.map { $0.geometry.bounds.height }.max() ?? 0
                        self.quadtreeSizeSummary = "Tile sizes: \(Int(round(maxW)))×\(Int(round(maxH))) px down to \(Int(round(minW)))×\(Int(round(minH))) px"
                    } else {
                        self.quadtreeSizeSummary = ""
                    }
                    
                    self.statusMessage = "Ready: \(newEngine.tiles.count) tile shapes generated."
                    self.updateMemoryEstimate()
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run { [weak self] in
                    self?.statusMessage = "Error generating tiles: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Source Folder Handling
    public func addSourceFolder(_ url: URL) {
        if !sourceFolders.contains(url) {
            sourceFolders.append(url)
        }
        rescanSources()
    }
    
    public func removeSourceFolder(_ url: URL) {
        sourceFolders.removeAll { $0 == url }
        rescanSources()
    }
    
    public func rescanSources() {
        sourcesScanTask?.cancel()
        let folders = self.sourceFolders
        sourcesScanTask = Task.detached(priority: .utility) { [weak self, folders] in
            var allItems: [MosaicCandidateItem] = []
            let localLoader = ImageLoader()
            for folder in folders {
                if Task.isCancelled { return }
                let found = localLoader.findImages(in: folder)
                for url in found {
                    allItems.append(MosaicCandidateItem(
                        id: url.path,
                        displayName: url.lastPathComponent,
                        sourceProviderID: "local",
                        originalURL: url
                    ))
                }
            }
            if Task.isCancelled { return }
            let finalItems = allItems
            let countHeic = finalItems.filter { 
                let ext = ($0.originalURL?.pathExtension ?? "").lowercased()
                return ext == "heic" || ext == "heif" || ext == "hif"
            }.count
            
            await MainActor.run { [weak self, finalItems] in
                guard let self = self else { return }
                self.localCandidateItems = finalItems
                self.heicCount = countHeic
                self.recomputeCombinedCandidates()
            }
        }
    }
    
    public func recomputeCombinedCandidates() {
        var combined: [MosaicCandidateItem] = []
        
        if useLocalFolders {
            combined.append(contentsOf: localCandidateItems)
        }
        if useApplePhotos && isPhotosAuthorized {
            combined.append(contentsOf: applePhotosCandidateItems)
        }
        
        self.candidateItems = combined
        self.foundImageURLs = combined.map { $0.canonicalURL }
        self.totalImagesCount = combined.count
        
        // Multi-format breakdown text
        if useLocalFolders && useApplePhotos && isPhotosAuthorized {
            self.formatBreakdownText = "\(applePhotosCandidateItems.count) Photos • \(localCandidateItems.count) Folder items (Total: \(combined.count))"
        } else if useApplePhotos && isPhotosAuthorized {
            let albumTitle = self.availableAlbums.first(where: { $0.id == self.selectedAlbumID })?.title ?? "Photos"
            self.formatBreakdownText = "\(applePhotosCandidateItems.count) photos in \(albumTitle)"
        } else if useLocalFolders {
            var counts: [String: Int] = [:]
            for item in localCandidateItems {
                let ext = (item.originalURL?.pathExtension ?? "").lowercased()
                switch ext {
                case "heic", "heif", "hif":
                    counts["HEIC/HIF", default: 0] += 1
                case "avif":
                    counts["AVIF", default: 0] += 1
                case "jpg", "jpeg":
                    counts["JPEG", default: 0] += 1
                case "png":
                    counts["PNG", default: 0] += 1
                case "tiff", "tif":
                    counts["TIFF", default: 0] += 1
                case "webp":
                    counts["WebP", default: 0] += 1
                case "gif":
                    counts["GIF", default: 0] += 1
                case "bmp":
                    counts["BMP", default: 0] += 1
                default:
                    if !ext.isEmpty {
                        counts[ext.uppercased(), default: 0] += 1
                    }
                }
            }
            let sorted = counts.filter { $0.value > 0 }.sorted { $0.value > $1.value }
            self.formatBreakdownText = sorted.map { "\($0.value) \($0.key)" }.joined(separator: " • ")
        } else {
            self.formatBreakdownText = "No active image sources selected"
        }
        
        updateMemoryEstimate()
        if targetCGImage != nil && !foundImageURLs.isEmpty {
            statusMessage = "Ready to start! Found \(foundImageURLs.count) photos in pool."
        }
    }
    
    private func updateMemoryEstimate() {
        let est = MemoryChecker.estimate(
            sourceImageCount: foundImageURLs.count,
            tileCount: totalTilesCount,
            outputWidth: 3000,
            outputHeight: 2000
        )
        self.estimatedRAMText = MemoryChecker.formatBytes(est.totalPeakBytes)
        self.isMemorySafe = est.isSafe
    }
    
    // MARK: - Image Source Providers Handling
    public var isPhotosAuthorized: Bool {
        return photosAuthStatus == .authorized || photosAuthStatus == .limited
    }
    
    public func refreshPhotosAuthorization() {
        self.photosAuthStatus = ApplePhotosSource.authorizationStatus()
        if isPhotosAuthorized {
            self.availableAlbums = ApplePhotosSource.shared.fetchAvailableAlbums()
            loadApplePhotosCandidates()
        } else {
            self.applePhotosCandidateItems = []
            recomputeCombinedCandidates()
        }
    }
    
    public func requestPhotosAccess() {
        Task { @MainActor in
            let status = await ApplePhotosSource.requestAuthorization()
            self.photosAuthStatus = status
            if self.isPhotosAuthorized {
                self.availableAlbums = ApplePhotosSource.shared.fetchAvailableAlbums()
                self.loadApplePhotosCandidates()
            } else {
                self.useApplePhotos = false
            }
        }
    }
    
    public func loadApplePhotosCandidates() {
        guard isPhotosAuthorized else { return }
        self.isLoadingPhotos = true
        self.statusMessage = "Loading Photos library..."
        
        ApplePhotosSource.shared.selectedAlbumID = selectedAlbumID
        
        Task { @MainActor in
            do {
                let items = try await ApplePhotosSource.shared.enumerateCandidates()
                self.applePhotosCandidateItems = items
                self.isLoadingPhotos = false
                self.recomputeCombinedCandidates()
            } catch {
                self.isLoadingPhotos = false
                self.statusMessage = "Error loading photos: \(error.localizedDescription)"
            }
        }
    }
    
    public func cgImageForTile(_ tile: MosaicTile) -> CGImage? {
        guard let url = tile.bestImageURL else { return nil }
        if url.scheme == "applephotos" {
            if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let idItem = comps.queryItems?.first(where: { $0.name == "id" })?.value {
                return ApplePhotosSource.shared.cachedDisplayThumbnail(byIdentifier: idItem, maxPixelSize: 320)
            }
        } else if url.isFileURL {
            let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
            if let src = CGImageSourceCreateWithURL(url as CFURL, opts as CFDictionary) {
                return CGImageSourceCreateImageAtIndex(src, 0, nil)
            }
        }
        return nil
    }
    
    #if os(macOS)
    public func imageForTile(_ tile: MosaicTile) -> NSImage? {
        guard let cgImg = cgImageForTile(tile) else { return nil }
        return NSImage(cgImage: cgImg, size: NSSize(width: cgImg.width, height: cgImg.height))
    }
    #endif
    
    // MARK: - Matching Execution
    public func toggleMatching() {
        guard !isExporting else { return }
        if isRunning {
            pauseMatching()
        } else {
            startMatching()
        }
    }
    
    public func startMatching() {
        guard !isExporting, let engine = self.engine, !candidateItems.isEmpty else { return }
        
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        #endif
        
        self.isRunning = true
        self.isPaused = false
        self.statusMessage = "Matching photos..."
        
        let items = self.candidateItems
        
        matchingTask = Task.detached(priority: .userInitiated) { [weak self, engine, items] in
            let total = items.count
            var count = 0
            let loader = ImageLoader()
            let batchSize = max(64, ProcessInfo.processInfo.activeProcessorCount * 8)
            var lastUIUpdateTime = ContinuousClock.now
            var lastCanvasUpdateTime = ContinuousClock.now
            var hadUpdatesSinceLastCanvasRefresh = false
            
            var index = 0
            while index < total {
                if Task.isCancelled { break }
                
                // Check pause state
                while engine.isPaused && !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                if Task.isCancelled { break }
                
                let endIndex = min(index + batchSize, total)
                let currentChunk = Array(items[index..<endIndex])
                index = endIndex
                
                var chunkCandidates: [SourceImageCandidate] = []
                chunkCandidates.reserveCapacity(currentChunk.count)
                
                await withTaskGroup(of: SourceImageCandidate?.self) { group in
                    for item in currentChunk {
                        group.addTask {
                            if Task.isCancelled { return nil }
                            
                            let thumbData: Data?
                            if item.sourceProviderID == "apple-photos" {
                                thumbData = try? await ApplePhotosSource.shared.loadCandidateThumbnail(for: item)
                            } else if let url = item.originalURL {
                                thumbData = loader.loadThumbnail(from: url, targetSize: 16)
                            } else {
                                thumbData = nil
                            }
                            
                            guard let data = thumbData else { return nil }
                            return SourceImageCandidate(
                                identifier: item.id,
                                url: item.canonicalURL,
                                thumbnailPixels: data
                            )
                        }
                    }
                    for await cand in group {
                        if let cand = cand {
                            chunkCandidates.append(cand)
                        }
                    }
                }
                
                if Task.isCancelled { break }
                
                let anyChunkUpdated = engine.testCandidatesBatch(chunkCandidates)
                if anyChunkUpdated {
                    hadUpdatesSinceLastCanvasRefresh = true
                }
                
                count = endIndex
                let currentCount = count
                let now = ContinuousClock.now
                let isBatchFinal = (currentCount >= total)
                
                // Throttle heavy canvas re-renders to at most once every 1.5 seconds during active matching,
                // or immediately upon batch completion. This keeps the Main Thread and macOS WindowServer 100% responsive,
                // completely eliminating beachballing and Dock activation stalls.
                let shouldRefreshCanvas = isBatchFinal || (hadUpdatesSinceLastCanvasRefresh && (now - lastCanvasUpdateTime >= .milliseconds(1500)))
                if shouldRefreshCanvas {
                    hadUpdatesSinceLastCanvasRefresh = false
                    lastCanvasUpdateTime = now
                }
                
                // Keep progress bar and status text smooth (~10 Hz / 100ms)
                if (now - lastUIUpdateTime >= .milliseconds(100)) || isBatchFinal {
                    lastUIUpdateTime = now
                    
                    let matched = engine.tiles.filter { $0.bestImageURL != nil }.count
                    let avgScore: Float
                    if matched > 0 {
                        let totalScore = engine.tiles.compactMap { $0.bestImageURL != nil ? $0.bestScore : nil }.reduce(0.0, +)
                        avgScore = totalScore / Float(matched)
                    } else {
                        avgScore = 1.0
                    }
                    let pct = Int(Double(currentCount) / Double(total) * 100.0)
                    let status = "Matching: \(currentCount)/\(total) photos (\(pct)%) | \(matched)/\(engine.tiles.count) tiles"
                    
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        if shouldRefreshCanvas {
                            self.canvasVersion += 1
                        }
                        self.processedImagesCount = currentCount
                        self.matchedTilesCount = matched
                        if matched > 0 {
                            self.averageScore = avgScore
                        }
                        self.statusMessage = status
                    }
                }
            }
            
            let finalMatched = engine.tiles.filter { $0.bestImageURL != nil }.count
            let finalTotal = engine.tiles.count
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.isRunning = false
                self.statusMessage = "Completed! Filled \(finalMatched) of \(finalTotal) tiles."
                self.canvasVersion += 1
                self.sendCompletionNotification(matched: finalMatched, total: finalTotal)
            }
        }
    }
    
    // MARK: - Notifications
    private func sendCompletionNotification(matched: Int, total: Int) {
        #if os(macOS)
        NSSound(named: "Glass")?.play()
        #endif
        
        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = "Mosaic Ready"
        content.body = "Mosaic complete! Filled \(matched) of \(total) tiles."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "com.carlomontec.mosaiclab.matching-complete-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        #endif
    }
    
    public func pauseMatching() {
        self.isPaused.toggle()
        self.engine?.isPaused = isPaused
        if isPaused {
            statusMessage = "Paused"
        } else {
            statusMessage = "Resuming matching..."
        }
    }
    
    public func stopMatching() {
        matchingTask?.cancel()
        engine?.isCancelled = true
        isRunning = false
        isPaused = false
        statusMessage = "Stopped"
    }
    
    // MARK: - Single-Tile Substitution
    public func findSubstitute(for tile: MosaicTile) {
        guard let engine = self.engine else { return }
        let tileIndex = tile.geometry.tileIndex
        var excluded = tileExcludedIdentifiers[tileIndex] ?? Set<String>()
        if let currentID = tile.bestImageIdentifier {
            excluded.insert(currentID)
        }
        tileExcludedIdentifiers[tileIndex] = excluded
        
        self.isFindingSubstitute = true
        
        Task.detached(priority: .userInitiated) { [weak self, engine, tile, excluded] in
            let candidates = await self?.foundImageURLs ?? []
            let result = await engine.findSubstitute(
                for: tile,
                candidateURLs: candidates,
                excludedIdentifiers: excluded
            )
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.isFindingSubstitute = false
                if result != nil {
                    self.canvasVersion += 1
                    // Re-trigger SwiftUI state update for the popover
                    let inspected = self.selectedTile
                    self.selectedTile = nil
                    self.selectedTile = inspected
                }
            }
        }
    }
    
    public func manuallySubstitute(tile: MosaicTile, imageURL: URL) {
        guard let engine = self.engine else { return }
        let score = engine.manuallyAssignImage(from: imageURL, to: tile)
        if score != nil {
            self.canvasVersion += 1
            let inspected = self.selectedTile
            self.selectedTile = nil
            self.selectedTile = inspected
        }
    }
    
    // MARK: - Export
    public func exportMosaic(outputWidth: Int, format: String, destinationURL: URL) {
        guard !isExporting else {
            statusMessage = "Export already in progress."
            return
        }
        guard let engine = self.engine else { return }
        
        self.isExporting = true
        self.statusMessage = "Exporting \(outputWidth)px mosaic (\(format.uppercased()))..."
        
        let tilesCopy = engine.tiles
        let mosaicSizeCopy = engine.mosaicSize
        let stroke = Float(self.strokeWidth)
        let strokeCol = self.strokeColor
        let isMono = (self.colorMetric == .monochrome)
        let transfer = Float(self.colorTransferStrength)
        
        Task.detached(priority: .userInitiated) {
            let renderer = MosaicRenderer()
            do {
                try renderer.render(
                    tiles: tilesCopy,
                    mosaicSize: mosaicSizeCopy,
                    outputWidth: outputWidth,
                    strokeWidth: stroke,
                    strokeColor: strokeCol,
                    colorTransferStrength: transfer,
                    isMonochrome: isMono,
                    outputURL: destinationURL
                )
                await MainActor.run {
                    self.isExporting = false
                    self.statusMessage = "Export complete: \(destinationURL.lastPathComponent)"
                    #if os(macOS)
                    NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
                    #endif
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.statusMessage = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    #if os(macOS)
    public func presentSavePanelAndExport(outputWidth: Int, format: String) {
        guard !isExporting else {
            statusMessage = "Export already in progress."
            return
        }
        guard self.engine != nil else { return }
        
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        let defaultBase = targetImageURL?.deletingPathExtension().lastPathComponent ?? "Mosaic"
        panel.nameFieldStringValue = defaultBase
        
        let utType: UTType
        switch format.uppercased() {
        case "HEIC":
            utType = .heic
        case "AVIF":
            utType = UTType(filenameExtension: "avif") ?? .png
        case "JPG", "JPEG":
            utType = .jpeg
        default:
            utType = .png
        }
        panel.allowedContentTypes = [utType]
        
        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let destinationURL = panel.url else { return }
            
            var finalURL = destinationURL
            let ext = (utType.preferredFilenameExtension ?? format).lowercased()
            while finalURL.pathExtension.lowercased() == ext,
                  finalURL.deletingPathExtension().pathExtension.lowercased() == ext {
                finalURL = finalURL.deletingPathExtension()
            }
            if finalURL.pathExtension.lowercased() != ext {
                finalURL = finalURL.appendingPathExtension(ext)
            }
            
            self.exportMosaic(outputWidth: outputWidth, format: format, destinationURL: finalURL)
        }
    }
    #endif
    
    // MARK: - Layout Change Confirmation & Project Safety
    public func resetMatches() {
        engine?.resetMatches()
        matchedTilesCount = 0
        processedImagesCount = 0
        averageScore = 1.0
        canvasVersion += 1
        statusMessage = "Matches cleared. Ready to start matching."
    }
    
    public func proposeLayoutChange(description: String, action: @escaping () -> Void) {
        if matchedTilesCount == 0 {
            action()
        } else {
            guard !showingLayoutChangeWarning else { return }
            self.pendingLayoutDescription = description
            self.pendingLayoutAction = action
            self.showingLayoutChangeWarning = true
        }
    }
    
    public func confirmLayoutChange() {
        showingLayoutChangeWarning = false
        if currentProjectURL != nil {
            hasDiscardedMatchesFromSavedFile = true
        }
        let action = pendingLayoutAction
        pendingLayoutAction = nil
        action?()
        if matchedTilesCount > 0 {
            resetMatches()
        }
    }
    
    public func cancelLayoutChange() {
        showingLayoutChangeWarning = false
        pendingLayoutAction = nil
        canvasVersion += 1
        objectWillChange.send()
    }
    
    public func saveAsBeforeLayoutChange() {
        showingLayoutChangeWarning = false
        saveProjectAsPrompt { [weak self] saved in
            guard let self = self else { return }
            if saved {
                self.confirmLayoutChange()
            } else {
                self.cancelLayoutChange()
            }
        }
    }
    
    // MARK: - Project Save & Open (.macosaix)
    @Published public var currentProjectURL: URL?
    
    public func newProject() {
        guard !isExporting else {
            statusMessage = "Cannot create new project while export is in progress."
            return
        }
        matchingTask?.cancel()
        tilePrepTask?.cancel()
        sourcesScanTask?.cancel()
        isLoadingProject = false
        isRunning = false
        isPaused = false
        engine = nil
        targetImageURL = nil
        targetCGImage = nil
        targetResolutionText = "No image loaded"
        sourceFolders = []
        foundImageURLs = []
        heicCount = 0
        formatBreakdownText = ""
        matchedTilesCount = 0
        totalTilesCount = 0
        currentProjectURL = nil
        hasDiscardedMatchesFromSavedFile = false
        showingOverwriteSavedWarning = false
        showingLayoutChangeWarning = false
        zoomScale = 1.0
        panOffset = .zero
        dragBaseOffset = .zero
        canvasVersion += 1
        statusMessage = "New project. Drag a picture to begin."
    }
    
    public func saveProject() {
        guard !isExporting, !isLoadingProject else {
            statusMessage = "Cannot save while export or loading is in progress."
            return
        }
        if hasDiscardedMatchesFromSavedFile, let _ = currentProjectURL {
            showingOverwriteSavedWarning = true
            return
        }
        if let currentURL = currentProjectURL {
            saveProject(to: currentURL)
        } else {
            #if os(macOS)
            saveProjectAsPrompt()
            #endif
        }
    }
    
    #if os(macOS)
    public func saveProjectAsPrompt(completion: ((Bool) -> Void)? = nil) {
        guard !isExporting, !isLoadingProject else {
            statusMessage = "Cannot save while export or loading is in progress."
            completion?(false)
            return
        }
        guard targetCGImage != nil else {
            statusMessage = "Cannot save project: No target image loaded."
            completion?(false)
            return
        }
        
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        var cleanName = currentProjectURL?.deletingPathExtension().lastPathComponent ?? targetImageURL?.deletingPathExtension().lastPathComponent ?? "Mosaic"
        while cleanName.lowercased().hasSuffix(".mosaiclab") || cleanName.lowercased().hasSuffix(".macosaix") {
            if cleanName.lowercased().hasSuffix(".mosaiclab") {
                cleanName = String(cleanName.dropLast(10))
            } else if cleanName.lowercased().hasSuffix(".macosaix") {
                cleanName = String(cleanName.dropLast(9))
            }
        }
        panel.nameFieldStringValue = cleanName
        var types = [UTType]()
        if let mosaiclabType = UTType(filenameExtension: "mosaiclab") {
            types.append(mosaiclabType)
        }
        if let macosaixType = UTType(filenameExtension: "macosaix") {
            types.append(macosaixType)
        }
        panel.allowedContentTypes = types
        panel.allowsOtherFileTypes = true
        panel.prompt = "Save Project"
        
        panel.begin { [weak self] response in
            guard let self = self else {
                completion?(false)
                return
            }
            guard response == .OK, let destinationURL = panel.url else {
                completion?(false)
                return
            }
            var finalURL = destinationURL
            let ext = finalURL.pathExtension.lowercased()
            if ext != "mosaiclab" && ext != "macosaix" {
                finalURL = finalURL.appendingPathExtension("mosaiclab")
            }
            self.saveProject(to: finalURL)
            completion?(true)
        }
    }
    #endif
    
    public func saveProject(to destinationURL: URL) {
        guard !isExporting else {
            statusMessage = "Cannot save while export is in progress."
            return
        }
        guard let engine = self.engine, let targetURL = self.targetImageURL else {
            statusMessage = "No active mosaic to save."
            return
        }
        
        let shapeStr: String
        switch shapeType {
        case .quadtree: shapeStr = "quadtree"
        case .rectangular: shapeStr = "rectangular"
        }
        
        let metricStr: String
        switch colorMetric {
        case .RGB: metricStr = "rgb"
        case .monochrome: metricStr = "monochrome"
        default: metricStr = "riemersma"
        }
        
        let settings = MosaicLabProject.ProjectSettings(
            shapeType: shapeStr,
            tilesAcross: tilesAcross,
            tilesDown: tilesDown,
            curviness: nil,
            strokeWidth: strokeWidth,
            strokeColor: strokeColor,
            maxReuse: maxReuse,
            minDistance: minDistance,
            colorMetric: metricStr,
            blendOpacity: blendOpacity,
            colorTransferStrength: colorTransferStrength,
            edgeWeight: edgeWeight,
            quadtreeMaxDepth: quadtreeMaxDepth,
            quadtreeThreshold: quadtreeThreshold,
            quadtreeBalanced: quadtreeBalanced,
            quadtreeDetailAlpha: quadtreeDetailAlpha,
            quadtreeAlgorithm: quadtreeAlgorithm,
            quadtreeMinTileDim: quadtreeMinTileDim
        )
        
        var uniqueThumbnails: [String: CGImage] = [:]
        var pathToThumbFile: [String: String] = [:]
        var thumbCounter = 0
        
        var tileRecords: [MosaicLabProject.TileMatchRecord] = []
        tileRecords.reserveCapacity(engine.tiles.count)
        for (idx, tile) in engine.tiles.enumerated() {
            var thumbFilename: String? = nil
            if let imageURL = tile.bestImageURL {
                let path = imageURL.path
                if let existing = pathToThumbFile[path] {
                    thumbFilename = existing
                } else {
                    let fn = String(format: "thumb_%05d.heic", thumbCounter)
                    thumbCounter += 1
                    pathToThumbFile[path] = fn
                    thumbFilename = fn
                    if let thumb = MosaicThumbnailCache.shared.thumbnail(for: imageURL, maxPixelSize: 256) {
                        uniqueThumbnails[fn] = thumb
                    }
                }
            }
            tileRecords.append(
                MosaicLabProject.TileMatchRecord(
                    index: idx,
                    imagePath: tile.bestImageURL?.path,
                    score: tile.bestScore,
                    thumbnailFile: thumbFilename
                )
            )
        }
        
        let mosaicSize = CGSize(
            width: targetCGImage?.width ?? 1280,
            height: targetCGImage?.height ?? 960
        )
        let preview = MosaicRenderer().renderToImage(
            tiles: engine.tiles,
            mosaicSize: mosaicSize,
            outputWidth: min(Int(mosaicSize.width), 1280),
            strokeWidth: Float(strokeWidth),
            strokeColor: strokeColor,
            colorTransferStrength: Float(colorTransferStrength),
            isMonochrome: (colorMetric == .monochrome)
        )
        let targetForEmbedding = targetCGImage
        
        let project = MosaicLabProject(
            version: "3.0.0",
            createdAt: Date(),
            targetImagePath: targetURL.path,
            sourceFolders: sourceFolders.map { $0.path },
            settings: settings,
            tiles: tileRecords
        )
        
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try MosaicProjectManager.shared.saveProject(
                    project,
                    targetImage: targetForEmbedding,
                    previewImage: preview,
                    thumbnails: uniqueThumbnails,
                    to: destinationURL
                )
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.currentProjectURL = destinationURL
                    self.hasDiscardedMatchesFromSavedFile = false
                    self.showingOverwriteSavedWarning = false
                    self.statusMessage = "Project saved: \(destinationURL.lastPathComponent)"
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.statusMessage = "Failed to save project: \(error.localizedDescription)"
                }
            }
        }
    }
    
    public func openProjectPrompt() {
        guard !isExporting, !isLoadingProject else {
            statusMessage = "Cannot open project while an operation is in progress."
            return
        }
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        var types: [UTType] = [.json]
        if let mosaiclabType = UTType(filenameExtension: "mosaiclab") {
            types.append(mosaiclabType)
        }
        if let macosaixType = UTType(filenameExtension: "macosaix") {
            types.append(macosaixType)
        }
        panel.allowedContentTypes = types
        panel.allowsOtherFileTypes = true
        panel.prompt = "Open Project"
        
        if panel.runModal() == .OK, let url = panel.url {
            openProject(from: url)
        }
        #else
        isProjectImporterPresented = true
        #endif
    }
    
    public func openProject(from projectURL: URL) {
        guard !isExporting, !isLoadingProject else {
            statusMessage = "Cannot open project while an operation is in progress."
            return
        }
        self.stopMatching()
        self.tilePrepTask?.cancel()
        self.sourcesScanTask?.cancel()
        self.isLoadingProject = true
        let projName = projectURL.lastPathComponent
        self.loadingProjectName = projName
        self.projectLoadingProgress = 0.05
        self.projectLoadingLogs = ["Opening \(projName)..."]
        self.statusMessage = "Opening \(projName)..."
        
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                await MainActor.run { [weak self] in
                    self?.appendLoadingLog("Reading project bundle...", progress: 0.15)
                }
                let bundle = try MosaicProjectManager.shared.loadProjectBundle(from: projectURL)
                let project = bundle.project
                
                await MainActor.run { [weak self] in
                    self?.appendLoadingLog("Locating target photo...", progress: 0.25)
                }
                let targetURL = URL(fileURLWithPath: project.targetImagePath)
                var resolvedCGImage: CGImage? = nil
                
                if FileManager.default.fileExists(atPath: targetURL.path) {
                    await MainActor.run { [weak self] in
                        self?.appendLoadingLog("Decoding original target image (\(targetURL.lastPathComponent))...", progress: 0.35)
                    }
                    let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
                    if let source = CGImageSourceCreateWithURL(targetURL as CFURL, opts as CFDictionary) {
                        let maxDim: Int = 2048
                        let thumbOpts: [CFString: Any] = [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceThumbnailMaxPixelSize: maxDim,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceShouldCacheImmediately: true
                        ]
                        resolvedCGImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts as CFDictionary)
                    }
                }
                
                // Fallback to embedded target image if original file is missing
                if resolvedCGImage == nil, let embeddedTarget = bundle.targetImage {
                    await MainActor.run { [weak self] in
                        self?.appendLoadingLog("Original photo path not found; using embedded target image.", progress: 0.35)
                    }
                    resolvedCGImage = embeddedTarget
                }
                
                guard let rawCGImage = resolvedCGImage else {
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        self.isLoadingProject = false
                        self.statusMessage = "Could not open target image: \(targetURL.lastPathComponent)"
                    }
                    return
                }
                
                let cgImage = MosaicEngine.normalizeToStandardSRGB(rawCGImage)
                let loadedW = cgImage.width
                let loadedH = cgImage.height
                
                await MainActor.run { [weak self] in
                    self?.appendLoadingLog("Target image normalized (\(loadedW) × \(loadedH) px)", progress: 0.45)
                }
                
                let shape: MosaicShapeType
                switch project.settings.shapeType.lowercased() {
                case "quadtree", "adaptive":
                    shape = .quadtree
                default:
                    shape = .rectangular
                }
                
                let metric: MosaicColorMetric
                switch project.settings.colorMetric.lowercased() {
                case "rgb":
                    metric = .RGB
                case "monochrome", "mono", "bw":
                    metric = .monochrome
                default:
                    metric = .riemersma
                }
                
                let qAlgo: MosaicQuadtreeAlgorithm = {
                    switch project.settings.quadtreeAlgorithm {
                    case "colorRange": return .colorRange
                    case "variance": return .variance
                    case "wholeCanvas": return .wholeCanvas
                    default: return .juliaRange
                    }
                }()
                
                let newEngine = MosaicEngine(
                    shapeType: shape,
                    tilesAcross: project.settings.tilesAcross,
                    tilesDown: project.settings.tilesDown,
                    maxReuse: project.settings.maxReuse,
                    minDistance: project.settings.minDistance,
                    metric: metric,
                    edgeWeight: Float(project.settings.edgeWeight),
                    quadtreeMaxDepth: project.settings.quadtreeMaxDepth,
                    quadtreeThreshold: Float(project.settings.quadtreeThreshold),
                    quadtreeBalanced: project.settings.quadtreeBalanced,
                    quadtreeDetailAlpha: Float(project.settings.quadtreeDetailAlpha),
                    quadtreeAlgorithm: qAlgo,
                    quadtreeMinTileDim: Float(project.settings.quadtreeMinTileDim)
                )
                
                await MainActor.run { [weak self] in
                    self?.appendLoadingLog("Generating tile shapes and rasterizing masks in parallel...", progress: 0.55)
                }
                
                try newEngine.prepare(with: cgImage) { [weak self] subProgress, status in
                    Task { @MainActor [weak self] in
                        self?.appendLoadingLog(status, progress: 0.55 + subProgress * 0.25)
                    }
                }
                
                await MainActor.run { [weak self] in
                    self?.appendLoadingLog("Restoring tile match history (\(project.tiles.count) records)...", progress: 0.80)
                }
                
                var restoredCount = 0
                var uniquePaths = Set<String>()
                for record in project.tiles {
                    if record.index >= 0 && record.index < newEngine.tiles.count,
                       let path = record.imagePath {
                        let tile = newEngine.tiles[record.index]
                        tile.bestImageIdentifier = path
                        let tileURL = URL(fileURLWithPath: path)
                        tile.bestImageURL = tileURL
                        tile.bestScore = record.score
                        restoredCount += 1
                        uniquePaths.insert(path)
                        
                        // Seed thumbnail cache immediately if embedded in bundle!
                        if let thumbFile = record.thumbnailFile, let thumbImg = bundle.thumbnails[thumbFile] {
                            MosaicThumbnailCache.shared.setThumbnail(thumbImg, for: tileURL)
                        }
                    }
                }
                
                if !bundle.thumbnails.isEmpty {
                    await MainActor.run { [weak self] in
                        self?.appendLoadingLog("Loaded \(bundle.thumbnails.count) embedded thumbnails (Instant cache)...", progress: 0.90)
                    }
                } else {
                    let uniqueURLs = uniquePaths.map { URL(fileURLWithPath: $0) }
                    await MainActor.run { [weak self] in
                        self?.appendLoadingLog("Caching \(uniqueURLs.count) thumbnails across CPU cores...", progress: 0.85)
                    }
                    
                    // Parallel preheating of unique thumbnails across all CPU cores for legacy projects
                    await withTaskGroup(of: Void.self) { group in
                        for url in uniqueURLs {
                            group.addTask {
                                MosaicThumbnailCache.shared.preheatThumbnail(for: url, maxPixelSize: 256)
                            }
                        }
                    }
                }
                
                let validSourceFolders = project.sourceFolders.compactMap { path in
                    let url = URL(fileURLWithPath: path)
                    return FileManager.default.fileExists(atPath: path) ? url : nil
                }
                
                let finalRestoredCount = restoredCount
                await MainActor.run { [weak self, finalRestoredCount] in
                    guard let self = self else { return }
                    
                    self.shapeType = shape
                    self.tilesAcross = project.settings.tilesAcross
                    self.tilesDown = project.settings.tilesDown
                    self.strokeWidth = project.settings.strokeWidth
                    self.strokeColor = project.settings.strokeColor
                    self.maxReuse = project.settings.maxReuse
                    self.minDistance = project.settings.minDistance
                    self.colorMetric = metric
                    self.blendOpacity = project.settings.blendOpacity
                    self.colorTransferStrength = project.settings.colorTransferStrength
                    self.edgeWeight = project.settings.edgeWeight
                    self.quadtreeMaxDepth = project.settings.quadtreeMaxDepth
                    self.quadtreeThreshold = project.settings.quadtreeThreshold
                    self.quadtreeBalanced = project.settings.quadtreeBalanced
                    self.quadtreeDetailAlpha = project.settings.quadtreeDetailAlpha
                    self.quadtreeAlgorithm = project.settings.quadtreeAlgorithm
                    self.quadtreeMinTileDim = project.settings.quadtreeMinTileDim
                    
                    self.targetImageURL = targetURL
                    self.targetCGImage = cgImage
                    self.targetResolutionText = "\(loadedW) × \(loadedH) px"
                    
                    self.engine = newEngine
                    self.totalTilesCount = newEngine.tiles.count
                    self.matchedTilesCount = finalRestoredCount
                    self.currentProjectURL = projectURL
                    self.hasDiscardedMatchesFromSavedFile = false
                    self.showingOverwriteSavedWarning = false
                    
                    if shape == .quadtree && !newEngine.tiles.isEmpty {
                        let minW = newEngine.tiles.map { $0.geometry.bounds.width }.min() ?? 0
                        let minH = newEngine.tiles.map { $0.geometry.bounds.height }.min() ?? 0
                        let maxW = newEngine.tiles.map { $0.geometry.bounds.width }.max() ?? 0
                        let maxH = newEngine.tiles.map { $0.geometry.bounds.height }.max() ?? 0
                        self.quadtreeSizeSummary = "Tile sizes: \(Int(round(maxW)))×\(Int(round(maxH))) px down to \(Int(round(minW)))×\(Int(round(minH))) px"
                    } else {
                        self.quadtreeSizeSummary = ""
                    }
                    
                    self.sourceFolders = validSourceFolders
                    self.canvasVersion += 1
                    self.updateMemoryEstimate()
                    
                    self.appendLoadingLog("Completed! Restored \(finalRestoredCount) / \(newEngine.tiles.count) matched tiles.", progress: 1.0)
                    self.statusMessage = "Project loaded! \(finalRestoredCount)/\(newEngine.tiles.count) tiles matched."
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                        self?.isLoadingProject = false
                    }
                    
                    self.rescanSources()
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.isLoadingProject = false
                    self.statusMessage = "Could not open project: \(error.localizedDescription)"
                }
            }
        }
    }
}

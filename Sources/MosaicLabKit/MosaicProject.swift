import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Data representation of a MosaicLab project file (.mosaiclab)
public struct MosaicLabProject: Codable, Sendable {
    public var version: String = "3.0.0"
    public var createdAt: Date = Date()
    public var targetImagePath: String
    public var sourceFolders: [String]
    public var settings: ProjectSettings
    public var tiles: [TileMatchRecord]
    
    public init(
        version: String = "3.0.0",
        createdAt: Date = Date(),
        targetImagePath: String,
        sourceFolders: [String],
        settings: ProjectSettings,
        tiles: [TileMatchRecord]
    ) {
        self.version = version
        self.createdAt = createdAt
        self.targetImagePath = targetImagePath
        self.sourceFolders = sourceFolders
        self.settings = settings
        self.tiles = tiles
    }
    
    enum CodingKeys: String, CodingKey {
        case version, createdAt, targetImagePath, sourceFolders, settings, tiles
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "3.0.0"
        
        if let date = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = date
        } else if let timeInterval = try? container.decode(Double.self, forKey: .createdAt) {
            createdAt = Date(timeIntervalSince1970: timeInterval)
        } else {
            createdAt = Date()
        }
        
        targetImagePath = try container.decode(String.self, forKey: .targetImagePath)
        sourceFolders = try container.decodeIfPresent([String].self, forKey: .sourceFolders) ?? []
        settings = try container.decodeIfPresent(ProjectSettings.self, forKey: .settings) ?? ProjectSettings(
            shapeType: "rectangular",
            tilesAcross: 30,
            tilesDown: 20,
            strokeWidth: 0,
            maxReuse: 0,
            minDistance: 0,
            colorMetric: "riemersma",
            blendOpacity: 0
        )
        tiles = try container.decodeIfPresent([TileMatchRecord].self, forKey: .tiles) ?? []
    }
    
    public struct ProjectSettings: Codable, Sendable {
        public var shapeType: String
        public var tilesAcross: Int
        public var tilesDown: Int
        public var curviness: Float?
        public var strokeWidth: Double
        public var strokeColor: String
        public var maxReuse: Int
        public var minDistance: Int
        public var colorMetric: String
        public var blendOpacity: Double
        public var colorTransferStrength: Double
        public var edgeWeight: Double
        public var quadtreeMaxDepth: Int
        public var quadtreeThreshold: Double
        public var quadtreeBalanced: Bool
        public var quadtreeDetailAlpha: Double
        public var quadtreeAlgorithm: String
        public var quadtreeMinTileDim: Double
        
        public init(
            shapeType: String,
            tilesAcross: Int,
            tilesDown: Int,
            curviness: Float? = nil,
            strokeWidth: Double,
            strokeColor: String = "black",
            maxReuse: Int,
            minDistance: Int,
            colorMetric: String,
            blendOpacity: Double,
            colorTransferStrength: Double = 0.0,
            edgeWeight: Double = 0.0,
            quadtreeMaxDepth: Int = 3,
            quadtreeThreshold: Double = 0.15,
            quadtreeBalanced: Bool = true,
            quadtreeDetailAlpha: Double = 0.5,
            quadtreeAlgorithm: String = "juliaRange",
            quadtreeMinTileDim: Double = 16.0
        ) {
            self.shapeType = shapeType
            self.tilesAcross = tilesAcross
            self.tilesDown = tilesDown
            self.curviness = curviness
            self.strokeWidth = strokeWidth
            self.strokeColor = strokeColor
            self.maxReuse = maxReuse
            self.minDistance = minDistance
            self.colorMetric = colorMetric
            self.blendOpacity = blendOpacity
            self.colorTransferStrength = colorTransferStrength
            self.edgeWeight = edgeWeight
            self.quadtreeMaxDepth = quadtreeMaxDepth
            self.quadtreeThreshold = quadtreeThreshold
            self.quadtreeBalanced = quadtreeBalanced
            self.quadtreeDetailAlpha = quadtreeDetailAlpha
            self.quadtreeAlgorithm = quadtreeAlgorithm
            self.quadtreeMinTileDim = quadtreeMinTileDim
        }
        
        enum CodingKeys: String, CodingKey {
            case shapeType, tilesAcross, tilesDown, curviness, strokeWidth, strokeColor, maxReuse, minDistance, colorMetric, blendOpacity, colorTransferStrength, edgeWeight, quadtreeMaxDepth, quadtreeThreshold, quadtreeBalanced, quadtreeDetailAlpha, quadtreeAlgorithm, quadtreeMinTileDim
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            shapeType = try container.decodeIfPresent(String.self, forKey: .shapeType) ?? "rectangular"
            tilesAcross = try container.decodeIfPresent(Int.self, forKey: .tilesAcross) ?? 30
            tilesDown = try container.decodeIfPresent(Int.self, forKey: .tilesDown) ?? 20
            curviness = try container.decodeIfPresent(Float.self, forKey: .curviness)
            strokeWidth = try container.decodeIfPresent(Double.self, forKey: .strokeWidth) ?? 0.0
            strokeColor = try container.decodeIfPresent(String.self, forKey: .strokeColor) ?? "black"
            maxReuse = try container.decodeIfPresent(Int.self, forKey: .maxReuse) ?? 0
            minDistance = try container.decodeIfPresent(Int.self, forKey: .minDistance) ?? 0
            colorMetric = try container.decodeIfPresent(String.self, forKey: .colorMetric) ?? "riemersma"
            blendOpacity = try container.decodeIfPresent(Double.self, forKey: .blendOpacity) ?? 0.0
            colorTransferStrength = try container.decodeIfPresent(Double.self, forKey: .colorTransferStrength) ?? 0.0
            edgeWeight = try container.decodeIfPresent(Double.self, forKey: .edgeWeight) ?? 0.0
            quadtreeMaxDepth = try container.decodeIfPresent(Int.self, forKey: .quadtreeMaxDepth) ?? 3
            quadtreeThreshold = try container.decodeIfPresent(Double.self, forKey: .quadtreeThreshold) ?? 0.15
            quadtreeBalanced = try container.decodeIfPresent(Bool.self, forKey: .quadtreeBalanced) ?? true
            quadtreeDetailAlpha = try container.decodeIfPresent(Double.self, forKey: .quadtreeDetailAlpha) ?? 0.5
            quadtreeAlgorithm = try container.decodeIfPresent(String.self, forKey: .quadtreeAlgorithm) ?? "juliaRange"
            quadtreeMinTileDim = try container.decodeIfPresent(Double.self, forKey: .quadtreeMinTileDim) ?? 16.0
        }
    }
    
    public struct TileMatchRecord: Codable, Sendable {
        public var index: Int
        public var imagePath: String?
        public var score: Float
        public var thumbnailFile: String?
        
        public init(index: Int, imagePath: String?, score: Float, thumbnailFile: String? = nil) {
            self.index = index
            self.imagePath = imagePath
            self.score = score
            self.thumbnailFile = thumbnailFile
        }
        
        enum CodingKeys: String, CodingKey {
            case index, imagePath, score, thumbnailFile
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            index = try container.decodeIfPresent(Int.self, forKey: .index) ?? 0
            imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
            score = try container.decodeIfPresent(Float.self, forKey: .score) ?? 0.0
            thumbnailFile = try container.decodeIfPresent(String.self, forKey: .thumbnailFile)
        }
    }
}

/// An unpacked project bundle containing project metadata, embedded thumbnails, preview image, and target image.
public struct ProjectBundle: Sendable {
    public let project: MosaicLabProject
    public let targetImage: CGImage?
    public let thumbnails: [String: CGImage]
    public let previewImage: CGImage?
    
    public init(
        project: MosaicLabProject,
        targetImage: CGImage? = nil,
        thumbnails: [String: CGImage] = [:],
        previewImage: CGImage? = nil
    ) {
        self.project = project
        self.targetImage = targetImage
        self.thumbnails = thumbnails
        self.previewImage = previewImage
    }
}

/// Thread-safe manager for saving and loading zipped .mosaiclab project files.
public final class MosaicProjectManager: @unchecked Sendable {
    public static let shared = MosaicProjectManager()
    
    public init() {}
    
    /// Saves a project to a compressed .mosaiclab zip archive, including QuickLook previews and embedded thumbnails.
    public func saveProject(
        _ project: MosaicLabProject,
        targetImage: CGImage? = nil,
        previewImage: CGImage? = nil,
        thumbnails: [String: CGImage] = [:],
        to destinationURL: URL
    ) throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("mosaiclab_save_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        // 1. Write mosaic.json
        let jsonURL = tempDir.appendingPathComponent("mosaic.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)
        try data.write(to: jsonURL)
        
        // 2. Write QuickLook previews for native macOS Finder Spacebar support
        if let preview = previewImage {
            let qlDir = tempDir.appendingPathComponent("QuickLook")
            try? fileManager.createDirectory(at: qlDir, withIntermediateDirectories: true)
            
            // Standard QuickLook preview image
            _ = Self.writeCGImage(preview, to: qlDir.appendingPathComponent("Preview.png"), as: UTType.png.identifier as CFString)
            // Smaller thumbnail icon for Finder
            _ = Self.writeCGImage(preview, to: qlDir.appendingPathComponent("Thumbnail.jpg"), as: UTType.jpeg.identifier as CFString, quality: 0.80)
        }
        
        // 3. Write target image if provided (ensures standalone portability via native HEIC)
        if let target = targetImage {
            let targetDir = tempDir.appendingPathComponent("Target")
            try? fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
            _ = Self.writeCGImage(target, to: targetDir.appendingPathComponent("target.heic"), as: "public.heic" as CFString, quality: 0.85)
        }
        
        // 4. Write constituent tile thumbnails (256px Retina HEIC)
        if !thumbnails.isEmpty {
            let thumbsDir = tempDir.appendingPathComponent("Thumbnails")
            try? fileManager.createDirectory(at: thumbsDir, withIntermediateDirectories: true)
            for (filename, thumbImg) in thumbnails {
                let thumbURL = thumbsDir.appendingPathComponent(filename)
                let uti: CFString = filename.hasSuffix(".heic") ? ("public.heic" as CFString) : (UTType.jpeg.identifier as CFString)
                _ = Self.writeCGImage(thumbImg, to: thumbURL, as: uti, quality: 0.80)
            }
        }
        
        // 5. Remove existing file at destination if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // 6. Compress folder into .mosaiclab archive using macOS native ditto
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--norsrc", tempDir.path, destinationURL.path]
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(
                domain: "MosaicProjectManager",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Failed to compress .mosaiclab project archive."]
            )
        }
    }
    
    /// Convenience overload for saving without extra assets.
    public func saveProject(
        _ project: MosaicLabProject,
        to destinationURL: URL
    ) throws {
        try saveProject(project, targetImage: nil, previewImage: nil, thumbnails: [:], to: destinationURL)
    }
    
    /// Loads a project bundle from a .mosaiclab zip archive, decoding project metadata, embedded thumbnails, and preview.
    public func loadProjectBundle(from sourceURL: URL) throws -> ProjectBundle {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("mosaiclab_load_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        // 1. Try extracting with ditto (handles .mosaiclab and .macosaix zip containers)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", sourceURL.path, tempDir.path]
        try? process.run()
        process.waitUntilExit()
        
        var targetJSONURL = tempDir.appendingPathComponent("mosaic.json")
        var baseDir = tempDir
        if !fileManager.fileExists(atPath: targetJSONURL.path) {
            if let enumerator = fileManager.enumerator(at: tempDir, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    if fileURL.lastPathComponent == "mosaic.json" {
                        targetJSONURL = fileURL
                        baseDir = fileURL.deletingLastPathComponent()
                        break
                    }
                }
            }
        }
        
        if fileManager.fileExists(atPath: targetJSONURL.path) {
            let data = try Data(contentsOf: targetJSONURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let project = try decoder.decode(MosaicLabProject.self, from: data)
            
            // Extract preview image if present
            var previewImg: CGImage? = nil
            let previewPNG = baseDir.appendingPathComponent("QuickLook/Preview.png")
            let previewJPG = baseDir.appendingPathComponent("QuickLook/Preview.jpg")
            if fileManager.fileExists(atPath: previewPNG.path) {
                previewImg = Self.readCGImage(from: previewPNG)
            } else if fileManager.fileExists(atPath: previewJPG.path) {
                previewImg = Self.readCGImage(from: previewJPG)
            }
            
            // Extract target image if present (supports native HEIC and legacy JPG)
            var targetImg: CGImage? = nil
            let targetHEIC = baseDir.appendingPathComponent("Target/target.heic")
            let targetPath = baseDir.appendingPathComponent("Target/target.jpg")
            if fileManager.fileExists(atPath: targetHEIC.path) {
                targetImg = Self.readCGImage(from: targetHEIC)
            } else if fileManager.fileExists(atPath: targetPath.path) {
                targetImg = Self.readCGImage(from: targetPath)
            }
            
            // Extract embedded thumbnails
            var loadedThumbnails: [String: CGImage] = [:]
            let thumbsDir = baseDir.appendingPathComponent("Thumbnails")
            if let files = try? fileManager.contentsOfDirectory(at: thumbsDir, includingPropertiesForKeys: nil) {
                for fileURL in files {
                    if let img = Self.readCGImage(from: fileURL) {
                        loadedThumbnails[fileURL.lastPathComponent] = img
                    }
                }
            }
            
            return ProjectBundle(
                project: project,
                targetImage: targetImg,
                thumbnails: loadedThumbnails,
                previewImage: previewImg
            )
        }
        
        // 2. Fallback: If opened as a plain uncompressed JSON file
        let rawData = try Data(contentsOf: sourceURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let project = try decoder.decode(MosaicLabProject.self, from: rawData)
        return ProjectBundle(project: project, targetImage: nil, thumbnails: [:], previewImage: nil)
    }
    
    /// Loads a project from a .mosaiclab zip archive or raw JSON file.
    public func loadProject(from sourceURL: URL) throws -> MosaicLabProject {
        return try loadProjectBundle(from: sourceURL).project
    }
    
    public static func writeCGImage(
        _ image: CGImage,
        to url: URL,
        as uti: CFString = "public.heic" as CFString,
        quality: Float = 0.80
    ) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, uti, 1, nil) else { return false }
        let opts: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(dest, image, opts as CFDictionary)
        return CGImageDestinationFinalize(dest)
    }
    
    public static func readCGImage(from url: URL) -> CGImage? {
        let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, opts as CFDictionary) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
}

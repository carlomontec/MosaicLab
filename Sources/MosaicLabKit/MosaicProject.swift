import Foundation
import CoreGraphics

/// Data representation of a MacOSaiX Remake project file (.macosaix)
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
    
    public struct ProjectSettings: Codable, Sendable {
        public var shapeType: String
        public var tilesAcross: Int
        public var tilesDown: Int
        public var curviness: Float
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
            curviness: Float,
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
            shapeType = try container.decode(String.self, forKey: .shapeType)
            tilesAcross = try container.decode(Int.self, forKey: .tilesAcross)
            tilesDown = try container.decode(Int.self, forKey: .tilesDown)
            curviness = try container.decode(Float.self, forKey: .curviness)
            strokeWidth = try container.decode(Double.self, forKey: .strokeWidth)
            strokeColor = try container.decodeIfPresent(String.self, forKey: .strokeColor) ?? "black"
            maxReuse = try container.decode(Int.self, forKey: .maxReuse)
            minDistance = try container.decode(Int.self, forKey: .minDistance)
            colorMetric = try container.decode(String.self, forKey: .colorMetric)
            blendOpacity = try container.decode(Double.self, forKey: .blendOpacity)
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
        
        public init(index: Int, imagePath: String?, score: Float) {
            self.index = index
            self.imagePath = imagePath
            self.score = score
        }
    }
}

/// Thread-safe manager for saving and loading zipped .macosaix project files.
public final class MosaicProjectManager: @unchecked Sendable {
    public static let shared = MosaicProjectManager()
    
    public init() {}
    
    /// Saves a project to a compressed .macosaix zip archive.
    public func saveProject(
        _ project: MosaicLabProject,
        to destinationURL: URL
    ) throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("macosaix_save_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        // 1. Write mosaic.json
        let jsonURL = tempDir.appendingPathComponent("mosaic.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)
        try data.write(to: jsonURL)
        
        // 2. Remove existing file at destination if present
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // 3. Compress folder into .macosaix archive using macOS native ditto
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--norsrc", tempDir.path, destinationURL.path]
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(
                domain: "MosaicProjectManager",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Failed to compress .macosaix project archive."]
            )
        }
    }
    
    /// Loads a project from a .macosaix zip archive or raw JSON file.
    public func loadProject(from sourceURL: URL) throws -> MosaicLabProject {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("macosaix_load_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        // 1. Try extracting with ditto (handles .macosaix zip containers)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", sourceURL.path, tempDir.path]
        try? process.run()
        process.waitUntilExit()
        
        let jsonURL = tempDir.appendingPathComponent("mosaic.json")
        if fileManager.fileExists(atPath: jsonURL.path) {
            let data = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(MosaicLabProject.self, from: data)
        }
        
        // 2. Fallback: If opened as a plain uncompressed JSON file
        let rawData = try Data(contentsOf: sourceURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MosaicLabProject.self, from: rawData)
    }
}

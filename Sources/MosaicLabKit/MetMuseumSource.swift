import Foundation
import CoreGraphics

/// Preset curated department / theme for The Metropolitan Museum of Art Open Access collection.
public struct MetDepartmentPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let departmentID: Int?
    public let defaultQuery: String
    public let iconName: String
    
    public init(id: String, title: String, departmentID: Int?, defaultQuery: String, iconName: String = "building.columns") {
        self.id = id
        self.title = title
        self.departmentID = departmentID
        self.defaultQuery = defaultQuery
        self.iconName = iconName
    }
}

/// Image source fetching Open Access public-domain artworks from The Metropolitan Museum of Art API.
public final class MetMuseumSource: MosaicImageSource, @unchecked Sendable {
    public static let shared = MetMuseumSource()
    
    public let id: String = "met-museum"
    public let displayName: String = "The Met Collection"
    public let iconName: String = "building.columns"
    
    public static let presets: [MetDepartmentPreset] = [
        MetDepartmentPreset(id: "european-paintings", title: "European Paintings", departmentID: 11, defaultQuery: "painting", iconName: "paintpalette"),
        MetDepartmentPreset(id: "asian-art", title: "Asian Art", departmentID: 6, defaultQuery: "art", iconName: "globe.asia.australia"),
        MetDepartmentPreset(id: "drawings-prints", title: "Drawings & Prints", departmentID: 9, defaultQuery: "print", iconName: "pencil.and.outline"),
        MetDepartmentPreset(id: "photographs", title: "Photographs", departmentID: 19, defaultQuery: "photograph", iconName: "camera"),
        MetDepartmentPreset(id: "medieval-art", title: "Medieval Art", departmentID: 17, defaultQuery: "medieval", iconName: "shield"),
        MetDepartmentPreset(id: "custom", title: "Custom Search...", departmentID: nil, defaultQuery: "", iconName: "magnifyingglass")
    ]
    
    public var selectedPresetID: String = "european-paintings"
    public var customQuery: String = ""
    public var resultLimit: Int = 500
    
    private let loader = ImageLoader()
    private let session: URLSession
    private let userAgent = "MosaicLab/0.1.0 (+https://github.com/carlomontec/MosaicLab; info@mosaiclab.app)"
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }
    
    public var isConfigured: Bool {
        return true
    }
    
    public var effectiveQuery: String {
        if selectedPresetID == "custom" {
            let trimmed = customQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "sunflower" : trimmed
        }
        if let preset = Self.presets.first(where: { $0.id == selectedPresetID }) {
            return preset.defaultQuery
        }
        return "painting"
    }
    
    public var effectiveDepartmentID: Int? {
        if selectedPresetID == "custom" {
            return nil
        }
        return Self.presets.first(where: { $0.id == selectedPresetID })?.departmentID
    }
    
    public func enumerateCandidates(progress: (@Sendable (Int, Int) -> Void)?) async throws -> [MosaicCandidateItem] {
        guard let searchURL = buildSearchURL(query: effectiveQuery, departmentID: effectiveDepartmentID) else {
            return []
        }
        
        var request = URLRequest(url: searchURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let objectIDs = json["objectIDs"] as? [Int], !objectIDs.isEmpty else {
            return []
        }
        
        let targetCount = min(resultLimit, objectIDs.count)
        
        var items: [MosaicCandidateItem] = []
        items.reserveCapacity(targetCount)
        
        // Fetch object details in controlled parallel batches (max 30 concurrent requests)
        let concurrency = 30
        var index = 0
        while items.count < targetCount && index < objectIDs.count {
            let endIndex = min(index + concurrency, objectIDs.count)
            let chunk = Array(objectIDs[index..<endIndex])
            index = endIndex
            
            let chunkResults = await withTaskGroup(of: MosaicCandidateItem?.self) { group in
                for objectID in chunk {
                    group.addTask { [weak self] in
                        guard let self = self else { return nil }
                        return await self.fetchObjectDetails(objectID: objectID)
                    }
                }
                var results: [MosaicCandidateItem] = []
                for await item in group {
                    if let item = item {
                        results.append(item)
                    }
                }
                return results
            }
            
            items.append(contentsOf: chunkResults)
            progress?(min(items.count, targetCount), targetCount)
        }
        
        progress?(items.count, items.count)
        return items
    }
    
    public func loadCandidateThumbnail(for item: MosaicCandidateItem) async throws -> Data? {
        guard let url = item.thumbnailURL ?? item.originalURL else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        
        if let cgImage = loader.decodeImage(from: data, maxPixelSize: 256) {
            MosaicThumbnailCache.shared.setThumbnail(cgImage, for: item.canonicalURL)
        }
        
        return loader.loadThumbnail(from: data, targetSize: 16)
    }
    
    public func loadDisplayThumbnail(for item: MosaicCandidateItem, maxPixelSize: Int = 140) async throws -> CGImage? {
        if let cached = MosaicThumbnailCache.shared.thumbnail(for: item.canonicalURL, maxPixelSize: maxPixelSize) {
            return cached
        }
        guard let url = item.thumbnailURL ?? item.originalURL else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        if let cgImage = loader.decodeImage(from: data, maxPixelSize: maxPixelSize) {
            MosaicThumbnailCache.shared.setThumbnail(cgImage, for: item.canonicalURL)
            return cgImage
        }
        return nil
    }
    
    public func loadFullResolutionImage(for item: MosaicCandidateItem) async throws -> CGImage? {
        guard let url = item.originalURL ?? item.thumbnailURL else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        return loader.decodeImage(from: data, maxPixelSize: nil)
    }
    
    // MARK: - Private Helpers
    
    private func buildSearchURL(query: String, departmentID: Int?) -> URL? {
        var components = URLComponents(string: "https://collectionapi.metmuseum.org/public/collection/v1/search")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "hasImages", value: "true"),
            URLQueryItem(name: "isPublicDomain", value: "true"),
            URLQueryItem(name: "q", value: query)
        ]
        if let deptID = departmentID {
            queryItems.append(URLQueryItem(name: "departmentId", value: "\(deptID)"))
        }
        components?.queryItems = queryItems
        return components?.url
    }
    
    private func fetchObjectDetails(objectID: Int) async -> MosaicCandidateItem? {
        guard let url = URL(string: "https://collectionapi.metmuseum.org/public/collection/v1/objects/\(objectID)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let isPublicDomain = json["isPublicDomain"] as? Bool ?? false
        guard isPublicDomain else { return nil }
        
        let primaryImageSmallStr = json["primaryImageSmall"] as? String ?? ""
        let primaryImageStr = json["primaryImage"] as? String ?? ""
        
        // Ensure at least one image URL exists
        let thumbURL = URL(string: primaryImageSmallStr)
        let origURL = URL(string: primaryImageStr) ?? thumbURL
        guard origURL != nil || thumbURL != nil else { return nil }
        
        let title = (json["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled"
        let artist = (json["artistDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = artist.isEmpty ? title : "\(title) — \(artist)"
        
        return MosaicCandidateItem(
            id: "\(objectID)",
            displayName: displayName,
            sourceProviderID: id,
            originalURL: origURL,
            thumbnailURL: thumbURL
        )
    }
}

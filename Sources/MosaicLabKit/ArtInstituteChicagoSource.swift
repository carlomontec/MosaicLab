import Foundation
import CoreGraphics

/// Preset curated collection for Art Institute of Chicago Open Access artworks.
public struct AICPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let searchQuery: String
    public let iconName: String
    
    public init(id: String, title: String, searchQuery: String, iconName: String = "paintpalette") {
        self.id = id
        self.title = title
        self.searchQuery = searchQuery
        self.iconName = iconName
    }
}

/// Image source fetching Open Access public-domain masterpieces from the Art Institute of Chicago (AIC).
public final class ArtInstituteChicagoSource: MosaicImageSource, @unchecked Sendable {
    public static let shared = ArtInstituteChicagoSource()
    
    public let id: String = "artic"
    public let displayName: String = "Art Institute of Chicago"
    public let iconName: String = "paintpalette.fill"
    
    public static let presets: [AICPreset] = [
        AICPreset(id: "masterpieces", title: "Famous Masterpieces", searchQuery: "masterpiece OR impressionism", iconName: "star.fill"),
        AICPreset(id: "paintings", title: "Paintings & Murals", searchQuery: "painting", iconName: "paintpalette"),
        AICPreset(id: "drawings", title: "Prints & Drawings", searchQuery: "print OR drawing", iconName: "pencil.and.outline"),
        AICPreset(id: "asian", title: "Asian Art & Woodblocks", searchQuery: "woodblock OR japanese OR chinese", iconName: "globe.asia.australia"),
        AICPreset(id: "custom", title: "Custom Search...", searchQuery: "", iconName: "magnifyingglass")
    ]
    
    public var selectedPresetID: String = "masterpieces"
    public var customQuery: String = ""
    public var resultLimit: Int = 1000
    
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
            return trimmed.isEmpty ? "painting" : trimmed
        }
        if let preset = Self.presets.first(where: { $0.id == selectedPresetID }) {
            return preset.searchQuery
        }
        return "masterpiece"
    }
    
    public func enumerateCandidates(progress: (@Sendable (Int, Int) -> Void)?) async throws -> [MosaicCandidateItem] {
        var items: [MosaicCandidateItem] = []
        var page = 1
        let targetTotal = max(50, min(resultLimit, 5000))
        let perPage = 100
        
        while items.count < targetTotal {
            let limitForThisPage = min(perPage, targetTotal - items.count)
            guard let url = buildSearchURL(query: effectiveQuery, page: page, limit: limitForThisPage) else {
                break
            }
            
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                break
            }
            
            let pageItems = parseSearchResponse(data: data)
            if pageItems.isEmpty {
                break
            }
            
            items.append(contentsOf: pageItems)
            progress?(items.count, targetTotal)
            page += 1
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
    
    private func buildSearchURL(query: String, page: Int, limit: Int) -> URL? {
        var components = URLComponents(string: "https://api.artic.edu/api/v1/artworks/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "query[term][is_public_domain]", value: "true"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "fields", value: "id,title,artist_display,image_id")
        ]
        return components?.url
    }
    
    private func parseSearchResponse(data: Data) -> [MosaicCandidateItem] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let artworks = json["data"] as? [[String: Any]] else {
            return []
        }
        
        var results: [MosaicCandidateItem] = []
        for artwork in artworks {
            guard let idNum = artwork["id"] as? Int,
                  let imageId = artwork["image_id"] as? String, !imageId.isEmpty else {
                continue
            }
            
            let title = (artwork["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled"
            let artistRaw = (artwork["artist_display"] as? String)?.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let displayName = artistRaw.isEmpty ? title : "\(title) — \(artistRaw)"
            
            let thumbURL = URL(string: "https://www.artic.edu/iiif/2/\(imageId)/full/256,/0/default.jpg")
            let fullURL = URL(string: "https://www.artic.edu/iiif/2/\(imageId)/full/843,/0/default.jpg") ?? thumbURL
            
            let item = MosaicCandidateItem(
                id: "\(idNum)",
                displayName: displayName,
                sourceProviderID: id,
                originalURL: fullURL,
                thumbnailURL: thumbURL
            )
            results.append(item)
        }
        return results
    }
}

import Foundation
import CoreGraphics

/// Preset curated collection for Biodiversity Heritage Library search.
public struct BHLPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let searchQuery: String
    public let iconName: String
    
    public init(id: String, title: String, searchQuery: String, iconName: String = "leaf") {
        self.id = id
        self.title = title
        self.searchQuery = searchQuery
        self.iconName = iconName
    }
}

/// Image source fetching high-resolution public-domain biological and botanical plates from BHL via Wikimedia Commons GLAM.
public final class BHLSource: MosaicImageSource, @unchecked Sendable {
    public static let shared = BHLSource()
    
    public let id: String = "bhl"
    public let displayName: String = "Biodiversity Heritage"
    public let iconName: String = "leaf.fill"
    
    public static let presets: [BHLPreset] = [
        BHLPreset(id: "botanical", title: "Botanical Plates & Flora", searchQuery: "\"Biodiversity Heritage Library\" (botanical OR flower OR plant OR flora)", iconName: "leaf"),
        BHLPreset(id: "birds", title: "Birds & Wildlife (Audubon)", searchQuery: "\"Biodiversity Heritage Library\" (bird OR wildlife OR fauna OR ornithology)", iconName: "bird"),
        BHLPreset(id: "insects", title: "Insects & Butterflies", searchQuery: "\"Biodiversity Heritage Library\" (butterfly OR insect OR beetle OR entomology)", iconName: "ant"),
        BHLPreset(id: "marine", title: "Marine Life & Shells", searchQuery: "\"Biodiversity Heritage Library\" (fish OR marine OR shell OR ocean OR mollusk)", iconName: "water.waves"),
        BHLPreset(id: "all", title: "All BHL Archives", searchQuery: "\"Biodiversity Heritage Library\"", iconName: "books.vertical"),
        BHLPreset(id: "custom", title: "Custom BHL Search...", searchQuery: "", iconName: "magnifyingglass")
    ]
    
    public var selectedPresetID: String = "botanical"
    public var customQuery: String = ""
    public var resultLimit: Int = 1000
    
    private let loader = ImageLoader()
    private let session: URLSession
    private let userAgent = "MosaicLab/0.1.0 (+https://github.com/carlomontec/MosaicLab; info@mosaiclab.app)"
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }
    
    public var isConfigured: Bool {
        return true
    }
    
    public var effectiveQuery: String {
        if selectedPresetID == "custom" {
            let trimmed = customQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "\"Biodiversity Heritage Library\""
            } else {
                return "\"Biodiversity Heritage Library\" \(trimmed)"
            }
        }
        if let preset = Self.presets.first(where: { $0.id == selectedPresetID }) {
            return preset.searchQuery
        }
        return "\"Biodiversity Heritage Library\" (botanical OR flower OR plant)"
    }
    
    public func enumerateCandidates(progress: (@Sendable (Int, Int) -> Void)?) async throws -> [MosaicCandidateItem] {
        var items: [MosaicCandidateItem] = []
        var continueOffset: String? = nil
        let targetTotal = max(50, min(resultLimit, 10000))
        
        while items.count < targetTotal {
            let batchLimit = min(50, targetTotal - items.count)
            guard let url = buildSearchURL(query: effectiveQuery, limit: batchLimit, continueOffset: continueOffset) else {
                break
            }
            
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                break
            }
            
            let (newItems, nextOffset) = parseSearchResponse(data: data)
            if newItems.isEmpty {
                break
            }
            
            items.append(contentsOf: newItems)
            progress?(items.count, targetTotal)
            
            if let next = nextOffset, !next.isEmpty, items.count < targetTotal {
                continueOffset = next
            } else {
                break
            }
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
    
    private func buildSearchURL(query: String, limit: Int, continueOffset: String?) -> URL? {
        var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: query),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: "\(limit)"),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url|size"),
            URLQueryItem(name: "iiurlwidth", value: "256"),
            URLQueryItem(name: "format", value: "json")
        ]
        if let offset = continueOffset {
            queryItems.append(URLQueryItem(name: "gsroffset", value: offset))
            queryItems.append(URLQueryItem(name: "continue", value: "gsroffset||"))
        }
        components?.queryItems = queryItems
        return components?.url
    }
    
    private func parseSearchResponse(data: Data) -> ([MosaicCandidateItem], String?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = json["query"] as? [String: Any],
              let pages = query["pages"] as? [String: [String: Any]] else {
            return ([], nil)
        }
        
        let continueDict = json["continue"] as? [String: Any]
        let nextOffset: String?
        if let offsetNum = continueDict?["gsroffset"] as? Int {
            nextOffset = "\(offsetNum)"
        } else if let offsetStr = continueDict?["gsroffset"] as? String {
            nextOffset = offsetStr
        } else {
            nextOffset = nil
        }
        
        var results: [MosaicCandidateItem] = []
        for (_, pageInfo) in pages {
            guard let title = pageInfo["title"] as? String,
                  let pageId = pageInfo["pageid"] as? Int,
                  let imageInfoArray = pageInfo["imageinfo"] as? [[String: Any]],
                  let firstInfo = imageInfoArray.first,
                  let originalURLStr = firstInfo["url"] as? String,
                  let originalURL = URL(string: originalURLStr) else {
                continue
            }
            
            let thumbURLStr = firstInfo["thumburl"] as? String
            let thumbURL = thumbURLStr.flatMap { URL(string: $0) }
            
            var cleanTitle = title
            if cleanTitle.hasPrefix("File:") {
                cleanTitle = String(cleanTitle.dropFirst(5))
            }
            cleanTitle = cleanTitle.replacingOccurrences(of: "_", with: " ")
            
            let item = MosaicCandidateItem(
                id: "\(pageId)",
                displayName: cleanTitle,
                sourceProviderID: id,
                originalURL: originalURL,
                thumbnailURL: thumbURL
            )
            results.append(item)
        }
        return (results, nextOffset)
    }
}

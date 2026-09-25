import Foundation
import CoreGraphics
import MosaicLabKit

func printUsage() {
    print("""
    MosaicLab CLI v0.1.0 (Apple Silicon Native)
    A tool for creating high-resolution photomosaics using modern image processing algorithms.
    Engineered by Carlo Monjaraz-Tec (2026). Inspired by classic MacOSaiX.
    
    Usage:
      mosaiclab-cli --target <image> --sources <folder> [options]
      
    Options:
      --target <path>        Target image to turn into a mosaic (HEIC, JPEG, PNG, etc.)
      --sources <folder>     Folder of source photos (HEIC, JPEG, PNG, etc.)
      --output <path>        Output image path (default: mosaic.png)
      --shape <type>         Tile shape: rect | hex | puzzle | quadtree (default: rect)
      --across <N>           Tiles horizontally (default: 30, or base across for quadtree)
      --down <N>             Tiles vertically (default: 20, or base down for quadtree)
      --quadtree-depth <N>   Max quadtree subdivision depth 1 - 5 (default: 3)
      --quadtree-thresh <f>  Quadtree detail sensitivity threshold 0.02 - 0.50 (default: 0.15)
      --quadtree-balance <b> Enforce 2:1 balanced transitions true|false (default: true)
      --quadtree-algo <a>    Segmentation algorithm: julia | color | variance | whole (default: julia)
      --quadtree-min-tile <N> Smallest tile dimension in pixels (default: 16)
      --quadtree-mode <m>    Detail mode for variance: edge | balanced | texture (default: balanced)
      --curviness <float>    Puzzle edge curviness 0.0 - 1.0 (default: 0.5)
      --max-reuse <N>        Maximum times any photo can be reused (default: 0 = unlimited)
      --min-distance <N>     Minimum tile distance between identical photos (default: 2)
      --width <pixels>       Output mosaic pixel width (default: 2400)
      --stroke <pixels>      Tile border stroke width (default: 0.0)
      --stroke-color <c>     Cutline border stroke color: black | white (default: black)
      --color-transfer <f>   Reinhard perceptual color transfer 0.0 - 1.0 (default: 0.0)
      --edge-weight <f>      Edge-aware directional matching 0.0 - 1.0 (default: 0.0)
      --metric <type>        Color metric: riemersma | rgb | monochrome (default: riemersma)
      --force                Bypass memory safety check if estimated RAM is very high
      --help                 Show this help message
    """)
}

func parseArguments() -> [String: String] {
    var args: [String: String] = [:]
    var key: String? = nil
    
    for arg in CommandLine.arguments.dropFirst() {
        if arg.hasPrefix("--") {
            key = String(arg.dropFirst(2))
            args[key!] = ""
        } else if let k = key {
            args[k] = arg
            key = nil
        }
    }
    return args
}

func main() async {
    let args = parseArguments()
    
    if args["help"] != nil || args.isEmpty {
        printUsage()
        exit(0)
    }
    
    guard let targetPath = args["target"] else {
        print("Error: --target argument is required.")
        printUsage()
        exit(1)
    }
    
    guard let sourcesPath = args["sources"] else {
        print("Error: --sources argument is required.")
        printUsage()
        exit(1)
    }
    
    let outputPath = args["output"] ?? "mosaic.png"
    let shapeStr = args["shape"]?.lowercased() ?? "rect"
    let across = Int(args["across"] ?? "30") ?? 30
    let down = Int(args["down"] ?? "20") ?? 20
    let curviness = Float(args["curviness"] ?? "0.5") ?? 0.5
    let maxReuse = Int(args["max-reuse"] ?? "0") ?? 0
    let minDistance = Int(args["min-distance"] ?? "2") ?? 2
    let outputWidth = Int(args["width"] ?? "2400") ?? 2400
    let strokeWidth = Float(args["stroke"] ?? "0.0") ?? 0.0
    let strokeColor = args["stroke-color"]?.lowercased() == "white" ? "white" : "black"
    let colorTransfer = max(0.0, min(1.0, Float(args["color-transfer"] ?? "0.0") ?? 0.0))
    let edgeWeight = max(0.0, min(1.0, Float(args["edge-weight"] ?? "0.0") ?? 0.0))
    let quadtreeDepth = max(1, min(5, Int(args["quadtree-depth"] ?? "3") ?? 3))
    let quadtreeThreshold = max(0.01, min(1.0, Float(args["quadtree-thresh"] ?? (args["quadtree-threshold"] ?? "0.15")) ?? 0.15))
    let quadtreeBalanced = (args["quadtree-balance"]?.lowercased() != "false" && args["quadtree-balance"] != "0")
    let quadtreeAlgoStr = args["quadtree-algo"]?.lowercased() ?? "julia"
    let quadtreeAlgo: MosaicQuadtreeAlgorithm = {
        switch quadtreeAlgoStr {
        case "color", "colorrange", "rgb": return .colorRange
        case "variance", "hybrid": return .variance
        case "whole", "wholecanvas", "canvas": return .wholeCanvas
        default: return .juliaRange
        }
    }()
    let quadtreeMinTileDim = max(4.0, min(128.0, Float(args["quadtree-min-tile"] ?? "16") ?? 16.0))
    let quadtreeModeStr = args["quadtree-mode"]?.lowercased() ?? "balanced"
    let quadtreeDetailAlpha: Float = {
        switch quadtreeModeStr {
        case "edge", "edge-aware": return 0.2
        case "texture", "texture-sensitive": return 0.8
        default: return 0.5
        }
    }()
    let metricStr = args["metric"]?.lowercased() ?? "riemersma"
    
    let shapeType: MosaicShapeType
    switch shapeStr {
    case "hex", "hexagonal":
        shapeType = .hexagonal
    case "puzzle":
        shapeType = .puzzle
    case "quadtree", "adaptive":
        shapeType = .quadtree
    default:
        shapeType = .rectangular
    }
    
    let colorMetric: MosaicColorMetric
    switch metricStr {
    case "rgb":
        colorMetric = .RGB
    case "monochrome", "mono", "bw":
        colorMetric = .monochrome
    default:
        colorMetric = .riemersma
    }
    
    let targetURL = URL(fileURLWithPath: targetPath)
    let sourcesURL = URL(fileURLWithPath: sourcesPath)
    let outputURL = URL(fileURLWithPath: outputPath)
    
    print("==================================================")
    print("  MosaicLab Engine v0.1.0")
    print("==================================================")
    print("Target:        \(targetURL.lastPathComponent)")
    print("Sources dir:   \(sourcesURL.path)")
    print("Shape:         \(shapeStr.uppercased())")
    if shapeType == .quadtree {
        if quadtreeAlgo == .wholeCanvas {
            print("Canvas root:   Single top-down decomposition")
        } else {
            print("Base grid:     \(across) x \(down)")
        }
        let algoName: String = {
            switch quadtreeAlgo {
            case .colorRange: return "RGB Color Range"
            case .variance: return "Variance / Hybrid"
            case .wholeCanvas: return "Whole Canvas Quadtree"
            default: return "Julia Range (max - min)"
            }
        }()
        print("Algorithm:     \(algoName)")
        print("Min tile size: \(Int(quadtreeMinTileDim)) px")
        print("Subdivision:   Max Depth \(quadtreeDepth), Sensitivity \(Int(quadtreeThreshold * 100))%, 2:1 Balanced: \(quadtreeBalanced ? "Yes" : "No")")
        if quadtreeAlgo == .variance {
            print("Detail mode:   \(quadtreeModeStr) (α=\(String(format: "%.1f", quadtreeDetailAlpha)))")
        }
    } else {
        print("Grid:          \(across) x \(down) tiles")
    }
    print("Max reuse:     \(maxReuse == 0 ? "Unlimited" : "\(maxReuse)")")
    print("Min distance:  \(minDistance) tiles")
    print("Color metric:  \(metricStr)")
    if strokeWidth > 0.001 {
        print("Cutlines:      \(strokeWidth) px (\(strokeColor))")
    }
    if colorTransfer > 0.001 {
        print("Color transfer: \(Int(colorTransfer * 100))%")
    }
    if edgeWeight > 0.001 {
        print("Edge weight:   \(Int(edgeWeight * 100))%")
    }
    print("Output width:  \(outputWidth) px")
    print("Output file:   \(outputURL.path)")
    print("--------------------------------------------------")
    
    let engine = MosaicEngine(
        shapeType: shapeType,
        tilesAcross: across,
        tilesDown: down,
        curviness: curviness,
        maxReuse: maxReuse,
        minDistance: minDistance,
        metric: colorMetric,
        edgeWeight: edgeWeight,
        quadtreeMaxDepth: quadtreeDepth,
        quadtreeThreshold: quadtreeThreshold,
        quadtreeBalanced: quadtreeBalanced,
        quadtreeDetailAlpha: quadtreeDetailAlpha,
        quadtreeAlgorithm: quadtreeAlgo,
        quadtreeMinTileDim: quadtreeMinTileDim
    )
    
    do {
        print("Preparing target image and tile geometries...")
        let prepStart = Date()
        try engine.prepare(targetURL: targetURL)
        print(String(format: "Tiles prepared in %.2f seconds.", Date().timeIntervalSince(prepStart)))
    } catch {
        print("Error preparing mosaic: \(error.localizedDescription)")
        exit(1)
    }
    
    let loader = ImageLoader()
    print("Scanning source folder for images...")
    let imageURLs = loader.findImages(in: sourcesURL)
    if imageURLs.isEmpty {
        print("Error: No supported images found in \(sourcesURL.path).")
        exit(1)
    }
    
    let heicCount = imageURLs.filter {
        let ext = $0.pathExtension.lowercased()
        return ext == "heic" || ext == "heif" || ext == "hif"
    }.count
    print("Found \(imageURLs.count) photos (\(heicCount) HEIC/HIF).")
    
    // RAM & Memory Pre-Flight Check
    let scale = CGFloat(outputWidth) / engine.mosaicSize.width
    let outputHeight = max(1, Int(engine.mosaicSize.height * scale))
    let memEstimate = MemoryChecker.estimate(
        sourceImageCount: imageURLs.count,
        tileCount: engine.tiles.count,
        outputWidth: outputWidth,
        outputHeight: outputHeight
    )
    MemoryChecker.printReport(
        estimate: memEstimate,
        sourceCount: imageURLs.count,
        tileCount: engine.tiles.count,
        width: outputWidth,
        height: outputHeight
    )
    
    if memEstimate.isDangerous && args["force"] == nil {
        print("\n[ABORTED] The estimated peak RAM exceeds 80% of your system's physical memory.")
        print("To run anyway, add --force to your command line, or reduce --width.")
        exit(1)
    }
    
    print("Extracting thumbnails and running matching...")
    
    let matchStart = Date()
    var processedCount = 0
    let totalImages = imageURLs.count
    
    for url in imageURLs {
        if let thumbPixels = loader.loadThumbnail(from: url, targetSize: 16) {
            let candidate = SourceImageCandidate(
                identifier: url.path,
                url: url,
                thumbnailPixels: thumbPixels
            )
            engine.testCandidate(candidate)
        }
        
        processedCount += 1
        if processedCount % 25 == 0 || processedCount == totalImages {
            let percent = Double(processedCount) / Double(totalImages) * 100.0
            let matchedTiles = engine.tiles.filter { $0.bestImageURL != nil }.count
            print(String(format: "\r[%3.0f%%] Processed %d/%d photos | Matched tiles: %d/%d",
                         percent, processedCount, totalImages, matchedTiles, engine.tiles.count),
                  terminator: "")
            fflush(stdout)
        }
    }
    print("")
    print(String(format: "Matching completed in %.2f seconds.", Date().timeIntervalSince(matchStart)))
    
    let matchedTiles = engine.tiles.filter { $0.bestImageURL != nil }.count
    let avgScore: Float
    if matchedTiles > 0 {
        let totalScore = engine.tiles.compactMap { $0.bestImageURL != nil ? $0.bestScore : nil }.reduce(0.0, +)
        avgScore = totalScore / Float(matchedTiles)
    } else {
        avgScore = 1.0
    }
    print(String(format: "Tiles filled: %d / %d (Avg match score: %.3f - lower is better)",
                 matchedTiles, engine.tiles.count, avgScore))
    
    print("Rendering high-resolution mosaic...")
    let renderStart = Date()
    let renderer = MosaicRenderer()
    do {
        try renderer.render(
            tiles: engine.tiles,
            mosaicSize: engine.mosaicSize,
            outputWidth: outputWidth,
            strokeWidth: strokeWidth,
            strokeColor: strokeColor,
            colorTransferStrength: colorTransfer,
            isMonochrome: (colorMetric == .monochrome),
            outputURL: outputURL
        )
        print(String(format: "Rendered and saved to \(outputURL.path) in %.2f seconds.",
                     Date().timeIntervalSince(renderStart)))
        print("Success! Mosaic is ready.")
    } catch {
        print("Error rendering mosaic: \(error.localizedDescription)")
        exit(1)
    }
}

await main()

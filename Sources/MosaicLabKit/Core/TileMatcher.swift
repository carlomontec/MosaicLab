import Foundation
import CoreGraphics
import Accelerate

public enum MosaicColorMetric: Int, Codable, CaseIterable, Sendable {
    case riemersma = 0
    case rgb = 1
    case monochrome = 2
    
    public static let RGB = MosaicColorMetric.rgb
    public static let Monochrome = MosaicColorMetric.monochrome
    public static let Riemersma = MosaicColorMetric.riemersma
}

public typealias ColorMetric = MosaicColorMetric

public struct MosaicEdgeDescriptor: Sendable, Equatable {
    public var bins: (Float, Float, Float, Float, Float, Float, Float, Float)
    public var energy: Float
    public var hasEdges: Bool
    
    public init(
        bins: (Float, Float, Float, Float, Float, Float, Float, Float) = (0, 0, 0, 0, 0, 0, 0, 0),
        energy: Float = 0,
        hasEdges: Bool = false
    ) {
        self.bins = bins
        self.energy = energy
        self.hasEdges = hasEdges
    }
    
    public static func == (lhs: MosaicEdgeDescriptor, rhs: MosaicEdgeDescriptor) -> Bool {
        return lhs.energy == rhs.energy &&
            lhs.hasEdges == rhs.hasEdges &&
            lhs.bins.0 == rhs.bins.0 &&
            lhs.bins.1 == rhs.bins.1 &&
            lhs.bins.2 == rhs.bins.2 &&
            lhs.bins.3 == rhs.bins.3 &&
            lhs.bins.4 == rhs.bins.4 &&
            lhs.bins.5 == rhs.bins.5 &&
            lhs.bins.6 == rhs.bins.6 &&
            lhs.bins.7 == rhs.bins.7
    }
}

public typealias EdgeDescriptor = MosaicEdgeDescriptor

private let MAX_COLOR_DIFF_RIEMERSMA: Float = 255.0 * 255.0 * 9.0
private let MAX_COLOR_DIFF_RGB: Float = 255.0 * 255.0 * 3.0
private let MAX_COLOR_DIFF_MONO: Float = 255.0 * 255.0

@inline(__always)
private func colorDifferenceMono(
    _ r1: UInt8, _ g1: UInt8, _ b1: UInt8,
    _ r2: UInt8, _ g2: UInt8, _ b2: UInt8
) -> Float {
    let y1 = Int(0.2126 * Float(r1) + 0.7152 * Float(g1) + 0.0722 * Float(b1) + 0.5)
    let y2 = Int(0.2126 * Float(r2) + 0.7152 * Float(g2) + 0.0722 * Float(b2) + 0.5)
    let diff = y1 - y2
    return Float(diff * diff)
}

@inline(__always)
private func colorDifferenceRiemersma(
    _ r1: UInt8, _ g1: UInt8, _ b1: UInt8,
    _ r2: UInt8, _ g2: UInt8, _ b2: UInt8
) -> Float {
    let redDiff = Int(r1) - Int(r2)
    let greenDiff = Int(g1) - Int(g2)
    let blueDiff = Int(b1) - Int(b2)
    
    let redAvg = (Float(r1) + Float(r2)) * 0.5
    let rWeight = 2.0 + redAvg / 255.0
    let bWeight = 2.0 + (255.0 - redAvg) / 255.0
    
    return rWeight * Float(redDiff * redDiff) +
           4.0 * Float(greenDiff * greenDiff) +
           bWeight * Float(blueDiff * blueDiff)
}

@inline(__always)
private func colorDifferenceRGB(
    _ r1: UInt8, _ g1: UInt8, _ b1: UInt8,
    _ r2: UInt8, _ g2: UInt8, _ b2: UInt8
) -> Float {
    let rd = Int(r1) - Int(r2)
    let gd = Int(g1) - Int(g2)
    let bd = Int(b1) - Int(b2)
    return Float(rd * rd + gd * gd + bd * bd)
}

public func MacOSaiXComputeEdgeDescriptor(
    _ rgba: UnsafePointer<UInt8>,
    _ width: Int,
    _ height: Int
) -> MosaicEdgeDescriptor {
    return MacOSaiXComputeEdgeDescriptor(rgba: rgba, width: width, height: height)
}

public func MacOSaiXComputeEdgeDescriptor(
    rgba: UnsafePointer<UInt8>,
    width: Int,
    height: Int
) -> MosaicEdgeDescriptor {
    guard width >= 3 && height >= 3 else {
        return MosaicEdgeDescriptor()
    }
    
    let totalPixels = width * height
    var luma = [Float](repeating: 0, count: totalPixels)
    
    for i in 0..<totalPixels {
        let idx = i * 4
        let r = Float(rgba[idx])
        let g = Float(rgba[idx + 1])
        let b = Float(rgba[idx + 2])
        luma[i] = 0.299 * r + 0.587 * g + 0.114 * b
    }
    
    var rawBins = [Float](repeating: 0, count: 8)
    var totalEnergy: Float = 0
    var edgeCount: Int = 0
    
    let pi: Float = .pi
    let binWidth = pi / 8.0
    
    for y in 1..<(height - 1) {
        let rowPrev = (y - 1) * width
        let rowCurr = y * width
        let rowNext = (y + 1) * width
        
        for x in 1..<(width - 1) {
            let gx = (luma[rowPrev + x + 1] - luma[rowPrev + x - 1]) +
                     2.0 * (luma[rowCurr + x + 1] - luma[rowCurr + x - 1]) +
                     (luma[rowNext + x + 1] - luma[rowNext + x - 1])
            
            let gy = (luma[rowNext + x - 1] - luma[rowPrev + x - 1]) +
                     2.0 * (luma[rowNext + x] - luma[rowPrev + x]) +
                     (luma[rowNext + x + 1] - luma[rowPrev + x + 1])
            
            let mag = sqrt(gx * gx + gy * gy)
            totalEnergy += mag
            edgeCount += 1
            
            var angle = atan2(gy, gx)
            if angle < 0 { angle += pi }
            if angle >= pi { angle -= pi }
            
            var binIdx = (angle / binWidth) - 0.5
            if binIdx < 0 { binIdx += 8.0 }
            let b0 = Int(binIdx) % 8
            let b1 = (b0 + 1) % 8
            let frac = binIdx - floor(binIdx)
            
            rawBins[b0] += mag * (1.0 - frac)
            rawBins[b1] += mag * frac
        }
    }
    
    let energy = (edgeCount > 0) ? (totalEnergy / Float(edgeCount)) : 0.0
    let hasEdges = (energy >= 8.0)
    
    var normSq: Float = 0
    for val in rawBins {
        normSq += val * val
    }
    let norm = sqrt(normSq)
    
    var finalBins: (Float, Float, Float, Float, Float, Float, Float, Float) = (0, 0, 0, 0, 0, 0, 0, 0)
    if norm > 0.0001 {
        finalBins = (
            rawBins[0] / norm,
            rawBins[1] / norm,
            rawBins[2] / norm,
            rawBins[3] / norm,
            rawBins[4] / norm,
            rawBins[5] / norm,
            rawBins[6] / norm,
            rawBins[7] / norm
        )
    }
    
    return MosaicEdgeDescriptor(bins: finalBins, energy: energy, hasEdges: hasEdges)
}

public func MosaicCompareEdgeDescriptors(
    _ a: MosaicEdgeDescriptor,
    _ b: MosaicEdgeDescriptor
) -> Float {
    if !a.hasEdges {
        return 0.0
    }
    if !b.hasEdges {
        return 1.0
    }
    
    var dot = a.bins.0 * b.bins.0 +
              a.bins.1 * b.bins.1 +
              a.bins.2 * b.bins.2 +
              a.bins.3 * b.bins.3 +
              a.bins.4 * b.bins.4 +
              a.bins.5 * b.bins.5 +
              a.bins.6 * b.bins.6 +
              a.bins.7 * b.bins.7
    
    if dot > 1.0 { dot = 1.0 }
    if dot < 0.0 { dot = 0.0 }
    
    return 1.0 - dot
}

public final class MosaicMatcher: @unchecked Sendable {
    private static let _shared = MosaicMatcher()
    public static let sharedMatcher = _shared
    public static func shared() -> MosaicMatcher { _shared }
    
    public init() {}
    
    public func compareTargetPixels(
        _ targetPixels: UnsafePointer<UInt8>,
        candidatePixels: UnsafePointer<UInt8>,
        maskPixels: UnsafePointer<UInt8>?,
        width: Int32,
        height: Int32,
        metric: MosaicColorMetric
    ) -> Float {
        guard width > 0 && height > 0 else { return 1.0 }
        
        let maxDiff: Float = {
            switch metric {
            case .monochrome: return MAX_COLOR_DIFF_MONO
            case .riemersma: return MAX_COLOR_DIFF_RIEMERSMA
            case .rgb: return MAX_COLOR_DIFF_RGB
            }
        }()
        
        var accumulatedSimilarity: Float = 0.0
        var totalPixelWeight: Float = 0.0
        let totalPixels = Int(width * height)
        
        for i in 0..<totalPixels {
            var weight: Float = 1.0
            if let mask = maskPixels {
                weight = Float(mask[i]) / 255.0
                if weight <= 0.001 {
                    continue
                }
            }
            
            let offset = i * 4
            let tr = targetPixels[offset]
            let tg = targetPixels[offset + 1]
            let tb = targetPixels[offset + 2]
            
            let cr = candidatePixels[offset]
            let cg = candidatePixels[offset + 1]
            let cb = candidatePixels[offset + 2]
            
            let diff: Float
            switch metric {
            case .monochrome:
                diff = colorDifferenceMono(tr, tg, tb, cr, cg, cb)
            case .riemersma:
                diff = colorDifferenceRiemersma(tr, tg, tb, cr, cg, cb)
            case .rgb:
                diff = colorDifferenceRGB(tr, tg, tb, cr, cg, cb)
            }
            
            var similarity = maxDiff - diff
            if similarity < 0.0 { similarity = 0.0 }
            
            accumulatedSimilarity += similarity * weight
            totalPixelWeight += weight
        }
        
        if totalPixelWeight <= 0.0001 {
            return 1.0
        }
        
        var score = 1.0 - (accumulatedSimilarity / (totalPixelWeight * maxDiff))
        if score < 0.0 { score = 0.0 }
        if score > 1.0 { score = 1.0 }
        return score
    }
    
    public func compareTargetPixels(
        _ targetPixels: UnsafePointer<UInt8>,
        targetEdgeDesc: MosaicEdgeDescriptor,
        candidatePixels: UnsafePointer<UInt8>,
        candidateEdgeDesc: MosaicEdgeDescriptor,
        maskPixels: UnsafePointer<UInt8>?,
        width: Int32,
        height: Int32,
        metric: MosaicColorMetric,
        edgeWeight: Float
    ) -> Float {
        let colorScore = compareTargetPixels(
            targetPixels,
            candidatePixels: candidatePixels,
            maskPixels: maskPixels,
            width: width,
            height: height,
            metric: metric
        )
        
        if edgeWeight <= 0.001 || !targetEdgeDesc.hasEdges {
            return colorScore
        }
        
        let edgeDist = MosaicCompareEdgeDescriptors(targetEdgeDesc, candidateEdgeDesc)
        
        var saliencyGate = (targetEdgeDesc.energy - 8.0) / (32.0 - 8.0)
        if saliencyGate < 0.0 { saliencyGate = 0.0 }
        if saliencyGate > 1.0 { saliencyGate = 1.0 }
        
        let effectiveWeight = edgeWeight * saliencyGate
        return (1.0 - effectiveWeight) * colorScore + effectiveWeight * edgeDist
    }
}

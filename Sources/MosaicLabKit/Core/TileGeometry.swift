import Foundation
import CoreGraphics

public enum MosaicShapeType: Int, Codable, CaseIterable, Sendable {
    case rectangular = 0
    case hexagonal = 1
    case puzzle = 2
    case quadtree = 3
}

public typealias ShapeType = MosaicShapeType

public enum MosaicQuadtreeAlgorithm: Int, Codable, CaseIterable, Sendable {
    case juliaRange = 0
    case colorRange = 1
    case variance = 2
    case wholeCanvas = 3
}

public typealias QuadtreeAlgorithm = MosaicQuadtreeAlgorithm

public final class MosaicTileGeometry: @unchecked Sendable {
    public let tileIndex: Int
    public let gridX: Int
    public let gridY: Int
    public let bounds: CGRect
    public let outline: CGPath
    
    public init(index: Int, gridX: Int, gridY: Int, bounds: CGRect, outline: CGPath) {
        self.tileIndex = index
        self.gridX = gridX
        self.gridY = gridY
        self.bounds = bounds
        self.outline = outline
    }
}

public typealias TileGeometry = MosaicTileGeometry

private enum PuzzleTabType: Int {
    case noTab = 0
    case inwards = -1
    case outwards = 1
}

private func createPuzzlePiecePath(
    tileBounds: CGRect,
    topTab: PuzzleTabType,
    leftTab: PuzzleTabType,
    rightTab: PuzzleTabType,
    bottomTab: PuzzleTabType,
    topLeftHCurve: Float, topLeftVCurve: Float,
    topRightHCurve: Float, topRightVCurve: Float,
    bottomLeftHCurve: Float, bottomLeftVCurve: Float,
    bottomRightHCurve: Float, bottomRightVCurve: Float
) -> CGPath {
    let path = CGMutablePath()
    let xSize = CGFloat(tileBounds.size.width)
    let ySize = CGFloat(tileBounds.size.height)
    let tabSize = CGFloat(min(xSize, ySize) / 3.0)
    
    let cTopLeftH = CGFloat(topLeftHCurve) * tabSize * 0.25
    let cTopLeftV = CGFloat(topLeftVCurve) * tabSize * 0.25
    let cTopRightH = CGFloat(topRightHCurve) * tabSize * 0.25
    let cTopRightV = CGFloat(topRightVCurve) * tabSize * 0.25
    let cBottomLeftH = CGFloat(bottomLeftHCurve) * tabSize * 0.25
    let cBottomLeftV = CGFloat(bottomLeftVCurve) * tabSize * 0.25
    let cBottomRightH = CGFloat(bottomRightHCurve) * tabSize * 0.25
    let cBottomRightV = CGFloat(bottomRightVCurve) * tabSize * 0.25
    
    path.move(to: CGPoint(x: 0, y: 0))
    
    // Bottom edge
    if bottomTab == .noTab {
        path.addCurve(
            to: CGPoint(x: xSize, y: 0),
            control1: CGPoint(x: xSize / 3.0, y: tabSize * CGFloat(bottomLeftHCurve)),
            control2: CGPoint(x: xSize * 2.0 / 3.0, y: tabSize * CGFloat(bottomRightHCurve))
        )
    } else {
        let orient: CGFloat = (bottomTab == .inwards) ? 1.0 : -1.0
        path.addCurve(to: CGPoint(x: xSize / 4.0, y: 0), control1: CGPoint(x: xSize / 12.0, y: cBottomLeftH), control2: CGPoint(x: xSize / 6.0, y: cBottomLeftH))
        path.addCurve(to: CGPoint(x: xSize * 5.0 / 12.0, y: tabSize / 2.0 * orient), control1: CGPoint(x: xSize / 3.0, y: -cBottomLeftH), control2: CGPoint(x: xSize / 2.0, y: tabSize / 4.0 * orient))
        path.addCurve(to: CGPoint(x: xSize / 2.0, y: tabSize * orient), control1: CGPoint(x: xSize / 3.0, y: tabSize * 0.75 * orient), control2: CGPoint(x: xSize * 3.0 / 8.0, y: tabSize * orient))
        path.addCurve(to: CGPoint(x: xSize * 7.0 / 12.0, y: tabSize / 2.0 * orient), control1: CGPoint(x: xSize * 15.0 / 24.0, y: tabSize * orient), control2: CGPoint(x: xSize * 2.0 / 3.0, y: tabSize * 0.75 * orient))
        path.addCurve(to: CGPoint(x: xSize * 3.0 / 4.0, y: 0), control1: CGPoint(x: xSize / 2.0, y: tabSize / 4.0 * orient), control2: CGPoint(x: xSize * 2.0 / 3.0, y: -cBottomRightH))
        path.addCurve(to: CGPoint(x: xSize, y: 0), control1: CGPoint(x: xSize * 10.0 / 12.0, y: cBottomRightH), control2: CGPoint(x: xSize * 11.0 / 12.0, y: cBottomRightH))
    }
    
    // Right edge
    if rightTab == .noTab {
        path.addCurve(
            to: CGPoint(x: xSize, y: ySize),
            control1: CGPoint(x: xSize + tabSize * CGFloat(bottomRightVCurve), y: ySize / 3.0),
            control2: CGPoint(x: xSize + tabSize * CGFloat(topRightVCurve), y: ySize * 2.0 / 3.0)
        )
    } else {
        let orient: CGFloat = (rightTab == .inwards) ? -1.0 : 1.0
        path.addCurve(to: CGPoint(x: xSize, y: ySize / 4.0), control1: CGPoint(x: xSize + cBottomRightV, y: ySize / 12.0), control2: CGPoint(x: xSize + cBottomRightV, y: ySize / 6.0))
        path.addCurve(to: CGPoint(x: xSize + tabSize / 2.0 * orient, y: ySize * 5.0 / 12.0), control1: CGPoint(x: xSize - cBottomRightV, y: ySize / 3.0), control2: CGPoint(x: xSize + tabSize / 4.0 * orient, y: ySize / 2.0))
        path.addCurve(to: CGPoint(x: xSize + tabSize * orient, y: ySize / 2.0), control1: CGPoint(x: xSize + tabSize * 0.75 * orient, y: ySize / 3.0), control2: CGPoint(x: xSize + tabSize * orient, y: ySize * 3.0 / 8.0))
        path.addCurve(to: CGPoint(x: xSize + tabSize / 2.0 * orient, y: ySize * 7.0 / 12.0), control1: CGPoint(x: xSize + tabSize * orient, y: ySize * 15.0 / 24.0), control2: CGPoint(x: xSize + tabSize * 0.75 * orient, y: ySize * 2.0 / 3.0))
        path.addCurve(to: CGPoint(x: xSize, y: ySize * 3.0 / 4.0), control1: CGPoint(x: xSize + tabSize / 4.0 * orient, y: ySize / 2.0), control2: CGPoint(x: xSize - cTopRightV, y: ySize * 2.0 / 3.0))
        path.addCurve(to: CGPoint(x: xSize, y: ySize), control1: CGPoint(x: xSize + cTopRightV, y: ySize * 10.0 / 12.0), control2: CGPoint(x: xSize + cTopRightV, y: ySize * 11.0 / 12.0))
    }
    
    // Top edge
    if topTab == .noTab {
        path.addCurve(
            to: CGPoint(x: 0, y: ySize),
            control1: CGPoint(x: xSize * 2.0 / 3.0, y: ySize + tabSize * CGFloat(topRightHCurve)),
            control2: CGPoint(x: xSize / 3.0, y: ySize + tabSize * CGFloat(topLeftHCurve))
        )
    } else {
        let orient: CGFloat = (topTab == .inwards) ? -1.0 : 1.0
        path.addCurve(to: CGPoint(x: xSize * 3.0 / 4.0, y: ySize), control1: CGPoint(x: xSize * 11.0 / 12.0, y: ySize + cTopRightH), control2: CGPoint(x: xSize * 10.0 / 12.0, y: ySize + cTopRightH))
        path.addCurve(to: CGPoint(x: xSize / 2.0, y: ySize + tabSize / 2.0 * orient), control1: CGPoint(x: xSize * 2.0 / 3.0, y: ySize - cTopRightH), control2: CGPoint(x: xSize / 2.0, y: ySize + tabSize / 4.0 * orient))
        path.addCurve(to: CGPoint(x: xSize * 3.0 / 8.0, y: ySize + tabSize * orient), control1: CGPoint(x: xSize * 2.0 / 3.0, y: ySize + tabSize * 0.75 * orient), control2: CGPoint(x: xSize * 15.0 / 24.0, y: ySize + tabSize * orient))
        path.addCurve(to: CGPoint(x: xSize * 5.0 / 12.0, y: ySize + tabSize / 2.0 * orient), control1: CGPoint(x: xSize * 3.0 / 8.0, y: ySize + tabSize * orient), control2: CGPoint(x: xSize / 3.0, y: ySize + tabSize * 0.75 * orient))
        path.addCurve(to: CGPoint(x: xSize / 4.0, y: ySize), control1: CGPoint(x: xSize / 2.0, y: ySize + tabSize / 4.0 * orient), control2: CGPoint(x: xSize / 3.0, y: ySize - cTopLeftH))
        path.addCurve(to: CGPoint(x: 0, y: ySize), control1: CGPoint(x: xSize / 6.0, y: ySize + cTopLeftH), control2: CGPoint(x: xSize / 12.0, y: ySize + cTopLeftH))
    }
    
    // Left edge
    if leftTab == .noTab {
        path.addCurve(
            to: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: tabSize * CGFloat(topLeftVCurve), y: ySize * 2.0 / 3.0),
            control2: CGPoint(x: tabSize * CGFloat(bottomLeftVCurve), y: ySize / 3.0)
        )
    } else {
        let orient: CGFloat = (leftTab == .inwards) ? 1.0 : -1.0
        path.addCurve(to: CGPoint(x: 0, y: ySize * 3.0 / 4.0), control1: CGPoint(x: cTopLeftV, y: ySize * 11.0 / 12.0), control2: CGPoint(x: cTopLeftV, y: ySize * 10.0 / 12.0))
        path.addCurve(to: CGPoint(x: tabSize / 2.0 * orient, y: ySize * 7.0 / 12.0), control1: CGPoint(x: -cTopLeftV, y: ySize * 2.0 / 3.0), control2: CGPoint(x: tabSize / 4.0 * orient, y: ySize / 2.0))
        path.addCurve(to: CGPoint(x: tabSize * orient, y: ySize / 2.0), control1: CGPoint(x: tabSize * 0.75 * orient, y: ySize * 2.0 / 3.0), control2: CGPoint(x: tabSize * orient, y: ySize * 15.0 / 24.0))
        path.addCurve(to: CGPoint(x: tabSize / 2.0 * orient, y: ySize * 5.0 / 12.0), control1: CGPoint(x: tabSize * orient, y: ySize * 3.0 / 8.0), control2: CGPoint(x: tabSize * 0.75 * orient, y: ySize / 3.0))
        path.addCurve(to: CGPoint(x: 0, y: ySize / 4.0), control1: CGPoint(x: tabSize / 4.0 * orient, y: ySize / 2.0), control2: CGPoint(x: -cBottomLeftV, y: ySize / 3.0))
        path.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: cBottomLeftV, y: ySize / 6.0), control2: CGPoint(x: cBottomLeftV, y: ySize / 12.0))
    }
    
    path.closeSubpath()
    
    var transform = CGAffineTransform(translationX: tileBounds.origin.x, y: tileBounds.origin.y)
    return path.copy(using: &transform) ?? path
}

// MARK: - Integral Image for Fast Quadtree Variance & Gradients

private final class IntegralImage {
    let width: Int
    let height: Int
    let sum: [Double]
    let sumSq: [Double]
    let sumGrad: [Double]?
    let smoothedGray: [UInt8]?
    let rgbBuffer: [UInt8]?
    
    init?(image: CGImage) {
        let origW = image.width
        let origH = image.height
        guard origW > 0 && origH > 0 else { return nil }
        
        let maxDim = 1024
        var w = origW
        var h = origH
        if w > maxDim || h > maxDim {
            if w > h {
                h = max(16, (h * maxDim) / w)
                w = maxDim
            } else {
                w = max(16, (w * maxDim) / h)
                h = maxDim
            }
        }
        self.width = w
        self.height = h
        
        var grayBuffer = [UInt8](repeating: 0, count: w * h)
        var rgbData = [UInt8](repeating: 0, count: w * h * 4)
        
        let graySpace = CGColorSpaceCreateDeviceGray()
        if let grayCtx = CGContext(
            data: &grayBuffer,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w,
            space: graySpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) {
            grayCtx.interpolationQuality = .low
            grayCtx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        
        let rgbSpace = CGColorSpaceCreateDeviceRGB()
        let rgbBitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        if let rgbCtx = CGContext(
            data: &rgbData,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: rgbSpace,
            bitmapInfo: rgbBitmapInfo
        ) {
            rgbCtx.interpolationQuality = .low
            rgbCtx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        self.rgbBuffer = rgbData
        
        // 3x3 box blur on gray for Julia Range
        var smooth = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                if y == 0 || y == h - 1 || x == 0 || x == w - 1 {
                    smooth[y * w + x] = grayBuffer[y * w + x]
                } else {
                    let s = Int(grayBuffer[(y - 1) * w + (x - 1)]) + Int(grayBuffer[(y - 1) * w + x]) + Int(grayBuffer[(y - 1) * w + (x + 1)]) +
                            Int(grayBuffer[y * w + (x - 1)])       + Int(grayBuffer[y * w + x])       + Int(grayBuffer[y * w + (x + 1)]) +
                            Int(grayBuffer[(y + 1) * w + (x - 1)]) + Int(grayBuffer[(y + 1) * w + x]) + Int(grayBuffer[(y + 1) * w + (x + 1)])
                    smooth[y * w + x] = UInt8(s / 9)
                }
            }
        }
        self.smoothedGray = smooth
        
        // Sobel gradient magnitude
        var gradBuffer = [Double](repeating: 0, count: w * h)
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let p00 = Double(grayBuffer[(y - 1) * w + (x - 1)])
                let p01 = Double(grayBuffer[(y - 1) * w + x])
                let p02 = Double(grayBuffer[(y - 1) * w + (x + 1)])
                let p10 = Double(grayBuffer[y * w + (x - 1)])
                let p12 = Double(grayBuffer[y * w + (x + 1)])
                let p20 = Double(grayBuffer[(y + 1) * w + (x - 1)])
                let p21 = Double(grayBuffer[(y + 1) * w + x])
                let p22 = Double(grayBuffer[(y + 1) * w + (x + 1)])
                
                let gx = -p00 + p02 - 2.0 * p10 + 2.0 * p12 - p20 + p22
                let gy = -p00 - 2.0 * p01 - p02 + p20 + 2.0 * p21 + p22
                gradBuffer[y * w + x] = sqrt(gx * gx + gy * gy) / 1442.0
            }
        }
        
        let tableW = w + 1
        let tableH = h + 1
        var tableSum = [Double](repeating: 0, count: tableW * tableH)
        var tableSumSq = [Double](repeating: 0, count: tableW * tableH)
        var tableSumGrad = [Double](repeating: 0, count: tableW * tableH)
        
        for y in 0..<h {
            var rowSum = 0.0
            var rowSumSq = 0.0
            var rowSumGrad = 0.0
            let rowOffset = y * w
            
            for x in 0..<w {
                let val = Double(grayBuffer[rowOffset + x]) / 255.0
                rowSum += val
                rowSumSq += val * val
                rowSumGrad += gradBuffer[rowOffset + x]
                
                let idx = (y + 1) * tableW + (x + 1)
                let aboveIdx = y * tableW + (x + 1)
                
                tableSum[idx] = tableSum[aboveIdx] + rowSum
                tableSumSq[idx] = tableSumSq[aboveIdx] + rowSumSq
                tableSumGrad[idx] = tableSumGrad[aboveIdx] + rowSumGrad
            }
        }
        
        self.sum = tableSum
        self.sumSq = tableSumSq
        self.sumGrad = tableSumGrad
    }
    
    func evaluateVariance(rect: CGRect, mosaicSize: CGSize) -> Double {
        guard width > 0 && height > 0 && mosaicSize.width > 0 && mosaicSize.height > 0 else { return 0 }
        
        let scaleX = Double(width) / Double(mosaicSize.width)
        let scaleY = Double(height) / Double(mosaicSize.height)
        
        let x0 = max(0.0, Double(rect.origin.x) * scaleX)
        let y0 = max(0.0, Double(rect.origin.y) * scaleY)
        let x1 = min(Double(width), Double(rect.origin.x + rect.size.width) * scaleX)
        let y1 = min(Double(height), Double(rect.origin.y + rect.size.height) * scaleY)
        
        let ix0 = Int(floor(x0))
        let iy0 = Int(floor(y0))
        var ix1 = Int(ceil(x1))
        var iy1 = Int(ceil(y1))
        
        if ix1 <= ix0 { ix1 = ix0 + 1 }
        if iy1 <= iy0 { iy1 = iy0 + 1 }
        if ix1 > width { ix1 = width }
        if iy1 > height { iy1 = height }
        
        let tableW = width + 1
        let a = sum[iy0 * tableW + ix0]
        let b = sum[iy0 * tableW + ix1]
        let c = sum[iy1 * tableW + ix0]
        let d = sum[iy1 * tableW + ix1]
        let s = d - b - c + a
        
        let asq = sumSq[iy0 * tableW + ix0]
        let bsq = sumSq[iy0 * tableW + ix1]
        let csq = sumSq[iy1 * tableW + ix0]
        let dsq = sumSq[iy1 * tableW + ix1]
        let sSq = dsq - bsq - csq + asq
        
        let count = Double((ix1 - ix0) * (iy1 - iy0))
        if count <= 1.0 { return 0 }
        
        let mean = s / count
        let variance = (sSq / count) - (mean * mean)
        return variance > 0 ? sqrt(variance) : 0
    }
    
    func evaluateGradient(rect: CGRect, mosaicSize: CGSize) -> Double {
        guard let sGrad = sumGrad, width > 0 && height > 0 && mosaicSize.width > 0 && mosaicSize.height > 0 else { return 0 }
        
        let scaleX = Double(width) / Double(mosaicSize.width)
        let scaleY = Double(height) / Double(mosaicSize.height)
        
        let x0 = max(0.0, Double(rect.origin.x) * scaleX)
        let y0 = max(0.0, Double(rect.origin.y) * scaleY)
        let x1 = min(Double(width), Double(rect.origin.x + rect.size.width) * scaleX)
        let y1 = min(Double(height), Double(rect.origin.y + rect.size.height) * scaleY)
        
        let ix0 = Int(floor(x0))
        let iy0 = Int(floor(y0))
        var ix1 = Int(ceil(x1))
        var iy1 = Int(ceil(y1))
        
        if ix1 <= ix0 { ix1 = ix0 + 1 }
        if iy1 <= iy0 { iy1 = iy0 + 1 }
        if ix1 > width { ix1 = width }
        if iy1 > height { iy1 = height }
        
        let tableW = width + 1
        let a = sGrad[iy0 * tableW + ix0]
        let b = sGrad[iy0 * tableW + ix1]
        let c = sGrad[iy1 * tableW + ix0]
        let d = sGrad[iy1 * tableW + ix1]
        let s = d - b - c + a
        
        let count = Double((ix1 - ix0) * (iy1 - iy0))
        return count > 1.0 ? (s / count) : 0
    }
    
    func evaluateHybrid(rect: CGRect, mosaicSize: CGSize, alpha: Float) -> Double {
        let sigma = evaluateVariance(rect: rect, mosaicSize: mosaicSize)
        let edgeDensity = evaluateGradient(rect: rect, mosaicSize: mosaicSize)
        let normSigma = min(1.0, sigma / 0.30)
        let normEdge = min(1.0, edgeDensity / 0.25)
        return Double(alpha) * normSigma + (1.0 - Double(alpha)) * normEdge
    }
    
    func evaluateJuliaRange(rect: CGRect, mosaicSize: CGSize) -> Double {
        guard let buf = smoothedGray, width > 0 && height > 0 && mosaicSize.width > 0 && mosaicSize.height > 0 else { return 0 }
        
        let scaleX = Double(width) / Double(mosaicSize.width)
        let scaleY = Double(height) / Double(mosaicSize.height)
        
        let ix0 = Int(floor(max(0.0, Double(rect.origin.x) * scaleX)))
        let iy0 = Int(floor(max(0.0, Double(rect.origin.y) * scaleY)))
        var ix1 = Int(ceil(min(Double(width), Double(rect.origin.x + rect.size.width) * scaleX)))
        var iy1 = Int(ceil(min(Double(height), Double(rect.origin.y + rect.size.height) * scaleY)))
        
        if ix1 <= ix0 { ix1 = ix0 + 1 }
        if iy1 <= iy0 { iy1 = iy0 + 1 }
        if ix1 > width { ix1 = width }
        if iy1 > height { iy1 = height }
        
        var minVal: UInt8 = 255
        var maxVal: UInt8 = 0
        
        for y in iy0..<iy1 {
            let rowOffset = y * width
            for x in ix0..<ix1 {
                let v = buf[rowOffset + x]
                if v < minVal { minVal = v }
                if v > maxVal { maxVal = v }
            }
        }
        
        return Double(maxVal - minVal) / 255.0
    }
    
    func evaluateColorRange(rect: CGRect, mosaicSize: CGSize) -> Double {
        guard let buf = rgbBuffer, width > 0 && height > 0 && mosaicSize.width > 0 && mosaicSize.height > 0 else { return 0 }
        
        let scaleX = Double(width) / Double(mosaicSize.width)
        let scaleY = Double(height) / Double(mosaicSize.height)
        
        let ix0 = Int(floor(max(0.0, Double(rect.origin.x) * scaleX)))
        let iy0 = Int(floor(max(0.0, Double(rect.origin.y) * scaleY)))
        var ix1 = Int(ceil(min(Double(width), Double(rect.origin.x + rect.size.width) * scaleX)))
        var iy1 = Int(ceil(min(Double(height), Double(rect.origin.y + rect.size.height) * scaleY)))
        
        if ix1 <= ix0 { ix1 = ix0 + 1 }
        if iy1 <= iy0 { iy1 = iy0 + 1 }
        if ix1 > width { ix1 = width }
        if iy1 > height { iy1 = height }
        
        var minR: UInt8 = 255, maxR: UInt8 = 0
        var minG: UInt8 = 255, maxG: UInt8 = 0
        var minB: UInt8 = 255, maxB: UInt8 = 0
        
        for y in iy0..<iy1 {
            let rowOffset = y * width * 4
            for x in ix0..<ix1 {
                let px = rowOffset + x * 4
                let r = buf[px]
                let g = buf[px + 1]
                let b = buf[px + 2]
                if r < minR { minR = r }; if r > maxR { maxR = r }
                if g < minG { minG = g }; if g > maxG { maxG = g }
                if b < minB { minB = b }; if b > maxB { maxB = b }
            }
        }
        
        let diffR = maxR - minR
        let diffG = maxG - minG
        let diffB = maxB - minB
        let maxDiff = max(diffR, max(diffG, diffB))
        return Double(maxDiff) / 255.0
    }
}

// MARK: - Quadtree Data Structure & 2:1 Balancing

private final class QuadNode {
    var bounds: CGRect
    var depth: Int
    var isLeaf: Bool = true
    var children: [QuadNode]?
    
    init(bounds: CGRect, depth: Int) {
        self.bounds = bounds
        self.depth = depth
    }
    
    func split() {
        guard isLeaf else { return }
        let halfW = bounds.size.width * 0.5
        let halfH = bounds.size.height * 0.5
        let x = bounds.origin.x
        let y = bounds.origin.y
        
        isLeaf = false
        children = [
            QuadNode(bounds: CGRect(x: x, y: y, width: halfW, height: halfH), depth: depth + 1),
            QuadNode(bounds: CGRect(x: x + halfW, y: y, width: halfW, height: halfH), depth: depth + 1),
            QuadNode(bounds: CGRect(x: x, y: y + halfH, width: halfW, height: halfH), depth: depth + 1),
            QuadNode(bounds: CGRect(x: x + halfW, y: y + halfH, width: halfW, height: halfH), depth: depth + 1)
        ]
    }
    
    func collectLeaves(into list: inout [QuadNode]) {
        if isLeaf {
            list.append(self)
        } else if let ch = children {
            for c in ch {
                c.collectLeaves(into: &list)
            }
        }
    }
}

private func buildQuadTree(
    rect: CGRect,
    depth: Int,
    maxDepth: Int,
    threshold: Float,
    minDimension: Float,
    ii: IntegralImage?,
    mosaicSize: CGSize,
    alpha: Float,
    algorithm: MosaicQuadtreeAlgorithm
) -> QuadNode {
    let node = QuadNode(bounds: rect, depth: depth)
    
    var score: Double = 0.0
    if let imageAnalysis = ii {
        switch algorithm {
        case .juliaRange:
            score = imageAnalysis.evaluateJuliaRange(rect: rect, mosaicSize: mosaicSize)
        case .colorRange:
            score = imageAnalysis.evaluateColorRange(rect: rect, mosaicSize: mosaicSize)
        case .variance, .wholeCanvas:
            score = imageAnalysis.evaluateHybrid(rect: rect, mosaicSize: mosaicSize, alpha: alpha)
        }
    }
    
    let canSubdivide = (depth < maxDepth) &&
                       (Float(rect.size.width) >= (minDimension * 2.0)) &&
                       (Float(rect.size.height) >= (minDimension * 2.0)) &&
                       (score >= Double(threshold))
    
    if canSubdivide {
        node.split()
        if let ch = node.children {
            node.children = ch.map { c in
                buildQuadTree(
                    rect: c.bounds,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    threshold: threshold,
                    minDimension: minDimension,
                    ii: ii,
                    mosaicSize: mosaicSize,
                    alpha: alpha,
                    algorithm: algorithm
                )
            }
        }
    }
    
    return node
}

private func nodesShareEdge(_ a: CGRect, _ b: CGRect) -> Bool {
    let eps: CGFloat = 0.1
    
    // Check horizontal adjacency
    let aRight = a.origin.x + a.size.width
    let bRight = b.origin.x + b.size.width
    let horizontalTouch = (abs(aRight - b.origin.x) < eps) || (abs(bRight - a.origin.x) < eps)
    if horizontalTouch {
        let overlapMin = max(a.origin.y, b.origin.y)
        let overlapMax = min(a.origin.y + a.size.height, b.origin.y + b.size.height)
        if overlapMax - overlapMin > eps {
            return true
        }
    }
    
    // Check vertical adjacency
    let aBottom = a.origin.y + a.size.height
    let bBottom = b.origin.y + b.size.height
    let verticalTouch = (abs(aBottom - b.origin.y) < eps) || (abs(bBottom - a.origin.y) < eps)
    if verticalTouch {
        let overlapMin = max(a.origin.x, b.origin.x)
        let overlapMax = min(a.origin.x + a.size.width, b.origin.x + b.size.width)
        if overlapMax - overlapMin > eps {
            return true
        }
    }
    
    return false
}

private func balanceQuadNodes(
    rootNodes: [QuadNode],
    leavesList: inout [QuadNode],
    maxDepth: Int,
    minDimension: Float
) {
    var changed = true
    var pass = 0
    let maxPasses = 8
    
    while changed && pass < maxPasses {
        changed = false
        pass += 1
        
        var nodesToSplit = [QuadNode]()
        let count = leavesList.count
        
        for i in 0..<count {
            let nodeA = leavesList[i]
            if !nodeA.isLeaf || nodeA.depth >= maxDepth { continue }
            if Float(nodeA.bounds.size.width) < (minDimension * 2.0) || Float(nodeA.bounds.size.height) < (minDimension * 2.0) { continue }
            
            for j in 0..<count {
                if i == j { continue }
                let nodeB = leavesList[j]
                if nodeB.depth < nodeA.depth + 2 { continue }
                
                if nodesShareEdge(nodeA.bounds, nodeB.bounds) {
                    nodesToSplit.append(nodeA)
                    break
                }
            }
        }
        
        if !nodesToSplit.isEmpty {
            changed = true
            for node in nodesToSplit {
                node.split()
            }
            leavesList.removeAll()
            for root in rootNodes {
                root.collectLeaves(into: &leavesList)
            }
        }
    }
}

// MARK: - Shapes Generator

public final class MosaicShapes: @unchecked Sendable {
    
    public static func generateShapes(
        for type: MosaicShapeType,
        mosaicSize: CGSize,
        across: Int,
        down: Int,
        curviness: Float,
        tabRatio: Float
    ) -> [MosaicTileGeometry] {
        return generateShapes(
            for: type,
            targetImage: nil,
            mosaicSize: mosaicSize,
            across: across,
            down: down,
            curviness: curviness,
            tabRatio: tabRatio,
            maxDepth: 3,
            detailThreshold: 0.15,
            balanced: true,
            detailAlpha: 0.5,
            algorithm: .juliaRange,
            minTileDim: 16.0
        )
    }
    
    public static func generateShapes(
        for type: MosaicShapeType,
        targetImage: CGImage?,
        mosaicSize: CGSize,
        across: Int,
        down: Int,
        curviness: Float,
        tabRatio: Float,
        maxDepth: Int,
        detailThreshold: Float
    ) -> [MosaicTileGeometry] {
        return generateShapes(
            for: type,
            targetImage: targetImage,
            mosaicSize: mosaicSize,
            across: across,
            down: down,
            curviness: curviness,
            tabRatio: tabRatio,
            maxDepth: maxDepth,
            detailThreshold: detailThreshold,
            balanced: true,
            detailAlpha: 0.5,
            algorithm: .juliaRange,
            minTileDim: 16.0
        )
    }
    
    public static func generateShapes(
        for type: MosaicShapeType,
        targetImage: CGImage?,
        mosaicSize: CGSize,
        across: Int,
        down: Int,
        curviness: Float,
        tabRatio: Float,
        maxDepth: Int,
        detailThreshold: Float,
        balanced: Bool
    ) -> [MosaicTileGeometry] {
        return generateShapes(
            for: type,
            targetImage: targetImage,
            mosaicSize: mosaicSize,
            across: across,
            down: down,
            curviness: curviness,
            tabRatio: tabRatio,
            maxDepth: maxDepth,
            detailThreshold: detailThreshold,
            balanced: balanced,
            detailAlpha: 0.5,
            algorithm: .juliaRange,
            minTileDim: 16.0
        )
    }
    
    public static func generateShapes(
        for type: MosaicShapeType,
        targetImage: CGImage?,
        mosaicSize: CGSize,
        across: Int,
        down: Int,
        curviness: Float,
        tabRatio: Float,
        maxDepth: Int,
        detailThreshold: Float,
        balanced: Bool,
        detailAlpha: Float
    ) -> [MosaicTileGeometry] {
        return generateShapes(
            for: type,
            targetImage: targetImage,
            mosaicSize: mosaicSize,
            across: across,
            down: down,
            curviness: curviness,
            tabRatio: tabRatio,
            maxDepth: maxDepth,
            detailThreshold: detailThreshold,
            balanced: balanced,
            detailAlpha: detailAlpha,
            algorithm: .juliaRange,
            minTileDim: 16.0
        )
    }
    
    public static func generateShapes(
        for type: MosaicShapeType,
        targetImage: CGImage?,
        mosaicSize: CGSize,
        across: Int,
        down: Int,
        curviness: Float,
        tabRatio: Float,
        maxDepth: Int,
        detailThreshold: Float,
        balanced: Bool,
        detailAlpha: Float,
        algorithm: MosaicQuadtreeAlgorithm,
        minTileDim: Float
    ) -> [MosaicTileGeometry] {
        let xCount = across > 0 ? across : 30
        let yCount = down > 0 ? down : 20
        var results = [MosaicTileGeometry]()
        results.reserveCapacity(xCount * yCount)
        
        switch type {
        case .rectangular:
            let xSize = mosaicSize.width / CGFloat(xCount)
            let ySize = mosaicSize.height / CGFloat(yCount)
            var index = 0
            
            for y in 0..<yCount {
                for x in 0..<xCount {
                    let tileRect = CGRect(x: CGFloat(x) * xSize, y: CGFloat(y) * ySize, width: xSize, height: ySize)
                    let rectPath = CGPath(rect: tileRect, transform: nil)
                    let geom = MosaicTileGeometry(index: index, gridX: x, gridY: y, bounds: tileRect, outline: rectPath)
                    index += 1
                    results.append(geom)
                }
            }
            
        case .quadtree:
            let xSize = mosaicSize.width / CGFloat(xCount)
            let ySize = mosaicSize.height / CGFloat(yCount)
            let ii = targetImage.flatMap { IntegralImage(image: $0) }
            
            let effectiveMinDim = minTileDim > 1.0 ? minTileDim : 16.0
            let wholeMaxDepth = maxDepth > 0 ? (maxDepth + 3) : 6
            let effDepth = maxDepth > 0 ? Float(maxDepth) : 3.0
            let minUnitW = (algorithm == .wholeCanvas) ?
                (Float(mosaicSize.width) / pow(2.0, Float(wholeMaxDepth))) :
                (Float(xSize) / pow(2.0, effDepth))
            let minUnitH = (algorithm == .wholeCanvas) ?
                (Float(mosaicSize.height) / pow(2.0, Float(wholeMaxDepth))) :
                (Float(ySize) / pow(2.0, effDepth))
            
            var rootNodes = [QuadNode]()
            var leavesList = [QuadNode]()
            
            if algorithm == .wholeCanvas {
                let canvasRect = CGRect(origin: .zero, size: mosaicSize)
                let root = buildQuadTree(
                    rect: canvasRect,
                    depth: 0,
                    maxDepth: wholeMaxDepth,
                    threshold: detailThreshold,
                    minDimension: effectiveMinDim,
                    ii: ii,
                    mosaicSize: mosaicSize,
                    alpha: detailAlpha,
                    algorithm: .juliaRange
                )
                rootNodes.append(root)
                root.collectLeaves(into: &leavesList)
                if balanced {
                    balanceQuadNodes(rootNodes: rootNodes, leavesList: &leavesList, maxDepth: wholeMaxDepth, minDimension: effectiveMinDim)
                }
            } else {
                for y in 0..<yCount {
                    for x in 0..<xCount {
                        let baseRect = CGRect(x: CGFloat(x) * xSize, y: CGFloat(y) * ySize, width: xSize, height: ySize)
                        let root = buildQuadTree(
                            rect: baseRect,
                            depth: 0,
                            maxDepth: maxDepth,
                            threshold: detailThreshold,
                            minDimension: effectiveMinDim,
                            ii: ii,
                            mosaicSize: mosaicSize,
                            alpha: detailAlpha,
                            algorithm: algorithm
                        )
                        rootNodes.append(root)
                        root.collectLeaves(into: &leavesList)
                    }
                }
                if balanced {
                    balanceQuadNodes(rootNodes: rootNodes, leavesList: &leavesList, maxDepth: maxDepth, minDimension: effectiveMinDim)
                }
            }
            
            var tileIndex = 0
            for leaf in leavesList {
                let rect = leaf.bounds
                let rectPath = CGPath(rect: rect, transform: nil)
                let gx = minUnitW > 0 ? Int(round(Float(rect.midX) / minUnitW)) : 0
                let gy = minUnitH > 0 ? Int(round(Float(rect.midY) / minUnitH)) : 0
                
                let geom = MosaicTileGeometry(index: tileIndex, gridX: gx, gridY: gy, bounds: rect, outline: rectPath)
                tileIndex += 1
                results.append(geom)
            }
            
        case .hexagonal:
            let xSize = mosaicSize.width / (CGFloat(xCount) - (1.0 / 3.0))
            let ySize = mosaicSize.height / CGFloat(yCount)
            var index = 0
            
            func clampX(_ v: CGFloat) -> CGFloat { min(max(v, 0.0), mosaicSize.width) }
            func clampY(_ v: CGFloat) -> CGFloat { min(max(v, 0.0), mosaicSize.height) }
            
            for x in 0..<xCount {
                let currentYCount = (x % 2 == 0) ? yCount : (yCount + 1)
                for y in 0..<currentYCount {
                    let originX = xSize * (CGFloat(x) - (1.0 / 3.0))
                    let originY = ySize * ((x % 2 == 0) ? CGFloat(y) : (CGFloat(y) - 0.5))
                    
                    let hexPath = CGMutablePath()
                    hexPath.move(to: CGPoint(x: clampX(originX + xSize / 3.0), y: clampY(originY)))
                    hexPath.addLine(to: CGPoint(x: clampX(originX + xSize), y: clampY(originY)))
                    hexPath.addLine(to: CGPoint(x: clampX(originX + xSize * 4.0 / 3.0), y: clampY(originY + ySize / 2.0)))
                    hexPath.addLine(to: CGPoint(x: clampX(originX + xSize), y: clampY(originY + ySize)))
                    hexPath.addLine(to: CGPoint(x: clampX(originX + xSize / 3.0), y: clampY(originY + ySize)))
                    hexPath.addLine(to: CGPoint(x: clampX(originX), y: clampY(originY + ySize / 2.0)))
                    hexPath.closeSubpath()
                    
                    let bounds = hexPath.boundingBox
                    let geom = MosaicTileGeometry(index: index, gridX: x, gridY: y, bounds: bounds, outline: hexPath)
                    index += 1
                    results.append(geom)
                }
            }
            
        case .puzzle:
            // Tab directions matrix
            let totalSepX = xCount * 2 + 1
            var tabTypes = [[PuzzleTabType]](repeating: [PuzzleTabType](repeating: .noTab, count: yCount), count: totalSepX)
            for x in 0..<totalSepX {
                for y in 0..<yCount {
                    if Int.random(in: 0..<100) >= Int(tabRatio * 100.0) {
                        tabTypes[x][y] = .noTab
                    } else {
                        tabTypes[x][y] = (Int.random(in: 0...1) == 0) ? .inwards : .outwards
                    }
                }
            }
            
            // Curviness matrices
            var hCurviness = [[Float]](repeating: [Float](repeating: 0, count: yCount + 1), count: xCount + 1)
            var vCurviness = [[Float]](repeating: [Float](repeating: 0, count: yCount + 1), count: xCount + 1)
            for x in 0...xCount {
                for y in 0...yCount {
                    let randH = Float(Int.random(in: -100...99)) / 100.0
                    let randV = Float(Int.random(in: -100...99)) / 100.0
                    hCurviness[x][y] = (y == 0 || y == yCount) ? 0.0 : randH * curviness
                    vCurviness[x][y] = (x == 0 || x == xCount) ? 0.0 : randV * curviness
                }
            }
            
            let xSize = mosaicSize.width / CGFloat(xCount)
            let ySize = mosaicSize.height / CGFloat(yCount)
            var index = 0
            
            func invertTab(_ tab: PuzzleTabType) -> PuzzleTabType {
                switch tab {
                case .noTab: return .noTab
                case .inwards: return .outwards
                case .outwards: return .inwards
                }
            }
            
            for y in 0..<yCount {
                for x in 0..<xCount {
                    let tileBounds = CGRect(x: CGFloat(x) * xSize, y: CGFloat(y) * ySize, width: xSize, height: ySize)
                    
                    let topTab: PuzzleTabType = (y == yCount - 1) ? .noTab : tabTypes[x * 2][y]
                    let leftTab: PuzzleTabType = (x == 0) ? .noTab : tabTypes[x * 2 - 1][y]
                    let rightTab: PuzzleTabType = (x == xCount - 1) ? .noTab : invertTab(tabTypes[x * 2 + 1][y])
                    let bottomTab: PuzzleTabType = (y == 0) ? .noTab : invertTab(tabTypes[x * 2][y - 1])
                    
                    let piecePath = createPuzzlePiecePath(
                        tileBounds: tileBounds,
                        topTab: topTab,
                        leftTab: leftTab,
                        rightTab: rightTab,
                        bottomTab: bottomTab,
                        topLeftHCurve: hCurviness[x][y + 1],
                        topLeftVCurve: -vCurviness[x][y + 1],
                        topRightHCurve: -hCurviness[x + 1][y + 1],
                        topRightVCurve: -vCurviness[x + 1][y + 1],
                        bottomLeftHCurve: hCurviness[x][y],
                        bottomLeftVCurve: vCurviness[x][y],
                        bottomRightHCurve: -hCurviness[x + 1][y],
                        bottomRightVCurve: vCurviness[x + 1][y]
                    )
                    
                    let bounds = piecePath.boundingBox
                    let geom = MosaicTileGeometry(index: index, gridX: x, gridY: y, bounds: bounds, outline: piecePath)
                    index += 1
                    results.append(geom)
                }
            }
        }
        
        return results
    }
}

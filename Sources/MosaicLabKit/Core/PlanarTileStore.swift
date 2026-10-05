import Foundation
import CoreGraphics
import simd

public final class PlanarTileStore: @unchecked Sendable {
    public let tileCount: Int
    public let tR: UnsafeMutablePointer<Float>
    public let tG: UnsafeMutablePointer<Float>
    public let tB: UnsafeMutablePointer<Float>
    public let tW: UnsafeMutablePointer<Float>
    public let tBlk: UnsafeMutablePointer<Float>
    public let invNorm: [Float]
    public let effectiveEdgeWeight: [Float]
    public let isFullyOpaque: [Bool]
    public let edgeDescriptors: [MosaicEdgeDescriptor]
    
    // We keep track of the tiles' original indices if needed, though they map 1:1 with 0..<tileCount
    
    public init(tiles: [MosaicTile], metric: MosaicColorMetric, edgeWeight: Float) {
        self.tileCount = tiles.count
        
        // Allocate aligned memory for 256 floats per tile
        self.tR = UnsafeMutablePointer<Float>.allocate(capacity: tileCount * 256)
        self.tG = UnsafeMutablePointer<Float>.allocate(capacity: tileCount * 256)
        self.tB = UnsafeMutablePointer<Float>.allocate(capacity: tileCount * 256)
        self.tW = UnsafeMutablePointer<Float>.allocate(capacity: tileCount * 256)
        
        // 48 floats per tile for block means (16 blocks x 3 channels)
        self.tBlk = UnsafeMutablePointer<Float>.allocate(capacity: tileCount * 48)
        
        var invNormArray = [Float](repeating: 0, count: tileCount)
        var effArray = [Float](repeating: 0, count: tileCount)
        var maskArray = [Bool](repeating: true, count: tileCount)
        var edgeDescArray = [MosaicEdgeDescriptor]()
        edgeDescArray.reserveCapacity(tileCount)
        
        let maxDiff: Float
        switch metric {
        case .rgb: maxDiff = 255.0 * 255.0 * 3.0
        case .riemersma: maxDiff = 255.0 * 255.0 * 9.0
        case .monochrome: maxDiff = 255.0 * 255.0 // Handled slightly differently or treated as RGB
        }
        
        for (t, tile) in tiles.enumerated() {
            let px = tile.targetBuffer
            let m = tile.maskBuffer
            var W: Float = 0
            
            for p in 0..<256 {
                tR[t * 256 + p] = Float(px[p * 4])
                tG[t * 256 + p] = Float(px[p * 4 + 1])
                tB[t * 256 + p] = Float(px[p * 4 + 2])
                
                let w = Float(m[p]) / 255.0
                tW[t * 256 + p] = w
                W += w
                
                if m[p] != 255 {
                    maskArray[t] = false
                }
            }
            
            invNormArray[t] = 1.0 / (max(W, 0.0001) * maxDiff)
            
            // Fill 4x4 block means
            for by in 0..<4 {
                for bx in 0..<4 {
                    var sr: Float = 0, sg: Float = 0, sb: Float = 0
                    for y in 0..<4 {
                        for x in 0..<4 {
                            let p = (by * 4 + y) * 16 + bx * 4 + x
                            sr += tR[t * 256 + p]
                            sg += tG[t * 256 + p]
                            sb += tB[t * 256 + p]
                        }
                    }
                    let k = by * 4 + bx
                    tBlk[t * 48 + k] = sr / 16.0
                    tBlk[t * 48 + 16 + k] = sg / 16.0
                    tBlk[t * 48 + 32 + k] = sb / 16.0
                }
            }
            
            let ed = tile.edgeDescriptor
            edgeDescArray.append(ed)
            
            if edgeWeight > 0.001 && ed.hasEdges {
                // Saliency gate
                var saliencyGate = (ed.energy - 8.0) / 24.0
                if saliencyGate < 0.0 { saliencyGate = 0.0 }
                if saliencyGate > 1.0 { saliencyGate = 1.0 }
                effArray[t] = edgeWeight * saliencyGate
            }
        }
        
        self.invNorm = invNormArray
        self.effectiveEdgeWeight = effArray
        self.isFullyOpaque = maskArray
        self.edgeDescriptors = edgeDescArray
    }
    
    deinit {
        tR.deallocate()
        tG.deallocate()
        tB.deallocate()
        tW.deallocate()
        tBlk.deallocate()
    }
}

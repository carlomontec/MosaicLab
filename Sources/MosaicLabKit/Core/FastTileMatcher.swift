import Foundation
import CoreGraphics
import simd

public struct FastMatchResult {
    public var candidateIndex: Int32
    public var score: Float
}

public final class FastTileMatcher {
    public static func match(
        store: PlanarTileStore,
        candidates: [SourceImageCandidate],
        metric: MosaicColorMetric,
        edgeWeight: Float,
        currentBestScores: [Float],
        keepTopK: Int
    ) -> [[FastMatchResult]] {
        let m = candidates.count
        guard m > 0 else { return [] }
        
        let n = store.tileCount
        
        var cR = [Float](repeating: 0, count: m * 256)
        var cG = [Float](repeating: 0, count: m * 256)
        var cB = [Float](repeating: 0, count: m * 256)
        var cBlk = [Float](repeating: 0, count: m * 48)
        let cEdge = candidates.map { $0.edgeDescriptor }
        
        for (c, cand) in candidates.enumerated() {
            cand.thumbnailPixels.withUnsafeBytes { raw in
                guard let px = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                for p in 0..<256 {
                    cR[c * 256 + p] = Float(px[p * 4])
                    cG[c * 256 + p] = Float(px[p * 4 + 1])
                    cB[c * 256 + p] = Float(px[p * 4 + 2])
                }
            }
            // Fill blocks
            for by in 0..<4 {
                for bx in 0..<4 {
                    var sr: Float = 0, sg: Float = 0, sb: Float = 0
                    for y in 0..<4 {
                        for x in 0..<4 {
                            let p = c * 256 + (by * 4 + y) * 16 + bx * 4 + x
                            sr += cR[p]
                            sg += cG[p]
                            sb += cB[p]
                        }
                    }
                    let k = by * 4 + bx
                    cBlk[c * 48 + k] = sr / 16.0
                    cBlk[c * 48 + 16 + k] = sg / 16.0
                    cBlk[c * 48 + 32 + k] = sb / 16.0
                }
            }
        }
        
        let lbScale: Float = metric == .rgb ? 1 : 2
        let gScale: Float = metric == .rgb ? 1 : 4
        
        // Minimize GCD overhead by dispatching exactly one chunk per CPU core
        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        let chunks = max(1, coreCount)
        let chunk = (n + chunks - 1) / chunks
        
        let isRGB = metric == .rgb
        let isMono = metric == .monochrome
        
        var results = [[FastMatchResult]](repeating: [], count: n)
        let resultsLock = NSLock()
        
        cR.withUnsafeBufferPointer { cRBuf in
        cG.withUnsafeBufferPointer { cGBuf in
        cB.withUnsafeBufferPointer { cBBuf in
        cBlk.withUnsafeBufferPointer { cBlkBuf in
        currentBestScores.withUnsafeBufferPointer { bestBuf in
            DispatchQueue.concurrentPerform(iterations: chunks) { ch in
                let startTile = ch * chunk
                let endTile = min(n, startTile + chunk)
                
                var localResults = [[FastMatchResult]](repeating: [], count: endTile - startTile)
                
                for t in startTile..<endTile {
                    let localT = t - startTile
                    var bs = bestBuf[t]
                    let inv = store.invNorm[t]
                    let e = store.effectiveEdgeWeight[t]
                    let ef = 1.0 - e
                    let full = store.isFullyOpaque[t]
                    
                    let tb = store.tBlk.advanced(by: t * 48)
                    let tr = store.tR.advanced(by: t * 256)
                    let tg = store.tG.advanced(by: t * 256)
                    let tb_channel = store.tB.advanced(by: t * 256)
                    let tw = store.tW.advanced(by: t * 256)
                    let tEd = store.edgeDescriptors[t]
                    
                    var topMatches = [FastMatchResult]()
                    topMatches.reserveCapacity(keepTopK + 1)
                    
                    for c in 0..<m {
                        // Jensen block mean pruning
                        if full {
                            let cb = cBlkBuf.baseAddress!.advanced(by: c * 48)
                            let dR = UnsafeRawPointer(tb).loadUnaligned(as: SIMD16<Float>.self) - UnsafeRawPointer(cb).loadUnaligned(as: SIMD16<Float>.self)
                            let dG = UnsafeRawPointer(tb + 16).loadUnaligned(as: SIMD16<Float>.self) - UnsafeRawPointer(cb + 16).loadUnaligned(as: SIMD16<Float>.self)
                            let dB = UnsafeRawPointer(tb + 32).loadUnaligned(as: SIMD16<Float>.self) - UnsafeRawPointer(cb + 32).loadUnaligned(as: SIMD16<Float>.self)
                            
                            let lb: Float
                            if isMono {
                                // Mono uses Luma for pruning approximation, but we can just use RGB for a safer bound or implement mono pruning
                                // Fallback to RGB pruning
                                lb = (dR * dR + dG * dG + dB * dB).sum() * 16.0 * inv * ef
                            } else {
                                lb = (lbScale * (dR * dR + dB * dB) + gScale * dG * dG).sum() * 16.0 * inv * ef
                            }
                            
                            let candidateLimit = min(bs, topMatches.last?.score ?? bs)
                            if keepTopK == 1 {
                                if lb >= bs { continue }
                            } else {
                                if topMatches.count == keepTopK && lb >= candidateLimit { continue }
                            }
                        }
                        
                        let cr = cRBuf.baseAddress!.advanced(by: c * 256)
                        let cg = cGBuf.baseAddress!.advanced(by: c * 256)
                        let cbb = cBBuf.baseAddress!.advanced(by: c * 256)
                        
                        var acc = SIMD16<Float>(repeating: 0)
                        var k = 0
                        while k < 256 {
                            let r1 = UnsafeRawPointer(tr + k).loadUnaligned(as: SIMD16<Float>.self)
                            let g1 = UnsafeRawPointer(tg + k).loadUnaligned(as: SIMD16<Float>.self)
                            let b1 = UnsafeRawPointer(tb_channel + k).loadUnaligned(as: SIMD16<Float>.self)
                            let w  = UnsafeRawPointer(tw + k).loadUnaligned(as: SIMD16<Float>.self)
                            
                            let r2 = UnsafeRawPointer(cr + k).loadUnaligned(as: SIMD16<Float>.self)
                            let g2 = UnsafeRawPointer(cg + k).loadUnaligned(as: SIMD16<Float>.self)
                            let b2 = UnsafeRawPointer(cbb + k).loadUnaligned(as: SIMD16<Float>.self)
                            
                            let dr = r1 - r2
                            let dg = g1 - g2
                            let db = b1 - b2
                            
                            if isRGB {
                                acc += w * (dr * dr + dg * dg + db * db)
                            } else if isMono {
                                let y1 = 0.2126 * r1 + 0.7152 * g1 + 0.0722 * b1
                                let y2 = 0.2126 * r2 + 0.7152 * g2 + 0.0722 * b2
                                let dy = y1 - y2
                                acc += w * (dy * dy)
                            } else {
                                // riemersma
                                let ravg = (r1 + r2) * (0.5 / 255.0)
                                acc += w * ((2.0 + ravg) * dr * dr + 4.0 * dg * dg + (3.0 - ravg) * db * db)
                            }
                            k += 16
                        }
                        
                        var s = min(1.0, acc.sum() * inv)
                        if e > 0 {
                            s = ef * s + e * MosaicCompareEdgeDescriptors(tEd, cEdge[c])
                        }
                        
                        // Only consider candidates that strictly improve this tile's current score
                        if s < bs {
                            if keepTopK == 1 {
                                bs = s
                                if topMatches.isEmpty { topMatches.append(FastMatchResult(candidateIndex: Int32(c), score: s)) }
                                else { topMatches[0] = FastMatchResult(candidateIndex: Int32(c), score: s) }
                            } else {
                                if topMatches.count < keepTopK || s < topMatches.last!.score {
                                    topMatches.append(FastMatchResult(candidateIndex: Int32(c), score: s))
                                    topMatches.sort { $0.score < $1.score }
                                    if topMatches.count > keepTopK { topMatches.removeLast() }
                                }
                            }
                        }
                    }
                    localResults[localT] = topMatches
                }
                
                resultsLock.lock()
                for t in startTile..<endTile {
                    results[t] = localResults[t - startTile]
                }
                resultsLock.unlock()
            }
        }}}}}
        
        return results
    }
}

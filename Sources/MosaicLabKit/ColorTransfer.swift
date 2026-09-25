import Foundation
import CoreGraphics
import Accelerate

/// Represents statistical color properties (mean and standard deviation) in OKLab perceptual color space.
public struct ColorStatistics: Sendable, Codable, Equatable {
    public let meanL: Float
    public let meanA: Float
    public let meanB: Float
    public let stdL: Float
    public let stdA: Float
    public let stdB: Float
    
    public init(meanL: Float, meanA: Float, meanB: Float, stdL: Float, stdA: Float, stdB: Float) {
        self.meanL = meanL
        self.meanA = meanA
        self.meanB = meanB
        // Use a small epsilon to prevent division-by-zero during normalization
        self.stdL = max(stdL, 0.001)
        self.stdA = max(stdA, 0.001)
        self.stdB = max(stdB, 0.001)
    }
}

/// Implements Reinhard Perceptual Color Transfer in the OKLab color space.
///
/// Based on:
/// - Reinhard et al. (2001), "Color Transfer between Images", IEEE CG&A
/// - Ottosson (2020), "A perceptual color space for image processing" (OKLab)
///
/// Shifts the mean and standard deviation of candidate image pixels to match
/// the target tile's color distribution, blended by an adjustable strength parameter.
public enum ColorTransfer {
    
    // MARK: - Fast Lookup Table (sRGB -> Linear)
    
    /// Precomputed 256-entry lookup table mapping 8-bit sRGB channel values to linear floating-point values.
    /// Eliminates expensive transcendental pow() calls in tight pixel loops.
    public static let srgbToLinearLUT: [Float] = {
        var lut = [Float](repeating: 0, count: 256)
        for b in 0...255 {
            let v = Float(b) / 255.0
            lut[b] = (v <= 0.04045) ? (v / 12.92) : pow((v + 0.055) / 1.055, 2.4)
        }
        return lut
    }()
    
    // MARK: - Color Space Conversions (sRGB <-> OKLab)
    
    @inline(__always)
    private static func srgbToLinear(_ c: Float) -> Float {
        let v = max(0.0, min(1.0, c))
        return (v <= 0.04045) ? (v / 12.92) : pow((v + 0.055) / 1.055, 2.4)
    }
    
    @inline(__always)
    private static func linearToSrgb(_ c: Float) -> Float {
        let v = max(0.0, min(1.0, c))
        let srgb = (v <= 0.0031308) ? (v * 12.92) : (1.055 * pow(v, 1.0 / 2.4) - 0.055)
        return max(0.0, min(1.0, srgb))
    }
    
    @inline(__always)
    private static func rgbToOKLab(r: Float, g: Float, b: Float) -> (l: Float, a: Float, b: Float) {
        let l_cone = cbrtf(max(0.0, 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b))
        let m_cone = cbrtf(max(0.0, 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b))
        let s_cone = cbrtf(max(0.0, 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b))
        
        let L = 0.2104542553 * l_cone + 0.7936177850 * m_cone - 0.0040720468 * s_cone
        let a = 1.9779984951 * l_cone - 2.4285922050 * m_cone + 0.4505937099 * s_cone
        let b_val = 0.0259040371 * l_cone + 0.7827717662 * m_cone - 0.8086757660 * s_cone
        
        return (L, a, b_val)
    }
    
    @inline(__always)
    private static func oklabToRGB(L: Float, a: Float, b: Float) -> (r: Float, g: Float, b: Float) {
        let l_cone = L + 0.3963377774 * a + 0.2158037573 * b
        let m_cone = L - 0.1055613458 * a - 0.0638541728 * b
        let s_cone = L - 0.0894841775 * a - 1.2914855480 * b
        
        let l3 = l_cone * l_cone * l_cone
        let m3 = m_cone * m_cone * m_cone
        let s3 = s_cone * s_cone * s_cone
        
        let r_lin = +4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
        let g_lin = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
        let b_lin = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3
        
        return (linearToSrgb(r_lin), linearToSrgb(g_lin), linearToSrgb(b_lin))
    }
    
    // MARK: - Statistical Calculations
    
    /// Computes mean and standard deviation in OKLab space from a raw RGBA byte buffer (e.g. 16x16 thumbnail).
    public static func computeStatistics(fromRGBA bytes: UnsafePointer<UInt8>, count: Int) -> ColorStatistics {
        guard count > 0 else {
            return ColorStatistics(meanL: 0.5, meanA: 0, meanB: 0, stdL: 0.1, stdA: 0.1, stdB: 0.1)
        }
        
        var sumL: Float = 0
        var sumA: Float = 0
        var sumB: Float = 0
        
        var oklabValues = [(l: Float, a: Float, b: Float)]()
        oklabValues.reserveCapacity(count)
        
        for i in 0..<count {
            let offset = i * 4
            let r = srgbToLinearLUT[Int(bytes[offset])]
            let g = srgbToLinearLUT[Int(bytes[offset + 1])]
            let b = srgbToLinearLUT[Int(bytes[offset + 2])]
            
            let lab = rgbToOKLab(r: r, g: g, b: b)
            oklabValues.append(lab)
            sumL += lab.l
            sumA += lab.a
            sumB += lab.b
        }
        
        let n = Float(count)
        let meanL = sumL / n
        let meanA = sumA / n
        let meanB = sumB / n
        
        var varL: Float = 0
        var varA: Float = 0
        var varB: Float = 0
        
        for v in oklabValues {
            let dL = v.l - meanL
            let dA = v.a - meanA
            let dB = v.b - meanB
            varL += dL * dL
            varA += dA * dA
            varB += dB * dB
        }
        
        let stdL = sqrt(varL / n)
        let stdA = sqrt(varA / n)
        let stdB = sqrt(varB / n)
        
        return ColorStatistics(meanL: meanL, meanA: meanA, meanB: meanB, stdL: stdL, stdA: stdA, stdB: stdB)
    }
    
    /// Computes OKLab statistics for a full CGImage.
    public static func computeStatistics(from image: CGImage) -> ColorStatistics {
        let width = min(image.width, 64)
        let height = min(image.height, 64)
        let totalPixels = width * height
        
        var buffer = [UInt8](repeating: 0, count: totalPixels * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let ctx = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return ColorStatistics(meanL: 0.5, meanA: 0, meanB: 0, stdL: 0.1, stdA: 0.1, stdB: 0.1)
        }
        
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return computeStatistics(fromRGBA: buffer, count: totalPixels)
    }
    
    // MARK: - Color Transfer Execution
    
    /// Applies Reinhard color transfer to a candidate CGImage based on target statistics and a strength factor [0.0, 1.0].
    /// Optionally accepts precomputed candidate `sourceStats` to avoid redundant statistical passes.
    public static func applyColorTransfer(
        to candidate: CGImage,
        sourceStats: ColorStatistics? = nil,
        targetStats: ColorStatistics,
        strength: Float
    ) -> CGImage {
        // If strength is virtually zero, return the original candidate untouched
        if strength <= 0.001 {
            return candidate
        }
        
        let width = candidate.width
        let height = candidate.height
        let totalPixels = width * height
        let bytesPerRow = width * 4
        
        var buffer = [UInt8](repeating: 0, count: totalPixels * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let ctx = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return candidate
        }
        
        ctx.interpolationQuality = .high
        ctx.draw(candidate, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 1. Candidate's own color statistics (cached or computed)
        let srcStats = sourceStats ?? computeStatistics(fromRGBA: buffer, count: totalPixels)
        
        // Scale factors: ratio of target variance to source variance
        let scaleL = targetStats.stdL / srcStats.stdL
        let scaleA = targetStats.stdA / srcStats.stdA
        let scaleB = targetStats.stdB / srcStats.stdB
        
        let lambda = max(0.0, min(1.0, strength))
        
        // Combined linear interpolation coefficients:
        // final = (1 - lambda) * orig + lambda * ((orig - srcMean) * scale + targetMean)
        //       = orig * ((1 - lambda) + lambda * scale) + lambda * (targetMean - srcMean * scale)
        let coeffL = (1.0 - lambda) + lambda * scaleL
        let biasL  = lambda * (targetStats.meanL - srcStats.meanL * scaleL)
        
        let coeffA = (1.0 - lambda) + lambda * scaleA
        let biasA  = lambda * (targetStats.meanA - srcStats.meanA * scaleA)
        
        let coeffB = (1.0 - lambda) + lambda * scaleB
        let biasB  = lambda * (targetStats.meanB - srcStats.meanB * scaleB)
        
        // 2. Transform pixels in OKLab space
        for i in 0..<totalPixels {
            let offset = i * 4
            let rRaw = buffer[offset]
            let gRaw = buffer[offset + 1]
            let bRaw = buffer[offset + 2]
            let aRaw = buffer[offset + 3]
            
            // Linear RGB via LUT -> OKLab
            let rLin = srgbToLinearLUT[Int(rRaw)]
            let gLin = srgbToLinearLUT[Int(gRaw)]
            let bLin = srgbToLinearLUT[Int(bRaw)]
            
            let origLab = rgbToOKLab(r: rLin, g: gLin, b: bLin)
            
            // Fast Reinhard FMA transfer
            let finalL = origLab.l * coeffL + biasL
            let finalA = origLab.a * coeffA + biasA
            let finalB = origLab.b * coeffB + biasB
            
            // OKLab -> sRGB
            let (rOut, gOut, bOut) = oklabToRGB(L: finalL, a: finalA, b: finalB)
            
            buffer[offset]     = UInt8(max(0.0, min(255.0, rOut * 255.0 + 0.5)))
            buffer[offset + 1] = UInt8(max(0.0, min(255.0, gOut * 255.0 + 0.5)))
            buffer[offset + 2] = UInt8(max(0.0, min(255.0, bOut * 255.0 + 0.5)))
            buffer[offset + 3] = aRaw // Preserve original alpha
        }
        
        return ctx.makeImage() ?? candidate
    }
    
    /// Converts a CGImage to pristine Rec. 709 grayscale / monochrome.
    public static func convertToMonochrome(_ image: CGImage) -> CGImage {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return image }
        
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: grayColorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return image
        }
        
        context.interpolationQuality = CGInterpolationQuality.high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}

// MARK: - MosaicTile Integration

private var tileStatsAssociationKey: UInt8 = 0

final class ColorStatisticsBox: @unchecked Sendable {
    let value: ColorStatistics
    init(_ value: ColorStatistics) { self.value = value }
}

extension MosaicTile {
    /// Lazily computes and caches the OKLab color statistics of the target tile.
    public var targetColorStatistics: ColorStatistics {
        if let existing = objc_getAssociatedObject(self, &tileStatsAssociationKey) as? ColorStatisticsBox {
            return existing.value
        }
        
        guard let data = self.targetPixels else {
            return ColorStatistics(meanL: 0.5, meanA: 0, meanB: 0, stdL: 0.1, stdA: 0.1, stdB: 0.1)
        }
        
        let stats = (data as Data).withUnsafeBytes { ptr -> ColorStatistics in
            guard let baseAddress = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return ColorStatistics(meanL: 0.5, meanA: 0, meanB: 0, stdL: 0.1, stdA: 0.1, stdB: 0.1)
            }
            return ColorTransfer.computeStatistics(fromRGBA: baseAddress, count: (data as Data).count / 4)
        }
        
        objc_setAssociatedObject(self, &tileStatsAssociationKey, ColorStatisticsBox(stats), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return stats
    }
}

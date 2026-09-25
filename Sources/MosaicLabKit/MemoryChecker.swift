import Foundation
import Darwin

public struct MemoryEstimate {
    public let physicalMemoryBytes: UInt64
    public let availableMemoryBytes: UInt64
    public let thumbnailBytes: UInt64
    public let tileMaskBytes: UInt64
    public let canvasBytes: UInt64
    public let workingBufferBytes: UInt64
    public let totalPeakBytes: UInt64
    
    public var peakPercentageOfPhysical: Double {
        return Double(totalPeakBytes) / Double(physicalMemoryBytes) * 100.0
    }
    
    public var isSafe: Bool {
        return totalPeakBytes <= availableMemoryBytes && peakPercentageOfPhysical < 50.0
    }
    
    public var isDangerous: Bool {
        return totalPeakBytes > availableMemoryBytes || peakPercentageOfPhysical > 75.0
    }
}

public final class MemoryChecker {
    public init() {}
    
    public static func getSystemMemoryInfo() -> (physical: UInt64, available: UInt64) {
        let physical = ProcessInfo.processInfo.physicalMemory
        
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            var pageSize: vm_size_t = 0
            _ = host_page_size(hostPort, &pageSize)
            let freePages = UInt64(stats.free_count) + UInt64(stats.inactive_count)
            let available = freePages * UInt64(pageSize)
            return (physical, available)
        }
        
        // Fallback: estimate available as 50% of physical
        return (physical, physical / 2)
    }
    
    public static func estimate(
        sourceImageCount: Int,
        tileCount: Int,
        outputWidth: Int,
        outputHeight: Int
    ) -> MemoryEstimate {
        let (physical, available) = getSystemMemoryInfo()
        
        // 1. Each 16x16 thumbnail is 16 * 16 * 4 bytes = 1,024 bytes (1 KB)
        let thumbBytes = UInt64(max(0, sourceImageCount)) * 1024
        
        // 2. Each tile has geometry + 16x16 mask (256B) + 16x16 snippet (1024B) + metadata (~500B) = ~1.8 KB
        let tileBytes = UInt64(max(0, tileCount)) * 1800
        
        // 3. High-resolution canvas framebuffer: width * height * 4 bytes (RGBA)
        let canvasBytes = UInt64(max(1, outputWidth)) * UInt64(max(1, outputHeight)) * 4
        
        // 4. Working buffer for decoding 1 full-res image during render + ImageIO scratch: ~64 MB
        let workingBuffer: UInt64 = 64 * 1024 * 1024
        
        let totalPeak = thumbBytes + tileBytes + canvasBytes + workingBuffer
        
        return MemoryEstimate(
            physicalMemoryBytes: physical,
            availableMemoryBytes: available,
            thumbnailBytes: thumbBytes,
            tileMaskBytes: tileBytes,
            canvasBytes: canvasBytes,
            workingBufferBytes: workingBuffer,
            totalPeakBytes: totalPeak
        )
    }
    
    public static func formatBytes(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1024 * 1024 {
            return String(format: "%.1f KB", b / 1024.0)
        } else if b < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", b / (1024.0 * 1024.0))
        } else {
            return String(format: "%.2f GB", b / (1024.0 * 1024.0 * 1024.0))
        }
    }
    
    public static func printReport(estimate: MemoryEstimate, sourceCount: Int, tileCount: Int, width: Int, height: Int) {
        print("--------------------------------------------------")
        print("  RAM & Memory Pre-Flight Check:")
        print("--------------------------------------------------")
        print("  System Physical RAM:    \(formatBytes(estimate.physicalMemoryBytes))")
        print("  System Available RAM:   ~\(formatBytes(estimate.availableMemoryBytes))")
        print("  Source Thumbnails:      \(formatBytes(estimate.thumbnailBytes)) (\(sourceCount) photos @ 16x16)")
        print("  Tile Vector Masks:      \(formatBytes(estimate.tileMaskBytes)) (\(tileCount) tiles)")
        print("  Canvas Framebuffer:     \(formatBytes(estimate.canvasBytes)) (\(width) x \(height) px)")
        print("  Working Decode Buffer:  ~\(formatBytes(estimate.workingBufferBytes))")
        print("  ------------------------------------------------")
        print(String(format: "  Estimated Peak RAM:     %@ (%.1f%% of system RAM)",
                     formatBytes(estimate.totalPeakBytes),
                     estimate.peakPercentageOfPhysical))
        
        if estimate.isSafe {
            print("  Memory Safety Status:   [OK] Safe to proceed!")
        } else if estimate.isDangerous {
            print("  Memory Safety Status:   [DANGER] Exceeds 80% of physical RAM! Mosaic may cause swapping.")
        } else {
            print("  Memory Safety Status:   [CAUTION] Moderate memory footprint. Proceeding.")
        }
        print("--------------------------------------------------")
    }
}

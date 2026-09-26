import SwiftUI

public struct QuadtreeInfoView: View {
    let onClose: () -> Void
    
    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.orange.opacity(0.8), .pink.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                    Image(systemName: "square.split.2x2")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adaptive Multi-Resolution Tiling")
                        .font(.headline)
                    Text("Hierarchical Quadtree Decomposition")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Core Concept
            VStack(alignment: .leading, spacing: 6) {
                Label("How it Works", systemImage: "sparkles")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Uniform grid mosaics force a compromise: if tiles are small, background photos lose identity; if tiles are large, facial features and sharp contours become blocky.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Adaptive Tiling dynamically divides the canvas based on local image contrast and detail. Regions with high variance (eyes, silhouettes, text) recursively split into fine sub-tiles, while uniform regions (skies, walls) remain large, beautiful photos.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Real-Time Integral Image
            VStack(alignment: .leading, spacing: 6) {
                Label("O(1) Constant-Time Variance", systemImage: "bolt.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("By precomputing Summed-Area Tables (Integral Images of luminance and squared luminance), the variance of any arbitrary sub-region is computed in 8 table lookups. This enables instant real-time tile re-tessellation in under 2 milliseconds.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Recommended Settings
            VStack(alignment: .leading, spacing: 6) {
                Label("Recommended Settings", systemImage: "slider.horizontal.3")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 6) {
                        Text("• Base Grid:")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("16–24 across. Governs the size of large background photos.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("• Max Depth:")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("Level 2 or 3 (allows up to 16× or 64× smaller focal tiles).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("• Sensitivity:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        Text("12% – 18%: Sweet spot! Crisp focal points with balanced backgrounds.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .background(Color.platformControlBackground.opacity(0.6))
                .cornerRadius(6)
            }
            
            Divider()
            
            // Academic Sources & Citations
            VStack(alignment: .leading, spacing: 6) {
                Label("Academic References", systemImage: "books.vertical.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Finkel, R. A., & Bentley, J. L. (1974). Quad Trees: A Data Structure for Retrieval on Composite Keys. Acta Informatica, 4(1), 1–9.")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("2. Crow, F. C. (1984). Summed-Area Tables for Texture Mapping. ACM SIGGRAPH Computer Graphics, 18(3), 207–212.")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("3. Klein, A. W., Grant, T., Finkelstein, A., & Salesin, D. H. (2002). Non-photorealistic Virtual Environments. ACM SIGGRAPH, 527–534.")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(width: 440)
    }
}

import SwiftUI

public struct EdgeMatchingInfoView: View {
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
                            colors: [.teal.opacity(0.8), .indigo.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                    Image(systemName: "lines.measurement.horizontal")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edge-Aware Matching")
                        .font(.headline)
                    Text("Sobel Gradients & HOG Directional Alignment")
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
                Text("Standard photomosaic matching evaluates only color values. When a target tile contains a sharp edge (such as an eye contour, silhouette, or architectural horizon), traditional matching may place an image that has the right color but runs completely counter to the line flow.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Edge-Aware matching computes an 8-bin **Histogram of Oriented Gradients (HOG)** using 3×3 Sobel spatial filters, rewarding candidate photos whose internal visual lines flow along the target image contours.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Saliency Gating
            VStack(alignment: .leading, spacing: 6) {
                Label("Saliency Gating", systemImage: "shield.checkered")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("In flat target regions (like clear skies or smooth skin), edge energy is near zero. The algorithm automatically gates the edge weight down to zero in these areas, ensuring color matching remains optimal without noise.")
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
                        Text("• 0%:")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("Standard color-only matching (classic MacOSaiX).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("• 25% – 45%:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        Text("Sweet spot! Strengthens contours, silhouettes, and structural features.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("• 70% – 100%:")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("Strong structural alignment, favoring edge continuity over color tone.")
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
                    Text("1. Dalal, N., & Triggs, B. (2005). Histograms of Oriented Gradients for Human Detection. IEEE CVPR, 1, 886–893.")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("2. Park, J., Kang, K., & Chung, K. (2006). Edge-based Tile Mosaic Simulation. Computer Graphics Forum, 25(3), 441–448.")
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

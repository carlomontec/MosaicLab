import SwiftUI

public struct ColorTransferInfoView: View {
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
                            colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                    Image(systemName: "paintpalette.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Perceptual Color Transfer")
                        .font(.headline)
                    Text("Reinhard Statistical Harmonization in OKLab")
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
                Text("Unlike simple opacity blending—which washes out photos into a faint overlay—Reinhard color transfer shifts the statistical color distribution (mean and variance) of each constituent photo to match its assigned tile.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Why OKLab
            VStack(alignment: .leading, spacing: 6) {
                Label("Why OKLab Space?", systemImage: "chart.xyaxis.line")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Classical Reinhard transfer operates in Ruderman ℓαβ. MacOSaiX Remake uses the modern **OKLab** perceptual space (2020), which cleanly decorrelates lightness from chroma. This keeps internal photo contrast, edges, and deep shadows razor-sharp while naturally adjusting hue and saturation.")
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
                        Text("Raw, unadjusted source photos (classic photomosaic).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("• 30% – 50%:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        Text("Sweet spot! Preserves photo authenticity while tying the whole mosaic together.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("• 100%:")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("Full chromatic convergence to the target image's palette.")
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
                    Text("1. Reinhard, E., Ashikhmin, M., Gooch, B., & Shirley, P. (2001). Color Transfer between Images. IEEE Computer Graphics and Applications, 21(5), 34–41.")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("2. Ottosson, B. (2020). A perceptual color space for image processing (Oklab).")
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

import SwiftUI
import AppKit

public struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let iconImage = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: iconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            }
            
            // Header
            VStack(spacing: 4) {
                Text("MosaicLab")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Version 0.1.0 • Apple Silicon Native")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Description & Credits
            VStack(alignment: .leading, spacing: 14) {
                Text("A native tool for creating high-resolution photomosaics using modern computer vision and image processing algorithms.")
                    .font(.callout)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inspiration:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text("Inspired by Frank M. Midgley's classic Mac OS X software MacOSaiX (2002–2007).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Engineering:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text("Engineered by Carlo Monjaraz-Tec (2026) using native macOS technologies:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        bulletPoint("Adaptive quadtree subdivision (Julia range & color divergence) with 2:1 neighbor balancing")
                        bulletPoint("Edge-aware directional matching using 8-bin Sobel HOG gradient histograms")
                        bulletPoint("Reinhard statistical color transfer in OKLab perceptual color space")
                        bulletPoint("Multi-threaded asynchronous solver with real-time memory safety check")
                        bulletPoint("Native Apple Photos (PhotoKit) and local folder source pooling")
                        bulletPoint("Interlocking cubic Bézier jigsaw puzzles, hexagonal, and rectangular tessellations")
                    }
                    .padding(.top, 2)
                    .padding(.leading, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Footer & Link
            HStack {
                Button(action: {
                    if let url = URL(string: "https://github.com/carlomontec/MosaicLab") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("GitHub Project", systemImage: "link")
                }
                .buttonStyle(.link)
                
                Spacer()
                
                Button("OK") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.regular)
            }
        }
        .padding(26)
        .frame(width: 480)
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

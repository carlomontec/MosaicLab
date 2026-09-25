import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct TargetImageWell: View {
    @EnvironmentObject private var viewModel: MosaicViewModel
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            if let nsImage = viewModel.targetNSImage {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 140)
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                    
                    Button(action: {
                        viewModel.targetImageURL = nil
                        viewModel.targetNSImage = nil
                        viewModel.targetCGImage = nil
                        viewModel.targetResolutionText = "No image loaded"
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .padding(4)
                }
                
                Text(viewModel.targetResolutionText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                    
                    Text("Drop target image here")
                        .font(.callout)
                        .fontWeight(.medium)
                    
                    Text("Supports HEIC, AVIF, JPEG, PNG, WebP, TIFF")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Button("Choose Picture...") {
                        selectTargetImage()
                    }
                    .controlSize(.small)
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            viewModel.isTargetDropTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: viewModel.isTargetDropTargeted ? 2 : 1, dash: [5])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.isTargetDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                        )
                )
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isTargetDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let fileURL = url else { return }
                DispatchQueue.main.async {
                    if fileURL.pathExtension.lowercased() == "macosaix" {
                        viewModel.openProject(from: fileURL)
                    } else {
                        viewModel.setTargetImage(from: fileURL)
                    }
                }
            }
            return true
        }
    }
    
    private func selectTargetImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        var types: [UTType] = [.image, .heic, .jpeg, .png, .tiff]
        if let hifType = UTType(filenameExtension: "hif") {
            types.append(hifType)
        }
        if let avifType = UTType(filenameExtension: "avif") {
            types.append(avifType)
        }
        if let webpType = UTType(filenameExtension: "webp") {
            types.append(webpType)
        }
        panel.allowedContentTypes = types
        panel.prompt = "Choose Target"
        
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.setTargetImage(from: url)
        }
    }
}

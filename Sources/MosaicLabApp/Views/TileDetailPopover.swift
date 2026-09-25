import SwiftUI
import AppKit
import UniformTypeIdentifiers
import MosaicLabKit

public struct TileDetailPopover: View {
    @EnvironmentObject private var viewModel: MosaicViewModel
    let tile: MosaicTile
    let onClose: () -> Void
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tile (\(tile.geometry.gridX), \(tile.geometry.gridY))")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            if let imageURL = tile.bestImageURL {
                if let nsImg = viewModel.imageForTile(tile) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240, maxHeight: 180)
                        .cornerRadius(6)
                        .shadow(radius: 2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if imageURL.scheme == "applephotos" {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.stack")
                                .foregroundColor(.accentColor)
                            Text("Apple Photos")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Text(imageURL.lastPathComponent)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    
                    let matchPct = max(0, min(100, Int((1.0 - tile.bestScore) * 100)))
                    Text("Match Quality: \(matchPct)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    HStack(spacing: 6) {
                        // Find Substitute (Next Best Candidate)
                        Button(action: {
                            viewModel.findSubstitute(for: tile)
                        }) {
                            HStack(spacing: 4) {
                                if viewModel.isFindingSubstitute {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text("Find Substitute")
                            }
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isFindingSubstitute || viewModel.foundImageURLs.isEmpty)
                        .help("Evaluate candidate images and assign the next-best matching photo for this tile")
                        
                        // Manual Choose Photo
                        Button(action: {
                            chooseManualPhoto()
                        }) {
                            Image(systemName: "photo.badge.plus")
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                        .help("Choose any photo from disk to place in this tile")
                        
                        // Reveal in Finder (for local files)
                        if imageURL.isFileURL {
                            Button(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([imageURL])
                            }) {
                                Image(systemName: "folder")
                            }
                            .controlSize(.small)
                            .buttonStyle(.bordered)
                            .help("Reveal original photo in Finder")
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("No photo matched to this tile yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                
                Button(action: {
                    chooseManualPhoto()
                }) {
                    Label("Choose Photo...", systemImage: "photo.badge.plus")
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 280)
    }
    
    private func chooseManualPhoto() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        var types: [UTType] = [.image, .heic, .jpeg, .png, .tiff]
        if let hif = UTType(filenameExtension: "hif") { types.append(hif) }
        if let avif = UTType(filenameExtension: "avif") { types.append(avif) }
        if let webp = UTType(filenameExtension: "webp") { types.append(webp) }
        panel.allowedContentTypes = types
        panel.prompt = "Select Photo"
        
        if panel.runModal() == .OK, let selectedURL = panel.url {
            viewModel.manuallySubstitute(tile: tile, imageURL: selectedURL)
        }
    }
}

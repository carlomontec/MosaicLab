import SwiftUI
import MosaicLabKit
#if os(macOS)
import AppKit
#endif

public struct SettingsView: View {
    @EnvironmentObject private var viewModel: MosaicViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Memory (RAM) Cache").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Active Descriptors in RAM", systemImage: "memorychip")
                            .font(.subheadline)
                        Spacer()
                        Text("\(viewModel.ramCacheSizeText)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }
                    
                    Text("\(viewModel.ramCachePhotosCount) candidate photo descriptors currently resident in memory. Retained between runs so tweaking layout parameters matches instantly without disk decoding.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button(role: .destructive, action: {
                            viewModel.showingClearRAMConfirm = true
                        }) {
                            Text("Clear RAM Cache")
                        }
                        .disabled(viewModel.ramCachePhotosCount == 0 || viewModel.isRunning)
                        .confirmationDialog("Clear RAM Cache?", isPresented: $viewModel.showingClearRAMConfirm) {
                            Button("Clear RAM", role: .destructive) {
                                viewModel.clearRAMCache()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will purge all in-memory photo descriptors. Any subsequent runs will reload from the disk cache or original files.")
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Persistent Disk Cache").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Cached Descriptors on Disk", systemImage: "internaldrive")
                            .font(.subheadline)
                        Spacer()
                        Text("\(viewModel.diskCacheSizeText)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                    }
                    
                    Text("\(viewModel.diskCachePhotosCount) preprocessed photo descriptors saved in SQLite on your Mac. When reopening MosaicLab or matching new targets, pre-analyzed photos load in milliseconds.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Maximum Disk Cache Size:", selection: $viewModel.maxDiskBytesLimit) {
                        Text("500 MB").tag(500 * 1024 * 1024)
                        Text("1 GB").tag(1024 * 1024 * 1024)
                        Text("2 GB (Default)").tag(2 * 1024 * 1024 * 1024)
                        Text("5 GB").tag(5 * 1024 * 1024 * 1024)
                        Text("10 GB").tag(10 * 1024 * 1024 * 1024)
                        Text("Unlimited").tag(0)
                    }
                    .pickerStyle(.menu)
                    
                    HStack(spacing: 12) {
                        Button(role: .destructive, action: {
                            viewModel.showingClearDiskConfirm = true
                        }) {
                            Text("Purge Disk Cache")
                        }
                        .disabled(viewModel.diskCachePhotosCount == 0 || viewModel.isRunning)
                        .confirmationDialog("Purge Disk Cache?", isPresented: $viewModel.showingClearDiskConfirm) {
                            Button("Purge Disk Cache", role: .destructive) {
                                viewModel.clearDiskCache()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will delete all saved descriptor files in ~/Library/Caches. Photos will need to be re-analyzed on future runs.")
                        }
                        
                        #if os(macOS)
                        Button("Reveal in Finder") {
                            let folder = SourceCandidateCache.shared.cacheFolderURL
                            NSWorkspace.shared.activateFileViewerSelecting([folder])
                        }
                        #endif
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Tile Thumbnail Cache").font(.headline)) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Display thumbnails (256px) are cached in memory for Retina-sharp canvas blitting. If macOS reports high memory pressure, thumbnails evict automatically.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Clear All Caches (RAM & Disk)") {
                        viewModel.clearAllCaches()
                    }
                    .disabled(viewModel.isRunning)
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 380)
        .onAppear {
            viewModel.updateCacheStatistics()
        }
    }
}

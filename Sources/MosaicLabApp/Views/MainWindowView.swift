import SwiftUI
import AppKit
import MosaicLabKit

public struct MainWindowView: View {
    @EnvironmentObject private var viewModel: MosaicViewModel
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            SidebarView()
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
            
            MosaicCanvasView()
                .frame(minWidth: 500, minHeight: 450)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                // Open Project
                Button(action: {
                    viewModel.openProjectPrompt()
                }) {
                    Image(systemName: "folder")
                }
                .help("Open Project (⌘O)")
                .disabled(viewModel.isExporting)
                
                // Save Project
                Button(action: {
                    viewModel.saveProject()
                }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Save Project (⌘S)")
                .disabled(viewModel.targetCGImage == nil || viewModel.isExporting)
                
                // About Button
                Button(action: {
                    viewModel.isAboutPresented = true
                }) {
                    Image(systemName: "info.circle")
                }
                .help("About MosaicLab")
                .disabled(viewModel.isExporting || viewModel.isLoadingProject)
            }
            
            ToolbarItem(placement: .principal) {
                // Centered Status & Progress indicator
                HStack(spacing: 8) {
                    if (viewModel.isRunning && !viewModel.isPaused) || viewModel.isExporting || viewModel.isLoadingProject {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.statusMessage)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                        .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
                )
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                // Export Button
                Button(action: {
                    viewModel.isExportSheetPresented = true
                }) {
                    Label("Export...", systemImage: "square.and.arrow.up")
                }
                .disabled(!viewModel.hasCompletedTiles || viewModel.isExporting || viewModel.isLoadingProject)
                .keyboardShortcut("e", modifiers: [.command])
                
                // Play / Pause matching (Top Right Corner)
                Button(action: {
                    viewModel.toggleMatching()
                }) {
                    Label(
                        viewModel.isRunning ? (viewModel.isPaused ? "Resume" : "Pause") : "Start",
                        systemImage: viewModel.isRunning ? (viewModel.isPaused ? "play.fill" : "pause.fill") : "play.fill"
                    )
                }
                .disabled((!viewModel.canStart && !viewModel.isRunning) || viewModel.isExporting || viewModel.isLoadingProject)
                .keyboardShortcut("r", modifiers: [.command])
                
                if viewModel.isRunning {
                    Button(action: {
                        viewModel.stopMatching()
                    }) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .keyboardShortcut(".", modifiers: [.command])
                    .disabled(viewModel.isExporting || viewModel.isLoadingProject)
                }
            }
        }
        .overlay {
            if viewModel.isExporting {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text(viewModel.statusMessage)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text("Please wait while the high-resolution mosaic is being rendered and written to disk.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: 360)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
                    )
                }
                .transition(.opacity)
                .allowsHitTesting(true)
            } else if viewModel.isLoadingProject {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.regular)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Loading \(viewModel.loadingProjectName)...")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Reconstructing mosaic geometry & matching records")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        ProgressView(value: viewModel.projectLoadingProgress, total: 1.0)
                            .progressViewStyle(.linear)
                        
                        // Progress Logging Console
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(viewModel.projectLoadingLogs.enumerated()), id: \.offset) { idx, log in
                                        HStack(alignment: .top, spacing: 6) {
                                            if idx == viewModel.projectLoadingLogs.count - 1 && viewModel.projectLoadingProgress < 1.0 {
                                                Image(systemName: "arrow.right.circle.fill")
                                                    .foregroundColor(.accentColor)
                                                    .font(.caption2)
                                            } else {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                                    .font(.caption2)
                                            }
                                            Text(log)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(idx == viewModel.projectLoadingLogs.count - 1 ? .primary : .secondary)
                                        }
                                        .id(idx)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                            }
                            .frame(height: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .onChange(of: viewModel.projectLoadingLogs.count) { newCount in
                                if newCount > 0 {
                                    withAnimation {
                                        proxy.scrollTo(newCount - 1, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 460)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.25), radius: 14, y: 6)
                    )
                }
                .transition(.opacity)
                .allowsHitTesting(true)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isExporting)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoadingProject)
        .sheet(isPresented: $viewModel.isExportSheetPresented) {
            ExportSheetView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.isAboutPresented) {
            AboutView()
        }
        .popover(item: $viewModel.selectedTile) { tile in
            TileDetailPopover(tile: tile) {
                viewModel.selectedTile = nil
            }
            .environmentObject(viewModel)
        }
        .alert("Clear Matched Tiles?", isPresented: $viewModel.showingLayoutChangeWarning) {
            Button("Save As New Project...") {
                viewModel.saveAsBeforeLayoutChange()
            }
            Button("Discard Matches & Change", role: .destructive) {
                viewModel.confirmLayoutChange()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelLayoutChange()
            }
        } message: {
            let matches = viewModel.matchedTilesCount
            let diskMsg = viewModel.currentProjectURL != nil ? "\n\nYour saved project file on disk (“\(viewModel.currentProjectURL!.lastPathComponent)”) will remain untouched unless you choose to overwrite it." : ""
            Text("Modifying \(viewModel.pendingLayoutDescription) will regenerate all tile shapes and discard \(matches) matched photos.\(diskMsg)")
        }
        .alert("Overwrite Existing Project?", isPresented: $viewModel.showingOverwriteSavedWarning) {
            Button("Save As New Project...") {
                viewModel.saveProjectAsPrompt()
            }
            Button("Overwrite", role: .destructive) {
                if let url = viewModel.currentProjectURL {
                    viewModel.hasDiscardedMatchesFromSavedFile = false
                    viewModel.saveProject(to: url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let filename = viewModel.currentProjectURL?.lastPathComponent ?? "the file"
            Text("The project file “\(filename)” on disk has previously matched tiles, but your current workspace has regenerated tiles without matches.\n\nOverwriting will replace the file on disk with the current empty grid.")
        }
    }
}

// Extension to allow MosaicTile in .popover(item:)
extension MosaicTile: Identifiable {
    public var id: Int {
        return self.geometry.tileIndex
    }
}

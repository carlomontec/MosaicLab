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
                
                // Save Project
                Button(action: {
                    viewModel.saveProject()
                }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Save Project (⌘S)")
                .disabled(viewModel.targetCGImage == nil)
                
                // About Button
                Button(action: {
                    viewModel.isAboutPresented = true
                }) {
                    Image(systemName: "info.circle")
                }
                .help("About MosaicLab")
            }
            
            ToolbarItem(placement: .principal) {
                // Centered Status & Progress indicator
                HStack(spacing: 8) {
                    if (viewModel.isRunning && !viewModel.isPaused) || viewModel.isExporting {
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
                .disabled(!viewModel.hasCompletedTiles)
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
                .disabled(!viewModel.canStart && !viewModel.isRunning)
                .keyboardShortcut("r", modifiers: [.command])
                
                if viewModel.isRunning {
                    Button(action: {
                        viewModel.stopMatching()
                    }) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .keyboardShortcut(".", modifiers: [.command])
                }
            }
        }
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
    }
}

// Extension to allow MosaicTile in .popover(item:)
extension MosaicTile: Identifiable {
    public var id: Int {
        return self.geometry.tileIndex
    }
}

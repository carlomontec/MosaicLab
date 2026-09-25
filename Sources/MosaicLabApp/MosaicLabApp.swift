import SwiftUI
import AppKit

@MainActor
final class MosaicLabAppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: MosaicViewModel?
    private var pendingOpenURL: URL?
    
    func setViewModel(_ vm: MosaicViewModel) {
        self.viewModel = vm
        if let pending = pendingOpenURL {
            vm.openProject(from: pending)
            pendingOpenURL = nil
        }
    }
    
    nonisolated func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            let ext = url.pathExtension.lowercased()
            if ext == "mosaiclab" {
                Task { @MainActor [weak self] in
                    if let vm = self?.viewModel {
                        vm.openProject(from: url)
                    } else {
                        self?.pendingOpenURL = url
                    }
                }
                break
            }
        }
    }
}

@main
struct MosaicLabApp: App {
    @NSApplicationDelegateAdaptor(MosaicLabAppDelegate.self) private var appDelegate
    @StateObject private var viewModel = MosaicViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(viewModel)
                .frame(minWidth: 960, minHeight: 650)
                .navigationTitle(viewModel.currentProjectURL?.lastPathComponent ?? "MosaicLab")
                .onAppear {
                    appDelegate.setViewModel(viewModel)
                }
                .onOpenURL { url in
                    let ext = url.pathExtension.lowercased()
                    if ext == "mosaiclab" {
                        viewModel.openProject(from: url)
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About MosaicLab") {
                    viewModel.isAboutPresented = true
                }
            }
            
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    viewModel.newProject()
                }
                .keyboardShortcut("n", modifiers: [.command])
                
                Button("Open Project...") {
                    viewModel.openProjectPrompt()
                }
                .keyboardShortcut("o", modifiers: [.command])
                
                Divider()
                
                Button("Save Project") {
                    viewModel.saveProject()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(viewModel.targetCGImage == nil)
                
                Button("Save Project As...") {
                    viewModel.saveProjectAsPrompt()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(viewModel.targetCGImage == nil)
                
                Divider()
                
                Button("Export Mosaic...") {
                    viewModel.isExportSheetPresented = true
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(!viewModel.hasCompletedTiles)
            }
        }
    }
}

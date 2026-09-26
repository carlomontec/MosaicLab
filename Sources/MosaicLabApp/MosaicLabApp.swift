import SwiftUI
#if os(macOS)
import AppKit
import UserNotifications

@MainActor
final class MosaicLabAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var viewModel: MosaicViewModel?
    private var pendingOpenURL: URL?
    private var lastHandledURL: URL?
    private var lastHandledTime: TimeInterval = 0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    func setViewModel(_ vm: MosaicViewModel) {
        self.viewModel = vm
        if let pending = pendingOpenURL {
            handleOpenURL(pending)
            pendingOpenURL = nil
        }
    }
    
    func handleOpenURL(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        guard ext == "mosaiclab" || ext == "macosaix" else { return }
        
        let now = ProcessInfo.processInfo.systemUptime
        if lastHandledURL == url && (now - lastHandledTime) < 1.5 {
            return
        }
        lastHandledURL = url
        lastHandledTime = now
        
        if let vm = viewModel {
            vm.openProject(from: url)
            NSApplication.shared.activate(ignoringOtherApps: true)
        } else {
            pendingOpenURL = url
        }
    }
    
    nonisolated func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            Task { @MainActor [weak self] in
                self?.handleOpenURL(url)
                sender.reply(toOpenOrPrint: .success)
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }
}
#endif

@main
struct MosaicLabApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MosaicLabAppDelegate.self) private var appDelegate
    #endif
    @StateObject private var viewModel = MosaicViewModel()
    
    var body: some Scene {
        #if os(macOS)
        Window("MosaicLab", id: "main") {
            MainWindowView()
                .environmentObject(viewModel)
                .frame(minWidth: 960, minHeight: 650)
                .navigationTitle(viewModel.currentProjectURL?.lastPathComponent ?? "MosaicLab")
                .onAppear {
                    appDelegate.setViewModel(viewModel)
                }
                .onOpenURL { url in
                    appDelegate.handleOpenURL(url)
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
                .disabled(viewModel.isExporting || viewModel.isLoadingProject)
                
                Button("Open Project...") {
                    viewModel.openProjectPrompt()
                }
                .keyboardShortcut("o", modifiers: [.command])
                .disabled(viewModel.isExporting || viewModel.isLoadingProject)
                
                Divider()
                
                Button("Save Project") {
                    viewModel.saveProject()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(viewModel.targetCGImage == nil || viewModel.isExporting || viewModel.isLoadingProject)
                
                Button("Save Project As...") {
                    viewModel.saveProjectAsPrompt()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(viewModel.targetCGImage == nil || viewModel.isExporting || viewModel.isLoadingProject)
                
                Divider()
                
                Button("Export Mosaic...") {
                    viewModel.isExportSheetPresented = true
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(!viewModel.hasCompletedTiles || viewModel.isExporting || viewModel.isLoadingProject)
            }
        }
        #else
        WindowGroup {
            MainWindowView()
                .environmentObject(viewModel)
                .navigationTitle(viewModel.currentProjectURL?.lastPathComponent ?? "MosaicLab")
                .onOpenURL { url in
                    viewModel.openProject(from: url)
                }
        }
        #endif
    }
}
